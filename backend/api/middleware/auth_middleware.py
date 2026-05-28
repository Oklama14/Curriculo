import os
import logging
from fastapi import Request, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)

# Tenta importar firebase_admin
try:
    from firebase_admin import auth
    FIREBASE_AUTH_AVAILABLE = True
except ImportError:
    FIREBASE_AUTH_AVAILABLE = False

class FirebaseAuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Permite requisições OPTIONS (CORS preflight) passarem sem autenticação
        if request.method == "OPTIONS":
            return await call_next(request)

        # Verifica se a autenticação está habilitada nas variáveis de ambiente
        auth_enabled = os.getenv("AUTH_ENABLED", "false").lower() == "true"
        
        # Paths públicos que não requerem autenticação
        public_paths = ["/", "/docs", "/openapi.json", "/redoc"]
        path = request.url.path
        
        # Ignora rotas públicas ou estáticas se elas forem acessadas
        is_public = path in public_paths or path.startswith("/static")
        
        if not auth_enabled or is_public:
            # Bypass da autenticação
            request.state.user_id = "local_dev_user"
            request.state.user_email = "local_dev_user@example.com"
            return await call_next(request)

        # Se a autenticação estiver habilitada mas Firebase admin SDK não estiver disponível, erro
        if not FIREBASE_AUTH_AVAILABLE:
            logger.error("AUTH_ENABLED=true mas Firebase Admin SDK não está disponível.")
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={"detail": "Configuração de autenticação inválida no servidor."}
            )

        # Obtém o token do header de Authorization
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content={"detail": "Token de autenticação ausente ou inválido."}
            )

        token = auth_header.split(" ")[1]
        try:
            # Valida o token
            decoded_token = auth.verify_id_token(token)
            request.state.user_id = decoded_token.get("uid")
            request.state.user_email = decoded_token.get("email", "")
        except Exception as e:
            logger.warning("Falha na validação do token Firebase: %s", str(e))
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content={"detail": "Token de autenticação inválido ou expirado."}
            )

        return await call_next(request)
