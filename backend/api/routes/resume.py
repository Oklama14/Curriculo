"""
resume.py — Rotas para upload e gerenciamento do currículo base LaTeX.

Permite que qualquer usuário faça upload do seu próprio arquivo .tex,
substituindo o currículo base usado pelo sistema de tailoring.
"""

import os
import logging
from pathlib import Path
from datetime import datetime

from fastapi import APIRouter, HTTPException, UploadFile, File
from ..schemas.models import ResumeUploadResponse, ResumeInfoResponse
from ...core.latex_parser import validate_tex_syntax

logger = logging.getLogger(__name__)
router = APIRouter()

# Tamanho máximo permitido para upload: 500KB
MAX_FILE_SIZE = 512_000


def _resolve_tex_path() -> Path:
    """Resolve o caminho do currículo base .tex."""
    tex_path = os.getenv("RESUME_TEX_PATH", "curriculo.tex")
    resolved = Path(tex_path)
    if not resolved.is_absolute():
        # Tenta resolver a partir da raiz do projeto
        root_path = Path(__file__).resolve().parent.parent.parent.parent / "curriculo.tex"
        if root_path.exists():
            return root_path
        # Caso contrário, usa o caminho padrão para criar o arquivo
        return root_path
    return resolved


@router.post("/upload", response_model=ResumeUploadResponse)
async def upload_resume(file: UploadFile = File(...)):
    """
    Faz upload de um novo currículo base .tex.

    O arquivo substitui o currículo anterior e será usado em todas as
    futuras otimizações via Gemini.

    Validações:
    - Apenas arquivos .tex são aceitos
    - Tamanho máximo: 500KB
    - Sintaxe LaTeX básica deve ser válida (\\documentclass, balanceamento de {})
    """
    # Valida a extensão do arquivo
    if not file.filename or not file.filename.endswith(".tex"):
        raise HTTPException(
            status_code=400,
            detail="Apenas arquivos .tex (LaTeX) são aceitos. "
                   "Envie seu currículo no formato LaTeX."
        )

    # Lê o conteúdo do arquivo
    content_bytes = await file.read()

    # Valida tamanho
    if len(content_bytes) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"Arquivo muito grande ({len(content_bytes)} bytes). "
                   f"Limite máximo: {MAX_FILE_SIZE} bytes (500KB)."
        )

    # Decodifica o conteúdo
    try:
        content = content_bytes.decode("utf-8")
    except UnicodeDecodeError:
        try:
            content = content_bytes.decode("latin-1")
        except Exception:
            raise HTTPException(
                status_code=400,
                detail="Não foi possível decodificar o arquivo. "
                       "Certifique-se de que o arquivo está em UTF-8 ou Latin-1."
            )

    # Valida que o conteúdo não está vazio
    if not content.strip():
        raise HTTPException(
            status_code=400,
            detail="O arquivo enviado está vazio."
        )

    # Valida a sintaxe LaTeX usando o validador existente
    is_valid, syntax_errors = validate_tex_syntax(content)
    if not is_valid:
        raise HTTPException(
            status_code=422,
            detail=f"O arquivo .tex possui erros de sintaxe LaTeX: "
                   f"{'; '.join(syntax_errors)}. "
                   f"Corrija os erros e tente novamente."
        )

    # Resolve o caminho e salva o arquivo
    tex_path = _resolve_tex_path()

    try:
        tex_path.write_text(content, encoding="utf-8")
        logger.info(
            "✓ Currículo base atualizado: %s (%d bytes, arquivo original: %s)",
            tex_path, len(content_bytes), file.filename,
        )
    except Exception as e:
        logger.exception("Erro ao salvar currículo: %s", e)
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao salvar o arquivo: {str(e)}"
        )

    # Conta seções encontradas para feedback ao usuário
    import re
    sections = re.findall(r'\\section\{(.+?)\}', content)

    return ResumeUploadResponse(
        success=True,
        filename=file.filename,
        size_bytes=len(content_bytes),
        sections_found=sections,
        message=f"Currículo '{file.filename}' carregado com sucesso! "
                f"Seções detectadas: {', '.join(sections) if sections else 'nenhuma'}.",
    )


@router.get("/current", response_model=ResumeInfoResponse)
async def get_current_resume():
    """
    Retorna informações sobre o currículo base atualmente carregado.
    """
    tex_path = _resolve_tex_path()

    if not tex_path.exists():
        raise HTTPException(
            status_code=404,
            detail="Nenhum currículo base encontrado. "
                   "Faça upload de um arquivo .tex primeiro."
        )

    try:
        content = tex_path.read_text(encoding="utf-8")
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Erro ao ler o currículo base."
        )

    import re
    sections = re.findall(r'\\section\{(.+?)\}', content)

    # Obtém data de modificação do arquivo
    stat = tex_path.stat()
    modified_at = datetime.fromtimestamp(stat.st_mtime).isoformat()

    return ResumeInfoResponse(
        filename=tex_path.name,
        size_bytes=len(content.encode("utf-8")),
        sections_found=sections,
        modified_at=modified_at,
        exists=True,
    )


@router.get("/preview")
async def preview_resume():
    """
    Retorna o conteúdo completo do currículo .tex atual para preview.
    """
    tex_path = _resolve_tex_path()

    if not tex_path.exists():
        raise HTTPException(
            status_code=404,
            detail="Nenhum currículo base encontrado."
        )

    try:
        content = tex_path.read_text(encoding="utf-8")
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Erro ao ler o currículo base."
        )

    return {"content": content}
