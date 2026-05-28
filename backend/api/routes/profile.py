"""
profile.py — Rotas para gerenciar o perfil do usuário.
"""

import logging
from fastapi import APIRouter, Depends, Request, HTTPException
from ..schemas.models import UserProfile, ProfileUpdateRequest
from ..services.firebase_service import get_firebase_service, FirebaseService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/", response_model=UserProfile)
def get_profile(
    request: Request,
    firebase: FirebaseService = Depends(get_firebase_service)
):
    """Retorna o perfil do usuário atualmente logado."""
    user_id = getattr(request.state, "user_id", None)
    user_email = getattr(request.state, "user_email", "")
    
    if not user_id:
        raise HTTPException(status_code=401, detail="Usuário não autenticado")

    profile_data = firebase.get_profile(user_id)
    
    # Se o email não estiver no perfil, preenche com o do token
    if not profile_data.get("email") and user_email:
        profile_data["email"] = user_email
        
    return UserProfile(
        name=profile_data.get("name", "Usuário"),
        email=profile_data.get("email", ""),
        linkedin_url=profile_data.get("linkedin_url"),
        gupy_url=profile_data.get("gupy_url"),
        photo_url=profile_data.get("photo_url"),
    )


@router.put("/", response_model=UserProfile)
def update_profile(
    request: Request,
    profile_req: ProfileUpdateRequest,
    firebase: FirebaseService = Depends(get_firebase_service)
):
    """Atualiza ou cria o perfil do usuário."""
    user_id = getattr(request.state, "user_id", None)
    user_email = getattr(request.state, "user_email", "")

    if not user_id:
        raise HTTPException(status_code=401, detail="Usuário não autenticado")

    # Filtra valores None para não sobrescrever dados existentes com None
    update_data = {k: v for k, v in profile_req.dict().items() if v is not None}
    
    # Garante que temos o email se ele vier do token
    if "email" not in update_data and user_email:
        update_data["email"] = user_email

    updated_profile = firebase.update_profile(user_id, update_data)
    
    return UserProfile(
        name=updated_profile.get("name", "Usuário"),
        email=updated_profile.get("email", ""),
        linkedin_url=updated_profile.get("linkedin_url"),
        gupy_url=updated_profile.get("gupy_url"),
        photo_url=updated_profile.get("photo_url"),
    )
