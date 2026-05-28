FROM python:3.12-slim

# Instala dependências do sistema e TeX Live mínimo para compilar o currículo
RUN apt-get update && apt-get install -y --no-install-recommends \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-lang-portuguese \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia os arquivos de requisitos primeiro para aproveitar o cache do Docker
COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copia os diretórios do projeto
COPY backend/ ./backend/
COPY curriculo.tex .

# Instala o navegador Chromium do Playwright e suas dependências de sistema
RUN apt-get update && \
    playwright install chromium && \
    playwright install-deps chromium && \
    rm -rf /var/lib/apt/lists/*

# Configura variável de ambiente para encoding UTF-8 no Python
ENV PYTHONIOENCODING=utf-8

# Inicia o servidor FastAPI com recarregamento desativado em produção
CMD ["uvicorn", "backend.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
