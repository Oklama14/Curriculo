"""
Scraper package.
Exposes specific scrapers and a helper to dispatch them based on URL.
"""

import logging
from urllib.parse import urlparse
from .base_scraper import BaseScraper
from .gupy_scraper import GupyScraper
from .linkedin_scraper import LinkedInScraper

logger = logging.getLogger(__name__)


def get_scraper_for_url(url: str) -> BaseScraper:
    """
    Retorna a instância do scraper correto com base na URL fornecida.

    Args:
        url: URL da vaga.

    Returns:
        Instância de BaseScraper correspondente.

    Raises:
        ValueError: Se a URL não for suportada.
    """
    parsed_url = urlparse(url)
    hostname = parsed_url.hostname or ""
    hostname = hostname.lower()

    if "gupy.io" in hostname:
        return GupyScraper()
    elif "linkedin.com" in hostname:
        return LinkedInScraper()
    else:
        raise ValueError(
            f"URL não suportada: '{hostname}'. Apenas Gupy e LinkedIn são suportados no momento."
        )
