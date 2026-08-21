# Pedidos

Registro do que o Miguel pediu, nas palavras dele. Item sai daqui só quando
estiver entregue e conferido.

## 21/08/2026

- [x] *"quero criar uma skill para o claude, onde ele conseguirá se comunicar com
  o codex, e outras ias agenticas como o antigravity."*
- [x] *"basicamente, o claude ta fazendo sla, qualquer app, soq pra agilizar, ele
  manda o antigravity por exemplo, ou o codex fazer o desing do site. e etc, como
  se fosse realmente uma equipe"*

## Entregue em 21/08/2026

- `team` instalado em `~/.local/bin`, adaptadores em `~/.ia-team/agents`, skill em
  `~/.claude/skills/team`. Quatro agentes prontos nesta máquina: codex,
  antigravity, claude e opencode.
- Repositório: https://github.com/NspxMiguel/ia-team
- Página: https://www.nspx.dev/ia-team/ (feita pelo próprio antigravity, via
  `team run`), com foto no cartão da vitrine.

## Ideias que ficaram de fora (por enquanto)

- Adaptador para `cursor-agent`, `aider` e `droid` — nenhum está instalado na
  máquina; o esqueleto do adaptador aceita novos agentes sem mexer no `team`.
- Rodar a equipe inteira em paralelo numa mesma tarefa de escrita (hoje o
  paralelo é só de leitura, no `team panel`).
