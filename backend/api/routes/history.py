"""
history.py — Rota para obter o histórico de execuções do Resume Tailor.
"""

import logging
from typing import List
from fastapi import APIRouter, Depends, Request
from ..schemas.models import HistoryItem
from ..services.firebase_service import get_firebase_service, FirebaseService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/", response_model=List[HistoryItem])
def get_tailor_history(
    http_request: Request,
    firebase: FirebaseService = Depends(get_firebase_service)
):
    """Retorna o histórico completo de execuções de otimização de currículo."""
    user_id = getattr(http_request.state, "user_id", "local_dev_user")
    history = firebase.get_history(user_id)
    
    # Mapeia para o esquema de saída
    items = []
    for h in history:
        items.append(HistoryItem(
            id=h.get("id", ""),
            timestamp=h.get("timestamp", ""),
            job_description=h.get("job_description", ""),
            diff=h.get("diff", ""),
            pdf_url=h.get("pdf_url"),
            tex_url=h.get("tex_url"),
        ))
    return items
