# TailorCV_ACS 🤖📄

Uma plataforma automatizada pessoal para otimização de currículos e coleta de vagas de emprego. O sistema analisa descrições de vagas recolhidas via Web Scraping (LinkedIn/Gupy) ou fornecidas manualmente, e utiliza a Inteligência Artificial do Google Gemini para reescrever as experiências e enfatizar palavras-chave do currículo original (escrito em LaTeX), maximizando a compatibilidade com sistemas ATS (*Applicant Tracking Systems*).

Tudo isso é feito respeitando a **Regra de Ouro**: **Zero Alucinação** (sem inventar nenhuma experiência, cargo ou tecnologia que não existam no currículo base).

---

## 🚀 Principais Funcionalidades

* **Otimização Inteligente**: Processamento inteligente de textos LaTeX estruturados usando a API do Google Gemini, preservando a sintaxe LaTeX original.
* **Compilação Segura de PDF**: Compilação local automatizada usando `pdflatex` via subprocesso em container isolado Docker.
* **Scraper Integrado**: Coleta automatizada de vagas (LinkedIn e Gupy) usando Playwright Stealth para obter descrições completas e detalhadas de requisitos.
* **Visualização de Diff Interativa**: Comparativo em tempo real (versão original vs. otimizada) antes de decidir compilar o arquivo final.
* **Upload Dinâmico de Currículo**: Qualquer usuário pode fazer o upload do seu próprio arquivo `.tex` pela interface web para utilizá-lo como o currículo base em tempo real.
* **Firebase com Fallback Local**: Login de usuários e persistência do histórico com Firebase Auth/Firestore/Storage. Se as chaves não estiverem configuradas, o sistema degrada graciosamente para salvar os dados localmente em arquivos JSON.
* **Interface "Dark Amethyst"**: UI moderna e fluida desenvolvida em Flutter Web com estética escura premium, efeitos de Glassmorphism e layouts responsivos de split-view.

---

## 🛠️ Stack Tecnológico

* **Backend**: Python 3.11, FastAPI, Pydantic, Playwright (Scraping), Google GenAI SDK (Gemini API)
* **Frontend**: Flutter Web (Dart), ChangeNotifier (Gerenciamento de Estado), Glassmorphism UI
* **Ambiente & Compilação**: Docker, TeX Live (pdflatex) com fontes padrão brasileiras
* **Serviços Cloud**: Firebase (Auth, Firestore, Cloud Storage)

---

## 📁 Estrutura do Repositório

```text
Projeto Currículo/
├── curriculo.tex            # Currículo base atual (pode ser sobrescrito via upload na UI)
├── escopo.md                # Requisitos iniciais do projeto
├── CLAUDE.md                # Guia de desenvolvimento e atalhos rápidos
├── README.md                # Este guia explicativo do projeto
│
├── backend/                 # API FastAPI e motor Python
│   ├── api/                 # Rotas da API, esquemas e serviços
│   ├── core/                # Parser LaTeX, compilador de PDF e orquestrador de IA
│   ├── scraper/             # Web scrapers em Playwright para Gupy e LinkedIn
│   ├── tests/               # Suíte de testes automatizados com Pytest
│   └── output/              # PDFs/TEXs gerados e fallback local (gitignored)
│
├── docker/                  # Configurações do Docker e Docker Compose
└── frontend/                # Interface Flutter Web
```

---

## ⚙️ Configuração Inicial

### 1. Pré-requisitos
* Docker e Docker Compose instalados.
* Flutter SDK (caso queira rodar o frontend sem Docker localmente).
* Chave de API do Google Gemini.

### 2. Configurando o Ambiente (.env)
Crie um arquivo `.env` na pasta `backend/` com base no template `.env.example`:

```bash
cp backend/.env.example backend/.env
```

Edite o arquivo `backend/.env` preenchendo as chaves necessárias:
```ini
# Chave de API do Gemini (Obrigatória)
GEMINI_API_KEY=sua_chave_gemini_aqui

# Configurações do Firebase (Opcional - caso omitido, usará fallback local)
FIREBASE_CREDENTIALS_PATH=backend/firebase-credentials.json
FIREBASE_STORAGE_BUCKET=seu-app.appspot.com

# Variáveis opcionais do Scraper
HEADLESS_SCRAPER=true
```

---

## 🐳 Como Executar a Aplicação

### Modo 1: Tudo via Docker (Recomendado)

O Docker Compose inicializa o backend FastAPI com suporte ao TeX Live pré-configurado e serve os arquivos estáticos do frontend.

1. **Iniciar a aplicação**:
   ```bash
   docker compose -f docker/docker-compose.yml up -d
   ```
2. **Acessar os serviços**:
   * API Backend: [http://localhost:8000](http://localhost:8000)
   * Documentação Swagger (Swagger UI): [http://localhost:8000/docs](http://localhost:8000/docs)
   * Interface Web (Frontend): [http://localhost:8000/](http://localhost:8000/)

3. **Ver logs em tempo real**:
   ```bash
   docker compose -f docker/docker-compose.yml logs -f api
   ```

4. **Derrubar os contêineres**:
   ```bash
   docker compose -f docker/docker-compose.yml down
   ```

---

### Modo 2: Execução Local Separada (Desenvolvimento)

#### Backend
Se preferir rodar o backend localmente sem Docker (necessita de `pdflatex` instalado no PATH do seu sistema operacional):

1. Crie e ative um ambiente virtual Python:
   ```bash
   cd backend
   python -m venv .venv
   # No Windows:
   .venv\Scripts\activate
   # No Linux/macOS:
   source .venv/bin/activate
   ```
2. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   playwright install
   ```
3. Inicie o servidor Uvicorn:
   ```bash
   uvicorn api.main:app --reload --port 8000
   ```

#### Frontend (Flutter Web)
1. Instale as dependências Dart/Flutter:
   ```bash
   cd frontend
   flutter pub get
   ```
2. Inicie o servidor de desenvolvimento do Flutter:
   ```bash
   flutter run -d chrome --web-port 3000
   ```

---

## 🧪 Testes Automatizados

A suíte de testes valida o compilador PDF, o analisador LaTeX e a orquestração da inteligência artificial.

* **Executar localmente**:
  ```bash
  pytest backend/tests/ -v
  ```
* **Executar dentro do contêiner Docker**:
  ```bash
  docker compose -f docker/docker-compose.yml exec api pytest backend/tests/ -v
  ```

---

## ⚠️ Regra de Ouro: Zero Alucinação

O motor de IA (`backend/core/ai_engine.py`) e os templates de prompt (`backend/core/prompt_templates.py`) foram rigorosamente programados sob restrições estritas de alucinação:
1. **Veracidade**: A IA apenas reescreve ou reorganiza a ênfase de experiências reais que o usuário incluiu em seu `curriculo.tex` base.
2. **Nenhuma Criação**: É proibido criar datas, projetos fictícios, empresas não declaradas ou aumentar proficiências técnicas artificialmente.
3. **Validação Estrutural**: O `latex_parser.py` valida a paridade de chaves, blocos `\begin` e `\end` no LaTeX gerado antes de submetê-lo à compilação, prevenindo falhas de compilação.
