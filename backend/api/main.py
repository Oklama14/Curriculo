"""
main.py — Ponto de entrada da API FastAPI para o AI Resume Tailor.
Configura o app, CORS, monta arquivos estáticos e inclui as rotas.
"""

import os
import logging
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv

# Configura o logging básico para a API
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-8s │ %(name)s │ %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)

# Carrega variáveis de ambiente
env_path = Path("backend/.env")
if env_path.exists():
    load_dotenv(env_path)
    logger.info("✓ Variáveis de ambiente carregadas de %s", env_path)
else:
    load_dotenv()

from .routes import tailor, jobs, history, profile, apply, resume
from .middleware.auth_middleware import FirebaseAuthMiddleware

# Inicializa o FastAPI
app = FastAPI(
    title="AI Resume Tailor & Job Scraper API",
    description="Backend API para otimização de currículos baseados em LaTeX usando Google Gemini.",
    version="1.0.0",
)

# Configura CORS (Cross-Origin Resource Sharing)
# Como é uma aplicação local e de uso pessoal, liberamos todas as origens
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_origin_regex=".*", # Permite subdomínios locais do Flutter
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registra o middleware de autenticação Firebase
app.add_middleware(FirebaseAuthMiddleware)

# Garante que o diretório de saída existe
output_dir = Path("backend/output")
output_dir.mkdir(parents=True, exist_ok=True)

# Monta o diretório de outputs como pasta de arquivos estáticos
# Permite fazer o download dos arquivos compilados em: http://localhost:8000/static/<nome_do_arquivo>
app.mount("/static", StaticFiles(directory=str(output_dir)), name="static")

# Inclui as rotas do projeto
app.include_router(tailor.router, prefix="/api/v1/tailor", tags=["Tailoring"])
app.include_router(jobs.router, prefix="/api/v1/jobs", tags=["Scraper / Vagas"])
app.include_router(history.router, prefix="/api/v1/history", tags=["Histórico"])
app.include_router(profile.router, prefix="/api/v1/profile", tags=["Perfil"])
app.include_router(apply.router, prefix="/api/v1/apply", tags=["Candidatura"])
app.include_router(resume.router, prefix="/api/v1/resume", tags=["Currículo Base"])


@app.get("/api/v1/auth/me")
def get_current_user(request: Request):
    """Retorna os dados do usuário autenticado no request state."""
    return {
        "uid": getattr(request.state, "user_id", None),
        "email": getattr(request.state, "user_email", None)
    }


@app.get("/")
def read_root():
    """Endpoint de checagem de saúde da API."""
    return {
        "status": "online",
        "service": "AI Resume Tailor API",
        "version": "1.0.0",
        "documentation": "/docs"
    }


if __name__ == "__main__":
    import uvicorn
    # Inicializa o servidor local na porta 8000
    uvicorn.run("backend.api.main:app", host="0.0.0.0", port=8000, reload=True)
