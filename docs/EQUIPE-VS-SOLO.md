# Três IAs juntas ou o Claude sozinho?

Mesmas duas tarefas de dificuldade média, mesmo enunciado, duas arenas limpas.

**Tarefa 1** — módulo `resumir.js`: corta texto sem quebrar palavra, prefere
terminar em fim de frase a partir de 60% do limite, reticências só quando cortou
mesmo, mais casos de borda. **Tarefa 2** — módulo `fila.js`: fila assíncrona com
limite de simultâneas, repetição com espera crescente, desistência e
cancelamento por `AbortSignal`. As duas com suíte de testes em `node:test`.

## O placar

| | Três IAs em paralelo | Claude sozinho |
| --- | --- | --- |
| Tempo de parede | **105 s** | **301 s** |
| Entregou | 2 módulos, 2 suítes, README | o mesmo |
| Testes próprios passando | 17 (7 + 10) | 14 (10 + 4) |
| Linhas de código | 371 | 399 |
| Custo em dólar (Anthropic) | **US$ 0,47** | **US$ 1,22** |
| Outros consumos | 22.842 tokens do plano Codex; Groq de graça | — |
| Turnos do agente | — | 8 |

Quem fez o quê no time: Codex na tarefa 1, Claude na tarefa 2, Groq no README —
os três ao mesmo tempo, cada um na sua worktree.

Numa primeira tentativa, o Claude sozinho passou de **10 minutos** e ainda não
tinha escrito o README quando o relógio estourou. A segunda tentativa, medida
acima, terminou em 5 minutos.

## O que os números não dizem

Rodar os testes de um lado contra a implementação do outro derruba quase tudo —
e o motivo não é qualidade. O enunciado pedia "tratar limite menor que 10", e
cada um entendeu de um jeito defensável: o Codex **lança** `RangeError`, o
Claude **aceita** e corta assim mesmo. A forma de exportar também divergiu
(`module.exports = resumir` contra `module.exports = { resumir }`).

Duas soluções corretas e incompatíveis, pela mesma razão de sempre: a
especificação não fixou a interface. Vale para dois agentes e vale para um só —
só que com um agente ninguém percebe, porque não há com quem colidir.

## Quando vale cada um

**Vale dividir** quando as partes não se tocam: aqui foram dois módulos
independentes e um texto, e a divisão pagou em tempo (2,9× mais rápido) e em
dinheiro (2,6× mais barato do lado Anthropic, com a parte mecânica indo para um
modelo gratuito).

**Não vale** quando o trabalho é uma coisa só e indivisível, quando as partes
compartilham estado ou arquivo, ou quando escrever o contrato custaria mais que
fazer. O preço da divisão é o contrato: sem ele, o tempo economizado volta como
retrabalho na hora de juntar.
