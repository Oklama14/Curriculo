"""
linkedin_scraper.py — Scraper para a plataforma LinkedIn (linkedin.com).

Estratégia de extração (em ordem de tentativa):
  1. Guest API pública (jobs-guest) — rápida, mas frequentemente bloqueada pelo LinkedIn.
  2. Playwright com stealth — navegador headless com disfarce anti-bot.

Dependências:
  - httpx (async HTTP client)
  - playwright (headless browser)
  - playwright-stealth (anti-detection patches)
  - beautifulsoup4 (HTML parser)
"""

import re
import httpx
import logging
from bs4 import BeautifulSoup
from urllib.parse import urlparse
from playwright.async_api import async_playwright

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)

# Tenta importar playwright-stealth (opcional mas altamente recomendado)
try:
    from playwright_stealth import stealth_async
    STEALTH_AVAILABLE = True
except ImportError:
    STEALTH_AVAILABLE = False
    logger.warning(
        "playwright-stealth não instalado. O LinkedIn pode bloquear o scraper. "
        "Instale com: pip install playwright-stealth"
    )


# Seletores CSS atualizados para LinkedIn 2024/2025 (múltiplas variantes para resiliência)
SELECTORS = {
    "title": [
        ".job-details-jobs-unified-top-card__job-title",
        ".jobs-unified-top-card__job-title",
        "h1.top-card-layout__title",
        "h1.t-24.t-bold",
        "h1",
    ],
    "company": [
        ".job-details-jobs-unified-top-card__company-name",
        ".jobs-unified-top-card__company-name a",
        ".jobs-unified-top-card__company-name",
        ".topcard__org-name-link",
        "a[href*='/company/']",
    ],
    "description": [
        ".jobs-description__content",
        ".jobs-box__html-content",
        ".jobs-description-content__text",
        ".show-more-less-html__markup",
        ".description__text",
        "#job-details",
    ],
    "show_more": [
        "button.jobs-description__footer-button",
        "button.show-more-less-html__button--more",
        "[aria-label='Exibir mais']",
        "[aria-label='Show more']",
    ],
}

# Headers realistas para requisições HTTP
DEFAULT_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "DNT": "1",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-User": "?1",
    "Cache-Control": "max-age=0",
}


class LinkedInScraper(BaseScraper):
    """Scraper para extração de vagas do LinkedIn."""

    async def scrape_job(self, url: str) -> dict:
        logger.info("Iniciando extração LinkedIn para: %s", url)

        # Extrai o ID da vaga da URL
        job_id = self._extract_job_id(url)
        if job_id:
            try:
                guest_data = await self._scrape_via_guest_api(job_id, url)
                if guest_data:
                    logger.info("Extração LinkedIn concluída com sucesso via Guest API.")
                    return guest_data
            except Exception as e:
                logger.warning("Falha ao extrair via Guest API do LinkedIn: %s. Tentando Playwright...", e)

        # Fallback para Playwright com stealth
        return await self._scrape_via_playwright(url)

    def _extract_job_id(self, url: str) -> str | None:
        """Extrai o ID numérico da vaga a partir da URL do LinkedIn."""
        # Padrões comuns:
        # /jobs/view/3847291048
        # /jobs/view/title-3847291048
        # ?currentJobId=3847291048
        match_view = re.search(r'/jobs/view/(?:.*?-)?([\d]{7,12})', url)
        if match_view:
            return match_view.group(1)

        match_param = re.search(r'currentJobId=([\d]+)', url)
        if match_param:
            return match_param.group(1)

        # Qualquer número longo de 9-12 dígitos no path
        match_number = re.search(r'(\d{9,12})', url)
        if match_number:
            return match_number.group(1)

        return None

    async def _scrape_via_guest_api(self, job_id: str, original_url: str) -> dict | None:
        """
        Tenta fazer GET na API pública de posts de vaga para convidados (jobs-guest).
        Usa httpx.AsyncClient para não bloquear o event loop.
        """
        guest_url = f"https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/{job_id}"
        logger.info("Acessando Guest API do LinkedIn: %s", guest_url)

        async with httpx.AsyncClient(follow_redirects=True) as client:
            response = await client.get(
                guest_url,
                headers=DEFAULT_HEADERS,
                timeout=15.0,
            )

        if response.status_code == 999:
            logger.warning("LinkedIn retornou HTTP 999 (bloqueio anti-bot). Guest API indisponível.")
            return None

        if response.status_code != 200:
            logger.warning("Guest API do LinkedIn retornou status %d", response.status_code)
            return None

        soup = BeautifulSoup(response.text, "html.parser")

        # 1. Título do cargo
        title = "Vaga LinkedIn"
        for selector in SELECTORS["title"]:
            title_el = soup.select_one(selector)
            if title_el and title_el.get_text(strip=True):
                title = title_el.get_text(strip=True)
                break

        # 2. Nome da empresa
        company = "Empresa do LinkedIn"
        for selector in SELECTORS["company"]:
            company_el = soup.select_one(selector)
            if company_el and company_el.get_text(strip=True):
                company = company_el.get_text(strip=True)
                break

        # 3. Descrição da vaga
        desc_el = None
        for selector in SELECTORS["description"]:
            desc_el = soup.select_one(selector)
            if desc_el and desc_el.get_text(strip=True):
                break
            desc_el = None

        if not desc_el:
            logger.warning("Guest API não retornou descrição da vaga.")
            return None

        # Formata o HTML da descrição em texto puro legível
        description = self._html_to_clean_text(desc_el)

        return {
            "url": original_url,
            "title": title,
            "company": company,
            "description": description,
        }

    async def _scrape_via_playwright(self, url: str) -> dict:
        """
        Carrega a página pública do LinkedIn usando Playwright com stealth
        e extrai as informações da vaga.
        """
        logger.info("Iniciando Playwright (stealth=%s) para LinkedIn...", STEALTH_AVAILABLE)

        async with async_playwright() as p:
            # Lança Chromium com flags anti-detecção
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--disable-features=IsolateOrigins,site-per-process",
                    "--no-sandbox",
                    "--disable-setuid-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-accelerated-2d-canvas",
                    "--disable-gpu",
                ],
            )

            # Cria contexto com user-agent e viewport realistas
            context = await browser.new_context(
                user_agent=DEFAULT_HEADERS["User-Agent"],
                viewport={"width": 1366, "height": 768},
                locale="pt-BR",
                timezone_id="America/Sao_Paulo",
                extra_http_headers={
                    "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
                },
            )

            page = await context.new_page()

            # Aplica patches de stealth se disponível
            if STEALTH_AVAILABLE:
                await stealth_async(page)

            # Navega até o LinkedIn
            try:
                await page.goto(url, wait_until="domcontentloaded", timeout=45000)
            except Exception as e:
                await browser.close()
                raise Exception(f"Timeout ao acessar página do LinkedIn: {e}")

            # Aguarda um breve momento para carregamento dinâmico
            await page.wait_for_timeout(2000)

            # Verifica se foi redirecionado para login/authwall
            current_url = page.url.lower()
            if any(wall in current_url for wall in ["authwall", "/login", "/checkpoint", "signup"]):
                await browser.close()
                raise Exception(
                    "O LinkedIn exigiu autenticação para acessar esta vaga. "
                    "Isso pode ocorrer quando:\n"
                    "  1. A vaga é privada ou expirou\n"
                    "  2. O LinkedIn detectou acesso automatizado\n"
                    "  3. A vaga requer conta logada para visualização\n\n"
                    "Alternativas:\n"
                    "  - Cole a descrição da vaga manualmente no campo de texto\n"
                    "  - Tente novamente em alguns minutos\n"
                    "  - Use uma vaga do LinkedIn que seja pública"
                )

            # Título
            title = "Vaga LinkedIn"
            for selector in SELECTORS["title"]:
                title_el = await page.query_selector(selector)
                if title_el:
                    text = (await title_el.inner_text()).strip()
                    if text:
                        title = text
                        break

            # Empresa
            company = "Empresa no LinkedIn"
            for selector in SELECTORS["company"]:
                company_el = await page.query_selector(selector)
                if company_el:
                    text = (await company_el.inner_text()).strip()
                    if text:
                        company = text
                        break

            # Tenta clicar no botão "Exibir mais" para expandir a descrição
            for selector in SELECTORS["show_more"]:
                try:
                    show_more = await page.query_selector(selector)
                    if show_more and await show_more.is_visible():
                        await show_more.click()
                        await page.wait_for_timeout(1000)
                        break
                except Exception:
                    pass

            # Descrição
            description = ""
            for selector in SELECTORS["description"]:
                desc_el = await page.query_selector(selector)
                if desc_el:
                    text = (await desc_el.inner_text()).strip()
                    if len(text) > 50:  # Evita capturar fragmentos pequenos
                        description = text
                        break

            await browser.close()

            # Se não pegou descrição, lança erro com mensagem útil
            if not description:
                raise Exception(
                    "Não foi possível extrair a descrição da vaga da página do LinkedIn.\n"
                    "A página pode ter um layout diferente do esperado.\n"
                    "Alternativa: copie e cole a descrição da vaga manualmente."
                )

            return {
                "url": url,
                "title": title,
                "company": company,
                "description": description,
            }

    @staticmethod
    def _html_to_clean_text(element) -> str:
        """Converte um elemento BeautifulSoup de HTML para texto limpo e legível."""
        # Adiciona quebras de linha para tags de bloco
        for tag in element.find_all(['p', 'li', 'br', 'div', 'h1', 'h2', 'h3', 'h4']):
            tag.append('\n')
        text = element.get_text()
        # Remove múltiplas quebras de linha consecutivas
        text = re.sub(r'\n\s*\n', '\n\n', text)
        return text.strip()
