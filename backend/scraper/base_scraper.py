"""
base_scraper.py — Classe base abstrata para todos os scrapers de vagas.
"""

from abc import ABC, abstractmethod


class BaseScraper(ABC):
    """Classe base que define o contrato para os scrapers de vagas."""

    @abstractmethod
    async def scrape_job(self, url: str) -> dict:
        """
        Extrai os detalhes de uma vaga a partir de sua URL.

        Args:
            url: URL da vaga.

        Returns:
            Dicionário contendo:
                - url: str
                - title: str
                - company: str
                - description: str
        
        Raises:
            Exception: Se falhar ao acessar ou extrair os dados.
        """
        pass
