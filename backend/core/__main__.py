"""
__main__.py — Ponto de entrada CLI para a PoC do AI Resume Tailor.

Uso:
    python -m backend.core --job "descrição da vaga"
    python -m backend.core --job-file caminho/para/vaga.txt
    python -m backend.core --job-file backend/examples/vaga_exemplo.txt
"""

import argparse
import logging
import sys
from pathlib import Path

from dotenv import load_dotenv

from .tailor import ResumeTailor
from .pdf_compiler import is_pdflatex_available


def setup_logging(verbose: bool = False) -> None:
    """Configura o logging para console com formatação colorida."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s │ %(levelname)-8s │ %(message)s",
        datefmt="%H:%M:%S",
        handlers=[logging.StreamHandler(sys.stdout)],
    )


def main():
    parser = argparse.ArgumentParser(
        description="AI Resume Tailor — Otimiza seu currículo LaTeX para vagas específicas usando IA",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  python -m backend.core --job-file backend/examples/vaga_exemplo.txt
  python -m backend.core --job "Estamos buscando um QA Analyst com experiência em automação..."
  python -m backend.core --job-file vaga.txt --no-skills --verbose
        """,
    )

    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument(
        "--job",
        type=str,
        help="Texto da descrição da vaga (inline)",
    )
    input_group.add_argument(
        "--job-file",
        type=str,
        help="Caminho para arquivo .txt com a descrição da vaga",
    )

    parser.add_argument(
        "--tex",
        type=str,
        default="curriculo.tex",
        help="Caminho para o arquivo .tex do currículo (default: curriculo.tex)",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="backend/output",
        help="Diretório de saída (default: backend/output)",
    )
    parser.add_argument(
        "--no-skills",
        action="store_true",
        help="Não otimizar a seção de habilidades",
    )
    parser.add_argument(
        "--no-pdf",
        action="store_true",
        help="Não tentar compilar PDF (apenas gerar .tex)",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Logging detalhado (DEBUG)",
    )

    args = parser.parse_args()
    setup_logging(args.verbose)
    logger = logging.getLogger(__name__)

    # Carrega variáveis de ambiente
    env_path = Path("backend/.env")
    if env_path.exists():
        load_dotenv(env_path)
        logger.info("✓ Variáveis de ambiente carregadas de %s", env_path)
    else:
        load_dotenv()
        if not env_path.exists():
            logger.warning(
                "⚠ Arquivo .env não encontrado em backend/.env. "
                "Copie backend/.env.example para backend/.env e configure sua API key."
            )

    # Lê descrição da vaga
    if args.job_file:
        job_file = Path(args.job_file)
        if not job_file.exists():
            logger.error("✗ Arquivo de vaga não encontrado: %s", job_file)
            sys.exit(1)
        job_description = job_file.read_text(encoding="utf-8")
        logger.info("✓ Vaga carregada de: %s (%d caracteres)", job_file, len(job_description))
    else:
        job_description = args.job

    # Verifica pdflatex
    if not args.no_pdf and not is_pdflatex_available():
        logger.warning(
            "⚠ pdflatex não encontrado. O .tex será gerado mas o PDF não será compilado. "
            "Instale TeX Live/MiKTeX ou use --no-pdf para silenciar este aviso."
        )

    # Executa o tailoring
    print()
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║            🤖  AI Resume Tailor — PoC v1.0                 ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()

    try:
        tailor = ResumeTailor(
            tex_path=args.tex,
            output_dir=args.output,
        )

        result = tailor.tailor(
            job_description=job_description,
            tailor_skills=not args.no_skills,
            compile_pdf=not args.no_pdf,
        )

        # Exibe resultado
        print()
        if result.success:
            print("╔══════════════════════════════════════════════════════════════╗")
            print("║                    ✅  SUCESSO!                             ║")
            print("╚══════════════════════════════════════════════════════════════╝")
            print()
            print(result.diff_text)
            print()
            print(f"📄 .tex salvo em: {result.tex_path}")
            if result.pdf_path:
                print(f"📋 .pdf salvo em: {result.pdf_path}")
            else:
                print("📋 PDF não compilado (pdflatex indisponível)")
            print()

            if result.errors:
                print("⚠ Avisos:")
                for err in result.errors:
                    print(f"  - {err}")
        else:
            print("╔══════════════════════════════════════════════════════════════╗")
            print("║                    ❌  FALHOU                               ║")
            print("╚══════════════════════════════════════════════════════════════╝")
            print()
            for err in result.errors:
                print(f"  ✗ {err}")

    except FileNotFoundError as e:
        logger.error("✗ %s", e)
        sys.exit(1)
    except ValueError as e:
        logger.error("✗ Erro de configuração: %s", e)
        sys.exit(1)
    except Exception as e:
        logger.exception("✗ Erro inesperado: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
