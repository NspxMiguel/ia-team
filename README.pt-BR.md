# ia-team

Põe as outras IAs de linha de comando da máquina para trabalhar — e devolve o
que elas fizeram como um patch para revisar antes de encostar no repositório.

O Claude Code continua sendo o líder: ele escreve o briefing, manda a tarefa
para o agente que combina com ela e lê o diff. O outro agente trabalha numa
worktree descartável do git, então nada cai no seu branch sem alguém aplicar de
propósito.

```bash
team run antigravity "refaz o hero da landing: cara de caro, sem framework"
team diff antigravity-20260821-132212
team apply antigravity-20260821-132212
```

## Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/NspxMiguel/ia-team/main/install.sh | bash
```

Instala três coisas: o comando `team` em `~/.local/bin`, os adaptadores em
`~/.ia-team/agents` e a skill `team` do Claude Code em `~/.claude/skills/team`.
Precisa de `git` e `python3`, mais nada.

## O time

O `ia-team` não traz modelo nenhum — ele dirige o que já está instalado e
logado. `team doctor` diz em que pé está cada um.

| Adaptador | Roda | Bom em |
| --- | --- | --- |
| `codex` | `codex exec` | Refatoração grande, backend, testes, seguir spec à risca |
| `antigravity` | `agy -p` | Interface, landing page, CSS, protótipo rápido |
| `claude` | `claude -p` (Haiku) | Segunda leitura de um diff, varredura barata |
| `opencode` | `opencode run` | A opinião de outro provedor |
| `cursor` | `cursor-agent -p` | Frontend, mudança espalhada em muitos arquivos |
| `gemini` | `gemini -p` | Documento longo, pesquisa |

Adicionar mais um é criar um arquivo em `~/.ia-team/agents` com quatro funções —
`adapter_probe`, `adapter_ask`, `adapter_run` e os metadados. Copiar
`agents/codex.sh` e trocar o comando resolve.

## Comandos

```
team doctor                     quem está instalado e logado
team agents                     o time e a especialidade de cada um
team ask <agente> "pergunta"    pergunta só de leitura — nenhum arquivo é tocado
team panel "pergunta"           a mesma pergunta para todo mundo, em paralelo
team run <agente> "tarefa"      tarefa de verdade, em worktree isolada
team runs [n]                   execuções recentes
team show <id>                  briefing, relatório e resumo do patch
team diff <id>                  o patch inteiro
team apply <id>                 aplica o patch no seu diretório de trabalho
team drop <id>                  joga fora a execução e a worktree
team wait <id>                  espera uma execução `--bg` terminar
```

Opções de `ask`, `panel` e `run`: `--dir <caminho>`, `--model <slug>`,
`--timeout <segundos>` (padrão 900), `--file <caminho>` para anexar uma spec ou
um mockup (pode repetir), `--here` para trabalhar no próprio diretório e `--bg`
para disparar e continuar fazendo outra coisa.

## Como uma execução funciona

1. `git worktree add` a partir do `HEAD`, em `~/.ia-team/worktrees/<id>`, num
   branch `team/<agente>/<carimbo>`. O que estava sem commit vai junto, para o
   agente ver a mesma árvore que você vê.
2. Um briefing é escrito: a sua tarefa mais o combinado — não sair do diretório,
   não commitar, não dar push, seguir o estilo que já existe e relatar no fim.
3. O agente roda headless com prazo. Tudo fica em `~/.ia-team/runs/<id>`:
   `brief.md`, `log.txt`, `patch.diff`, `meta.json`.
4. `team show` resume, `team diff` mostra o patch, `team apply` põe no
   repositório de verdade e `team drop` apaga a tentativa inteira.

Nenhum agente commita nem dá push. Publicar continua sendo decisão de gente.

## Custo e limite

Cada execução gasta a cota do agente para quem você mandou — `team panel` gasta
quatro de uma vez. Dois agentes nos mesmos arquivos produzem dois patches que
conflitam: paralelismo é para trabalho que não se encosta.

O briefing é um arquivo em disco que vai para o modelo de outra empresa: cite o
nome da variável de ambiente, nunca cole o valor de um segredo.

## Testes

```bash
tests/test.sh
```

Cobre o que não depende de modelo: descoberta de adaptador, geração do briefing,
ciclo da worktree, captura do patch, `apply` e `drop`.

## Licença

MIT.
