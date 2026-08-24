# Comandos dos Agentes de Linha de Comando

Esta tabela resume as flags principais de cada agente CLI do ia-team, baseada na saída de `--help` de cada binário na máquina atual.

---

## Tabela Comparativa

| Agente | Como rodar sem interface | Como escolher o modelo | Como listar modelos | Como continuar uma sessão | Flag de aprovação automática |
|--------|--------------------------|------------------------|---------------------|---------------------------|------------------------------|
| **codex** | `codex exec "prompt"` ou `codex e "prompt"` | `-m, --model <MODEL>` | Não há flag nativa para listar modelos | `codex exec resume --last` ou `codex resume --last` | `--dangerously-bypass-approvals-and-sandbox` |
| **claude** | `claude -p "prompt"` ou `claude --print "prompt"` | `--model <nome>` (ex.: `--model haiku`) | Não há flag nativa para listar modelos | `-c, --continue` (continua a mais recente no diretório atual) | `--dangerously-skip-permissions` |
| **gemini** | `gemini -p "prompt"` ou `gemini --prompt "prompt"` | `-m, --model <MODEL>` | Não há flag nativa para listar modelos | `-r, --resume latest` ou `-r, --resume <número>` | `-y, --yolo` ou `--approval-mode yolo` |
| **cursor** | `cursor-agent -p "prompt"` | `--model <nome>` (não aceita `-m`) | `cursor-agent models` ou `--list-models` | `--resume` | `--force` |
| **opencode** | `opencode run "mensagem"` | `-m, --model <provider/model>` | `opencode models [provider]` | `-c, --continue` ou `-s, --session <id>` | `--auto` |
| **antigravity** | **Binário não encontrado na máquina** | — | — | — | — |

---

## Observações por Agente

### codex
- O comando `exec` (alias `e`) roda em modo não-interativo.
- `--model` aceita nomes como `o3`, `gpt-4o`, etc.
- Para listar modelos disponíveis, consulte a documentação da OpenAI ou use `codex exec` com uma pergunta sobre modelos.
- `resume --last` continua a sessão mais recente; `resume <id>` continua uma específica.
- `--dangerously-bypass-approvals-and-sandbox` pula **todas** as confirmações e remove o sandbox — use apenas em ambientes controlados.

### claude
- `-p/--print` roda em modo headless (não-interativo) e imprime o resultado no stdout.
- Não há flag para trocar de modelo via CLI; o modelo é definido pela conta Anthropic (Sonnet, Opus, Haiku).
- Não há comando nativo para listar modelos.
- `-c/--continue` retoma a conversa mais recente no diretório de trabalho atual.
- `--dangerously-skip-permissions` desativa todas as verificações de permissão — recomendado apenas para sandboxes sem internet.

### gemini
- `-p/--prompt` executa em modo não-interativo (headless).
- `-m/--model` aceita nomes como `gemini-2.5-pro`, `gemini-2.5-flash`, etc.
- Não há flag nativa para listar modelos; use a documentação do Google AI Studio.
- `-r/--resume latest` retoma a sessão mais recente; `-r/--resume <n>` retoma pelo índice (use `--list-sessions` para ver).
- `-y/--yolo` ou `--approval-mode yolo` aprova automaticamente todas as ferramentas. Também existe `auto_edit` para aprovar só edições.

### opencode
- `run` executa com uma mensagem inicial em modo não-interativo.
- `-m/--model` usa o formato `provider/model` (ex: `anthropic/claude-3.5-sonnet`, `openai/gpt-4o`).
- `opencode models [provider]` lista modelos do provedor especificado ou de todos se omitido.
- `-c/--continue` continua a última sessão; `-s/--session <id>` continua uma específica; `--fork` cria um fork ao continuar.
- `--auto` aprova automaticamente permissões não explicitamente negadas (perigoso).

---

## Agentes de API (OpenAI, Groq, Moonshot, Zhipu, DashScope, etc.)

Para os agentes baseados em API (implementados como scripts em `agents/*.sh`), **a troca de modelo não é feita via flag do binário do provedor**, e sim pela flag `--model` do próprio `team`:

```bash
team --model <modelo> <agente> "prompt"
```

Para descobrir quais modelos um provedor ainda serve (incluindo gratuidade), use:

```bash
team models <agente>
```

Exemplos:
```bash
team models openai
team models groq
team models moonshot
```

O comando `team models` consulta o endpoint `/models` de cada provedor configurado, mantém um cache em `state/models.json` com triestado de gratuidade (gratuito / pago / desconhecido), histórico de mudanças e sugestão de troca quando o modelo padrão some da lista de gratuitos. Rode com `--once` para forçar uma verificação imediata; sem argumentos, respeita o intervalo mínimo (padrão 3 dias) gravado no estado.