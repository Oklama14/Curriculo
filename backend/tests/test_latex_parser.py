"""
test_latex_parser.py — Testes unitários para o parser de LaTeX.

Testa:
  - Extração correta de experiências e habilidades
  - Reinjeção de bullets sem corromper o .tex
  - Validação de sintaxe LaTeX
  - Preservação da estrutura do documento
"""

import sys
from pathlib import Path

# Adiciona o diretório raiz ao path para imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from backend.core.latex_parser import (
    parse_resume,
    extract_experience_bullets,
    extract_skills,
    inject_modified_bullets,
    validate_tex_syntax,
    format_experience_for_prompt,
    ExperienceBlock,
)


# Carrega o currículo real para testes
CURRICULO_PATH = Path(__file__).resolve().parent.parent.parent / "curriculo.tex"
if CURRICULO_PATH.exists():
    CURRICULO_TEX = CURRICULO_PATH.read_text(encoding="utf-8")
else:
    CURRICULO_TEX = ""


# ===== Testes de extração =====

def test_extract_experiences_count():
    """Deve encontrar exatamente 4 experiências no currículo."""
    if not CURRICULO_TEX:
        print("  ⚠ SKIP: curriculo.tex não encontrado")
        return
    experiences = extract_experience_bullets(CURRICULO_TEX)
    assert len(experiences) == 4, f"Esperado 4 experiências, encontrou {len(experiences)}"
    print(f"  ✓ Encontradas {len(experiences)} experiências")


def test_extract_experience_companies():
    """Deve extrair os nomes corretos das empresas."""
    if not CURRICULO_TEX:
        print("  ⚠ SKIP: curriculo.tex não encontrado")
        return
    experiences = extract_experience_bullets(CURRICULO_TEX)
    companies = [e.empresa for e in experiences]
    
    assert "SegDev | Tecnologia em Seguros" in companies[0], f"Empresa 1: {companies[0]}"
    assert "Gama-log" in companies[1], f"Empresa 2: {companies[1]}"
    print(f"  ✓ Empresas extraídas: {[c[:30] for c in companies]}")


def test_extract_experience_bullets_content():
    """Deve extrair bullets com conteúdo não-vazio."""
    if not CURRICULO_TEX:
        print("  ⚠ SKIP: curriculo.tex não encontrado")
        return
    experiences = extract_experience_bullets(CURRICULO_TEX)
    for exp in experiences:
        assert len(exp.bullets) > 0, f"Empresa {exp.empresa} sem bullets"
        for bullet in exp.bullets:
            assert len(bullet) > 10, f"Bullet muito curto: '{bullet}'"
    
    # SegDev deve ter 6 bullets
    assert len(experiences[0].bullets) == 6, (
        f"SegDev: esperado 6 bullets, encontrou {len(experiences[0].bullets)}"
    )
    print(f"  ✓ Bullets extraídos: {[len(e.bullets) for e in experiences]}")


def test_extract_skills():
    """Deve extrair a seção de habilidades."""
    if not CURRICULO_TEX:
        print("  ⚠ SKIP: curriculo.tex não encontrado")
        return
    skills = extract_skills(CURRICULO_TEX)
    assert skills is not None, "Seção de habilidades não encontrada"
    assert len(skills.items) > 0, "Nenhum item de habilidade extraído"
    print(f"  ✓ {len(skills.items)} categorias de habilidades extraídas")


def test_extract_positions():
    """Deve registrar posições válidas para reinjeção."""
    if not CURRICULO_TEX:
        print("  ⚠ SKIP: curriculo.tex não encontrado")
        return
    experiences = extract_experience_bullets(CURRICULO_TEX)
    for exp in experiences:
        assert exp.itemize_start > 0, f"{exp.empresa}: itemize_start inválido"
        assert exp.itemize_end > exp.itemize_start, f"{exp.empresa}: itemize_end inválido"
        
        # Verifica que as posições apontam para o conteúdo correto
        extracted = CURRICULO_TEX[exp.itemize_start:exp.itemize_end]
        assert "\\begin{itemize}" in extracted, f"{exp.empresa}: posição não contém \\begin{{itemize}}"
        assert "\\end{itemize}" in extracted, f"{exp.empresa}: posição não contém \\end{{itemize}}"
    
    print("  ✓ Todas as posições são válidas")


# ===== Testes de reinjeção =====

def test_inject_preserves_structure():
    """Reinjeção com mesmos bullets deve manter o documento idêntico."""
    if not CURRICULO_TEX:
        print("  ⚠ SKIP: curriculo.tex não encontrado")
        return
    resume = parse_resume(CURRICULO_TEX)
    
    # Reinjeta os mesmos bullets (sem modificação)
    result = inject_modified_bullets(
        CURRICULO_TEX,
        resume.experiences,
        resume.skills,
    )
    
    # O resultado deve manter a estrutura (cabeçalho, seções, etc.)
    assert "\\documentclass" in result
    assert "\\begin{document}" in result
    assert "\\end{document}" in result
    assert "\\section{Experiência}" in result
    assert "\\section{Habilidades}" in result
    assert "\\section{Educação}" in result
    assert "\\section{Certificações}" in result
    assert "Arthur Chaves Sousa" in result
    
    print("  ✓ Estrutura do documento preservada após reinjeção")


def test_inject_modified_bullets():
    """Reinjeção com bullets modificados deve alterar apenas os bullets."""
    if not CURRICULO_TEX:
        print("  ⚠ SKIP: curriculo.tex não encontrado")
        return
    resume = parse_resume(CURRICULO_TEX)
    
    # Modifica o primeiro bullet da primeira experiência
    modified_exps = resume.experiences.copy()
    if modified_exps[0].bullets:
        original_first = modified_exps[0].bullets[0]
        modified_exps[0] = ExperienceBlock(
            empresa=modified_exps[0].empresa,
            cargo=modified_exps[0].cargo,
            periodo=modified_exps[0].periodo,
            localidade=modified_exps[0].localidade,
            bullets=["BULLET MODIFICADO PARA TESTE"] + modified_exps[0].bullets[1:],
            itemize_start=modified_exps[0].itemize_start,
            itemize_end=modified_exps[0].itemize_end,
        )
    
    result = inject_modified_bullets(CURRICULO_TEX, modified_exps)
    
    assert "BULLET MODIFICADO PARA TESTE" in result
    assert original_first not in result
    # Outras experiências devem permanecer
    assert "Gama-log" in result
    
    print("  ✓ Bullets modificados injetados corretamente")


# ===== Testes de validação =====

def test_validate_valid_tex():
    """Currículo original deve passar na validação."""
    if not CURRICULO_TEX:
        print("  ⚠ SKIP: curriculo.tex não encontrado")
        return
    is_valid, errors = validate_tex_syntax(CURRICULO_TEX)
    assert is_valid, f"Currículo deveria ser válido. Erros: {errors}"
    print("  ✓ Currículo original é válido")


def test_validate_missing_documentclass():
    """Deve detectar falta de \\documentclass."""
    is_valid, errors = validate_tex_syntax("\\begin{document}\\end{document}")
    assert not is_valid
    assert any("documentclass" in e for e in errors)
    print("  ✓ Detecta \\documentclass faltando")


def test_validate_unbalanced_braces():
    """Deve detectar chaves desbalanceadas."""
    tex = "\\documentclass{article}\\begin{document}{texto\\end{document}"
    is_valid, errors = validate_tex_syntax(tex)
    assert not is_valid
    assert any("Chaves desbalanceadas" in e for e in errors)
    print("  ✓ Detecta chaves desbalanceadas")


def test_validate_unbalanced_environments():
    """Deve detectar ambientes begin/end desbalanceados."""
    tex = "\\documentclass{article}\\begin{document}\\begin{itemize}\\end{document}"
    is_valid, errors = validate_tex_syntax(tex)
    assert not is_valid
    assert any("itemize" in e for e in errors)
    print("  ✓ Detecta ambientes desbalanceados")


# ===== Teste de formatação para prompt =====

def test_format_experience_for_prompt():
    """Deve formatar experiência para inclusão no prompt."""
    exp = ExperienceBlock(
        empresa="Empresa Teste",
        cargo="Developer",
        periodo="2024 - Presente",
        localidade="Remoto",
        bullets=["Desenvolveu sistema X", "Implementou feature Y"],
    )
    result = format_experience_for_prompt(exp)
    assert "Empresa Teste" in result
    assert "Developer" in result
    assert "Desenvolveu sistema X" in result
    print("  ✓ Formatação para prompt correta")


# ===== Runner =====

def run_all_tests():
    """Executa todos os testes e reporta resultados."""
    tests = [
        ("Extração: quantidade de experiências", test_extract_experiences_count),
        ("Extração: nomes das empresas", test_extract_experience_companies),
        ("Extração: conteúdo dos bullets", test_extract_experience_bullets_content),
        ("Extração: seção de habilidades", test_extract_skills),
        ("Extração: posições para reinjeção", test_extract_positions),
        ("Reinjeção: preserva estrutura", test_inject_preserves_structure),
        ("Reinjeção: bullets modificados", test_inject_modified_bullets),
        ("Validação: .tex válido", test_validate_valid_tex),
        ("Validação: falta documentclass", test_validate_missing_documentclass),
        ("Validação: chaves desbalanceadas", test_validate_unbalanced_braces),
        ("Validação: ambientes desbalanceados", test_validate_unbalanced_environments),
        ("Formatação: prompt", test_format_experience_for_prompt),
    ]

    print("\n" + "=" * 60)
    print("  TESTES -- latex_parser.py")
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
    success = run_all_tests()
    sys.exit(0 if success else 1)
