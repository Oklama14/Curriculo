"""
tailor.py — Rota para processar a otimização de currículos.
"""

import os
import asyncio
import logging
from pathlib import Path
from fastapi import APIRouter, HTTPException, Depends, Request
from ...core.tailor import ResumeTailor
from ..schemas.models import TailorRequest, TailorResponse
from ..services.firebase_service import get_firebase_service, FirebaseService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/", response_model=TailorResponse)
async def tailor_resume(
    request: TailorRequest,
    http_request: Request,
    firebase: FirebaseService = Depends(get_firebase_service)
):
    """
    Otimiza o currículo base para a vaga fornecida.
    Salva os resultados no Firebase/local e retorna o diff e conteúdos.

    Usa asyncio.to_thread para executar a operação de tailoring (que é
    bloqueante por causa da chamada ao Gemini) sem bloquear o event loop.
    """
    # Resolve o caminho do currículo base
    tex_path = os.getenv("RESUME_TEX_PATH", "curriculo.tex")
    
    # Normalização robusta de caminhos
    resolved_path = Path(tex_path)
    if not resolved_path.exists():
        # Tenta resolver a partir da raiz se rodando de subdiretório
        root_path = Path(__file__).resolve().parent.parent.parent.parent / "curriculo.tex"
        if root_path.exists():
            resolved_path = root_path
        else:
            raise HTTPException(
                status_code=404,
                detail=f"Currículo base não encontrado em: {tex_path}. Configure RESUME_TEX_PATH no .env."
            )

    logger.info("Iniciando tailoring usando currículo base: %s", resolved_path)

    try:
        # Instancia o orquestrador core
        tailor = ResumeTailor(
            tex_path=resolved_path,
            output_dir="backend/output",
        )

        # Executa a operação de tailoring em uma thread separada para não
        # bloquear o event loop do FastAPI durante a chamada ao Gemini
        result = await asyncio.to_thread(
            tailor.tailor,
            job_description=request.job_description,
            tailor_skills=request.tailor_skills,
            compile_pdf=request.compile_pdf,
        )

        if not result.success:
            raise HTTPException(
                status_code=500,
                detail=f"Falha ao realizar otimização do currículo: {', '.join(result.errors)}"
            )

        # Salva o resultado no banco/sistema de arquivos local
        user_id = getattr(http_request.state, "user_id", "local_dev_user")
        saved_run = firebase.save_tailor_run(
            user_id=user_id,
            job_description=request.job_description,
            diff=result.diff_text,
            tex_path=result.tex_path,
            pdf_path=result.pdf_path if result.pdf_path else None
        )

        return TailorResponse(
            success=True,
            diff=result.diff_text,
            tex_content=result.modified_tex,
            pdf_url=saved_run.get("pdf_url"),
            tex_url=saved_run.get("tex_url"),
            errors=result.errors
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Erro interno na rota de tailoring: %s", e)
        raise HTTPException(
            status_code=500,
            detail=f"Erro interno do servidor: {str(e)}"
        )
