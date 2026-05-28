"""
test_routes.py — Testes para as novas rotas (auth, perfil, candidatura).
"""

import os
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

# Adiciona o diretório raiz ao path para imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from fastapi.testclient import TestClient
from backend.api.main import app

client = TestClient(app)


def test_auth_me_endpoint():
    """Deve retornar os dados do usuário dev quando AUTH_ENABLED=false."""
    with patch.dict(os.environ, {"AUTH_ENABLED": "false"}):
        response = client.get("/api/v1/auth/me")
        assert response.status_code == 200
        data = response.json()
        assert data["uid"] == "local_dev_user"
        assert data["email"] == "local_dev_user@example.com"
    print("  ✓ test_auth_me_endpoint passed")


def test_profile_endpoints():
    """Deve criar/obter/atualizar perfil local do usuário."""
    with patch.dict(os.environ, {"AUTH_ENABLED": "false"}):
        # 1. Obter perfil (deve retornar os valores padrão do local dev)
        response = client.get("/api/v1/profile/")
        assert response.status_code == 200
        profile = response.json()
        assert profile["name"] == "Usuário Local Dev"
        
        # 2. Atualizar perfil
        update_data = {
            "name": "Novo Nome Teste",
            "linkedin_url": "https://linkedin.com/in/nome-teste",
            "gupy_url": "https://gupy.io/vagas/teste"
        }
        response = client.put("/api/v1/profile/", json=update_data)
        assert response.status_code == 200
        updated = response.json()
        assert updated["name"] == "Novo Nome Teste"
        assert updated["linkedin_url"] == "https://linkedin.com/in/nome-teste"
        assert updated["gupy_url"] == "https://gupy.io/vagas/teste"
        
        # 3. Obter perfil atualizado
        response = client.get("/api/v1/profile/")
        assert response.status_code == 200
        profile2 = response.json()
        assert profile2["name"] == "Novo Nome Teste"
    print("  ✓ test_profile_endpoints passed")


def test_apply_prepare_endpoint():
    """Deve preparar a candidatura a partir de um tailor_run e URL."""
    with patch.dict(os.environ, {"AUTH_ENABLED": "false"}):
        # Primeiro, mockamos o firebase_service para retornar uma execução do tailor
        from backend.api.services.firebase_service import get_firebase_service
        firebase = get_firebase_service()
        
        # Mock para get_tailor_run e get_scraped_jobs
        dummy_run = {
            "id": "test_run_id",
            "pdf_url": "/static/curriculo_test.pdf",
            "job_description": "Requisitos de Software"
        }
        
        with patch.object(firebase, "get_tailor_run", return_value=dummy_run):
            req_data = {
                "job_url": "https://linkedin.com/jobs/view/12345",
                "tailor_run_id": "test_run_id"
            }
            response = client.post("/api/v1/apply/prepare", json=req_data)
            assert response.status_code == 200
            apply_pkg = response.json()
            
            assert apply_pkg["job_url"] == "https://linkedin.com/jobs/view/12345"
            assert apply_pkg["pdf_url"] == "/static/curriculo_test.pdf"
            assert apply_pkg["pdf_filename"] == "curriculo_test.pdf"
            assert len(apply_pkg["checklist"]) > 0
    print("  ✓ test_apply_prepare_endpoint passed")


def run_all_tests():
    print("\n" + "=" * 60)
    print("  TESTES DE ROTAS E AUTENTICAÇÃO")
    print("=" * 60 + "\n")
    
    tests = [
        ("Auth Me (Bypass)", test_auth_me_endpoint),
        ("Profile endpoints", test_profile_endpoints),
        ("Apply Prepare endpoint", test_apply_prepare_endpoint),
    ]
    
    passed = 0
    failed = 0
    
    for name, test_fn in tests:
        try:
            print(f"[TEST] {name}")
            test_fn()
            passed += 1
        except AssertionError as e:
            print(f"  [FAIL]: {e}")
            failed += 1
        except Exception as e:
            print(f"  [ERROR]: {e}")
            failed += 1
            
    print(f"\n{'=' * 60}")
    print(f"  Resultado: {passed} OK  {failed} FAIL")
    print(f"{'=' * 60}\n")
    
    return failed == 0


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
