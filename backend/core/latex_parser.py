"""
latex_parser.py — Parser e manipulador do arquivo .tex do currículo.

Responsável por:
  - Ler e interpretar a estrutura do currículo LaTeX
  - Extrair bullet points editáveis (experiências e habilidades)
  - Reinjetar bullet points modificados preservando a estrutura intacta
  - Validar que a sintaxe LaTeX não foi corrompida
"""

import re
from dataclasses import dataclass, field


@dataclass
class ExperienceBlock:
    """Representa um bloco de experiência profissional extraído do .tex."""
    empresa: str
    cargo: str
    periodo: str
    localidade: str
    bullets: list[str] = field(default_factory=list)
    # Posições no texto original para reinjeção precisa
    itemize_start: int = 0
    itemize_end: int = 0


@dataclass
class SkillsBlock:
    """Representa a seção de habilidades extraída do .tex."""
    items: list[str] = field(default_factory=list)
    itemize_start: int = 0
    itemize_end: int = 0


@dataclass
class ResumeData:
    """Dados completos extraídos do currículo."""
    raw_tex: str
    experiences: list[ExperienceBlock] = field(default_factory=list)
    skills: SkillsBlock | None = None


def parse_resume(tex_content: str) -> ResumeData:
    """
    Faz o parse completo do currículo .tex.

    Extrai experiências profissionais (com seus bullet points) e habilidades.
    Preserva as posições originais no texto para reinjeção posterior.

    Args:
        tex_content: Conteúdo completo do arquivo .tex

    Returns:
        ResumeData com experiências e habilidades extraídas
    """
    resume = ResumeData(raw_tex=tex_content)
    resume.experiences = extract_experience_bullets(tex_content)
    resume.skills = extract_skills(tex_content)
    return resume


def extract_experience_bullets(tex_content: str) -> list[ExperienceBlock]:
    """
    Extrai todos os blocos de experiência profissional do .tex.

    Identifica cada \\subsection* dentro da seção Experiência,
    extraindo empresa, cargo, período e bullet points.

    Args:
        tex_content: Conteúdo completo do arquivo .tex

    Returns:
        Lista de ExperienceBlock com dados de cada experiência
    """
    experiences = []

    # Localiza a seção de Experiência
    exp_section_match = re.search(
        r'\\section\{Experiência\}(.*?)(?=\\section\{|\\end\{document\})',
        tex_content,
        re.DOTALL
    )
    if not exp_section_match:
        return experiences

    exp_section = exp_section_match.group(1)
    exp_section_start = exp_section_match.start(1)

    # Encontra cada subsection dentro de Experiência
    subsection_pattern = re.compile(
        r'\\subsection\*\{\\texorpdfstring\{.*?\\textbf\{(.+?)\}.*?\}\{.*?\}\}'
        r'.*?'
        r'\\textit\{(.+?)\\hfill\s*(.+?)\}',
        re.DOTALL
    )

    for match in subsection_pattern.finditer(exp_section):
        empresa_raw = match.group(1).strip()
        cargo = match.group(2).strip()
        periodo = match.group(3).strip()

        # Extrai localidade do hfill no subsection
        localidade_match = re.search(
            r'\\hfill\s*(.+?)$',
            match.group(0).split('\n')[0] if '\n' in match.group(0) else match.group(0)
        )

        # Tenta extrair localidade da linha do subsection
        subsection_line = match.group(0)
        loc_match = re.search(r'\\hfill\s+([A-Za-zÀ-ú/\s-]+?)(?:\s*\})', subsection_line)
        localidade = loc_match.group(1).strip() if loc_match else ""

        # Encontra o bloco itemize associado a esta experiência
        # Procura a partir da posição atual no exp_section
        search_start = match.end()
        itemize_match = re.search(
            r'(\\begin\{itemize\})(.*?)(\\end\{itemize\})',
            exp_section[search_start:],
            re.DOTALL
        )

        bullets = []
        itemize_start = 0
        itemize_end = 0

        if itemize_match:
            # Posições absolutas no tex_content original
            itemize_start = exp_section_start + search_start + itemize_match.start()
            itemize_end = exp_section_start + search_start + itemize_match.end()

            # Extrai cada \item
            items_text = itemize_match.group(2)
            bullet_pattern = re.compile(r'\\item\s+(.+?)(?=\\item|$)', re.DOTALL)
            for bullet_match in bullet_pattern.finditer(items_text):
                bullet_text = bullet_match.group(1).strip()
                # Remove quebras de linha internas e espaços extras
                bullet_text = re.sub(r'\s+', ' ', bullet_text)
                bullets.append(bullet_text)

        experience = ExperienceBlock(
            empresa=empresa_raw,
            cargo=cargo,
            periodo=periodo,
            localidade=localidade,
            bullets=bullets,
            itemize_start=itemize_start,
            itemize_end=itemize_end,
        )
        experiences.append(experience)

    return experiences


def extract_skills(tex_content: str) -> SkillsBlock | None:
    """
    Extrai a seção de Habilidades do .tex.

    Args:
        tex_content: Conteúdo completo do arquivo .tex

    Returns:
        SkillsBlock com os itens de habilidades, ou None se não encontrado
    """
    skills_match = re.search(
        r'\\section\{Habilidades\}(.*?)(?=\\section\{|\\end\{document\})',
        tex_content,
        re.DOTALL
    )
    if not skills_match:
        return None

    skills_section = skills_match.group(1)
    skills_section_start = skills_match.start(1)

    itemize_match = re.search(
        r'(\\begin\{itemize\})(.*?)(\\end\{itemize\})',
        skills_section,
        re.DOTALL
    )
    if not itemize_match:
        return None

    items = []
    items_text = itemize_match.group(2)
    bullet_pattern = re.compile(r'\\item\s+(.+?)(?=\\item|$)', re.DOTALL)
    for bullet_match in bullet_pattern.finditer(items_text):
        bullet_text = bullet_match.group(1).strip()
        bullet_text = re.sub(r'\s+', ' ', bullet_text)
        items.append(bullet_text)

    return SkillsBlock(
        items=items,
        itemize_start=skills_section_start + itemize_match.start(),
        itemize_end=skills_section_start + itemize_match.end(),
    )


def inject_modified_bullets(
    tex_content: str,
    modified_experiences: list[ExperienceBlock],
    modified_skills: SkillsBlock | None = None,
) -> str:
    """
    Injeta bullet points modificados de volta no .tex original.

    Substitui os blocos \\begin{itemize}...\\end{itemize} pelas versões
    modificadas, preservando toda a estrutura do documento intacta.

    IMPORTANTE: Os blocos devem ser processados de trás para frente
    para que as posições não sejam invalidadas pelas substituições.

    Args:
        tex_content: Conteúdo original do .tex
        modified_experiences: Lista de ExperienceBlock com bullets modificados
        modified_skills: SkillsBlock com itens modificados (opcional)

    Returns:
        Conteúdo do .tex com os bullets substituídos
    """
    # Coleta todos os blocos a substituir com suas posições
    replacements: list[tuple[int, int, str]] = []

    for exp in modified_experiences:
        if exp.itemize_start == 0 and exp.itemize_end == 0:
            continue
        new_itemize = _build_itemize_block(exp.bullets, indent=12)
        replacements.append((exp.itemize_start, exp.itemize_end, new_itemize))

    if modified_skills and modified_skills.itemize_start > 0:
        new_itemize = _build_itemize_block(modified_skills.items, indent=8)
        replacements.append((
            modified_skills.itemize_start,
            modified_skills.itemize_end,
            new_itemize,
        ))

    # Ordena de trás para frente para não invalidar posições
    replacements.sort(key=lambda x: x[0], reverse=True)

    result = tex_content
    for start, end, new_content in replacements:
        result = result[:start] + new_content + result[end:]

    return result


def _build_itemize_block(items: list[str], indent: int = 12) -> str:
    """
    Reconstrói um bloco \\begin{itemize}...\\end{itemize} a partir de uma lista de itens.

    Args:
        items: Lista de textos dos bullet points
        indent: Nível de indentação dos \\item (em espaços)

    Returns:
        Bloco itemize formatado em LaTeX
    """
    spaces = ' ' * indent
    outer_spaces = ' ' * (indent - 4) if indent >= 4 else ''

    lines = [f"{outer_spaces}\\begin{{itemize}}"]
    for item in items:
        lines.append(f"{spaces}\\item {item}")
    lines.append(f"{outer_spaces}\\end{{itemize}}")

    return '\n'.join(lines)


def validate_tex_syntax(tex_content: str) -> tuple[bool, list[str]]:
    """
    Validação básica da sintaxe LaTeX.

    Verifica:
    - Balanceamento de chaves {}
    - Balanceamento de \\begin/\\end
    - Presença de estrutura essencial (\\documentclass, \\begin{document})

    Args:
        tex_content: Conteúdo do .tex a validar

    Returns:
        Tupla (is_valid, list_of_errors)
    """
    errors = []

    # Verifica estrutura essencial
    if '\\documentclass' not in tex_content:
        errors.append("Falta \\documentclass")
    if '\\begin{document}' not in tex_content:
        errors.append("Falta \\begin{document}")
    if '\\end{document}' not in tex_content:
        errors.append("Falta \\end{document}")

    # Verifica balanceamento de chaves (simplificado, ignora escaped \{ \})
    # Remove sequências escapadas antes de contar
    clean = re.sub(r'\\[{}]', '', tex_content)
    open_braces = clean.count('{')
    close_braces = clean.count('}')
    if open_braces != close_braces:
        errors.append(
            f"Chaves desbalanceadas: {open_braces} abertas vs {close_braces} fechadas"
        )

    # Verifica balanceamento de begin/end
    begins = re.findall(r'\\begin\{(\w+)\}', tex_content)
    ends = re.findall(r'\\end\{(\w+)\}', tex_content)

    begin_counts: dict[str, int] = {}
    end_counts: dict[str, int] = {}
    for env in begins:
        begin_counts[env] = begin_counts.get(env, 0) + 1
    for env in ends:
        end_counts[env] = end_counts.get(env, 0) + 1

    all_envs = set(list(begin_counts.keys()) + list(end_counts.keys()))
    for env in all_envs:
        b = begin_counts.get(env, 0)
        e = end_counts.get(env, 0)
        if b != e:
            errors.append(
                f"Ambiente '{env}' desbalanceado: {b} \\begin vs {e} \\end"
            )

    return (len(errors) == 0, errors)


def format_experience_for_prompt(experience: ExperienceBlock) -> str:
    """
    Formata um bloco de experiência para inclusão no prompt da IA.

    Args:
        experience: Bloco de experiência a formatar

    Returns:
        Texto formatado para o prompt
    """
    bullets_text = '\n'.join(f"  - {b}" for b in experience.bullets)
    return (
        f"Empresa: {experience.empresa}\n"
        f"Cargo: {experience.cargo}\n"
        f"Período: {experience.periodo}\n"
        f"Bullet points atuais:\n{bullets_text}"
    )


def format_all_experiences_for_prompt(experiences: list[ExperienceBlock]) -> str:
    """
    Formata todas as experiências para inclusão no prompt da IA.

    Args:
        experiences: Lista de blocos de experiência

    Returns:
        Texto formatado com todas as experiências
    """
    sections = []
    for i, exp in enumerate(experiences, 1):
        sections.append(f"--- Experiência {i} ---\n{format_experience_for_prompt(exp)}")
    return '\n\n'.join(sections)
