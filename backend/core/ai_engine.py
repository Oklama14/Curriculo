"""
ai_engine.py — Integração com a API do Google Gemini.

Responsável por:
  - Enviar bullet points + descrição da vaga ao Gemini
  - Receber e parsear os bullets otimizados da resposta
  - Validar que nenhuma informação foi fabricada
"""

import os
import re
import time
import logging

from google import genai
from google.genai import types
from google.genai.errors import ClientError, ServerError

from .prompt_templates import (
    SYSTEM_PROMPT_TAILOR,
    SYSTEM_PROMPT_SKILLS,
    USER_PROMPT_TEMPLATE,
)
from .latex_parser import (
    ExperienceBlock,
    SkillsBlock,
    format_all_experiences_for_prompt,
)

logger = logging.getLogger(__name__)


class AIEngine:
    """Motor de IA que utiliza o Google Gemini para otimizar currículos."""

    def __init__(self, api_key: str | None = None, model: str | None = None):
        """
        Inicializa o motor de IA.

        Args:
            api_key: Chave da API do Gemini. Se None, usa a variável GEMINI_API_KEY.
            model: Nome do modelo. Se None, usa GEMINI_MODEL ou gemini-2.0-flash.
        """
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            raise ValueError(
                "GEMINI_API_KEY não configurada. "
                "Defina a variável de ambiente ou passe via parâmetro."
            )

        self.model_name = model or os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
        self.max_retries = 3
        self.base_retry_delay = 20  # segundos

        self.client = genai.Client(api_key=self.api_key)

        logger.info("AIEngine inicializado com modelo: %s", self.model_name)

    def tailor_experiences(
        self,
        experiences: list[ExperienceBlock],
        job_description: str,
        skills_text: str = "",
    ) -> list[ExperienceBlock]:
        """
        Envia as experiências e a vaga ao Gemini e retorna bullets otimizados.

        Args:
            experiences: Lista de blocos de experiência originais
            job_description: Texto da descrição da vaga
            skills_text: Texto das habilidades do currículo (para contexto)

        Returns:
            Lista de ExperienceBlock com bullets modificados pelo Gemini
        """
        experiences_text = format_all_experiences_for_prompt(experiences)

        user_prompt = USER_PROMPT_TEMPLATE.format(
            job_description=job_description,
            experiences_text=experiences_text,
            skills_text=skills_text,
            num_experiences=len(experiences),
        )

        logger.info("Enviando prompt ao Gemini (%d caracteres)...", len(user_prompt))

        response = self._call_gemini(
            contents=user_prompt,
            system_instruction=SYSTEM_PROMPT_TAILOR,
            temperature=0.15,
            max_output_tokens=8192,
        )

        response_text = response.text
        logger.info(
            "Resposta recebida (%d caracteres). Tokens: prompt=%s, resposta=%s",
            len(response_text),
            getattr(response.usage_metadata, 'prompt_token_count', '?'),
            getattr(response.usage_metadata, 'candidates_token_count', '?'),
        )

        # Parse da resposta em blocos por experiência
        modified_experiences = self._parse_experience_response(
            response_text, experiences
        )

        return modified_experiences

    def tailor_skills(
        self,
        skills: SkillsBlock,
        job_description: str,
    ) -> SkillsBlock:
        """
        Otimiza a seção de habilidades para a vaga alvo.

        Args:
            skills: Bloco de habilidades original
            job_description: Texto da descrição da vaga

        Returns:
            SkillsBlock com itens reordenados/ajustados
        """
        skills_text = '\n'.join(f"\\item {item}" for item in skills.items)

        user_prompt = (
            f"## DESCRIÇÃO DA VAGA\n\n{job_description}\n\n"
            f"---\n\n## HABILIDADES ATUAIS\n\n{skills_text}\n\n"
            f"---\n\nReordene e ajuste conforme as regras."
        )

        response = self._call_gemini(
            contents=user_prompt,
            system_instruction=SYSTEM_PROMPT_SKILLS,
            temperature=0.1,
            max_output_tokens=8192,
        )

        new_items = self._extract_items_from_response(response.text)

        if not new_items:
            logger.warning("Nenhum item extraído da resposta de skills. Mantendo original.")
            return skills

        return SkillsBlock(
            items=new_items,
            itemize_start=skills.itemize_start,
            itemize_end=skills.itemize_end,
        )

    def _call_gemini(
        self,
        contents: str,
        system_instruction: str,
        temperature: float = 0.15,
        max_output_tokens: int = 4096,
    ):
        """
        Chama a API do Gemini com retry automático para rate limits.

        Implementa backoff exponencial: espera 20s, 40s, 60s entre tentativas.
        Trata erros 429 (RESOURCE_EXHAUSTED) com mensagens amigáveis.

        Args:
            contents: Conteúdo do prompt
            system_instruction: System prompt
            temperature: Temperatura do modelo
            max_output_tokens: Máximo de tokens na resposta

        Returns:
            Resposta do Gemini

        Raises:
            RuntimeError: Se todas as tentativas falharem
        """
        last_error = None

        for attempt in range(1, self.max_retries + 1):
            try:
                response = self.client.models.generate_content(
                    model=self.model_name,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        system_instruction=system_instruction,
                        temperature=temperature,
                        max_output_tokens=max_output_tokens,
                    ),
                )
                return response

            except (ClientError, ServerError) as e:
                last_error = e
                error_str = str(e)
                is_retryable = (
                    "429" in error_str
                    or "RESOURCE_EXHAUSTED" in error_str
                    or "503" in error_str
                    or "UNAVAILABLE" in error_str
                )

                if is_retryable:
                    # Extrai o retry delay sugerido pela API, se disponível
                    import re as _re
                    delay_match = _re.search(r'retry.*?(\d+\.?\d*)s', error_str, _re.IGNORECASE)
                    suggested_delay = float(delay_match.group(1)) if delay_match else None

                    wait_time = suggested_delay or (self.base_retry_delay * attempt)

                    if attempt < self.max_retries:
                        logger.warning(
                            "Erro temporario da API (tentativa %d/%d): %s. "
                            "Aguardando %.0fs antes de tentar novamente...",
                            attempt, self.max_retries,
                            "Rate limit" if "429" in error_str else "Servidor indisponivel",
                            wait_time,
                        )
                        time.sleep(wait_time)
                    else:
                        raise RuntimeError(
                            f"API Gemini indisponivel apos {self.max_retries} tentativas.\n"
                            f"\n"
                            f"Possiveis solucoes:\n"
                            f"  1. Aguarde alguns minutos e tente novamente\n"
                            f"  2. Verifique sua quota em: https://ai.dev/rate-limit\n"
                            f"  3. Ative o billing no Google AI Studio para limites maiores\n"
                            f"  4. Use outro modelo: edite GEMINI_MODEL no backend/.env\n"
                            f"     Modelos disponiveis: gemini-2.0-flash, gemini-2.5-flash, gemini-1.5-flash\n"
                        ) from e
                else:
                    # Erro não-retryable — propaga imediatamente
                    raise

        # Não deveria chegar aqui, mas por segurança
        raise RuntimeError(f"Falha apos {self.max_retries} tentativas: {last_error}")

    def _parse_experience_response(
        self,
        response_text: str,
        original_experiences: list[ExperienceBlock],
    ) -> list[ExperienceBlock]:
        """
        Faz parse da resposta do Gemini em blocos de experiência.

        Identifica seções [EXPERIÊNCIA: Nome] e extrai os \\item de cada uma.
        Se não encontrar marcadores, tenta dividir por blocos de \\item.

        Args:
            response_text: Texto bruto da resposta do Gemini
            original_experiences: Experiências originais (para manter metadados)

        Returns:
            Lista de ExperienceBlock com bullets atualizados
        """
        modified = []

        # Tenta encontrar blocos marcados com [EXPERIÊNCIA: ...]
        exp_blocks = re.split(
            r'\[EXPERIÊNCIA:\s*(.+?)\]',
            response_text
        )

        if len(exp_blocks) > 1:
            # Formato com marcadores: [nome, conteúdo, nome, conteúdo, ...]
            # O primeiro elemento é o texto antes do primeiro marcador (ignorar)
            pairs = []
            for i in range(1, len(exp_blocks), 2):
                name = exp_blocks[i].strip()
                content = exp_blocks[i + 1] if i + 1 < len(exp_blocks) else ""
                pairs.append((name, content))

            for original in original_experiences:
                # Encontra o bloco correspondente pelo nome da empresa
                matched_content = None
                for name, content in pairs:
                    if _fuzzy_match(original.empresa, name):
                        matched_content = content
                        break

                if matched_content:
                    items = self._extract_items_from_response(matched_content)
                else:
                    logger.warning(
                        "Empresa '%s' não encontrada na resposta. Mantendo original.",
                        original.empresa
                    )
                    items = original.bullets

                modified.append(ExperienceBlock(
                    empresa=original.empresa,
                    cargo=original.cargo,
                    periodo=original.periodo,
                    localidade=original.localidade,
                    bullets=items if items else original.bullets,
                    itemize_start=original.itemize_start,
                    itemize_end=original.itemize_end,
                ))
        else:
            # Fallback: divide todos os \item entre as experiências proporcionalmente
            all_items = self._extract_items_from_response(response_text)
            if all_items:
                modified = self._distribute_items(all_items, original_experiences)
            else:
                logger.warning("Não foi possível extrair items da resposta. Mantendo original.")
                modified = original_experiences

        return modified

    def _extract_items_from_response(self, text: str) -> list[str]:
        """
        Extrai textos de \\item de um bloco de texto.

        Args:
            text: Texto contendo \\item entries

        Returns:
            Lista com o texto de cada item (sem o \\item prefix)
        """
        # Remove blocos de código markdown se presentes
        text = re.sub(r'```\w*\n?', '', text)

        items = []
        pattern = re.compile(r'\\item\s+(.+?)(?=\\item|$)', re.DOTALL)
        for match in pattern.finditer(text):
            item_text = match.group(1).strip()
            # Remove quebras de linha internas
            item_text = re.sub(r'\s+', ' ', item_text)
            if item_text:
                items.append(item_text)

        return items

    def _distribute_items(
        self,
        all_items: list[str],
        original_experiences: list[ExperienceBlock],
    ) -> list[ExperienceBlock]:
        """
        Distribui items proporcionalmente entre as experiências originais.

        Usado como fallback quando a IA não usa marcadores de experiência.

        Args:
            all_items: Todos os \\item extraídos da resposta
            original_experiences: Experiências originais

        Returns:
            Experiências com bullets distribuídos
        """
        modified = []
        idx = 0
        for original in original_experiences:
            n = len(original.bullets)
            assigned = all_items[idx:idx + n] if idx < len(all_items) else original.bullets
            idx += n

            modified.append(ExperienceBlock(
                empresa=original.empresa,
                cargo=original.cargo,
                periodo=original.periodo,
                localidade=original.localidade,
                bullets=assigned if assigned else original.bullets,
                itemize_start=original.itemize_start,
                itemize_end=original.itemize_end,
            ))

        return modified


def _fuzzy_match(original: str, candidate: str) -> bool:
    """
    Verifica se dois nomes de empresa são equivalentes (match fuzzy).

    Compara ignorando case, espaços extras e caracteres especiais comuns.

    Args:
        original: Nome original da empresa
        candidate: Nome candidato da resposta

    Returns:
        True se os nomes são considerados equivalentes
    """
    def normalize(s: str) -> str:
        s = s.lower().strip()
        s = re.sub(r'[|/\\–—-]', ' ', s)
        s = re.sub(r'\s+', ' ', s)
        return s

    norm_orig = normalize(original)
    norm_cand = normalize(candidate)

    # Match exato ou substring
    if norm_orig == norm_cand:
        return True
    if norm_orig in norm_cand or norm_cand in norm_orig:
        return True

    # Compara primeiras palavras significativas (ignorando termos genéricos comuns)
    GENERIC_WORDS = {
        "empresa", "tecnologia", "solucao", "solucoes", "comercio", "servicos",
        "sistemas", "logistica", "internacional", "despachos", "aduaneiros",
        "ltda", "corporation", "corp", "inc", "co", "limitada", "brasil",
        "brazil", "group", "grupo", "associados", "consultoria", "assessoria",
        "soluções", "tecnologias", "indústria", "industria", "comércio", "serviços",
        "importação", "exportação", "importacao", "exportacao"
    }

    words_orig = [w for w in norm_orig.split() if len(w) > 2 and w not in GENERIC_WORDS]
    words_cand = [w for w in norm_cand.split() if len(w) > 2 and w not in GENERIC_WORDS]
    if words_orig and words_cand:
        common = set(words_orig) & set(words_cand)
        if len(common) >= 1:
            return True

    return False
