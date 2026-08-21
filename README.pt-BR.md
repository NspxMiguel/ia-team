# ia-team

Põe as outras IAs da sua máquina para trabalhar como um time — em paralelo, e
conversando entre si — e devolve o que elas fizeram como patch, para revisar
antes de encostar no repositório.

O Claude Code (ou quem estiver rodando o `team`) continua sendo o líder: ele
divide o trabalho, escreve os briefings e lê cada diff. Cada agente trabalha
numa worktree descartável do git, então nada cai no seu branch sem alguém
aplicar de propósito.

```bash
team sprint "antigravity: a landing page, escura, sem framework" \
            "codex: a rota /api/links seguindo o README.md" \
            "groq: os testes das quatro rotas com node:test" \
            "gemini: o docs/COMO-USAR.md com exemplos de curl"
```

Quatro agentes, quatro worktrees, quatro patches — no tempo do mais lento.

## Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/NspxMiguel/ia-team/main/install.sh | bash
```

Instala o comando `team` em `~/.local/bin`, os adaptadores e o motor de API em
`~/.ia-team`, e a skill `team` do Claude Code em `~/.claude/skills/team`.
Precisa de `git` e `python3`, mais nada.

## O time

O `ia-team` não traz modelo nenhum. Ele dirige as CLIs que já estão instaladas e
qualquer API compatível com OpenAI para a qual você tenha chave. `team doctor`
diz quem está disponível agora.

**Colegas de linha de comando**

| Adaptador | Roda | Bom em |
| --- | --- | --- |
| `codex` | `codex exec` | Refatoração grande, backend, seguir spec à risca |
| `antigravity` | `agy -p` | Interface, landing page, CSS, protótipo |
| `gemini` | `gemini -p` | Contexto enorme, documento longo, documentação |
| `claude` | `claude -p` (Haiku) | Segunda leitura de um diff, varredura barata |
| `opencode` | `opencode run` | A opinião de outro provedor |
| `cursor` | `cursor-agent -p` | Frontend, mudança espalhada em muitos arquivos |

**Colegas por API** — um agente pequeno (`runner/cloud_agent.py`) dá ferramentas
de arquivo a eles, então editam o repositório em vez de descrever um patch:

| Adaptador | Tem plano grátis | Bom em |
| --- | --- | --- |
| `groq` | sim | Trabalho em volume e testes, responde em segundos |
| `nvidia` | sim | Raciocínio, segunda opinião de arquitetura |
| `openrouter` | sim | Variedade: vários fornecedores com uma chave só |
| `cerebras` | sim | O mais rápido de todos, edição repetitiva |
| `mistral` | sim | Refatoração, completar código |
| `together` | crédito grátis | Modelos abertos, volume em paralelo |
| `deepseek` | pago, barato | Raciocínio difícil, refatoração longa |

`team hire` mostra quem falta e como conseguir. As chaves vêm do ambiente ou do
chaveiro do sistema, pelo
[`claude-autonomous secret`](https://github.com/NspxMiguel/claude-autonomous) —
nunca passam pelo contexto do agente.

## Comandos

```
team doctor                      quem está disponível, logado e com cota
team agents                      o time e a especialidade de cada um
team hire [nome]                 como adicionar quem ainda não está configurado
team quota [--clear [agente]]    quem está de fora, e até quando

team run <agente> "tarefa"       uma tarefa, worktree isolada, patch de volta
team sprint "t1" "codex: t2" ... várias tarefas ao mesmo tempo, uma por agente
team standup                     quem está trabalhando agora
team ask <agente> "pergunta"     pergunta só de leitura
team panel "pergunta"            a mesma pergunta para todos, em paralelo

team board [n]                   o quadro de recados do time
team note <autor> "texto"        deixa um recado para o próximo agente
team relay <de> <para> "texto"   manda recado para um agente específico
team crosscheck <id> [--by x]    põe outro agente para revisar um patch

team runs | show | diff | apply | drop | wait
team suggest [--force|--mute]    oferece trazer mais IAs (pergunta uma vez só)
team port [--global]             ensina Codex/Gemini/opencode a usar o time
```

Opções de `run`, `sprint`, `ask` e `panel`: `--dir`, `--model`, `--timeout`
(padrão 900s), `--file` para anexar spec ou mockup, `--here` para não usar
worktree, `--bg` para disparar e continuar.

## Como uma execução funciona

1. `git worktree add` a partir do `HEAD`, em `~/.ia-team/worktrees/<id>`. O que
   estava sem commit vai junto e vira um commit de partida, então o patch que
   volta é o trabalho do agente e mais nada.
2. Um briefing é escrito: a tarefa, o combinado (não sair daqui, não rodar git,
   seguir o estilo que já existe), os recados recentes do quadro e qualquer
   mensagem endereçada àquele agente.
3. O agente roda headless com prazo. Em `~/.ia-team/runs/<id>` ficam
   `brief.md`, `report.md`, `log.txt`, `patch.diff` e `meta.json`.
4. O relatório vai para o quadro, e o que o agente marcou com `TIP:` chega aos
   outros.

Nenhum agente commita nem dá push — e se um commitar dentro da própria worktree
mesmo assim, o patch continua sendo capturado, porque o diff é tirado contra o
commit de partida.

## Quando a cota acaba

Plano grátis acaba no meio do trabalho. O motor de API espera o limite por
minuto passar e continua; quando o agente está sem cota de verdade — crédito
zerado, teto do plano — ele fica no banco com um cronômetro e o trabalho vai
para outro sozinho.

```bash
team quota                # quem está de fora e até quando
team quota --clear groq   # traz de volta antes da hora
```

## Paralelo sem pisar no pé um do outro

A divisão é por arquivo: dois agentes no mesmo arquivo produzem dois patches que
brigam. O `team sprint` avisa quando os patches se sobrepõem.

Escreva o contrato antes — um `team note` com as rotas, os nomes de arquivo e as
assinaturas — e quatro agentes constroem contra a mesma interface em vez de
inventarem quatro.

## Testes

```bash
tests/test.sh
```

49 verificações do que não depende de modelo: adaptadores, briefings, worktrees,
captura do patch (inclusive de agente que commita), quadro, recados, sprint,
banco de cota e repasse do trabalho, a sugestão que só aparece uma vez, e o
porte para outros agentes.

## Licença

MIT.
