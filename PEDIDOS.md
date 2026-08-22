# Pedidos

Registro do que o Miguel pediu, nas palavras dele. Item sai daqui só quando
estiver entregue e conferido.

## 21/08/2026

- [x] *"quero criar uma skill para o claude, onde ele conseguirá se comunicar com
  o codex, e outras ias agenticas como o antigravity."*
- [x] *"basicamente, o claude ta fazendo sla, qualquer app, soq pra agilizar, ele
  manda o antigravity por exemplo, ou o codex fazer o desing do site. e etc, como
  se fosse realmente uma equipe"*

## 21/08/2026 — segunda rodada

- [x] *"algo q n precise de uma palavra pra ele começar a agir, ele simplesmente
  começa a usar sem o usuario pedir."*
- [x] *"dps posta no github pra se outras pessoas quiserem usar tbm."*
- [x] *"pode integrar com varias ias, nao so oq ta no meu pc, lembresse."*
- [x] *"groq, aql ia gratis da nvidia, coloca tudo q der, open code e etc."*
- [x] *"pode baixar os programas, so me avisa pra fazer login se for necessario,
  ai tu ja testa tudo e cria a skill."*
- [x] *"pede tbm pra ela sugerir instalar algumas ias free, caso ache necessario.
  tipo, ve q ta mt grande o projeto, e ta demorando mt, ele recomenda. Ele fala
  algo tipo minha equipe está muito pequena para o projeto, posso adicionar
  outras ias para me ajudar? tem algumas gratis q te recomendo, e outras pagas.
  (Ignore o assunto da ia para eu nao falar isso novamente) ele fala uma vez so,
  se vc ignorar n aparece mais, só se vc msm pedir."*
- [x] *"ja testou??? quero q eles sejam tipo uma equipe de programadores msm.
  inventa um projeto nao muito dificil pra testar, e ver se eles tao conseguindo
  se comunicar corretamente e se tudo funciona bem."*
- [x] *"tbm tem q ter detecção de quando a quota acaba ne... quero uma equipe de
  programadores msm."*
- [x] *"quero tipo um time de vdd tlg? em quanto um faz algo, outro faz outra
  coisa, pra eles se ajudarem. quero q se comuniquem entre si tbm, dar dicas uma
  para a outra. Mandar tal ia fazer tal coisa, e etc. como se fosse realmente um
  grupo de trabalhadores."*
- [x] *"lembresse q o claude é o mais esperto de todos, e a skill é diretamente
  pensada pra ele usar. mas acho legal tbm vc portar pra outros apps como gemini
  pra funcionar com qualquer um."*

## Entregue em 21/08/2026

- `team` instalado em `~/.local/bin`, adaptadores em `~/.ia-team/agents`, skill em
  `~/.claude/skills/team`. Quatro agentes prontos nesta máquina: codex,
  antigravity, claude e opencode.
- Repositório: https://github.com/NspxMiguel/ia-team
- Página: https://www.nspx.dev/ia-team/ (feita pelo próprio antigravity, via
  `team run`), com foto no cartão da vitrine.

## 21/08/2026 — terceira rodada

- [x] *"adiciona na skill, que antes de terminar, checar tudo, pra n dar esse
  mesmo problema dnv: 'O botão não tem estilo nenhum — o CSS foi escrito em
  paralelo, antes do botão existir no HTML. Buraco clássico de trabalho
  paralelo.'"*

  Virou a seção "Before calling it done: walk the seams" na skill: listar o que
  um agente criou e outro tinha que estilizar/chamar/importar, conferir cada
  cruzamento na mão, exercitar a coisa de ponta a ponta em vez de ler o diff, e
  medir o que dá pra medir (contraste, erro de console, overflow, imagem que não
  carregou) em vez de olhar no olho.

- [x] *"tem q ter algum sistema de revisao, pra n dar isso q nem o antigravity,
  planos esgotam toda hora, tem q a cada tantos min, o claude revisar e checar as
  logs, pra ver se ele ta fazendo tudo certinho, e se nao acabou quota"*
- [x] *"ao perceber erro com a ia, ja sinalizar e dar timeout pelo tempo q aparece
  na ia, a maioria coloca quando reseta. pesquisa na net oq cada ia fala"*

## Entregue na segunda rodada (21/08/2026)

- Skill reescrita para agir sem palavra-chave: a descrição manda usar o time
  proativamente quando o trabalho se divide em partes que não se tocam.
- `team sprint` roda várias tarefas ao mesmo tempo, uma por agente, e avisa
  quando dois patches mexem no mesmo arquivo.
- Quadro de recados por projeto: `team note`, `team relay`, `team board`. Todo
  briefing carrega os recados recentes e as mensagens endereçadas ao agente.
  O que um agente marca com `TIP:` chega aos outros.
- `team crosscheck` põe um agente para revisar o patch de outro.
- Detecção de cota: limite por minuto o motor espera e continua; cota de verdade
  esgotada põe o agente no banco com cronômetro e o trabalho vai para outro.
- Sete agentes novos por API (groq, nvidia, openrouter, cerebras, mistral,
  together, deepseek), com um motor próprio que dá ferramentas de arquivo a eles.
- `team suggest` oferece contratar mais IAs uma vez só; ignorou, não volta.
- `team port` ensina Codex, Gemini CLI e opencode a usar o time (testado: o
  Codex respondeu com o `team sprint` certo depois do porte).
- Testado com um projeto de verdade — um encurtador de links feito por quatro
  agentes em paralelo, com os quatro testes passando no fim.

## Depende de você

- **Login em build.nvidia.com, openrouter.ai, cloud.cerebras.ai** (e, se quiser,
  Mistral e Together). Nenhum estava logado no Chrome. Depois do login eu pego a
  chave sozinho pelo botão de copiar do painel e guardo no chaveiro.

## Ideias que ficaram de fora (por enquanto)

- Adaptador para `cursor-agent`, `aider` e `droid` — nenhum está instalado na
  máquina; o esqueleto do adaptador aceita novos agentes sem mexer no `team`.
- Rodar a equipe inteira em paralelo numa mesma tarefa de escrita (hoje o
  paralelo é só de leitura, no `team panel`).
