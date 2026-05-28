"""
tailor.py — Orquestrador principal do fluxo de tailoring.

Coordena todo o pipeline:
  1. Lê o currículo .tex original
  2. Extrai experiências e habilidades (latex_parser)
  3. Envia ao Gemini para otimização (ai_engine)
  4. Injeta os bullets modificados de volta no .tex
  5. Valida a sintaxe LaTeX
  6. Compila o PDF (pdf_compiler) — se pdflatex disponível
  7. Gera o diff visual entre original e modificado
"""

import os
import logging
from pathlib import Path
from itertools import zip_longest
from dataclasses import dataclass, field
from datetime import datetime

from .latex_parser import (
    parse_resume,
    inject_modified_bullets,
    validate_tex_syntax,
    ExperienceBlock,
    SkillsBlock,
    ResumeData,
)
from .ai_engine import AIEngine
from .pdf_compiler import compile_tex_to_pdf, is_pdflatex_available

logger = logging.getLogger(__name__)


@dataclass
class TailorResult:
    """Resultado completo de uma operação de tailoring."""
    success: bool
    original_tex: str
    modified_tex: str
    original_experiences: list[ExperienceBlock] = field(default_factory=list)
    modified_experiences: list[ExperienceBlock] = field(default_factory=list)
    original_skills: SkillsBlock | None = None
    modified_skills: SkillsBlock | None = None
    pdf_path: str = ""
    tex_path: str = ""
    diff_text: str = ""
    errors: list[str] = field(default_factory=list)
    compilation_log: str = ""


class ResumeTailor:
    """Orquestrador principal do processo de tailoring de currículo."""

    def __init__(
        self,
        tex_path: str | Path,
        output_dir: str | Path = "backend/output",
        api_key: str | None = None,
        model: str | None = None,
    ):
        """
        Inicializa o tailor.

        Args:
            tex_path: Caminho para o arquivo .tex do currículo base
            output_dir: Diretório para salvar os arquivos gerados
            api_key: API key do Gemini (opcional, usa .env se não fornecida)
            model: Modelo Gemini a usar (opcional)
        """
        self.tex_path = Path(tex_path)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        if not self.tex_path.exists():
            raise FileNotFoundError(f"Arquivo .tex não encontrado: {self.tex_path}")

        self.ai_engine = AIEngine(api_key=api_key, model=model)
        self.original_tex = self.tex_path.read_text(encoding="utf-8")

        logger.info("ResumeTailor inicializado. Arquivo: %s", self.tex_path)

    def tailor(
        self,
        job_description: str,
        tailor_skills: bool = True,
        compile_pdf: bool = True,
    ) -> TailorResult:
        """
        Executa o fluxo completo de tailoring.

        Args:
            job_description: Texto da descrição da vaga alvo
            tailor_skills: Se True, também otimiza a seção de habilidades
            compile_pdf: Se True, tenta compilar o PDF (requer pdflatex)

        Returns:
            TailorResult com todos os dados da operação
        """
        result = TailorResult(
            success=False,
            original_tex=self.original_tex,
            modified_tex="",
        )

        try:
            # 1. Parse do currículo
            logger.info("═" * 50)
            logger.info("ETAPA 1: Parsing do currículo .tex")
            logger.info("═" * 50)
            resume_data = parse_resume(self.original_tex)
            result.original_experiences = resume_data.experiences
            result.original_skills = resume_data.skills

            logger.info(
                "Encontradas %d experiências e %d habilidades",
                len(resume_data.experiences),
                len(resume_data.skills.items) if resume_data.skills else 0,
            )

            for exp in resume_data.experiences:
                logger.info("  → %s | %s (%d bullets)", exp.empresa, exp.cargo, len(exp.bullets))

            # 2. Enviar ao Gemini para otimização
            logger.info("═" * 50)
            logger.info("ETAPA 2: Enviando ao Gemini para otimização")
            logger.info("═" * 50)

            skills_context = ""
            if resume_data.skills:
                skills_context = '\n'.join(f"- {item}" for item in resume_data.skills.items)

            modified_experiences = self.ai_engine.tailor_experiences(
                experiences=resume_data.experiences,
                job_description=job_description,
                skills_text=skills_context,
            )
            result.modified_experiences = modified_experiences

            # 3. Otimizar habilidades (se solicitado)
            modified_skills = None
            if tailor_skills and resume_data.skills:
                logger.info("═" * 50)
                logger.info("ETAPA 3: Otimizando seção de habilidades")
                logger.info("═" * 50)
                modified_skills = self.ai_engine.tailor_skills(
                    skills=resume_data.skills,
                    job_description=job_description,
                )
                result.modified_skills = modified_skills

            # 4. Injetar bullets modificados no .tex
            logger.info("═" * 50)
            logger.info("ETAPA 4: Injetando bullets modificados no .tex")
            logger.info("═" * 50)
            modified_tex = inject_modified_bullets(
                tex_content=self.original_tex,
                modified_experiences=modified_experiences,
                modified_skills=modified_skills,
            )
            result.modified_tex = modified_tex

            # 5. Validar sintaxe LaTeX
            logger.info("═" * 50)
            logger.info("ETAPA 5: Validando sintaxe LaTeX")
            logger.info("═" * 50)
            is_valid, syntax_errors = validate_tex_syntax(modified_tex)
            if not is_valid:
                for err in syntax_errors:
                    logger.error("  ✗ %s", err)
                    result.errors.append(err)
                logger.error("Sintaxe LaTeX inválida. Abortando compilação.")
                return result
            logger.info("  ✓ Sintaxe LaTeX válida")

            # 6. Gerar diff
            result.diff_text = self._generate_diff(
                result.original_experiences,
                result.modified_experiences,
                result.original_skills,
                result.modified_skills,
            )

            # 7. Salvar .tex modificado
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            tex_filename = f"curriculo_tailored_{timestamp}"
            tex_output = self.output_dir / f"{tex_filename}.tex"
            tex_output.write_text(modified_tex, encoding="utf-8")
            result.tex_path = str(tex_output)
            logger.info("  ✓ .tex salvo: %s", tex_output)

            # 8. Compilar PDF (se disponível e solicitado)
            if compile_pdf and is_pdflatex_available():
                logger.info("═" * 50)
                logger.info("ETAPA 6: Compilando PDF")
                logger.info("═" * 50)
                success, pdf_path, comp_log = compile_tex_to_pdf(
                    tex_content=modified_tex,
                    output_dir=self.output_dir,
                    filename=tex_filename,
                )
                result.compilation_log = comp_log
                if success:
                    result.pdf_path = pdf_path
                    logger.info("  ✓ PDF gerado: %s", pdf_path)
                else:
                    logger.warning("  ⚠ PDF não compilado: %s", comp_log[:200])
                    result.errors.append(f"Compilação PDF falhou: {comp_log[:200]}")
            elif compile_pdf:
                msg = "pdflatex não disponível. .tex salvo para compilação via Docker (Fase 2)."
                logger.info("  ℹ %s", msg)
            
            result.success = True

        except Exception as e:
            logger.exception("Erro durante tailoring: %s", e)
            result.errors.append(str(e))

        return result

    def _generate_diff(
        self,
        original_exps: list[ExperienceBlock],
        modified_exps: list[ExperienceBlock],
        original_skills: SkillsBlock | None,
        modified_skills: SkillsBlock | None,
    ) -> str:
        """
        Gera um diff visual entre os bullets originais e modificados.

        Args:
            original_exps: Experiências originais
            modified_exps: Experiências modificadas
            original_skills: Habilidades originais
            modified_skills: Habilidades modificadas

        Returns:
            Texto formatado do diff
        """
        lines = []
        lines.append("=" * 70)
        lines.append("DIFF: ALTERAÇÕES NOS BULLET POINTS")
        lines.append("=" * 70)

        for orig, mod in zip(original_exps, modified_exps):
            lines.append(f"\n{'─' * 50}")
            lines.append(f"📋 {orig.empresa} | {orig.cargo}")
            lines.append(f"{'─' * 50}")

            max_bullets = max(len(orig.bullets), len(mod.bullets))
            for i in range(max_bullets):
                orig_bullet = orig.bullets[i] if i < len(orig.bullets) else "(novo)"
                mod_bullet = mod.bullets[i] if i < len(mod.bullets) else "(removido)"

                if orig_bullet != mod_bullet:
                    lines.append(f"\n  Bullet {i + 1}:")
                    lines.append(f"  ❌ ANTES: {orig_bullet}")
                    lines.append(f"  ✅ DEPOIS: {mod_bullet}")
                else:
                    lines.append(f"\n  Bullet {i + 1}: (sem alteração)")
                    lines.append(f"  ── {orig_bullet[:80]}...")

        if original_skills and modified_skills:
            lines.append(f"\n{'─' * 50}")
            lines.append("📋 HABILIDADES")
            lines.append(f"{'─' * 50}")
            for i, (orig_item, mod_item) in enumerate(
                zip_longest(
                    original_skills.items,
                    modified_skills.items,
                    fillvalue="(vazio)"
                )
            ):
                if orig_item != mod_item:
                    lines.append(f"\n  Item {i + 1}:")
                    lines.append(f"  ❌ ANTES: {orig_item}")
                    lines.append(f"  ✅ DEPOIS: {mod_item}")

        lines.append(f"\n{'=' * 70}")
        return '\n'.join(lines)
