# Projeto: TailorCV_ACS

## 1. Visão Geral
Plataforma pessoal automatizada para otimização de currículos. O sistema analisa descrições de vagas e utiliza Inteligência Artificial para reescrever *bullet points* e ajustar *keywords* do currículo original (escrito em LaTeX). O objetivo é aumentar a taxa de conversão em *Applicant Tracking Systems* (ATS), sem inventar ou falsificar experiências. A plataforma também contará com um *scraper* ativo para buscar vagas compatíveis.

## 2. Arquitetura e Stack Tecnológico
Foco em arquitetura limpa, modularidade e padrões robustos para futura portabilidade.

* **Frontend:** Flutter (Build inicial para Web, estruturado com padrões de arquitetura mobile nativa para futura migração).
    * **UI/UX:** Estética "Cyberpunk" / "Dark Amethyst" (tons profundos de violeta, índigo e detalhes luminosos). Interface focada em produtividade (visualização do currículo lado a lado com a vaga).
* **Backend:** Python com FastAPI. Orquestração de IA, processamento de texto plano (`.tex`) e execução de comandos de sistema.
* **Infraestrutura Core:** Docker. Contêiner isolado rodando uma distribuição mínima do TeX Live para compilação segura dos PDFs.
* **Banco de Dados e Auth:** Firebase (Firestore para histórico de *prompts*/vagas e Storage para armazenamento das versões `.tex` e `.pdf`).
* **Automação (Scraping):** Playwright (Python). Navegador *headless* para contornar proteções básicas e extrair requisitos dinâmicos de plataformas de vagas.

## 3. Regras de Negócio e Comportamento da IA

### 3.1. Restrições do Modelo de IA
* **Temperatura:** Baixa (`0.1` a `0.2`) para respostas determinísticas.
* **Zero Alucinação:** A IA tem liberdade para reescrever e dar nova ênfase aos *bullet points* das experiências anteriores, mas é **estritamente proibida** de inventar cargos, empresas, métricas ou tecnologias que não estejam no arquivo original.
* **Saída:** A IA deve retornar apenas as partes modificadas do texto para serem injetadas no arquivo `.tex` ou o documento `.tex` inteiro validado, sem quebrar a sintaxe do LaTeX.

### 3.2. Motor LaTeX (Source of Truth)
* O arquivo `.tex` é a única fonte da verdade.
* O backend injeta as modificações no texto plano, aciona o comando `pdflatex` via `subprocess` dentro do contêiner Docker, gera o `.pdf` e devolve a URL final para o frontend.

## 4. Plano de Execução (Roadmap de Desenvolvimento)

A implementação deve ocorrer de dentro para fora, mitigando o maior risco técnico primeiro (a manipulação do LaTeX pela IA).

* **Fase 1: Prova de Conceito (PoC) do Motor Core**
    * Script Python puro local.
    * Leitura de um arquivo `curriculo_base.tex`.
    * Integração com API de LLM (passando uma vaga *hardcoded* e um *System Prompt* rigoroso).
    * Execução local do `pdflatex` via biblioteca `subprocess` para validar se o arquivo gerado não corrompe a formatação estrutural.

* **Fase 2: Containerização e Infraestrutura**
    * Criação do `Dockerfile` contendo Python + TeX Live.
    * Garantia de que a compilação ocorre com sucesso dentro do ambiente isolado.

* **Fase 3: Construção da API (FastAPI) e Integração (Firebase)**
    * Criação do endpoint `/api/v1/tailor`.
    * Integração com Firebase Admin SDK para salvar logs de alterações e armazenar o PDF gerado no Storage.

* **Fase 4: Automação do Scraper**
    * Implementação do script Playwright para buscar um cargo específico.
    * Extração limpa do texto das descrições de vagas.

* **Fase 5: Interface (Flutter)**
    * Desenvolvimento do dashboard Web.
    * Tela de inserção da URL/texto da vaga ou busca via scraper.
    * Visualizador do PDF compilado.
    * Fluxo de aprovação do "Diff" (o que a IA sugeriu alterar vs. o que estava no original) antes da compilação final.