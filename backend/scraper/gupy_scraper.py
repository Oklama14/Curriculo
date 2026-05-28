"""
gupy_scraper.py — Scraper para a plataforma Gupy (*.gupy.io).
Tenta usar a API pública JSON da Gupy para rapidez e confiabilidade.
Se falhar, faz fallback para Playwright (headless browser).
"""

import re
import httpx
import logging
from bs4 import BeautifulSoup
from urllib.parse import urlparse
from playwright.async_api import async_playwright

from .base_scraper import BaseScraper

logger = logging.getLogger(__name__)


class GupyScraper(BaseScraper):
    """Scraper para extração de vagas da plataforma Gupy."""

    async def scrape_job(self, url: str) -> dict:
        logger.info("Iniciando extração Gupy para: %s", url)

        # Tenta primeiro pela API da Gupy para ser mais rápido e leve
        try:
            api_data = await self._scrape_via_api(url)
            if api_data:
                logger.info("Extração Gupy concluída com sucesso via API JSON.")
                return api_data
        except Exception as e:
            logger.warning("Falha ao extrair Gupy via API: %s. Tentando via Playwright...", e)

        # Fallback para Playwright se a API falhar
        return await self._scrape_via_playwright(url)

    async def _scrape_via_api(self, url: str) -> dict | None:
        """Tenta extrair os dados fazendo uma requisição direta para a API REST da Gupy."""
        parsed_url = urlparse(url)
        hostname = parsed_url.hostname  # Ex: empresa.gupy.io
        path = parsed_url.path          # Ex: /jobs/123456
        
        if not hostname or "gupy.io" not in hostname:
            return None

        # Encontra o ID da vaga no path (último segmento numérico)
        match = re.search(r'/jobs/(\d+)', path)
        if not match:
            return None
        
        job_id = match.group(1)
        # Monta a URL da API da Gupy
        api_url = f"https://{hostname}/api/v1/jobs/{job_id}"
        
        logger.info("Fazendo GET na API Gupy: %s", api_url)
        async with httpx.AsyncClient(follow_redirects=True) as client:
            response = await client.get(api_url, timeout=10.0)

        if response.status_code != 200:
            logger.warning("API Gupy retornou status %d", response.status_code)
            return None
            
        data = response.json()
        
        # Extrai título, empresa e descrições
        title = data.get("name", "Vaga Gupy")
        company = data.get("companyName", hostname.split('.')[0].capitalize())
        
        # Gupy retorna HTML nas descrições. Usamos BeautifulSoup para limpar e formatar em texto puro.
        desc_html = data.get("description", "")
        spec_html = data.get("specification", "")
        
        def clean_html(html_content: str) -> str:
            if not html_content:
                return ""
            soup = BeautifulSoup(html_content, "html.parser")
            # Adiciona quebras de linha para listas e parágrafos para manter legibilidade
            for tag in soup.find_all(['p', 'li', 'br', 'div', 'h1', 'h2', 'h3', 'h4']):
                tag.append('\n')
            text = soup.get_text()
            # Remove múltiplos espaços em branco e quebras de linha consecutivas
            text = re.sub(r'\n\s*\n', '\n\n', text)
            return text.strip()

        description_text = clean_html(desc_html)
        requirements_text = clean_html(spec_html)
        
        full_desc = f"{description_text}\n\n## Requisitos e Habilidades:\n{requirements_text}"
        
        return {
            "url": url,
            "title": title.strip(),
            "company": company.strip(),
            "description": full_desc.strip()
        }

    async def _scrape_via_playwright(self, url: str) -> dict:
        """Fallback: carrega a página headless usando Playwright e extrai as tags do DOM."""
        logger.info("Iniciando Playwright para Gupy...")
        
        async with async_playwright() as p:
            # Lança o Chromium em modo headless
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()
            
            # Define timeout longo e muda o user-agent para evitar bloqueio básico
            await page.set_extra_http_headers({
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
            })
            
            await page.goto(url, wait_until="networkidle", timeout=60000)
            
            # Seletores conhecidos da Gupy para título e empresa
            # Título da vaga costuma estar num H1
            title_element = await page.query_selector("h1")
            title = await title_element.inner_text() if title_element else "Vaga Gupy"
            
            # Tenta pegar a empresa a partir do logo/cabeçalho ou do hostname
            company = urlparse(url).hostname.split('.')[0].capitalize()
            
            # Seção de descrição da Gupy costuma ter data-testid="text-description" ou classes semelhantes
            desc_element = await page.query_selector('[data-testid="text-description"]')
            if desc_element:
                description = await desc_element.inner_text()
            else:
                # Fallback: extrai o texto do elemento principal de conteúdo
                main_content = await page.query_selector("main")
                if main_content:
                    description = await main_content.inner_text()
                else:
                    description = await page.locator("body").inner_text()
                    
            await browser.close()
            
            return {
                "url": url,
                "title": title.strip(),
                "company": company.strip(),
                "description": description.strip()
            }
