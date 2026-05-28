"""
test_ai_engine.py — Testes unitários para o motor de IA (AIEngine).

Testa:
  - Fuzzy match de nomes de empresas
  - Extração de itens \item das respostas da IA
  - Distribuição fallback de itens entre as experiências
  - Parse de respostas estruturadas do Gemini
  - Lógica de retry com backoff exponencial para erros temporários da API
"""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

# Adiciona o diretório raiz ao path para imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from backend.core.ai_engine import AIEngine, _fuzzy_match
from backend.core.latex_parser import ExperienceBlock, SkillsBlock
from google.genai.errors import ClientError, ServerError


def test_fuzzy_match():
    """Deve parear nomes de empresas semelhantes ignorando case/caracteres especiais."""
    assert _fuzzy_match("SegDev | Tecnologia em Seguros", "SegDev") is True
    assert _fuzzy_match("Gama-log Solução em Comércio", "Gama-log") is True
    assert _fuzzy_match("SB Despachos Aduaneiros", "SB Despachos") is True
    assert _fuzzy_match("KR Logística Internacional", "KR Logística") is True
    assert _fuzzy_match("Empresa A", "Empresa B") is False
    # Certificar que termos genéricos comuns sozinhos não causam falso positivo
    assert _fuzzy_match("Tecnologia", "Logística") is False
    print("  ✓ Fuzzy match test passed")


def test_extract_items_from_response():
    """Deve extrair itens de LaTeX de um texto de resposta bruto."""
    engine = AIEngine(api_key="dummy_key")
    text = (
        "Aqui está sua resposta:\n"
        "\\item Primeiro item interessante\n"
        "\\item Segundo item com \\textbf{negrito} e formatação\n"
        "\\item Terceiro item"
    )
    items = engine._extract_items_from_response(text)
    assert len(items) == 3
    assert items[0] == "Primeiro item interessante"
    assert items[1] == "Segundo item com \\textbf{negrito} e formatação"
    assert items[2] == "Terceiro item"
    print("  ✓ Extract items test passed")


def test_distribute_items():
    """Deve distribuir os itens proporcionalmente baseado nos blocos originais."""
    engine = AIEngine(api_key="dummy_key")
    orig_exps = [
        ExperienceBlock(empresa="Empresa 1", cargo="Dev", periodo="", localidade="", bullets=["a", "b"]),
        ExperienceBlock(empresa="Empresa 2", cargo="QA", periodo="", localidade="", bullets=["c"]),
    ]
    all_items = ["Item 1", "Item 2", "Item 3"]
    
    distributed = engine._distribute_items(all_items, orig_exps)
    assert len(distributed) == 2
    assert distributed[0].bullets == ["Item 1", "Item 2"]
    assert distributed[1].bullets == ["Item 3"]
    print("  ✓ Distribute items test passed")


def test_parse_experience_response():
    """Deve parsear blocos de experiência identificados por [EXPERIÊNCIA: ...]."""
    engine = AIEngine(api_key="dummy_key")
    orig_exps = [
        ExperienceBlock(empresa="SegDev", cargo="QA", periodo="", localidade="", bullets=["a"]),
        ExperienceBlock(empresa="Gama-log", cargo="Dev", periodo="", localidade="", bullets=["b"]),
    ]
    
    response_text = (
        "[EXPERIÊNCIA: SegDev]\n"
        "\\item Bullet SegDev 1\n"
        "\n"
        "[EXPERIÊNCIA: Gama-log]\n"
        "\\item Bullet Gamalog 1\n"
    )
    
    parsed = engine._parse_experience_response(response_text, orig_exps)
    assert len(parsed) == 2
    assert parsed[0].empresa == "SegDev"
    assert parsed[0].bullets == ["Bullet SegDev 1"]
    assert parsed[1].empresa == "Gama-log"
    assert parsed[1].bullets == ["Bullet Gamalog 1"]
    print("  ✓ Parse experience response test passed")


@patch("time.sleep", return_value=None)
def test_retry_logic_rate_limit(mock_sleep):
    """Deve tentar 3 vezes ao receber erro 429 RESOURCE_EXHAUSTED e depois falhar."""
    engine = AIEngine(api_key="dummy_key")
    
    # Configura o mock do client do Gemini para lançar erro 429
    mock_error = ClientError(code=429, response_json={"message": "Resource exhausted (429 limit: 0)"})
    engine.client.models.generate_content = MagicMock(side_effect=mock_error)
    
    try:
        engine._call_gemini("prompt", "system")
        assert False, "Deveria ter lançado RuntimeError"
    except RuntimeError as e:
        assert "API Gemini indisponivel" in str(e)
    
    # Verifica que chamou 3 vezes (max_retries) e esperou entre elas
    assert engine.client.models.generate_content.call_count == 3
    assert mock_sleep.call_count == 2
    print("  ✓ Retry rate limit test passed")


@patch("time.sleep", return_value=None)
def test_retry_logic_server_error(mock_sleep):
    """Deve tentar 3 vezes ao receber erro 503 Service Unavailable."""
    engine = AIEngine(api_key="dummy_key")
    mock_error = ServerError(code=503, response_json={"message": "Service Unavailable (503)"})
    engine.client.models.generate_content = MagicMock(side_effect=mock_error)
    
    try:
        engine._call_gemini("prompt", "system")
        assert False, "Deveria ter lançado RuntimeError"
    except RuntimeError as e:
        assert "API Gemini indisponivel" in str(e)
        
    assert engine.client.models.generate_content.call_count == 3
    print("  ✓ Retry server error test passed")


def run_all_tests():
    """Executa todos os testes unitários do AIEngine."""
    tests = [
        ("Fuzzy Match de empresas", test_fuzzy_match),
        ("Extração de itens do LaTeX", test_extract_items_from_response),
        ("Distribuição fallback de itens", test_distribute_items),
        ("Parse de blocos estruturados", test_parse_experience_response),
        ("Lógica de retry (Rate Limit 429)", test_retry_logic_rate_limit),
        ("Lógica de retry (Server Error 503)", test_retry_logic_server_error),
    ]

    print("\n" + "=" * 60)
    print("  TESTES -- ai_engine.py")
    print("=" * 60 + "\n")

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
    import os
    # Evita ler a chave de API real nos testes
    os.environ["GEMINI_API_KEY"] = "dummy_key"
    success = run_all_tests()
    sys.exit(0 if success else 1)
