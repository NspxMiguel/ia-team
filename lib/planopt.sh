# Ponte para o claude-plan-optimizer, quando ele existe nesta máquina.
#
# O `team` sabia escolher **quem** faz o trabalho — pelo assunto: design vai
# para o antigravity, backend para o codex. Não sabia escolher **quanto** o
# trabalho merece, então mudar uma cor e refazer uma arquitetura pegavam o mesmo
# modelo do mesmo agente.
#
# O planopt responde essa segunda pergunta. Ele é um projeto separado de
# propósito: quem quiser rodar o `team` sem ele continua rodando igual, e é por
# isso que todas as funções aqui caem no silêncio quando ele não está instalado.
# Integração que quebra a ferramenta quando a dependência falta não é opcional.

PLANOPT_BIN="${PLANOPT_BIN:-planopt}"

planopt_existe() {
  command -v "$PLANOPT_BIN" >/dev/null 2>&1
}

# A faixa de custo de uma tarefa: trivial | barata | media | cara.
# Vazio quando o planopt não está aqui, quando o pedido é continuação, ou
# quando ele não se compromete — e vazio quer dizer "decida como antes".
planopt_faixa() { # planopt_faixa <texto>
  planopt_existe || return 0
  "$PLANOPT_BIN" classifica --json "$1" 2>/dev/null | python3 -c '
import json, sys
try:
    v = json.load(sys.stdin)
except (ValueError, OSError):
    raise SystemExit
# Continuação não tem faixa de propósito: o custo é o da tarefa em curso, e o
# `team` não tem como saber qual era. Melhor não opinar do que opinar errado.
if v.get("continuacao") or not v.get("tier"):
    raise SystemExit
# Confiança baixa é em cima do corte, onde a classificação é sorte. Ali o
# silêncio vale mais que o palpite.
if (v.get("confianca") or 0) < 0.7:
    raise SystemExit
print(v["tier"])
' 2>/dev/null
}

# O modelo que aquele agente deve usar nessa faixa. Vazio quando não há opinião,
# e aí vale o padrão do adaptador.
#
# A faixa entra pronta, já classificada: o `team` classifica o texto uma vez e
# pergunta o modelo de cada candidato. Reclassificar a cada pergunta seria
# trabalho repetido e, pior, a chance de duas respostas discordarem sobre o
# mesmo pedido.
planopt_modelo() { # planopt_modelo <agente> <faixa>
  _planopt_campo modelo "$1" "$2"
}

# A fila de reserva daquela faixa, separada por vírgula.
#
# Plano gratuito estrangula por modelo, não por conta: quando um recusa, o
# vizinho costuma responder na hora. Sem esta lista, a faixa mais barata é a
# que mais falha — exatamente ao contrário do que deveria ser.
planopt_alternativas() { # planopt_alternativas <agente> <faixa>
  planopt_existe || return 0
  [ -n "${2:-}" ] || return 0
  "$PLANOPT_BIN" modelo --json "$1" "$2" 2>/dev/null | python3 -c '
import json, sys
try:
    dados = json.load(sys.stdin)
except (ValueError, OSError):
    raise SystemExit
if isinstance(dados, dict):
    print(",".join(dados.get("alternativas") or []))
' 2>/dev/null
}

# O esforço de raciocínio, para as três CLIs que aceitam um.
planopt_esforco() { # planopt_esforco <agente> <faixa>
  _planopt_campo esforco "$1" "$2"
}

# Um campo do veredito, lido do JSON e não da posição na linha.
#
# A saída de texto é para gente ler: ela junta modelo e esforço com espaço e
# omite o que está vazio. Um agente que só tem esforço — o codex, cujo modelo é
# o padrão da própria CLI — imprimia "high" na primeira coluna, e quem lesse por
# posição pegava "high" como nome de modelo. Campo tem nome; coluna não.
_planopt_campo() { # _planopt_campo <campo> <agente> <faixa>
  planopt_existe || return 0
  [ -n "${3:-}" ] || return 0
  # O prefixo de ambiente vale só para o comando à esquerda do pipe, e quem
  # precisa da variável é o python3 à direita.
  PLANOPT_CAMPO="$1" \
  "$PLANOPT_BIN" modelo --json "$2" "$3" 2>/dev/null | PLANOPT_CAMPO="$1" python3 -c '
import json, os, sys
try:
    dados = json.load(sys.stdin)
except (ValueError, OSError):
    raise SystemExit
if isinstance(dados, dict):
    valor = dados.get(os.environ.get("PLANOPT_CAMPO", "")) or ""
    if valor:
        print(valor)
' 2>/dev/null
}

# Quanto aquela carteira pesa na escolha do agente, dada a faixa.
#
# A regra que isto codifica: trabalho barato vai para quem não custa nada, e
# trabalho caro vai para o mais forte que **não** seja o plano medido. Delegar
# existe justamente para não gastar esse plano — mandar o trabalho caro de volta
# para ele seria dar a volta inteira para chegar no mesmo lugar.
planopt_peso_carteira() { # planopt_peso_carteira <agente> <faixa>
  local agente="$1" faixa="$2"
  [ -n "$faixa" ] || { echo 0; return; }
  local carteira
  case "$agente" in
    ollama|lmstudio|vllm)                     carteira=local ;;
    groq|openrouter|omniroute|gemini|antigravity|cerebras) carteira=gratis ;;
    codex)                                    carteira=secundaria ;;
    claude)                                   carteira=medida ;;
    cursor)                                   carteira=emprestada ;;
    *)                                        carteira=outra ;;
  esac
  case "$faixa:$carteira" in
    trivial:local|barata:local)     echo 8 ;;
    trivial:gratis|barata:gratis)   echo 6 ;;
    trivial:medida|barata:medida)   echo -8 ;;   # o desperdício que se quer acabar
    trivial:emprestada|barata:emprestada) echo -12 ;;  # cota de outra pessoa
    media:gratis)                   echo 4 ;;
    media:local)                    echo -2 ;;   # modelo pequeno demais para isto
    media:medida)                   echo -3 ;;
    cara:secundaria)                echo 6 ;;
    cara:gratis)                    echo 2 ;;
    cara:local)                     echo -10 ;;  # não tem porte para o trabalho
    cara:medida)                    echo -4 ;;
    *)                              echo 0 ;;
  esac
}
