import os
import sys
import unittest
from datetime import datetime
from unittest.mock import patch


sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import quota  # noqa: E402


class AnalisarQuotaTest(unittest.TestCase):
    def test_openai_limite_por_minuto(self):
        resultado = quota.analisar(
            "Rate limit reached for gpt-5 in organization org_1 on tokens per "
            "min (TPM): Limit 100000, Used 96749"
        )
        self.assertEqual(resultado["tipo"], "rate")
        self.assertEqual(resultado["espera"], 0)
        self.assertEqual(resultado["provedor"], "openai")
        self.assertIn("Rate limit reached", resultado["fonte"])

    def test_retry_after_em_segundos(self):
        resultado = quota.analisar("HTTP 429\nRetry-After: 30")
        self.assertEqual(resultado["tipo"], "rate")
        self.assertEqual(resultado["espera"], 30)
        self.assertEqual(resultado["fonte"], "Retry-After: 30")

    def test_cursor_e_openrouter_com_429(self):
        for provedor in ("Cursor", "OpenRouter"):
            with self.subTest(provedor=provedor):
                resultado = quota.analisar(
                    "%s: HTTP 429 Too Many Requests; Retry-After: 20" % provedor
                )
                self.assertEqual(resultado["tipo"], "rate")
                self.assertEqual(resultado["espera"], 20)
                self.assertEqual(resultado["provedor"], provedor.lower())

    def test_retry_after_ms_do_azure(self):
        resultado = quota.analisar("Azure OpenAI 429; retry-after-ms: 4500")
        self.assertEqual(resultado["tipo"], "rate")
        self.assertEqual(resultado["espera"], 5)
        self.assertEqual(resultado["provedor"], "azure")

    def test_retry_fracionario_do_gemini(self):
        resultado = quota.analisar(
            "Gemini RESOURCE_EXHAUSTED. Please retry in 15.002899939s"
        )
        self.assertEqual(resultado["tipo"], "rate")
        self.assertEqual(resultado["espera"], 16)
        self.assertEqual(resultado["provedor"], "google")

    def test_resource_exhausted_sem_tempo_e_quota(self):
        resultado = quota.analisar("Gemini API: RESOURCE_EXHAUSTED")
        self.assertEqual(resultado["tipo"], "quota")
        self.assertEqual(resultado["espera"], 0)

    def test_quota_atual_excedida(self):
        resultado = quota.analisar("You exceeded your current quota")
        self.assertEqual(resultado["tipo"], "quota")

    def test_groq_em_milissegundos(self):
        resultado = quota.analisar("Groq: Please try again in 960ms")
        self.assertEqual(resultado["tipo"], "rate")
        self.assertEqual(resultado["espera"], 1)
        self.assertEqual(resultado["provedor"], "groq")

    def test_groq_limite_diario_e_quota(self):
        resultado = quota.analisar(
            "Groq rate_limit_exceeded on tokens per day (TPD): Limit 100000"
        )
        self.assertEqual(resultado["tipo"], "quota")
        self.assertEqual(resultado["espera"], 0)

    def test_rate_limit_exceeded_sem_tempo(self):
        resultado = quota.analisar('{"code":"rate_limit_exceeded"}')
        self.assertEqual(resultado["tipo"], "rate")

    def test_antigravity_com_duracao_composta(self):
        resultado = quota.analisar(
            "Error: Individual quota reached. Please upgrade your subscription "
            "to increase your limits. Resets in 159h20m58s."
        )
        self.assertEqual(resultado["tipo"], "quota")
        self.assertEqual(resultado["espera"], 573658)
        self.assertEqual(resultado["provedor"], "antigravity")

    def test_hora_absoluta_no_proximo_dia(self):
        agora = datetime(2026, 8, 21, 16, 0, 0)  # sexta-feira
        with patch("quota.datetime") as relogio:
            relogio.now.return_value = agora
            resultado = quota.analisar("Claude 5-hour limit reached - resets 3:45pm")
        self.assertEqual(resultado["tipo"], "quota")
        self.assertEqual(resultado["espera"], 23 * 3600 + 45 * 60)
        self.assertEqual(resultado["provedor"], "anthropic")

    def test_hora_absoluta_com_dia_da_semana(self):
        agora = datetime(2026, 8, 21, 13, 0, 0)  # sexta-feira
        with patch("quota.datetime") as relogio:
            relogio.now.return_value = agora
            resultado = quota.analisar(
                "Claude: You have hit your weekly limit - resets Mon 12:00am"
            )
        self.assertEqual(resultado["tipo"], "quota")
        self.assertEqual(resultado["espera"], 59 * 3600)
        self.assertGreaterEqual(resultado["espera"], 0)

    def test_duracao_prevalece_sobre_as_palavras(self):
        curto = quota.analisar("Individual quota reached; retry in 30s")
        longo = quota.analisar("Rate limit reached; retry in 2h")
        self.assertEqual(curto["tipo"], "rate")
        self.assertEqual(longo["tipo"], "quota")

    def test_auth(self):
        resultado = quota.analisar("OpenAI HTTP 401: invalid API key")
        self.assertEqual(resultado["tipo"], "auth")
        self.assertEqual(resultado["espera"], 0)
        self.assertEqual(resultado["provedor"], "openai")

    def test_erro_generico(self):
        resultado = quota.analisar("HTTP 500: Internal Server Error")
        self.assertEqual(resultado["tipo"], "erro")
        self.assertEqual(resultado["espera"], 0)

    def test_texto_sem_erro(self):
        self.assertEqual(
            quota.analisar("Tarefa concluida: todos os testes passaram."),
            {"tipo": None, "espera": 0, "fonte": "", "provedor": None},
        )


    def test_codex_sem_cota(self):
        """O Codex escreve "You've hit" sem espaço antes do apóstrofo.

        Com o padrão antigo isso caía em erro genérico, e três execuções
        seguidas foram registradas como falha em vez de falta de cota.
        """
        texto = ("ERROR: You've hit your usage limit. Upgrade to Pro "
                 "(https://chatgpt.com/explore/pro), visit "
                 "https://chatgpt.com/codex/settings/usage to purchase more "
                 "credits or try again")
        self.assertEqual(quota.analisar(texto)["tipo"], "quota")

    def test_codex_apostrofo_tipografico(self):
        self.assertEqual(quota.analisar("You’ve hit your usage limit")["tipo"], "quota")


if __name__ == "__main__":
    unittest.main()
