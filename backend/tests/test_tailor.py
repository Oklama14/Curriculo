"""
test_tailor.py — Testes de integração/unitários para o orquestrador ResumeTailor.

Testa:
  - Inicialização do ResumeTailor e leitura do currículo base
  - Fluxo orquestrado (Parsing -> AI Tailoring -> Injeção -> Validação LaTeX)
  - Geração correta do diff de visualização
  - Criação dos arquivos de output (.tex modificado)
"""

import sys
import shutil
from pathlib import Path
from unittest.mock import MagicMock, patch

# Adiciona o diretório raiz ao path para imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from backend.core.tailor import ResumeTailor, TailorResult
from backend.core.latex_parser import ExperienceBlock, SkillsBlock


# Cria caminhos temporários para testes
TEST_DIR = Path(__file__).resolve().parent
TEMP_OUTPUT_DIR = TEST_DIR / "temp_output"
CURRICULO_PATH = TEST_DIR.parent.parent / "curriculo.tex"


def setup_module():
    """Garante diretório de output limpo para os testes."""
    if TEMP_OUTPUT_DIR.exists():
        shutil.rmtree(TEMP_OUTPUT_DIR)
    TEMP_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def teardown_module():
    """Remove diretório temporário após os testes."""
    if TEMP_OUTPUT_DIR.exists():
        shutil.rmtree(TEMP_OUTPUT_DIR)


def test_resume_tailor_init():
    """Deve inicializar o ResumeTailor carregando o .tex base."""
    if not CURRICULO_PATH.exists():
        print("  ⚠ SKIP: curriculo.tex não encontrado para o teste")
        return

    tailor = ResumeTailor(
        tex_path=CURRICULO_PATH,
        output_dir=TEMP_OUTPUT_DIR,
        api_key="dummy_key",
    )
    assert tailor.original_tex is not None
    assert "\\documentclass" in tailor.original_tex
    print("  ✓ Init test passed")


@patch("backend.core.tailor.AIEngine")
@patch("backend.core.tailor.is_pdflatex_available", return_value=False)
def test_tailor_flow_success(mock_pdf_avail, mock_ai_class):
    """Deve executar todo o fluxo com sucesso (com mocks da IA)."""
    if not CURRICULO_PATH.exists():
        print("  ⚠ SKIP: curriculo.tex não encontrado para o teste")
        return

    # Configura mocks para o AIEngine
    mock_ai_instance = MagicMock()
    mock_ai_class.return_value = mock_ai_instance
    
    # Mock para tailor_experiences
    def side_effect_experiences(experiences, job_description, skills_text):
        modified = []
        for exp in experiences:
            modified.append(ExperienceBlock(
                empresa=exp.empresa,
                cargo=exp.cargo,
                periodo=exp.periodo,
                localidade=exp.localidade,
                bullets=[f"Otimizado: {b}" for b in exp.bullets],
                itemize_start=exp.itemize_start,
                itemize_end=exp.itemize_end,
            ))
        return modified
        
    mock_ai_instance.tailor_experiences.side_effect = side_effect_experiences
    
    # Mock para tailor_skills
    def side_effect_skills(skills, job_description):
        return SkillsBlock(
            items=[f"Otimizado skill: {item}" for item in skills.items],
            itemize_start=skills.itemize_start,
            itemize_end=skills.itemize_end,
        )
    mock_ai_instance.tailor_skills.side_effect = side_effect_skills

    tailor = ResumeTailor(
        tex_path=CURRICULO_PATH,
        output_dir=TEMP_OUTPUT_DIR,
        api_key="dummy_key",
    )
    
    result = tailor.tailor(
        job_description="Requisitos: QA de API com Postman e Cypress, metodologias ágeis.",
        tailor_skills=True,
        compile_pdf=False,  # desabilita compilação de PDF nos testes
    )
    
    assert isinstance(result, TailorResult)
    assert result.success is True
    assert len(result.errors) == 0
    assert result.modified_tex != ""
    assert "Otimizado:" in result.modified_tex
    assert "Otimizado skill:" in result.modified_tex
    assert result.tex_path != ""
    assert Path(result.tex_path).exists()
    
    # Verifica que o diff foi gerado
    assert "DIFF: ALTERAÇÕES NOS BULLET POINTS" in result.diff_text
    assert "❌ ANTES:" in result.diff_text
    assert "✅ DEPOIS:" in result.diff_text
    print("  ✓ Full tailor flow test passed")


def run_all_tests():
    """Executa todos os testes unitários do orquestrador Tailor."""
    setup_module()
    
    tests = [
        ("Inicialização do ResumeTailor", test_resume_tailor_init),
        ("Fluxo completo de Tailoring (Success)", test_tailor_flow_success),
    ]

    print("\n" + "=" * 60)
    print("  TESTES -- tailor.py")
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

    teardown_module()

    print(f"\n{'=' * 60}")
    print(f"  Resultado: {passed} OK  {failed} FAIL")
    print(f"{'=' * 60}\n")

    return failed == 0


if __name__ == "__main__":
    import os
    os.environ["GEMINI_API_KEY"] = "dummy_key"
    success = run_all_tests()
    sys.exit(0 if success else 1)
