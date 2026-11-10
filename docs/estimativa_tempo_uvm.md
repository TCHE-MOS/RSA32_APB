# Estimativa de duração da campanha UVM

Configuração lida em 09/11/2026, após a alteração de `CORNERS_CASES_EXP_12`
para zero. Estes valores são uma fotografia da configuração, não um relatório
de aprovação da campanha completa.

| Largura de EXP | Casos |
|---|---:|
| 4 bits | 5 |
| 8 bits | 5 |
| 12 bits | 0 |
| 16 bits | 1 |
| 32 bits | 1 |
| Total corners | 12 |

Clock de 10 ns (100 MHz), seed padrão 1. Também são executadas as sequences
`rsa_operation`, `soft_reset`, `test_id` e os oito padrões X/Z.

## Orçamento e limite do simulador

O orçamento conservador de cada caso válido é
`25000 + 1024 + 256 * 2**largura` ciclos. Somam-se as cotas de preparação e
das demais sequences, e aplica-se margem global de 25%.

Para esta configuração:

- Orçamento calculado: **13.744.118.667.090 ns**, ou **3 h 49 min 4,119 s simulados**.
- Watchdog automático aplicado no Xcelium: **9.000.000.000.000 ns**, ou **2 h 30 min simulados**.
- Limite seguro para valores explícitos no lançador Xcelium: **9200 s simulados**.

O orçamento é um limite conservador para detectar travamentos; não é a
duração esperada. Em um teste mínimo no Xcelium 24.03-s013, agendar o orçamento
antigo causou `TRTOVF` em tempo zero. Dividir em atrasos de 1 s apenas adiou
o mesmo erro para aproximadamente 9223 s. Portanto, fragmentar o watchdog
não resolve o limite absoluto desta versão do simulador.

Os scripts preservam os 12 casos e avisam quando o orçamento não cabe no
limite. Uma expiração continua sendo falha (`UVM_FATAL [PH_TIMEOUT]`), e não
aprovação de uma campanha parcial. O limite do Xezim é tratado separadamente.

## Estimativa de duração efetiva

O núcleo RSA v2 decrementa o valor do expoente em cada iteração, em
`src/MG/rsa32/v2/rsa32_core_ctrl.sv`. O esforço cresce aproximadamente com
o **valor** de EXP. Um expoente de 32 bits sorteado uniformemente tem média
próxima de 2,147 bilhões, portanto também exige bilhões de iterações.

Uma aproximação para este RTL é 138 ciclos por iteração quando o bit mais
alto de MOD é o bit 31, com cerca de três ciclos adicionais por zero à
esquerda do módulo. Isso é compatível com os tempos medidos nos casos curtos.
Assumindo MOD não nulo e EXP aproximadamente uniformes, a média fica próxima
de 141 ciclos por iteração. É uma estimativa analítica, não uma garantia
formal de latência nem uma previsão dos operandos exatos sorteados pela seed 1.

O caso de 32 bits domina: aproximadamente **303 bilhões de ciclos**, ou
**3028 s (50 min 28 s) simulados**, em média. Os demais casos acrescentam
uma parcela pequena comparada a esse caso. A duração muda bastante com EXP.

Foi medido um trecho de **1 ms simulado** da configuração atual, seed 1,
com cobertura, assertions, SHM, VCD e `UVM_MEDIUM`: **8,29 s reais**, sem
incluir a compilação/elaboração. O trecho passou pelos casos de 4 e 8 bits
e foi interrompido deliberadamente durante o caso de 16 bits. A interrupção
provocou a assertion forte de conclusão pendente; esse teste parcial não
é uma regressão aprovada.

Extrapolando a velocidade desse trecho:

`3028 s simulados * (8,29 s reais / 0,001 s simulado) ≈ 290 dias reais`.

Assim, com a configuração completa de gravação, a ordem de grandeza é de
**meses**, e não minutos. Os 290 dias são uma extrapolação indicativa de uma
amostra curta, dependente da seed, carga da máquina, atividade do circuito e
I/O. O trecho gerou aproximadamente 356 MiB de VCD e 57 MiB de SHM; manter
essa taxa por toda a campanha também exigiria armazenamento muito elevado.

Para execuções rotineiras, convém separar os casos extensos de 32 bits da
regressão curta e escolher quais sinais/janelas de tempo precisam de ondas.
Reduzir o número de casos de 4/8 bits terá pouco efeito enquanto houver um
caso com EXP de 32 bits sem restrição de valor. Nenhuma cota ou restrição de
operandos foi alterada nesta correção.

## Validação da correção

- Oito testes automatizados de limites, overrides e seleção do simulador:
  `python3 scripts/validation/test_uvm_campaign_timing.py`.
- Bancada real avançou até 1 ms com `+UVM_TIMEOUT=9000000000000,YES`, sem `TRTOVF`.
- Teste focado de ID com esse mesmo watchdog concluiu em 200 ns, com
  `UVM_ERROR=0` e `UVM_FATAL=0`.
- Teste com watchdog de 1 ns gerou `UVM_FATAL [PH_TIMEOUT]` exatamente em 1 ns.

A campanha completa de 12 casos não foi executada até o fim.
