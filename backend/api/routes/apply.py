"""
apply.py — Rota para preparar candidatura semi-automática.
"""

import logging
from pathlib import Path
from fastapi import APIRouter, Depends, Request, HTTPException
from ..schemas.models import ApplyPrepareRequest, ApplyPrepareResponse, ApplyProfileInfo
from ..services.firebase_service import get_firebase_service, FirebaseService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/prepare", response_model=ApplyPrepareResponse)
def prepare_application(
    request: Request,
    apply_req: ApplyPrepareRequest,
    firebase: FirebaseService = Depends(get_firebase_service)
):
    """
    Prepara o pacote de candidatura com base na vaga e na execução de tailoring.
    """
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=401, detail="Usuário não autenticado")

    # 1. Busca perfil do usuário
    profile_data = firebase.get_profile(user_id)
    profile_info = ApplyProfileInfo(
        name=profile_data.get("name", "Usuário"),
        linkedin_url=profile_data.get("linkedin_url")
    )

    # 2. Busca a execução do tailor run
    tailor_run = firebase.get_tailor_run(user_id, apply_req.tailor_run_id)
    if not tailor_run:
        raise HTTPException(
            status_code=404, 
            detail=f"Execução do Tailor com ID '{apply_req.tailor_run_id}' não encontrada."
        )

    pdf_url = tailor_run.get("pdf_url")
    pdf_filename = Path(pdf_url).name if pdf_url else "curriculo_otimizado.pdf"

    # 3. Busca a vaga nos scraped_jobs para obter título e empresa
    scraped_jobs = firebase.get_scraped_jobs(user_id)
    job_title = "Vaga Otimizada"
    company = "Empresa"
    
    for job in scraped_jobs:
        # Tenta match exato ou parcial da URL
        if job.get("url") == apply_req.job_url or apply_req.job_url in job.get("url", ""):
            job_title = job.get("title", job_title)
            company = job.get("company", company)
            break

    # 4. Constrói checklist
    checklist = []
    
    if pdf_url:
        checklist.append("✅ Currículo otimizado e compilado")
        checklist.append("✅ PDF disponível para download")
    else:
        checklist.append("⚠️ Currículo otimizado (compilação do PDF falhou)")
        checklist.append("❌ PDF indisponível")

    if profile_info.linkedin_url:
        checklist.append("✅ Conta LinkedIn configurada no perfil")
    else:
        checklist.append("⚠️ LinkedIn não configurado no perfil")

    checklist.append("⏳ Abra o link e faça upload do PDF no navegador")

    # 5. Define URL de candidatura
    apply_url = apply_req.job_url

    return ApplyPrepareResponse(
        job_url=apply_req.job_url,
        apply_url=apply_url,
        pdf_url=pdf_url,
        pdf_filename=pdf_filename,
        job_title=job_title,
        company=company,
        profile=profile_info,
        checklist=checklist
    )
