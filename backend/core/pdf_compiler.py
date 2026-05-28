"""
pdf_compiler.py — Compilação de arquivos .tex em PDF via pdflatex.

Responsável por:
  - Verificar se pdflatex está disponível no sistema
  - Compilar o .tex modificado em PDF
  - Capturar erros de compilação e reportar
"""

import os
import shutil
import subprocess
import tempfile
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


def is_pdflatex_available() -> bool:
    """
    Verifica se pdflatex está instalado e acessível no PATH.

    Returns:
        True se pdflatex está disponível
    """
    return shutil.which("pdflatex") is not None


def compile_tex_to_pdf(
    tex_content: str,
    output_dir: str | Path,
    filename: str = "curriculo_tailored",
) -> tuple[bool, str, str]:
    """
    Compila um conteúdo .tex em PDF usando pdflatex.

    O processo:
    1. Salva o .tex em um diretório temporário
    2. Executa pdflatex (2x para referências cruzadas)
    3. Move o PDF resultante para o output_dir
    4. Limpa arquivos temporários

    Args:
        tex_content: Conteúdo completo do arquivo .tex
        output_dir: Diretório onde salvar o PDF final
        filename: Nome base do arquivo (sem extensão)

    Returns:
        Tupla (sucesso: bool, pdf_path: str, log_output: str)
        - sucesso: True se o PDF foi gerado com sucesso
        - pdf_path: Caminho completo do PDF gerado (vazio se falhou)
        - log_output: Saída do pdflatex (para debug)
    """
    if not is_pdflatex_available():
        msg = (
            "pdflatex não encontrado no sistema. "
            "Instale TeX Live ou MiKTeX, ou use Docker (Fase 2)."
        )
        logger.error(msg)
        return False, "", msg

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Usa diretório temporário para a compilação
    with tempfile.TemporaryDirectory() as tmpdir:
        tex_path = Path(tmpdir) / f"{filename}.tex"
        tex_path.write_text(tex_content, encoding="utf-8")

        # Executa pdflatex 2 vezes (para resolver referências)
        full_log = ""
        for run in range(2):
            logger.info("Executando pdflatex (passada %d/2)...", run + 1)
            try:
                result = subprocess.run(
                    [
                        "pdflatex",
                        "-interaction=nonstopmode",
                        "-halt-on-error",
                        f"-output-directory={tmpdir}",
                        str(tex_path),
                    ],
                    capture_output=True,
                    text=True,
                    timeout=60,
                    cwd=tmpdir,
                )
                full_log += f"\n--- Passada {run + 1} ---\n"
                full_log += result.stdout
                if result.stderr:
                    full_log += f"\nSTDERR:\n{result.stderr}"

                if result.returncode != 0:
                    logger.error("pdflatex falhou (passada %d). Exit code: %d", run + 1, result.returncode)
                    # Extrai linhas de erro relevantes
                    error_lines = _extract_latex_errors(result.stdout)
                    error_msg = '\n'.join(error_lines) if error_lines else result.stdout[-500:]
                    return False, "", f"Erro na compilação LaTeX:\n{error_msg}"

            except subprocess.TimeoutExpired:
                logger.error("pdflatex timeout (>60s)")
                return False, "", "Timeout: pdflatex demorou mais de 60 segundos."
            except FileNotFoundError:
                return False, "", "pdflatex não encontrado no PATH."

        # Move PDF para output_dir
        pdf_tmp = Path(tmpdir) / f"{filename}.pdf"
        if pdf_tmp.exists():
            pdf_final = output_dir / f"{filename}.pdf"
            shutil.copy2(str(pdf_tmp), str(pdf_final))

            # Também salva o .tex modificado
            tex_final = output_dir / f"{filename}.tex"
            shutil.copy2(str(tex_path), str(tex_final))

            logger.info("PDF gerado com sucesso: %s", pdf_final)
            return True, str(pdf_final), full_log
        else:
            return False, "", "PDF não foi gerado (arquivo não encontrado após compilação)."


def _extract_latex_errors(log_text: str) -> list[str]:
    """
    Extrai linhas de erro relevantes do log do pdflatex.

    Args:
        log_text: Saída completa do pdflatex

    Returns:
        Lista de linhas de erro relevantes
    """
    errors = []
    lines = log_text.split('\n')
    for i, line in enumerate(lines):
        if line.startswith('!') or 'Error' in line or 'Fatal' in line:
            # Inclui a linha de erro e as próximas 2 para contexto
            errors.append(line)
            for j in range(1, 3):
                if i + j < len(lines):
                    errors.append(lines[i + j])
            errors.append('')  # Separador
    return errors
