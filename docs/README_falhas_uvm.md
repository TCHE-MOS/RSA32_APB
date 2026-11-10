# Falhas RSA_APB — comparação v1/v2 e contraprova sem UVM

Registro de 08/11/2026. Referência funcional: [datasheet RSA_APB](apb_integration.pdf),
seções 3.2, 4.1, 4.4 e 6.5.

## Descrição da falha em texto corrente

O problema aparece quando tentamos executar uma operação RSA com o módulo igual a zero. Nessa situação, o esperado é que o circuito sinalize o erro e mantenha o resultado da operação anterior. O que vimos, porém, foi a ativação dos sinais de conclusão e erro ao mesmo tempo. Com isso, o registrador de status indica as duas condições, e o resultado anterior acaba substituído por `0xFFFFFFFF`.

Também percebemos que o sinal de erro continua ativo até aplicarmos um reset. No teste com a versão v2, tentamos limpar os eventos pelo registrador de status: o sinal de conclusão foi limpo, mas o erro permaneceu, mantendo a interrupção ativa.

Também testamos a operação com **expoente igual a zero**, aplicando **DIN = `0x181D60BF`** e módulo `0xC2065569`. Nesse caso, o resultado esperado é `0x00000001`. Esse é um cenário diferente da falha descrita, que ocorre quando o **módulo** é zero.

A falha apareceu nas duas versões do RSA e foi reproduzida no testbench sem UVM ou SVAs. Isso mostra que as assertions estão apontando um comportamento que realmente ocorre na simulação. O próximo passo é localizar, no RTL, por que uma operação inválida sinaliza conclusão e por que o erro permanece ativo.

## Execuções comparadas

As duas execuções usaram seed 1, as sequences `rsa_operation -> soft_reset ->
corners_exp` e dez casos corners de EXP de 4 bits. As demais larguras estavam
desabilitadas. Os dez casos contêm oito operações válidas, uma escrita proibida
no ID e uma operação com MOD zero.

| Item | RSA v2 | RSA v1 |
| --- | --- | --- |
| Execução | `2026-11-08_14-34-27_5lIXaz` | `2026-11-08_14-42-58_mdKgMI` |
| Fontes RSA registradas no comando | Cinco arquivos de `src/rsa32/v2/` | Somente `src/rsa32/v1/rsa_core_32.sv` |
| `rsa_operation` | PASS | PASS |
| `soft_reset` | PASS | PASS |
| Operações válidas corners | 8 PASS | 8 PASS |
| Escrita proibida no ID | PASS | PASS |
| MOD zero | FAIL | FAIL |
| STATUS final do caso MOD zero | `0x00000006` | `0x00000006` |
| RESULT do caso MOD zero | `0xFFFFFFFF` | `0xFFFFFFFF` |
| Assertions na tabela | 43 PASS, 2 FAIL, 4 não exercitadas | 43 PASS, 2 FAIL, 4 não exercitadas |
| UVM_ERROR / UVM_FATAL / UVM_WARNING | 2 / 0 / 0 | 2 / 0 / 0 |
| Timeout / casos interrompidos | 0 / 0 | 0 / 0 |
| Tempo simulado global | 429,66 µs | 429,66 µs |
| Tempo real global do Xezim | 114,416 s | 109,228 s |

Os arquivos `timing.csv` são idênticos: mesmos vetores, resultados e durações
simuladas por caso. A diferença de tempo real entre essas duas execuções
isoladas não estabelece uma vantagem de desempenho de uma versão.

Evidências preservadas:

| Artefato | v2 | v1 |
| --- | --- | --- |
| Log | [simulate.log](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-34-27_5lIXaz/simulate.log) | [simulate.log](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-42-58_mdKgMI/simulate.log) |
| Fontes e argumentos efetivos | [command.sh](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-34-27_5lIXaz/command.sh) | [command.sh](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-42-58_mdKgMI/command.sh) |
| Tempos por caso | [timing.csv](../reports/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-34-27_5lIXaz/timing.csv) | [timing.csv](../reports/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-42-58_mdKgMI/timing.csv) |
| Relatório | [index.html](../reports/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-34-27_5lIXaz/index.html) | [index.html](../reports/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-42-58_mdKgMI/index.html) |
| Ondas | [FST](../waveforms/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-34-27_5lIXaz.fst) | [FST](../waveforms/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-42-58_mdKgMI.fst) |

## Visualização das ondas UVM comparadas

Os dois FSTs das execuções UVM concluídas foram lidos até **429660000 ps =
429660 ns**, sem erro de conversão. O GTKWave carregou 421 sinais/aliases
na v1 e 547 na v2. A diferença de tamanho e quantidade de sinais corresponde
às hierarquias diferentes dos núcleos e, isoladamente, não indica truncamento.
Os sinais APB e o clock têm eventos até o encerramento da simulação.

Foram preparadas vistas com 25 sinais APB/RSA, zoom da faixa completa e
marcador A em **429365 ns**. No marcador, DONE e ERROR foram confirmados
como 1 pelo próprio GTKWave:

| Versão | Vista GTKWave | Alternativa VCD |
| --- | --- | --- |
| v1 | [apb_rsa.gtkw](../waveforms/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-42-58_mdKgMI.apb_rsa.gtkw) | [VCD](../waveforms/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-42-58_mdKgMI.vcd) |
| v2 | [apb_rsa.gtkw](../waveforms/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-34-27_5lIXaz.apb_rsa.gtkw) | [VCD](../waveforms/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-34-27_5lIXaz.vcd) |

Para abrir a vista da v1, que carrega seu FST automaticamente:

```bash
gtkwave -a waveforms/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_14-42-58_mdKgMI.apb_rsa.gtkw
```

Para outra execução, o [script de visualização](../scripts/MG/tcl/xezim_uvm_wave_view.tcl)
seleciona os onze pinos do topo e ajusta o zoom sem fixar um tempo final.
Nas novas simulações, ele usa `top_tb.th.dut_io_pinout`, um grupo passivo
sem subinstâncias ou parâmetros locais. Nos arquivos anteriores à inclusão
do monitor, usa os pinos equivalentes em `top_tb.th.apb_rsa_if`:

```bash
gtkwave caminho/execucao.fst -S scripts/MG/tcl/xezim_uvm_wave_view.tcl
```

O launcher aceita `--vcd` para exportar os próximos FSTs também nesse formato.
O VCD da v2 foi carregado e conferido no GTKWave: mesma faixa temporal e
mesmos valores no marcador. Isso confirma os arquivos analisados; não
determina o motivo de uma dificuldade de abertura no Wavecrux ou em outra
configuração local do visualizador. Execuções antigas interrompidas devem
ser avaliadas pelo instante em que realmente pararam.

## Registro consolidado das divergências

| Registro | Comportamento | Evidência confirmada | Situação |
| --- | --- | --- | --- |
| F01 | STATUS=`0x06` em MOD zero, com DONE e ERROR simultâneos. | UVM v1/v2, testbench procedural v2 e núcleo isolado v1/v2 (`ERR_EXCL`). | Aberta. Origem localizada no estado `ERROR` de `rsa_core_ctrl`. Esperado STATUS=`0x04`. |
| F02 | RESULT muda de `0x7B1005AC` para `0xFFFFFFFF` na operação com erro. | UVM v1/v2, testbench procedural v2 e núcleo isolado v1/v2 (`core_dout`=`0xFFFFFFFF` com `core_done`=1). | Aberta. Mesma origem de F01. Esperada retenção do valor anterior. |
| F03 | W1C=`0x06`, sem SRST anterior, deixa STATUS=`0x04`. | Testbench procedural v2; núcleo isolado v1/v2 (`ERR_W`, `RECOV`): `core_error` não é pulso. | Aberta. Origem localizada: `err_ff` só é zerado em `INIT` ou `DONE`. |
| F04 | IRQ permanece alta após a mesma tentativa de W1C. | Testbench procedural v2, com IER=`0x03` e STATUS.ERROR=`1`. | Efeito associado a F03. Não caracteriza, isoladamente, defeito na equação de IRQ. |
| N01 | `core_error` permanece alto após o erro até um reset ou a conclusão da operação seguinte. | Núcleo isolado v1/v2: 200 de 200 ciclos ociosos em nível alto; 3175 ciclos durante a operação seguinte. | Aberta. Mesma causa de F03; antes registrada como achado adicional nas ondas. |
| N02 | Com cargas consecutivas (LOAD_GAP=0), o núcleo não conclui a operação. | Núcleo isolado v1/v2 (`LOAD_GAP`): parado em `LOAD_E` após 20000 ciclos. | Aberta. Mascarada no topo, que usa `LOAD_GAP=1`. |

Os registros identificam divergências observáveis, não seis causas RTL
independentes. Os quatro resultados falhos da contraprova estão detalhados
na seção de execução sem UVM abaixo. A investigação no núcleo isolado, que
localiza a origem de F01–F03 e registra N01–N02, está na seção
[Investigação no núcleo RSA isolado](#investigação-no-núcleo-rsa-isolado).

## F01 — DONE e ERROR simultâneos em módulo zero

**Situação: aberta, reproduzida em v1 e v2.** Assertion: `CORNERS_STATUS`.

O caso 10 aplicou MSG=`0x1C2F4FF3`, EXP=`0x0000000A` e MOD=`0x00000000`.
As escritas e os readbacks dos operandos passaram; START foi aceito sem
PSLVERR. A primeira leitura de STATUS retornou BUSY=`1`, DONE=`0`, ERROR=`0`.

Na segunda leitura, em **429515 ns**, STATUS retornou `0x00000006`:
BUSY=`0`, DONE=`1`, ERROR=`1`. O esperado é `0x00000004`, somente ERROR.
As seções 4.1 e 4.4 especificam que MOD zero gera erro em vez de conclusão
válida.

As ondas de ambas as versões mostram `core_done` e `core_error` subindo
juntos em **429365 ns**. Essa violação já está presente na interface de
saída do núcleo.

**Atualização:** a bancada do núcleo isolado reproduz a violação sem APB e
localiza a instrução: o estado `ERROR` de `rsa_core_ctrl` atribui
`done_ff <= 1` e `err_ff <= 1` no mesmo flanco
([rsa32_core_ctrl.sv:168-173](../src/rsa32/v2/rsa32_core_ctrl.sv#L168-L173);
v1 em `rsa_core_32.sv:392-396`).

## F02 — RESULT sobrescrito após erro de módulo zero

**Situação: aberta, reproduzida em v1 e v2.** Assertion: `CORNERS_ERROR_RESULT`.

Antes de START, a leitura de RESULT em **429265 ns** retornou `0x7B1005AC`,
resultado da operação válida anterior. Após o erro, a leitura em
**429545 ns** retornou `0xFFFFFFFF`.

As seções 4.4 e 6.5 exigem preservar RESULT em uma operação com erro.
Portanto, o esperado dessa comparação é o valor anterior, `0x7B1005AC`.
Não se calcula exponenciação modular com divisor zero para formar essa
referência de retenção.

Nas duas versões, `core_dout` mudou para `0xFFFFFFFF` no mesmo instante em
que DONE e ERROR subiram. Isso é compatível com uma captura de dado
qualificada por DONE mesmo na presença de ERROR. A condição interna de
captura do wrapper ainda precisa ser investigada; os arquivos RTL não
foram alterados por este diagnóstico.

**Atualização:** no núcleo isolado, o mesmo estado `ERROR` que gera F01
também atribui `c_reg <= 32'hFFFFFFFF`. Por isso `core_dout` muda para
`0xFFFFFFFF` no mesmo ciclo em que `core_done` sobe. A captura em RESULT
é consequência desse DONE indevido.

## Cronologia comum das duas falhas

| Instante simulado | Observação |
| --- | --- |
| 429265 ns | RESULT anterior lido: `0x7B1005AC`. |
| 429295 ns | START aceito; primeiro LOAD apresenta MSG=`0x1C2F4FF3`. |
| 429315 ns | Segundo LOAD apresenta EXP=`0x0000000A`. |
| 429335 ns | Terceiro LOAD apresenta MOD=`0`. Há intervalos entre os LOADs. |
| 429365 ns | `core_done=1`, `core_error=1`, `core_dout=0xFFFFFFFF`. |
| 429375 ns | `core_done` volta a zero. |
| 429515 ns | STATUS=`0x06`; F01 detectada. |
| 429545 ns | RESULT=`0xFFFFFFFF`; F02 detectada. |
| 429575 ns | Escrita de SRST aceita. |
| 429585 ns | `core_error` volta a zero. |
| 429615 ns | Escrita W1C de `0x06` em STATUS. |
| 429655 ns | STATUS retorna zero após a recuperação SRST/W1C. |

Há **duas assertions falhas no mesmo caso**, sem evidência de que sejam
defeitos internos independentes. A recuperação permitiu concluir a campanha,
mas não apaga essas falhas. O código de saída 1 do launcher é coerente com
os dois UVM_ERROR.

`CORNERS_COMPLETION=PASS` significa que o polling observou um evento terminal;
a validade do STATUS é verificada separadamente. `RESPOSTA=PASS` nas transações
desse caso significa PSLVERR esperado, sem aprovar o conteúdo funcional.

## Achado adicional nas ondas

`core_error` permaneceu alto de **429365 a 429585 ns**, durante 220 ns ou
22 ciclos de PCLK, até o reset. A seção 3.2 descreve um pulso de um ciclo.
Esse comportamento também ocorreu em v1 e v2. É um achado adicional da
interface do núcleo, sem uma assertion exclusiva na tabela atual; não
representa um terceiro UVM_ERROR registrado nessas execuções.

**Atualização:** registrado como N01 e confirmado no núcleo isolado v1/v2
(`ERR_W`, `RECOV`). Após `ERROR`, a FSM segue para `LOAD_M`, e não para
`INIT`; como `err_ff` só é zerado em `INIT` ou `DONE`, o nível permanece.

## Contraprova com testbench.sv e RSA v2, sem UVM

O [testbench integrado](../testbenchs/rsa_apb_top/testbench.sv) foi executado
com Xezim e os cinco fontes RSA v2. Não foram compilados a biblioteca UVM,
seus pacotes, suas sequences ou suas SVAs. As comparações foram realizadas
pelas tasks APB e pela scoreboard procedural do próprio testbench.

O fluxo original possui somente módulos não nulos. Foi acrescentada a opção
`+MOD_ZERO`, que mantém esse fluxo e adiciona uma preparação válida com
MSG=`0x0F1C3861`, EXP=`9`, MOD=`0xC7C64DFB`, produzindo `0x7B1005AC`.
Depois aplica MSG=`0x1C2F4FF3`, EXP=`10`, MOD=`0`, exatamente como no caso
UVM investigado. A comparação de retenção usa RESULT lido antes de START;
a função matemática não é chamada com divisor zero.

| Execução | Verificações | PASS | FAIL | Tempo simulado | Saída |
| --- | --- | --- | --- | --- | --- |
| Fluxo original | 398 | 398 | 0 | 134980 ns | 0 |
| Fluxo original + preparação + MOD zero | 425 | 421 | 4 | 147040 ns | 1 |

Evidências: [log do fluxo original](../logs/amba_3_apb_rsa_apb_top/xezim/2026-11-08_14-53-09_SOGmCa/simulate.log),
[log do caso MOD zero](../logs/amba_3_apb_rsa_apb_top/xezim/2026-11-08_14-52-07_oiNTP9/simulate.log),
[comando efetivo sem UVM](../logs/amba_3_apb_rsa_apb_top/xezim/2026-11-08_14-52-07_oiNTP9/command.sh),
[ondas do caso MOD zero](../waveforms/amba_3_apb_rsa_apb_top/xezim/2026-11-08_14-52-07_oiNTP9.fst)
e [observações extraídas das ondas](../logs/amba_3_apb_rsa_apb_top/xezim/2026-11-08_14-52-07_oiNTP9/mod_zero_wave_observations.csv).

### Comparações que falharam

| Verificação procedural | Esperado | Observado | Relação com a UVM |
| --- | --- | --- | --- |
| `STATUS.ERR` | `0x00000004` | `0x00000006` | Reproduz F01 / `CORNERS_STATUS`. |
| `RESULT.KEEP` | `0x7B1005AC` | `0xFFFFFFFF` | Reproduz F02 / `CORNERS_ERROR_RESULT`. |
| `STATUS.IDLE` após W1C=`0x06`, sem SRST | `0x00000000` | `0x00000004` | Nova observação: DONE limpa, ERROR permanece ativo. |
| IRQ após o mesmo W1C | `0` | `1` | Consequência da permanência de ERROR com IER=`0x03`; não demonstra um defeito independente na equação de IRQ. |

Esses são quatro resultados de comparação falhos, não uma conclusão de
quatro defeitos RTL independentes. Na UVM, o caso de erro seguia diretamente
pela recuperação SRST/W1C: esse teste não exercitava a tentativa de limpar
ERROR somente com W1C, sem antes resetar o núcleo.

### Sequência observada nas ondas da contraprova

| Instante simulado | Observação |
| --- | --- |
| 146795 ns | RESULT anterior lido: `0x7B1005AC`. |
| 146855 ns | START aceito. |
| 146925 ns | `core_done=1`, `core_error=1`, `core_dout=0xFFFFFFFF`. |
| 146935 ns | `core_done` volta a zero; `core_error` permanece alto. |
| 146945 ns | Leitura de STATUS retorna `0x06`. |
| 146975 ns | Leitura de RESULT retorna `0xFFFFFFFF`. |
| 147005 ns | Escrita W1C=`0x06` em STATUS. |
| 147035 ns | Leitura de STATUS retorna `0x04`, com IRQ=`1`. |

Os instantes acima são as bordas de conclusão APB extraídas das ondas. A
tabela procedural imprime cinco ns depois, quando a task encerra o ACCESS
na descida do clock.

`core_error` continuou alto durante o W1C e até o fim dessa simulação, sem
um novo reset. Isso é compatível com a reafirmação do evento ERROR pelo
sinal de erro persistente. A condição interna exata ainda precisa ser
localizada no RTL. A equação de IRQ observada é coerente com STATUS.ERROR
ativo e IER habilitado.

A contraprova reproduz as leituras incorretas sem executar as SVAs UVM.
Portanto, elas não são a causa dessas duas divergências observadas no DUT
v2 simulado. O diagnóstico continua sujeito à localização da lógica interna
responsável; nenhum fonte RTL foi modificado para produzir esse resultado.

### Reprodução

```bash
# Fluxo original: esperado TEST PASS, 398 verificações.
bash scripts/MG/bash/xezim.sh

# Acrescenta o caso dirigido de módulo zero.
bash scripts/MG/bash/xezim.sh +MOD_ZERO
```

O [script](../scripts/MG/bash/xezim.sh) usa RSA v2 e grava comando, log, código
de saída e ondas por execução. Com o DUT atual, a segunda chamada termina
com código 1, pois as quatro comparações acima falham. A opção não altera
as cotas ou os estímulos da bancada UVM.

## Investigação no núcleo RSA isolado

Registro de 08/11/2026. Bancada:
[tb_rsa_core_fault.sv](../testbenchs/rsa_core_fault/tb_rsa_core_fault.sv);
script: [xezim_rsa_core_fault.sh](../scripts/MG/bash/xezim_rsa_core_fault.sh).

### Objetivo

As contraprovas anteriores reproduziram F01–F04 pelo barramento APB, com e
sem UVM, mas não separavam o núcleo do restante do sistema. Esta bancada
restringe a investigação ao `rsa_core` para responder duas perguntas:

1. A violação já existe na interface `core_*`, sem APB, wrapper ou regbank?
2. Se existe, qual estado e qual atribuição do RTL do núcleo a produzem?

### Metodologia

**Escopo da compilação.** Somente os fontes de `src/rsa32/v1` ou
`src/rsa32/v2` e a bancada. Nenhum fonte de `src/amba_3_apb`, nenhuma
biblioteca UVM e nenhuma SVA entram no comando. O RTL não foi alterado.

**Instâncias.**

| Instância | Módulo | Papel |
| --- | --- | --- |
| `dut` | `rsa_core` | Núcleo completo, dirigido diretamente por `core_rst`, `core_load` e `core_din`. |
| `u_mult` | `rsa_core_mult` | Teste unitário do multiplicador, separado do controle. |
| `u_mod` | `rsa_core_mod` | Teste unitário do redutor modular, separado do controle. |

**Referência independente da bancada.** O resultado esperado vem de dois
modelos escritos na própria bancada: exponenciação por *square-and-multiply*
e multiplicação repetida, ambos com produtos de 64 bits. Antes de qualquer
estímulo ao DUT, o cenário T0 confirma que os modelos concordam entre si
em 400 vetores e reproduzem valores conhecidos: `65^17 mod 3233 = 2790`,
`4^13 mod 497 = 445`, `0x7B1005AC` do caso UVM 10 e `1` para EXP=0. Uma
falha em T0 tornaria o restante da execução inconclusivo.

**Estímulo e amostragem.** Os pinos são dirigidos na borda de descida,
e as saídas são amostradas na borda de subida, antes das atribuições não
bloqueantes do mesmo flanco. Cada operando recebe `core_load=1` por um
ciclo, seguido por um intervalo configurável com `core_load=0`. O padrão
é um ciclo, como no topo com `LOAD_GAP=1`.

**Observação passiva.** Nenhum sinal interno é forçado. Três observadores
leem a hierarquia do `dut`:

| Observador | O que mede |
| --- | --- |
| Monitor `core_*` | Subidas e largura de `core_done` e `core_error`, ciclos com os dois altos e mudança de `core_dout` com `core_error` alto. |
| Scoreboards internos | Em cada `mult_start`, registra `a` e `b` e compara `mult_c` com `a*b` em `mult_done`. Em cada `mod_start`, registra `a` e `b` e compara `mod_c` com `a mod b` em `mod_done` sem erro. |
| Rastreio da FSM | Caminho de estados de `rsa_core_ctrl.state_reg`. O laço `ANALYZE/START` é resumido por contagem. Ao sair de `ERROR` ou `DONE`, anota `done_ff` e `err_ff` já atualizados por aquele estado. |

**Critério de aprovação.** Cada verificação compara a interface com a
seção 3.2 do datasheet (`core_done` e `core_error` com um ciclo; `core_error`
em vez de `core_done` quando n=0), com a seção 4.1 (domínio
`0 ≤ M, e, n ≤ 2^32 − 1`) e com a seção 4.3 (cargas consecutivas aceitas).
As verificações internas (`SUB_*`, `U_*`) não têm requisito no datasheet e
conferem apenas a aritmética. Comportamentos sem requisito explícito são
impressos como `[OBS]` e não contam como falha.

**Cenários.**

| Cenário | Estímulo | Verificações |
| --- | --- | --- |
| T0 | Somente modelos de referência. | `TB_REF` |
| T1 | 9 vetores fixos (EXP=0, EXP=1, M=0, n=1, M>n, n com MSB em 1, preparação do caso UVM 10) e 12 aleatórios (seed 1, e ≤ 48, n com 32, 16 ou 8 bits). | `RESULT`, `DONE_W`, `NO_ERR` |
| T2 | 7 vetores com M muito maior que n. | `RES_BIGM` |
| T3 | Preparação válida seguida de MSG=`0x1C2F4FF3`, EXP=10, n=0, sem reset; depois n=0 com EXP=0 e com M=0. | `ERR_ON`, `ERR_EXCL`, `ERR_W` |
| T4 | 200 ciclos ociosos após o erro; depois operação válida sem `core_rst`. | `RECOV`, `RESULT` |
| T5 | Erro seguido de `core_rst` de um ciclo; `core_rst` no meio de uma operação longa e operação válida em seguida. | `RST_ERR`, `RST_ABORT` |
| T6 | Mesmo vetor com 0, 1, 2 e 7 ciclos entre as cargas. | `LOAD_GAP` |
| T7 | 60 produtos 32×32 e 80 restos 64/32, inclusive divisores de 8 e 16 bits; `rsa_core_mod` com divisor zero. | `U_MULT`, `U_MOD` |

Os cenários reutilizam o vetor e a sequência do caso UVM 10 para manter a
comparação com F01–F02. A largura de `core_error` é observada por 24 ciclos
após o evento.

### Resultados

Execuções v2 e v1 com seed 1. As duas produziram a mesma matriz e o mesmo
tempo simulado (1382750 ns), com código de saída 1:

| ID | Propriedade do `rsa_core` | Datasheet | v2 | v1 |
| --- | --- | --- | --- | --- |
| `TB_REF` | Modelos de referência concordam | — | ok 6 | ok 6 |
| `RESULT` | `core_dout = M^e mod n` | 4.1 | ok 23 | ok 23 |
| `RES_BIGM` | Resultado correto com M ≫ n | 4.1 | ok 7 | ok 7 |
| `DONE_W` | `core_done` dura 1 ciclo | 3.2 | ok 30 | ok 30 |
| `NO_ERR` | Operação válida não gera `core_error` | 3.2/4.1 | ok 30 | ok 30 |
| `ERR_ON` | n=0 gera `core_error` | 3.2/4.1 | ok 3 | ok 3 |
| `ERR_EXCL` | n=0: `core_error` sem `core_done` | 3.2/4.1 | **FAIL 3/3** | **FAIL 3/3** |
| `ERR_W` | `core_error` dura 1 ciclo | 3.2 | **FAIL 1/1** | **FAIL 1/1** |
| `RECOV` | Operação após erro começa com `core_error=0` | 3.2 | **FAIL 2/2** | **FAIL 2/2** |
| `RST_ERR` | `core_rst` limpa `core_error` | 3.2/4.5 | ok 1 | ok 1 |
| `RST_ABORT` | `core_rst` aborta operação em curso | 3.2/4.5 | ok 2 | ok 2 |
| `LOAD_GAP` | Cargas aceitas com qualquer intervalo | 3.2/4.3 | **FAIL 1/4** | **FAIL 1/4** |
| `SUB_MULT` | Interno: `mult_c = a*b` | interno | ok 532 | ok 532 |
| `SUB_MOD` | Interno: `mod_c = a mod b` | interno | ok 531 | ok 531 |
| `U_MULT` | Unitário `rsa_core_mult` (60 produtos) | interno | ok 1 | ok 1 |
| `U_MOD` | Unitário `rsa_core_mod` (80 restos) | interno | ok 1 | ok 1 |

As 7 verificações falhas, idênticas nas duas versões:

| Verificação | Observado |
| --- | --- |
| `ERR_EXCL` | Nos três casos com n=0, `core_done` subiu uma vez, com um ciclo de `core_done` e `core_error` simultâneos. |
| `ERR_W` | `core_error` permaneceu alto durante os 24 ciclos observados e continuava alto. Nos 200 ciclos ociosos seguintes, ficou alto em todos. |
| `RECOV` | A operação seguinte começou com `core_error=1`, que ficou alto por 3175 ciclos e só caiu no estado `DONE`. O resultado dessa operação, `0x00000AE6`, estava correto. |
| `LOAD_GAP` | Com intervalo zero, não houve `core_done` em 20000 ciclos; a FSM parou em `LOAD_E`. Com 1, 2 e 7 ciclos, o resultado foi correto. |

Com n=0, o multiplicador e o redutor não foram acionados (`mult_start=0`):
o erro é decidido inteiramente em `rsa_core_ctrl`. `core_dout` passou de
`0x7B1005AC` para `0xFFFFFFFF` no ciclo do evento.

### Caminho de estados de `rsa_core_ctrl`

Operação com n=0 (caso UVM 10):

```text
LOAD_M > WAIT_M > LOAD_E > WAIT_E > LOAD_N > WAIT_N > ERROR[done_ff=1 err_ff=1] > LOAD_M
```

Operação válida seguinte, sem `core_rst`:

```text
LOAD_M > WAIT_M > LOAD_E > WAIT_E > LOAD_N > WAIT_N > CASE2 > (ANALYZE/START x15) > DONE[done_ff=1 err_ff=0] > LOAD_M
```

O primeiro caminho mostra que `ERROR` liga os dois flags e retorna para
`LOAD_M`. O segundo mostra que `DONE` é o primeiro estado a zerar `err_ff`
depois do erro.

### Localização no RTL

| Divergência | v2 | v1 | Mecanismo |
| --- | --- | --- | --- |
| F01, F02 / `ERR_EXCL` | [rsa32_core_ctrl.sv:168-173](../src/rsa32/v2/rsa32_core_ctrl.sv#L168-L173) | `rsa_core_32.sv:392-396` | O estado `ERROR` atribui `done_ff <= 1`, `err_ff <= 1` e `c_reg <= 32'hFFFFFFFF` no mesmo flanco. |
| F03, N01 / `ERR_W`, `RECOV` | [rsa32_core_ctrl.sv:112](../src/rsa32/v2/rsa32_core_ctrl.sv#L112), [:145](../src/rsa32/v2/rsa32_core_ctrl.sv#L145), [:192](../src/rsa32/v2/rsa32_core_ctrl.sv#L192) | `rsa_core_32.sv:345`, `:375`, `:409` | `ERROR` segue para `LOAD_M`; `err_ff` só é zerado em `INIT` ou `DONE`. |
| `RST_ERR` (aprovado) | [rsa32_core_ctrl.sv:143-147](../src/rsa32/v2/rsa32_core_ctrl.sv#L143-L147) | `rsa_core_32.sv:374-377` | `core_rst` leva a FSM a `INIT`, que zera `err_ff` no flanco seguinte: `core_error` cai um ciclo após o pulso de reset. |
| N02 / `LOAD_GAP` | [rsa32_core_ctrl.sv:91-110](../src/rsa32/v2/rsa32_core_ctrl.sv#L91-L110) | `rsa_core_32.sv:325-` | `WAIT_M`, `WAIT_E` e `WAIT_N` só avançam com `core_load=0`; três cargas consecutivas são vistas como uma única carga de M. |

### Hipótese descartada

Durante a análise do RTL, levantou-se a hipótese de que `rsa_core_mod`,
que faz uma comparação e no máximo uma subtração por posição de bit,
erraria o resto quando M ≫ n, já que `x_reg` começa com M sem redução
prévia. A simulação **não confirma** essa hipótese: `RES_BIGM` (7 vetores,
como `(2^32−1)^2 mod 3`), `U_MOD` (80 restos, com divisores de 8 e 16 bits)
e as 531 reduções internas de `SUB_MOD` passaram nas duas versões.

### Observações sem requisito no datasheet

Comportamento latente de `rsa_core_mod`, observado no teste unitário (T7):

- Com divisor zero, sobe `mod_done` e `mod_err` no mesmo ciclo, entrega
  `mod_c=0xFFFFFFFF` e mantém `mod_err` alto nos 16 ciclos seguintes. É o
  mesmo padrão do estado `ERROR` do controle.
- `mod_err` aparece como `x` após o reset, porque `mod_err_ff` não é
  atribuído em `INIT`.

No `rsa_core` completo, esse caminho não é alcançado: n=0 é desviado em
`WAIT_N` antes de acionar o multiplicador, e `mod_err` está desconectado
(`mod_err_unused`) em `rsa32_core_top.sv`. Não há falha observável hoje,
mas o padrão reapareceria se a detecção de n=0 passasse a depender desse
sub-bloco.

### Limitações

- Os vetores aleatórios usam e ≤ 48, porque a latência cresce
  linearmente com o expoente (cerca de 4500 ciclos para e=33). Expoentes
  de 32 bits completos não foram exercitados.
- As verificações refletem a seção 3.2 do datasheet. Esta bancada não
  avalia como os blocos fora do núcleo deveriam reagir à interface
  observada.
- As sondas internas dependem dos nomes `rsa_core_ctrl_blk`,
  `rsa_core_mult_blk`, `rsa_core_mod_blk`, `state_reg`, `done_ff` e `err_ff`,
  comuns a v1 e v2.

### Reprodução e evidências

```bash
bash scripts/MG/bash/xezim_rsa_core_fault.sh v2
bash scripts/MG/bash/xezim_rsa_core_fault.sh v1
# Opcionais: +SEED=<n> +N_RANDOM=<n> +RAND_EXP_MAX=<n>
```

Com o RTL atual, as duas chamadas terminam com código 1 e 7 falhas.

| Artefato | v2 | v1 |
| --- | --- | --- |
| Log | [simulate.log](../logs/rsa_core/xezim_core_fault/2026-11-08_16-26-39_v2_MzKaOe/simulate.log) | [simulate.log](../logs/rsa_core/xezim_core_fault/2026-11-08_16-26-41_v1_Pucczu/simulate.log) |
| Fontes e argumentos efetivos | [command.sh](../logs/rsa_core/xezim_core_fault/2026-11-08_16-26-39_v2_MzKaOe/command.sh) | [command.sh](../logs/rsa_core/xezim_core_fault/2026-11-08_16-26-41_v1_Pucczu/command.sh) |
| Ondas | [FST](../waveforms/rsa_core/xezim_core_fault/2026-11-08_16-26-39_v2_MzKaOe.fst) | [FST](../waveforms/rsa_core/xezim_core_fault/2026-11-08_16-26-41_v1_Pucczu.fst) |

## Outras falhas no histórico da bancada

As duas execuções comparadas não contêm outras falhas, warnings ou fatals.
Os eventos abaixo pertencem a rodadas anteriores ou a diagnósticos com
limites deliberadamente reduzidos, e não devem ser somados aos defeitos
funcionais atuais.

| Evento histórico | Evidência e interpretação | Situação nas duas execuções comparadas |
| --- | --- | --- |
| `RSA_POLL_TIMEOUT` | [Execução de 09:02](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_09-02-42_YNErad/simulate.log): 20000 leituras esgotadas com STATUS=`0x01`. | Não ocorreu. `rsa_operation` concluiu e seu resultado passou. |
| `RSA_OPERATION_ORDER` e `RSA_RESULT_BEFORE_DONE` | Apareceram com fluxo RSA incompleto, inclusive no encerramento por timeout da execução acima. Não provam, isoladamente, outro defeito aritmético. | Ambas PASS. |
| `SOFT_RESET_RESPONSE` | [Execução de 08:41](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_08-41-38_Ca2vwO/simulate.log): três respostas APB inesperadas após o fluxo RSA incompleto. O log isolado não localiza a causa interna. | Não ocorreu; `soft_reset` PASS. |
| Timeout de corners de 12/16 bits | [Execução de 10:22](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_10-22-30_8jyx6j/simulate.log): cap de 25000 leituras atingido ainda com BUSY. | Essas larguras estavam desabilitadas. Casos desses mesmos vetores concluíram posteriormente com o orçamento estendido na [campanha interrompida de 13:25](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_13-25-55_2TzcuL/simulate.log). |
| Timeouts de corners com cap de 100 leituras | [Diagnóstico de 10:19](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_10-19-14_VDlwqY/simulate.log): `+CORNERS_MAX_READS=100` provocou timeouts para verificar a continuidade da campanha. | Cap diagnóstico desabilitado (`0`). |
| `PH_TIMEOUT` | [Diagnóstico de 11:00](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_11-00-46_7yldkv/simulate.log): `+UVM_TIMEOUT=1800,YES` interrompeu deliberadamente o fluxo para validar o encerramento. | Não ocorreu. Todos os dez casos concluídos. |
| Interrupção da campanha longa | [Execução de 13:25](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_13-25-55_2TzcuL/simulate.log): interrompida por solicitação do usuário após sete casos PASS, durante o oitavo. | Não ocorreu. A interrupção não demonstra falha funcional do caso ainda em execução. |

## Verificações não exercitadas

As quatro linhas `NAO EXERC.` são iguais em v1 e v2:

| Assertion | Motivo | O que permitiria observá-la |
| --- | --- | --- |
| `APB_CTRL_READ_ZERO` | As sequences escreveram em CTRL, mas não leram CTRL. A regra verifica exclusivamente a leitura. | Acrescentar leitura APB de CTRL (`0x00`) em uma sequence existente; a SVA espera zero e PSLVERR=0. |
| `APB_IER_RESERVED` | Não houve leitura de IER. A regra observa IER[31:2] na resposta de uma leitura, não nas leituras de STATUS. | Acrescentar leitura de IER (`0x08`); os bits reservados devem ser zero. |
| `APB_WAIT_HOLD` | Não houve ACCESS com PREADY=0. O datasheet especifica zero wait states. | É uma regra genérica para um slave que ofereça espera. Neste dispositivo, a ausência de exercício é esperada; não se deve introduzir espera apenas para obter PASS. `APB_ZERO_WAIT` passou. |
| `CORNERS_W1C` no grupo `corners4_ERR` | O caso falhou em STATUS/RESULT e entrou em `recover_core()`, que ativa `sva_corners_recovery`, executa SRST e depois W1C. A assertion de limpeza normal exclui essa janela. | Depois de MOD zero, tentar W1C e observar STATUS/IRQ antes de entrar em recuperação. Preservar as falhas anteriores e usar SRST posteriormente se necessário. |

O indicador se refere à propriedade registrada na tabela, não à execução
do testcase inteiro. As campanhas comparadas executaram todos os dez casos:
planejados=10, concluídos=10, interrompidos=0, não iniciados=0.

O scoreboard registra previamente as linhas das propriedades. `NAO EXERC.`
significa que seus contadores de acertos e falhas ficaram em zero. Um PASS
é contabilizado por `cover property` de uma observação concreta; uma
implicação cujo antecedente nunca ocorreu não conta como aprovação. Essas
quatro linhas não indicam falta de compilação das SVAs.

Em particular, o caso MOD zero foi executado e falhou. A ausência de exercício
de `CORNERS_W1C` nesse grupo expõe uma lacuna do fluxo de verificação: ele
recuperava o núcleo antes de testar a limpeza isolada de ERROR. Por isso F03
e F04 apareceram na contraprova procedural, que usa W1C antes de qualquer
SRST, e não no resumo de assertions UVM dessas execuções.

Ausência de exercício não é FAIL nem comprovação de aprovação dessas regras.
A limpeza W1C normal foi exercitada e passou nos grupos `corners4_OK` e
`corners4_INV`. As demais larguras de EXP não foram avaliadas nessas duas
execuções.

## Investigação pendente

A origem de F01–F03 foi localizada no estado `ERROR` de `rsa_core_ctrl`,
em v1 e v2 (ver [Investigação no núcleo RSA isolado](#investigação-no-núcleo-rsa-isolado)).
Permanecem pendentes:

- Corrigir o estado `ERROR` para emitir somente `core_error`, como pulso de
  um ciclo, sem alterar `c_reg`, e repetir as bancadas UVM, procedural e
  do núcleo.
- Decidir se N02 (cargas consecutivas) será corrigido no núcleo ou
  documentado como restrição, com `LOAD_GAP ≥ 1`.
- Exercitar expoentes de 32 bits completos, ainda não cobertos pelos
  vetores aleatórios.
- Avaliar o comportamento latente de `rsa_core_mod` com divisor zero e a
  inicialização de `mod_err_ff`.
