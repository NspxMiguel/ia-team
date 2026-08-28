"""Reconhece erros de limite e indisponibilidade nos logs dos agentes."""

import math
import re
from datetime import datetime, timedelta


LIMITE_QUOTA = 60 * 60

_NUMERO = r"[0-9]+(?:[.,][0-9]+)?"
_UNIDADE = (
    r"milliseconds?|msecs?|ms|seconds?|secs?|s|minutes?|mins?|m(?!s)|"
    r"hours?|hrs?|h|days?|d"
)
_DURACAO = re.compile(
    r"\b(?:please\s+)?(?:try again|retry|resets?|will reset)\s+in\s+"
    r"(?P<duracao>(?:" + _NUMERO + r")\s*(?:" + _UNIDADE + r")"
    r"(?:\s*(?:" + _NUMERO + r")\s*(?:" + _UNIDADE + r"))*)",
    re.IGNORECASE,
)
_PARTE_DURACAO = re.compile(
    r"(?P<numero>" + _NUMERO + r")\s*(?P<unidade>" + _UNIDADE + r")",
    re.IGNORECASE,
)
_RETRY_AFTER_MS = re.compile(
    r"\bretry-after-ms\s*:\s*(?P<numero>" + _NUMERO + r")",
    re.IGNORECASE,
)
_RETRY_AFTER = re.compile(
    r"\bretry-after\s*:\s*(?P<numero>" + _NUMERO + r")",
    re.IGNORECASE,
)
_HORA_ABSOLUTA = re.compile(
    r"\b(?:resets?|will reset)(?:\s+(?:at|on))?\s+"
    r"(?:(?P<dia>mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|"
    r"fri(?:day)?|sat(?:urday)?|sun(?:day)?)\s+)?"
    r"(?P<hora>[0-9]{1,2}):(?P<minuto>[0-9]{2})\s*"
    r"(?P<periodo>a\.?m\.?|p\.?m\.?)\b",
    re.IGNORECASE,
)

_AUTENTICACAO = (
    re.compile(r"\bHTTP\s+(?:401|403)\b", re.IGNORECASE),
    re.compile(r"\b(?:unauthorized|unauthenticated|authentication_error)\b", re.IGNORECASE),
    re.compile(r"\b(?:invalid|incorrect|missing|expired)[ _-]*(?:api[ _-]*)?key\b", re.IGNORECASE),
    re.compile(r"\b(?:not signed in|login required|please (?:log|sign) in)\b", re.IGNORECASE),
)

# Os sinais de janela curta vêm antes dos apelos para fazer upgrade: vários
# provedores incluem esse apelo também num 429 que acaba em poucos segundos.
_RATE_FORTE = (
    re.compile(r"\brate[ _-]*limit(?:ed|[ _-]*(?:reached|exceeded))?\b", re.IGNORECASE),
    re.compile(r"\btoo many requests\b", re.IGNORECASE),
    re.compile(r"\b(?:tokens?|requests?)\s+per\s+min(?:ute)?\b|\bTPM\b|\bRPM\b", re.IGNORECASE),
)
_QUOTA = (
    re.compile(r"\binsufficient[ _-]*quota\b", re.IGNORECASE),
    re.compile(r"\b(?:individual\s+)?quota\s+(?:reached|exceeded|exhausted)\b", re.IGNORECASE),
    re.compile(r"\byou exceeded your current quota\b", re.IGNORECASE),
    re.compile(r"\bRESOURCE_EXHAUSTED\b", re.IGNORECASE),
    re.compile(r"\b(?:out of|no|insufficient)\s+credits?\b|\bcredit balance\b", re.IGNORECASE),
    re.compile(r"\b(?:daily|weekly|monthly|5-hour)\s+limit(?:\s+(?:reached|exceeded))?\b", re.IGNORECASE),
    # "You've hit your usage limit" vem sem espaço antes do apóstrofo, e o
    # apóstrofo pode ser reto ou tipográfico. Exigir "you 've" fazia o Codex
    # sem cota passar por erro genérico — três falhas seguidas sem diagnóstico.
    re.compile(r"\byou\s*(?:['\u2019]ve|have)?\s*hit your (?:usage |weekly |daily |monthly )?limit\b",
               re.IGNORECASE),
    re.compile(r"\bpurchase more credits\b|\bupgrade to pro\b", re.IGNORECASE),
    re.compile(r"\b(?:tokens?|requests?)\s+per\s+day\b|\bTPD\b|\bRPD\b", re.IGNORECASE),
    re.compile(r"\b(?:billing|spending)\s+(?:hard\s+)?limit\b", re.IGNORECASE),
    re.compile(r"\bupgrade your (?:subscription|plan)\b", re.IGNORECASE),
    re.compile(r"\b0 weighted tokens left\b", re.IGNORECASE),
    re.compile(r"\[QUOTA\]", re.IGNORECASE),
)
_RATE_GENERICO = (
    re.compile(r"\bHTTP\s+429\b", re.IGNORECASE),
    re.compile(r"\b429\s+Too Many Requests\b", re.IGNORECASE),
)
_ERRO = (
    re.compile(r"\bHTTP\s+(?:4[0-9]{2}|5[0-9]{2})\b", re.IGNORECASE),
    re.compile(r"(?:^|[\r\n])\s*(?:error|erro)\s*:", re.IGNORECASE),
    re.compile(r"[\"']error[\"']\s*:", re.IGNORECASE),
    re.compile(r"\b(?:internal server error|service unavailable|request timed out)\b", re.IGNORECASE),
)

_DIAS = {"mon": 0, "tue": 1, "wed": 2, "thu": 3,
         "fri": 4, "sat": 5, "sun": 6}


def _primeiro(texto, padroes):
    """Devolve o primeiro trecho no texto, não o primeiro padrão da lista."""
    encontrados = (padrao.search(texto) for padrao in padroes)
    encontrados = [achado for achado in encontrados if achado]
    return min(encontrados, key=lambda achado: achado.start()) if encontrados else None


def _segundos(numero, unidade):
    valor = float(numero.replace(",", "."))
    unidade = unidade.lower()
    if unidade.startswith("ms") or unidade.startswith("millisecond"):
        return valor / 1000.0
    if unidade == "m" or unidade.startswith("min"):
        return valor * 60
    if unidade == "h" or unidade.startswith("h"):
        return valor * 60 * 60
    if unidade == "d" or unidade.startswith("d"):
        return valor * 24 * 60 * 60
    return valor


def _espera_relativa(texto):
    achado = _RETRY_AFTER_MS.search(texto)
    if achado:
        valor = float(achado.group("numero").replace(",", ".")) / 1000.0
        return max(0, int(math.ceil(valor))), achado

    achado = _RETRY_AFTER.search(texto)
    if achado:
        valor = float(achado.group("numero").replace(",", "."))
        return max(0, int(math.ceil(valor))), achado

    achado = _DURACAO.search(texto)
    if not achado:
        return None, None
    total = sum(
        _segundos(parte.group("numero"), parte.group("unidade"))
        for parte in _PARTE_DURACAO.finditer(achado.group("duracao"))
    )
    return max(0, int(math.ceil(total))), achado


def _espera_absoluta(texto):
    achado = _HORA_ABSOLUTA.search(texto)
    if not achado:
        return None, None

    hora = int(achado.group("hora"))
    minuto = int(achado.group("minuto"))
    if not 1 <= hora <= 12 or minuto > 59:
        return None, None

    periodo = achado.group("periodo").replace(".", "").lower()
    hora = hora % 12 + (12 if periodo == "pm" else 0)
    agora = datetime.now()
    alvo = agora.replace(hour=hora, minute=minuto, second=0, microsecond=0)

    dia = achado.group("dia")
    if dia:
        alvo += timedelta(days=(_DIAS[dia[:3].lower()] - agora.weekday()) % 7)
        if alvo <= agora:
            alvo += timedelta(days=7)
    elif alvo <= agora:
        alvo += timedelta(days=1)

    return max(0, int(math.ceil((alvo - agora).total_seconds()))), achado


def _provedor(texto):
    baixo = texto.lower()
    if "retry-after-ms" in baixo or "azure openai" in baixo or "azure" in baixo:
        return "azure"
    for nome in ("openrouter", "groq", "cerebras", "mistral", "together",
                 "deepseek", "cursor"):
        if nome in baixo:
            return nome
    if "individual quota reached" in baixo or "antigravity" in baixo:
        return "antigravity"
    if "anthropic" in baixo or "claude" in baixo or "5-hour limit" in baixo \
            or "weekly limit" in baixo:
        return "anthropic"
    if "gemini" in baixo or "google" in baixo or "weighted tokens" in baixo \
            or "resource_exhausted" in baixo or re.search(r"please retry in\s+[0-9]+\.[0-9]{4}", baixo):
        return "google"
    if "tokens per day" in baixo or re.search(r"try again in\s*[0-9.]+\s*ms", baixo):
        return "groq"
    if "you exceeded your current quota" in baixo:
        return "google"
    if "openai" in baixo or "codex" in baixo or re.search(
            r"rate limit reached.+organization.+tokens per min", baixo, re.DOTALL):
        return "openai"
    return None


def _resultado(tipo=None, espera=0, fonte="", provedor=None):
    return {"tipo": tipo, "espera": espera, "fonte": fonte,
            "provedor": provedor}


def analisar(texto):
    """Analisa ``texto`` e devolve tipo, espera, fonte e provedor.

    Uma espera conhecida decide entre limite transitório (menos de uma hora) e
    cota (uma hora ou mais). Sem espera, a terminologia do provedor decide.
    """
    if not isinstance(texto, str) or not texto:
        return _resultado()

    autenticacao = _primeiro(texto, _AUTENTICACAO)
    if autenticacao:
        return _resultado("auth", fonte=autenticacao.group(0),
                          provedor=_provedor(texto))

    espera, tempo = _espera_relativa(texto)
    if tempo is None:
        espera, tempo = _espera_absoluta(texto)
    if tempo is not None:
        tipo = "quota" if espera >= LIMITE_QUOTA else "rate"
        return _resultado(tipo, espera, tempo.group(0), _provedor(texto))

    rate = _primeiro(texto, _RATE_FORTE)
    quota = _primeiro(texto, _QUOTA)
    diario = re.search(r"\b(?:tokens?|requests?)\s+per\s+day\b|\b(?:TPD|RPD)\b",
                       texto, re.IGNORECASE)
    if rate and not diario:
        return _resultado("rate", fonte=rate.group(0), provedor=_provedor(texto))
    if quota:
        return _resultado("quota", fonte=quota.group(0), provedor=_provedor(texto))

    rate = _primeiro(texto, _RATE_GENERICO)
    if rate:
        return _resultado("rate", fonte=rate.group(0), provedor=_provedor(texto))

    erro = _primeiro(texto, _ERRO)
    if erro:
        return _resultado("erro", fonte=erro.group(0), provedor=_provedor(texto))
    return _resultado()
