"""
jobs.py — Rotas para buscar e listar vagas extraídas (scraped).
"""

import logging
from typing import List
from fastapi import APIRouter, HTTPException, Depends, Request
from datetime import datetime
from ..schemas.models import JobScrapeRequest, JobScrapeResponse
from ..services.firebase_service import get_firebase_service, FirebaseService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/", response_model=List[JobScrapeResponse])
def list_scraped_jobs(
    http_request: Request,
    firebase: FirebaseService = Depends(get_firebase_service)
):
    """Retorna todas as vagas salvas (scraped)."""
    user_id = getattr(http_request.state, "user_id", "local_dev_user")
    jobs = firebase.get_scraped_jobs(user_id)
    
    items = []
    for j in jobs:
        items.append(JobScrapeResponse(
            url=j.get("url", ""),
            title=j.get("title", ""),
            company=j.get("company", ""),
            description=j.get("description", ""),
            extracted_at=datetime.fromisoformat(j["extracted_at"]) if "extracted_at" in j else datetime.utcnow()
        ))
    return items


@router.post("/scrape", response_model=JobScrapeResponse)
async def scrape_job(
    request: JobScrapeRequest,
    http_request: Request,
    firebase: FirebaseService = Depends(get_firebase_service)
):
    """
    Dispara a extração de uma vaga a partir de uma URL suportada (Gupy ou LinkedIn).
    Utiliza Playwright e APIs públicas para extrair os dados.
    """
    logger.info("Solicitação de scraping recebida para URL: %s", request.url)
    
    from ...scraper import get_scraper_for_url

    try:
        scraper = get_scraper_for_url(request.url)
        scraped_data = await scraper.scrape_job(request.url)
        
        job_data = {
            "url": scraped_data["url"],
            "title": scraped_data["title"],
            "company": scraped_data["company"],
            "description": scraped_data["description"],
            "extracted_at": datetime.utcnow().isoformat()
        }

        # Salva a vaga
        user_id = getattr(http_request.state, "user_id", "local_dev_user")
        saved_job = firebase.save_scraped_job(user_id, job_data)

        return JobScrapeResponse(
            url=saved_job["url"],
            title=saved_job["title"],
            company=saved_job["company"],
            description=saved_job["description"],
            extracted_at=datetime.fromisoformat(saved_job["extracted_at"])
        )

    except ValueError as e:
        # URL não suportada
        logger.warning("URL não suportada para scraping: %s", e)
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception("Falha na execução do scraper para a URL '%s': %s", request.url, e)
        raise HTTPException(
            status_code=500,
            detail=f"Falha ao extrair dados da vaga: {str(e)}"
        )
