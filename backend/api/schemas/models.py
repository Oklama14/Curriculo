"""
models.py — Modelos Pydantic para os esquemas de entrada e saída da API.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class TailorRequest(BaseModel):
    """Corpo da requisição para otimizar um currículo."""
    job_description: str = Field(
        ..., 
        description="Descrição em texto puro da vaga de emprego alvo."
    )
    tailor_skills: bool = Field(
        True, 
        description="Se True, também otimiza a seção de habilidades."
    )
    compile_pdf: bool = Field(
        True, 
        description="Se True, tenta compilar o PDF (caso pdflatex esteja disponível)."
    )


class TailorResponse(BaseModel):
    """Resposta contendo os resultados da otimização."""
    success: bool
    diff: str = Field(..., description="Diff visual comparando o original com o modificado.")
    tex_content: str = Field(..., description="Conteúdo LaTeX modificado.")
    pdf_url: Optional[str] = Field(None, description="URL ou caminho local para download do PDF gerado.")
    tex_url: Optional[str] = Field(None, description="URL ou caminho local para download do arquivo .tex.")
    errors: List[str] = Field(default_factory=list, description="Lista de erros ou avisos ocorridos.")


class JobScrapeRequest(BaseModel):
    """Corpo da requisição para extrair vaga de uma URL."""
    url: str = Field(..., description="URL da vaga (LinkedIn, Gupy, etc.)")


class JobScrapeResponse(BaseModel):
    """Resposta da extração da vaga."""
    url: str
    title: str = Field(..., description="Título do cargo da vaga.")
    company: str = Field(..., description="Nome da empresa.")
    description: str = Field(..., description="Descrição completa da vaga.")
    extracted_at: datetime = Field(default_factory=datetime.utcnow)


class HistoryItem(BaseModel):
    """Item individual no histórico de otimizações."""
    id: str
    timestamp: str
    job_description: str
    diff: str
    pdf_url: Optional[str] = None
    tex_url: Optional[str] = None


class UserProfile(BaseModel):
    """Modelo representando o perfil de um usuário."""
    name: str
    email: str
    linkedin_url: Optional[str] = None
    gupy_url: Optional[str] = None
    photo_url: Optional[str] = None


class ProfileUpdateRequest(BaseModel):
    """Campos que podem ser atualizados no perfil."""
    name: Optional[str] = None
    linkedin_url: Optional[str] = None
    gupy_url: Optional[str] = None
    photo_url: Optional[str] = None


class ApplyProfileInfo(BaseModel):
    """Informações de perfil embutidas na resposta de candidatura."""
    name: str
    linkedin_url: Optional[str] = None


class ApplyPrepareRequest(BaseModel):
    """Corpo da requisição para preparar candidatura."""
    job_url: str
    tailor_run_id: str


class ApplyPrepareResponse(BaseModel):
    """Resposta contendo os detalhes para a candidatura semi-automática."""
    job_url: str
    apply_url: str
    pdf_url: Optional[str] = None
    pdf_filename: Optional[str] = None
    job_title: str
    company: str
    profile: ApplyProfileInfo
    checklist: List[str]


class ResumeUploadResponse(BaseModel):
    """Resposta após upload bem-sucedido do currículo .tex."""
    success: bool
    filename: str = Field(..., description="Nome original do arquivo enviado.")
    size_bytes: int = Field(..., description="Tamanho do arquivo em bytes.")
    sections_found: List[str] = Field(
        default_factory=list,
        description="Seções LaTeX detectadas no currículo (ex: Experiência, Habilidades)."
    )
    message: str = Field(..., description="Mensagem de confirmação.")


class ResumeInfoResponse(BaseModel):
    """Informações sobre o currículo base atualmente carregado."""
    filename: str = Field(..., description="Nome do arquivo .tex.")
    size_bytes: int = Field(..., description="Tamanho do arquivo em bytes.")
    sections_found: List[str] = Field(
        default_factory=list,
        description="Seções LaTeX detectadas."
    )
    modified_at: str = Field(..., description="Data da última modificação (ISO 8601).")
    exists: bool = Field(True, description="Se o arquivo existe no sistema.")
