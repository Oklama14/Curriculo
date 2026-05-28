"""
firebase_service.py — Serviço para interagir com Firestore e Storage (Firebase Admin SDK).
Possui fallback transparente para o sistema de arquivos local se credenciais não forem fornecidas.

Este módulo exporta get_firebase_service() como singleton para uso em Depends().
"""

import os
import json
import logging
from pathlib import Path
from datetime import datetime
from functools import lru_cache
from uuid import uuid4

logger = logging.getLogger(__name__)

# Tenta importar as dependências do Firebase
try:
    import firebase_admin
    from firebase_admin import credentials, firestore, storage
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    logger.warning("Firebase Admin SDK não instalado. Usando fallback local.")


# Diretório de output resolvido de forma robusta (relativo a este arquivo)
_OUTPUT_DIR = Path(__file__).resolve().parent.parent.parent / "output"


class FirebaseService:
    """Serviço de banco de dados e storage. Suporta Firebase e fallback local."""

    def __init__(self):
        self.db = None
        self.bucket = None
        self.is_firebase_active = False

        if not FIREBASE_AVAILABLE:
            self._setup_local_fallback()
            return

        # Tenta inicializar o Firebase
        # 1. Procura por variável de ambiente com o caminho do JSON
        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
        
        # 2. Procura no local padrão do backend
        if not cred_path:
            default_path = Path("backend/firebase-credentials.json")
            if default_path.exists():
                cred_path = str(default_path)

        bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")

        if cred_path and os.path.exists(cred_path):
            try:
                # Inicializa app padrão se ainda não inicializado
                if not firebase_admin._apps:
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred, {
                        'storageBucket': bucket_name
                    })
                
                self.db = firestore.client()
                if bucket_name:
                    self.bucket = storage.bucket()
                
                self.is_firebase_active = True
                logger.info("Firebase inicializado com sucesso!")
            except Exception as e:
                logger.error("Erro ao inicializar Firebase: %s. Usando fallback local.", e)
                self._setup_local_fallback()
        else:
            logger.info("Credenciais do Firebase não encontradas. Usando fallback local.")
            self._setup_local_fallback()

    def _setup_local_fallback(self):
        """Prepara os diretórios locais para persistência mockada."""
        self.is_firebase_active = False
        self.local_dir = _OUTPUT_DIR
        self.local_dir.mkdir(parents=True, exist_ok=True)
        logger.info("Fallback local ativo. Dados salvos em: %s", self.local_dir)

    def get_profile(self, user_id: str) -> dict:
        """Recupera o perfil do usuário."""
        if self.is_firebase_active:
            try:
                doc = self.db.collection("users").document(user_id).get()
                if doc.exists:
                    return doc.to_dict()
                else:
                    # Se o perfil não existe no Firestore, cria um padrão e retorna
                    default_profile = {
                        "name": "Usuário Firebase",
                        "email": "",
                        "linkedin_url": "",
                        "gupy_url": "",
                        "photo_url": ""
                    }
                    return default_profile
            except Exception as e:
                logger.error("Erro ao obter perfil no Firestore: %s", e)
                return self._get_local_profile(user_id)
        else:
            return self._get_local_profile(user_id)

    def _get_local_profile(self, user_id: str) -> dict:
        profile_file = self.local_dir / f"local_profile_{user_id}.json"
        if not profile_file.exists():
            default_profile = {
                "name": "Usuário Local Dev",
                "email": "local_dev_user@example.com",
                "linkedin_url": "",
                "gupy_url": "",
                "photo_url": "https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y"
            }
            profile_file.write_text(json.dumps(default_profile, indent=2, ensure_ascii=False), encoding="utf-8")
            return default_profile
        try:
            return json.loads(profile_file.read_text(encoding="utf-8"))
        except Exception:
            return {}

    def update_profile(self, user_id: str, data: dict) -> dict:
        """Atualiza ou cria o perfil do usuário."""
        if self.is_firebase_active:
            try:
                self.db.collection("users").document(user_id).set(data, merge=True)
                doc = self.db.collection("users").document(user_id).get()
                return doc.to_dict()
            except Exception as e:
                logger.error("Erro ao atualizar perfil no Firestore: %s", e)
                return self._update_local_profile(user_id, data)
        else:
            return self._update_local_profile(user_id, data)

    def _update_local_profile(self, user_id: str, data: dict) -> dict:
        current = self._get_local_profile(user_id)
        for k, v in data.items():
            if v is not None:
                current[k] = v
        profile_file = self.local_dir / f"local_profile_{user_id}.json"
        profile_file.write_text(json.dumps(current, indent=2, ensure_ascii=False), encoding="utf-8")
        return current

    def save_tailor_run(
        self,
        user_id: str,
        job_description: str,
        diff: str,
        tex_path: str,
        pdf_path: str | None = None,
    ) -> dict:
        """
        Salva o log de execução do tailoring no banco de dados e arquivos no Storage/local.
        """
        run_id = str(uuid4())
        timestamp = datetime.now().isoformat()
        
        tex_url = None
        pdf_url = None

        # 1. Faz upload ou cópia dos arquivos
        if self.is_firebase_active:
            try:
                # Upload do TEX
                if tex_path and os.path.exists(tex_path):
                    blob_tex = self.bucket.blob(f"users/{user_id}/tailored/{run_id}/curriculo.tex")
                    blob_tex.upload_from_filename(tex_path)
                    blob_tex.make_public()
                    tex_url = blob_tex.public_url
                
                # Upload do PDF
                if pdf_path and os.path.exists(pdf_path):
                    blob_pdf = self.bucket.blob(f"users/{user_id}/tailored/{run_id}/curriculo.pdf")
                    blob_pdf.upload_from_filename(pdf_path)
                    blob_pdf.make_public()
                    pdf_url = blob_pdf.public_url
            except Exception as e:
                logger.error("Erro no upload de arquivos para Firebase Storage: %s", e)
                tex_url = f"/static/{Path(tex_path).name}" if tex_path else None
                pdf_url = f"/static/{Path(pdf_path).name}" if pdf_path else None
        else:
            tex_url = f"/static/{Path(tex_path).name}" if tex_path else None
            pdf_url = f"/static/{Path(pdf_path).name}" if pdf_path else None

        # 2. Persiste metadados no banco
        run_data = {
            "id": run_id,
            "timestamp": timestamp,
            "job_description": job_description,
            "diff": diff,
            "tex_url": tex_url,
            "pdf_url": pdf_url,
        }

        if self.is_firebase_active:
            try:
                self.db.collection("users").document(user_id).collection("tailoring_history").document(run_id).set(run_data)
            except Exception as e:
                logger.error("Erro ao salvar no Firestore: %s", e)
                self._save_to_local_history(user_id, run_data)
        else:
            self._save_to_local_history(user_id, run_data)

        return run_data

    def _save_to_local_history(self, user_id: str, run_data: dict):
        """Salva a execução no arquivo local_history_{user_id}.json."""
        try:
            history_file = self.local_dir / f"local_history_{user_id}.json"
            if not history_file.exists():
                history_file.write_text(json.dumps([]), encoding="utf-8")
            history = json.loads(history_file.read_text(encoding="utf-8"))
            history.insert(0, run_data)  # Insere no início
            history_file.write_text(json.dumps(history, indent=2, ensure_ascii=False), encoding="utf-8")
        except Exception as e:
            logger.error("Falha ao salvar no histórico local: %s", e)

    def get_history(self, user_id: str) -> list[dict]:
        """Recupera a lista de execuções de tailoring."""
        if self.is_firebase_active:
            try:
                docs = self.db.collection("users").document(user_id).collection("tailoring_history").order_by("timestamp", direction=firestore.Query.DESCENDING).stream()
                return [doc.to_dict() for doc in docs]
            except Exception as e:
                logger.error("Erro ao carregar histórico do Firestore: %s", e)
                return self._get_local_history(user_id)
        else:
            return self._get_local_history(user_id)

    def _get_local_history(self, user_id: str) -> list[dict]:
        """Recupera o histórico do arquivo JSON local."""
        try:
            history_file = self.local_dir / f"local_history_{user_id}.json"
            if not history_file.exists():
                return []
            return json.loads(history_file.read_text(encoding="utf-8"))
        except Exception:
            return []

    def get_tailor_run(self, user_id: str, run_id: str) -> dict | None:
        """Recupera uma execução de tailoring específica."""
        if self.is_firebase_active:
            try:
                doc = self.db.collection("users").document(user_id).collection("tailoring_history").document(run_id).get()
                if doc.exists:
                    return doc.to_dict()
                return None
            except Exception as e:
                logger.error("Erro ao carregar tailor run do Firestore: %s", e)
                return self._get_local_tailor_run(user_id, run_id)
        else:
            return self._get_local_tailor_run(user_id, run_id)

    def _get_local_tailor_run(self, user_id: str, run_id: str) -> dict | None:
        history = self.get_history(user_id)
        for item in history:
            if item.get("id") == run_id:
                return item
        return None

    def save_scraped_job(self, user_id: str, job_data: dict) -> dict:
        """Persiste uma vaga extraída no banco/local."""
        job_id = str(uuid4())
        job_data["id"] = job_id
        if "extracted_at" not in job_data:
            job_data["extracted_at"] = datetime.now().isoformat()

        if self.is_firebase_active:
            try:
                self.db.collection("users").document(user_id).collection("scraped_jobs").document(job_id).set(job_data)
            except Exception as e:
                logger.error("Erro ao salvar vaga no Firestore: %s", e)
                self._save_to_local_jobs(user_id, job_data)
        else:
            self._save_to_local_jobs(user_id, job_data)
            
        return job_data

    def _save_to_local_jobs(self, user_id: str, job_data: dict):
        """Salva vaga no arquivo local_scraped_jobs_{user_id}.json."""
        try:
            jobs_file = self.local_dir / f"local_scraped_jobs_{user_id}.json"
            if not jobs_file.exists():
                jobs_file.write_text(json.dumps([]), encoding="utf-8")
            jobs = json.loads(jobs_file.read_text(encoding="utf-8"))
            jobs.insert(0, job_data)
            jobs_file.write_text(json.dumps(jobs, indent=2, ensure_ascii=False), encoding="utf-8")
        except Exception as e:
            logger.error("Falha ao salvar vaga local: %s", e)

    def get_scraped_jobs(self, user_id: str) -> list[dict]:
        """Recupera a lista de vagas salvas."""
        if self.is_firebase_active:
            try:
                docs = self.db.collection("users").document(user_id).collection("scraped_jobs").order_by("extracted_at", direction=firestore.Query.DESCENDING).stream()
                return [doc.to_dict() for doc in docs]
            except Exception as e:
                logger.error("Erro ao carregar vagas do Firestore: %s", e)
                return self._get_local_jobs(user_id)
        else:
            return self._get_local_jobs(user_id)

    def _get_local_jobs(self, user_id: str) -> list[dict]:
        """Recupera as vagas salvas localmente."""
        try:
            jobs_file = self.local_dir / f"local_scraped_jobs_{user_id}.json"
            if not jobs_file.exists():
                return []
            return json.loads(jobs_file.read_text(encoding="utf-8"))
        except Exception:
            return []


@lru_cache(maxsize=1)
def get_firebase_service() -> FirebaseService:
    """
    Retorna uma instância singleton do FirebaseService.
    Usar como dependência FastAPI: Depends(get_firebase_service)
    """
    return FirebaseService()
