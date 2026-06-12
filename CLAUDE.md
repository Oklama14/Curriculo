# TailorCV_ACS — Developer Guide (CLAUDE.md)

Este documento contém as diretrizes de desenvolvimento, arquitetura do sistema, comandos comuns de execução, testes e regras críticas de negócio para o projeto **TailorCV_ACS**.

---

## 1. Visão Geral do Projeto
A plataforma é um assistente pessoal para otimizar currículos escritos em LaTeX com base nas descrições de vagas coletadas via Scraper (LinkedIn/Gupy) ou inseridas manualmente. A inteligência artificial (Google Gemini) ajusta a ênfase de palavras-chave e reescreve as experiências profissionais para maximizar a compatibilidade com sistemas ATS (*Applicant Tracking Systems*).

### Regra de Ouro (Zero Alucinação)
* **A IA NUNCA deve inventar informações.** Ela pode reescrever, reordenar ou enfatizar habilidades e responsabilidades existentes, mas é terminantemente proibida de criar empresas, cargos, datas, tecnologias ou métricas falsas que não constem no currículo original (`curriculo.tex`).

---

## 2. Comandos Comuns de Desenvolvimento

### 2.1. Backend (FastAPI / Python)

* **Iniciar todos os serviços via Docker:**
  ```bash
  docker compose -f docker/docker-compose.yml up -d
  ```
* **Recompilar a imagem do Docker (forçando atualização de cache do backend):**
  ```bash
  docker compose -f docker/docker-compose.yml build --no-cache
  ```
* **Visualizar logs do backend em tempo real:**
  ```bash
  docker compose -f docker/docker-compose.yml logs -f api
  ```
* **Derrubar contêineres e limpar volumes:**
  ```bash
  docker compose -f docker/docker-compose.yml down -v
  ```

### 2.2. Testes do Backend (Pytest)

* **Executar suíte de testes no ambiente local:**
  ```bash
  pytest backend/tests/ -v
  ```
* **Executar os testes dentro do container Docker ativo:**
  ```bash
  docker compose -f docker/docker-compose.yml exec api pytest backend/tests/ -v
  ```

### 2.3. Frontend (Flutter Web)

* **Atualizar pacotes/dependências Dart:**
  ```bash
  cd frontend
  flutter pub get
  ```
* **Executar análise estática de código (Linter):**
  ```bash
  cd frontend
  flutter analyze
  ```
* **Iniciar o servidor de desenvolvimento para Web:**
  ```bash
  cd frontend
  flutter run -d chrome
  ```
* **Compilar o bundle de produção Web:**
  ```bash
  cd frontend
  flutter build web --release
  ```

---

## 3. Estrutura do Projeto

```
Projeto Currículo/
├── curriculo.tex                    # Currículo original (Source of Truth do usuário)
├── escopo.md                        # Definição e requisitos iniciais do projeto
├── CLAUDE.md                        # Este guia de contexto para desenvolvedores/IAs
│
├── backend/                         # Backend em Python (FastAPI + Gemini + Playwright)
│   ├── requirements.txt             # Dependências Python (google-genai, fastapi, playwright, etc.)
│   ├── .env                         # Variáveis de ambiente locais (GEMINI_API_KEY, etc.)
│   ├── .env.example                 # Exemplo de configuração de ambiente
│   │
│   ├── core/                        # Motor Core
│   │   ├── latex_parser.py          # Parser e reinjeção estrutural de LaTeX
│   │   ├── ai_engine.py             # Interface Gemini (com retry, backoff e fuzzy matching)
│   │   ├── pdf_compiler.py          # Módulo de compilação pdflatex via subprocesso
│   │   ├── prompt_templates.py      # System Prompts estruturados para o Gemini
│   │   └── tailor.py                # Orquestrador central (Parser -> IA -> Compilador)
│   │
│   ├── api/                         # FastAPI Application Layer
│   │   ├── main.py                  # Ponto de entrada FastAPI, CORS e arquivos estáticos
│   │   ├── routes/                  # Endpoints divididos por escopo
│   │   │   ├── tailor.py            # POST /api/v1/tailor/ (processa otimização)
│   │   │   ├── jobs.py              # GET /api/v1/jobs/ & POST /api/v1/jobs/scrape
│   │   │   └── history.py           # GET /api/v1/history/ (timeline de otimizações)
│   │   ├── schemas/
│   │   │   └── models.py            # Modelos Pydantic de requisição e resposta
│   │   └── services/
│   │       └── firebase_service.py  # Serviço Firestore/Storage com fallback em JSON local
│   │
│   ├── scraper/                     # Módulo Scraper (Playwright + stealth)
│   │   ├── base_scraper.py          # Classe abstrata base do Scraper
│   │   ├── gupy_scraper.py          # Extração estruturada de páginas *.gupy.io (API + Playwright)
│   │   └── linkedin_scraper.py      # Extração (Guest API + Playwright stealth anti-bot)
│   │
│   ├── tests/                       # Testes de Integração e Unitários
│   │   ├── test_latex_parser.py     # Validação do Parser LaTeX (12 testes)
│   │   ├── test_ai_engine.py        # Validação do Gemini API integration (6 testes)
│   │   └── test_tailor.py           # Teste E2E do fluxo de otimização (2 testes)
│   │
│   └── output/                      # PDFs e TEXs gerados temporariamente (gitignored)
│
├── docker/                          # Infraestrutura Docker
│   ├── Dockerfile                   # Python + TeX Live (com fontes e idioma português)
│   └── docker-compose.yml           # Definição dos contêineres e volumes de desenvolvimento
│
└── frontend/                        # Interface Web em Flutter
    ├── pubspec.yaml                 # Dependências Dart (http, url_launcher, intl)
    ├── web/                         # Configuração Flutter Web
    └── lib/                         # Código Fonte Dart
        ├── main.dart                # Inicializador de localidade (pt_BR) e runApp
        ├── theme.dart               # Paleta de cores "Dark Amethyst" e decorações
        ├── models/
        │   ├── job_model.dart       # Modelo de dados de vagas coletadas
        │   └── history_model.dart   # Modelo de dados de logs anteriores
        ├── services/
        │   └── api_service.dart     # Cliente de rede HTTP mapeando endpoints
        ├── providers/
        │   └── app_state.dart       # Gerenciamento reativo de estado global (ChangeNotifier)
        ├── widgets/
        │   ├── glass_container.dart # Cartão glassmorphism translúcido com BackdropFilter
        │   └── diff_viewer.dart     # Console terminal renderizando adições/remoções
        └── views/
            ├── main_layout.dart     # Shell unificado com Sidebar e status de API
            ├── dashboard_view.dart  # Cartões de métricas rápidas e atalhos
            ├── tailor_view.dart     # Workspace Split-view principal (Logs + Download PDF)
            ├── history_view.dart    # Timeline de execuções passadas
            └── jobs_view.dart       # Coleta de novas URLs e busca de vagas salvas
```

---

## 4. Diretrizes Arquiteturais e Padrões de Código

### 4.1. Regras do Parser e Compilador LaTeX
* **Preservação de Tags:** O `latex_parser.py` divide o currículo de forma que o Gemini receba apenas o texto plano correspondente aos `\item` das seções editáveis.
* **Marcações Estruturais:** Comandos estruturais LaTeX como `\begin{itemize}`, `\subsection*`, formatações externas ou cabeçalhos **nunca** devem ser enviados para a IA. Ela apenas devolve a lista final de `\item` otimizados.
* **Validação Sintática:** Antes de salvar o arquivo `.tex` e gerar o PDF, o backend deve obrigatoriamente chamar `validate_tex_syntax(content)` para verificar a quantidade de `\item`, `\begin` e `\end` a fim de evitar quebras na compilação do TeX Live.

### 4.2. Segurança e Robustez da API
* **Fallback de Banco de Dados:** O Firebase Admin SDK degrada graciosamente para persistência no disco rígido local (`local_history.json` e `/static/`) caso as chaves não estejam disponíveis. A API deve manter o comportamento idêntico em ambos os modos.
* **Controle de Limites Gemini:** A chamada para otimização de Habilidades e Experiências deve usar a API do Gemini com o parâmetro `max_output_tokens=8192` para evitar truncamento prematuro de listas de competências grandes.
* **CORS:** Liberado globalmente no FastAPI (`allow_origin_regex=".*"`) para permitir conexões de origens locais efêmeras geradas pela ferramenta do Flutter Web (`localhost:XXXXX`).

### 4.3. Interface Dark Amethyst (Flutter Web)
Toda a interface deve respeitar a paleta de cores escuras e glows neon:
* **Fundo Primário:** `#080612` (Espaço profundo)
* **Destaques (Neon Accents):** `#A855F7` (Ametista) e `#6366F1` (Índigo laser)
* **Bordas e Vidro:** Cantos arredondados de `16.0`, opacidades de cores de fundo (como `0.8` ou `0.15`), `BackdropFilter` com sigma X/Y igual a `15.0` e bordas semi-transparentes de `1.2` de espessura.
* **Formato Monospace:** Monospace para exibição do Diff colorido e do código-fonte LaTeX gerado.
* **Acessibilidade de Links:** Downloads e abertura de páginas externas devem utilizar o utilitário `url_launcher` via chamadas assíncronas externas (`LaunchMode.externalApplication`).
