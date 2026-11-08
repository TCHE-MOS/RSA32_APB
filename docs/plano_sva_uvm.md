**Sistema de SVA da bancada UVM.**

Os checkers estao implementados sobre a base consolidada no commit
`3ac1530` e sao validados no Xezim. As assertions agora alimentam uma
tabela de resultados no log da propria simulacao. Os checkers observam o reset definido pelas rotinas;
nao aplicam novos resets entre os cenarios.

**Conexao e ativacao.**

Os cinco modulos de `UVM/assertions/` sao incluidos por
`assertions/assertions.svh` e instanciados em `top_th.svh`. Eles recebem
somente a interface APB. Nenhum sinal interno do DUT e utilizado.
`top_tb_pkg.svh` e incluido antes das classes que usam seus enderecos.

As verificacoes gerais de APB ficam ativas sempre que PRESETn esta
liberado. A virtual sequence ativa e desativa, ao redor de cada
sequence, os controles exclusivos da bancada:

- `sva_rsa_operation_active`: ordem e resposta da operacao RSA.
- `sva_soft_reset_active`: ordem e resposta do soft reset.
- `sva_test_id_active`: leitura, tentativa de escrita e preservacao do ID.
- `sva_corners_exp_active`: verificacoes da campanha corners.

Esses controles nao estao conectados ao DUT. Quem iniciar uma sequence
diretamente, sem a virtual sequence, deve controlar o enable do seu
cenario. Desativar um cenario antes do ultimo passo gera erro de
execucao incompleta. Interromper a simulacao por fatal continua sendo
falha, independentemente desses enables.

**Protocolo e amostragem.**

As propriedades de `apb_protocol_sva.sv` amostram na subida de PCLK e
ficam desabilitadas enquanto PRESETn nao for conhecido e igual a um.

| Identificador | Regra |
| --- | --- |
| APB_SETUP_ACCESS | SETUP selecionado deve ser seguido de ACCESS. |
| APB_CONTROL_STABLE | Endereco e direcao devem permanecer estaveis de SETUP para ACCESS e durante espera. |
| APB_WRITE_DATA_STABLE | O dado de escrita deve permanecer estavel de SETUP para ACCESS e durante espera. |
| APB_WAIT_HOLD | Durante espera, selecao e enable devem ser mantidos. |
| APB_ACCESS_END | Uma transferencia concluida deve sair de ACCESS no ciclo seguinte. |
| APB_ACCESS_ENTRY | ACCESS precisa ter sido precedido de SETUP ou espera. |
| APB_KNOWN_PHASE | Selecao e enable devem ser conhecidos. |
| APB_KNOWN_CONTROL | Endereco e direcao devem ser conhecidos quando selecionados. |
| APB_KNOWN_WRITE_DATA | PWDATA deve ser conhecido durante escrita selecionada. |
| APB_KNOWN_READY | PREADY deve ser conhecido em ACCESS. |
| APB_KNOWN_ERROR | PSLVERR deve ser conhecido na conclusao. |
| APB_KNOWN_READ_DATA | PRDATA deve ser conhecido em leitura concluida sem erro. |
| APB_ZERO_WAIT | PREADY deve ser um em ACCESS, conforme o dispositivo de zero wait states (3.1/7). |
| APB_CTRL_READ_ZERO | Leitura de CTRL retorna zero sem PSLVERR (6.1/6.7). |
| APB_ID_VALUE | ID retorna 0x52530200 (6.6). |
| APB_STATUS_RESERVED | STATUS[31:3] retorna zero (6.2). |
| APB_IER_RESERVED | IER[31:2] retorna zero (6.3). |
| APB_IRQ_STATUS | Em uma leitura de STATUS, IRQ coincide com (DONE & IER[0]) ou (ERROR & IER[1]) (4.4). |
| SVA_SCENARIO_CONFLICT | Os tres cenarios especificos nao podem estar ativos simultaneamente. |

Transferencia concluida significa `PSEL && PENABLE && PREADY`, com reset
liberado. Uma leitura com PSLVERR pode retornar dado desconhecido; nao
se exige PRDATA conhecido fora das leituras validas. Transferencias
consecutivas com PSEL mantido alto tambem sao aceitas.
O decodificador dos checkers funcionais ignora PADDR[1:0], conforme 3.1.
Para a referencia de IRQ, somente os dois enables de IER sao capturados
em escritas aceitas; SRST nao altera essa referencia. A verificacao de IRQ
ocorre junto da leitura de STATUS, e nao pretende observar todas as
transicoes internas do dispositivo.

O driver inicializa os controles em IDLE e conduz SETUP, ACCESS e sua
desativacao na descida. Na subida, aguarda PREADY e captura a resposta.
`max_wait_cycles`, inicialmente 1000, limita a espera de uma transferencia;
um excesso gera `APB_TRANSFER_TIMEOUT`. Esse limite e independente do
numero de leituras de STATUS permitido pela sequence.

O monitor agora observa todas as transferencias concluidas na subida,
criando um objeto novo para cada uma. O item preserva endereco e dado
em `logic`, inclusive X/Z, e possui o campo de resposta `pslverr`.

**Operacao RSA.**

Os fluxos de operacao e soft reset sao descritos diretamente com
`sequence`, `property` e `assert property`. O intervalo entre duas
transferencias e expresso por `(!transfer)[*0:$]`; nao ha maquinas de
estados procedurais para decidir a ordem. `strong` exige a conclusao
do fluxo, e `throughout` exige que o cenario continue ativo ate o fim.

`rsa_operation_sva.sv` acompanha os passos MSG, EXP, MOD, START, polling
de STATUS e RESULT. START deve escrever `0x01` em CTRL, e RESULT so pode
ser lido depois de uma leitura de STATUS igual a `0x02`. Leituras
intermediarias do polling sao aceitas. Um erro APB inesperado gera
`RSA_OPERATION_RESPONSE`; ordem incorreta e encerramento incompleto
geram `RSA_OPERATION_ORDER`. A leitura antecipada de RESULT tambem
possui a propriedade `RSA_RESULT_BEFORE_DONE`.
`RSA_STATUS_VALUE` exige STATUS=0x01 durante BUSY ou 0x02 na conclusao
do fluxo de operacao valida. A ordem MSG/EXP/MOD da propriedade de fluxo
descreve este testcase: o datasheet 4.2 permite carregar operandos em
qualquer ordem, sem exigir essa ordem para outros testes.

Nas operacoes randomizadas de `sequence_rsa_operation`, EXP usa apenas
os 8 bits inferiores; `data[31:8]` e restrito a zero na chamada
`item.randomize()`. A faixa resultante e de 0 a 255.

`max_status_reads` conta leituras APB, e nao ciclos de clock. Nao foi
introduzido um limite de latencia interna em ciclos sem especificacao.
A sequence de operacao simples permite ate 25.000 leituras. Corners usa
o perfil extenso em ciclos descrito adiante; o script calcula o watchdog
global da campanha, substituindo o antigo limite fixo de 2,5 ms.
O timeout curto de
1.000 ns foi usado apenas para validar os logs e nao e aplicado na
execucao normal.

`RSA_RESULT_VALUE` compara a leitura de RESULT com `MSG ** EXP mod MOD`.
O checker captura MSG, EXP e MOD nas escritas APB concluidas sem PSLVERR,
incluindo os valores randomizados. No START aceito, preserva os operandos
daquela operacao e calcula o esperado por exponenciacao modular binaria.
Os produtos intermediarios usam 64 bits para preservar operandos de 32 bits.
A referencia nao utiliza sinais internos ou o resultado do DUT.

O log `RSA_REFERENCE` apresenta os operandos e o esperado no START.
Na leitura de RESULT, a assertion registra PASS ou FAIL na tabela e
informa EXPECTED e ACTUAL. Escritas rejeitadas nao atualizam a referencia;
SRST invalida a operacao pendente. MOD zero ou operandos com X/Z nao
produzem uma referencia valida para aprovar uma leitura de RESULT.
O teste de erro por modulo zero e um cenario distinto do fluxo que espera DONE.
Sem leitura de RESULT, a comparacao nao e marcada como PASS, mesmo que
o esperado ja tenha sido calculado. O timeout conhecido continua sendo
reportado pelas verificacoes de conclusao.

**Soft reset.**

`soft_reset_sva.sv` acompanha MSG, EXP, MOD, START, STATUS anterior,
SRST e STATUS posterior. START escreve `0x01`, e SRST escreve `0x02`
em CTRL. A leitura posterior deve retornar zero, conforme a secao 4.5
e o mapa de STATUS de `docs/apb_integration.pdf`. Essa expectativa e fixa.
O checker reconhece tambem SRST com START simultaneo (CTRL=0x03), pois
6.1 estabelece a prioridade de SRST. Somente escritas aceitas disparam
a verificacao de STATUS. Desativar o cenario antes da leitura nao cancela
silenciosamente a obrigacao temporal.

O checker nao presume que SRST zera os operandos ou RESULT. Testar
retencao exigiria leituras adicionais. A verificacao de STATUS observa
a resposta APB; nao mede a latencia exata de sinais internos de reset.

**Falhas, cobertura e validacao.**

As acoes das assertions registram as falhas no scoreboard e continuam
emitindo `uvm_report_error`, preservando os identificadores UVM.

As propriedades possuem `cover property` para eventos relevantes.
As verificacoes executam na propria bancada UVM. Nao ha uma bancada
auxiliar de testes de SVA nem um runner separado. O reset inicial e
executado pelo driver conforme a rotina, sem um checker adicional.

Para executar a bancada existente no Xezim, a partir da raiz:

```bash
bash scripts/bash/xezim_uvm.sh --no-waves
```

Os includes e as instancias em `top_th.svh` ativam as assertions durante
a execucao normal. Cada falha produz a acao UVM_ERROR correspondente.

**Visualizacao das ondas UVM.**

Para gravar FST, execute o launcher sem `--no-waves`. O caminho do arquivo
e o comando de abertura sao impressos mesmo quando a campanha termina com
falhas funcionais. Uma falha de assertion nao significa que as ondas foram
interrompidas; confira o tempo final e o progresso no log.

```bash
bash scripts/bash/xezim_uvm.sh

# Abrir um FST com os pinos do topo e zoom de toda a simulacao:
gtkwave caminho/execucao.fst -S scripts/tcl/xezim_uvm_wave_view.tcl

# Gravar tambem uma alternativa VCD; requer fst2vcd:
bash scripts/bash/xezim_uvm.sh --vcd
```

O script Tcl configura apenas a selecao de sinais e o zoom do GTKWave.
Nas novas execucoes, os onze pinos ficam reunidos na instancia passiva
`top_tb.th.dut_io_pinout`, declarada em `UVM/top_th.svh` e incluida por
`UVM/testbench.svh`. Ela contem somente pclk_i, presetn_i, psel_i,
penable_i, pwrite_i, paddr_i, pwdata_i, prdata_o, pready_o, pslverr_o e irq_o,
sem subinstancias ou parametros locais. As larguras vem de `top_tb_pkg`.
Todas as portas do monitor sao entradas de observacao, inclusive as que
possuem sufixo `_o` por representarem saidas do DUT. Os sinais preservam X/Z.
O script Tcl prioriza esse grupo; em FSTs antigos, usa os mesmos sinais da
interface APB como alternativa. FSTs antigos nao recebem a nova instancia:
ela passa a existir nas ondas da proxima simulacao.
O FST original continua contendo toda a hierarquia gravada sob `top_tb.th`,
inclusive os sinais internos do DUT. A opcao `--vcd` exporta esses mesmos
dados, sem acrescentar sinais ou tempo; a precisao dos arquivos e de 1 ps.
`429660000 ps` no formato de ondas corresponde a `429660 ns` no log.
Arquivos de execucoes interrompidas contem somente o trecho efetivamente
simulado. Exporta-los nao recupera o restante da campanha.

**Tabela de resultados no log.**

O scoreboard existente acumula uma linha por identificador de assertion,
nos grupos APB, rsa_operation e soft_reset. Cada linha apresenta o
resultado, o numero de acertos e falhas e o instante em nanossegundos.
As mensagens de detalhe das falhas aparecem apos a tabela.

- `PASS`: houve uma observacao correspondente a propriedade, sem falhas.
- `FAIL`: houve ao menos uma falha; acertos posteriores nao apagam esse resultado.
- `NAO EXERC.`: nao houve observacao da verificacao, inclusive em cenarios nao iniciados.
- `INTERROMP.`: verificacao do cenario atual ficou sem resultado antes de um fatal.

Os acertos sao registrados por `cover property` das mesmas condicoes
verificadas. Uma implicacao verdadeira apenas porque seu antecedente
nao ocorreu nao e registrada como PASS. Os identificadores que antes
agrupavam mais de uma assertion foram separados para manter uma linha
por verificacao.

O teste inicializa os registros; a virtual sequence identifica o cenario
atual. Um bloco `final` do topo imprime a tabela apos a avaliacao das
assertions no encerramento, incluindo falhas temporais de propriedades
fortes ainda pendentes. Um fatal ou uma interrupcao externa aparece como EXECUCAO INTERROMPIDA no
cabecalho. As contagens finais UVM tambem sao impressas, pois algumas
falhas SVA podem ocorrer depois do resumo habitual da biblioteca.

O script Xezim e o relatorio de cobertura existente consideram essas
contagens finais. A ausencia de resumo UVM continua sendo tratada como
execucao incompleta. Os dados numericos de cobertura nao foram alterados.

O debug linha a linha fica visivel na verbosidade padrao (`UVM_LOW` ou
superior). Cada `SEQ_DEBUG` e emitido a partir da transacao observada pelo
monitor e apresenta cenario, numero da transacao, instante em ns,
direcao, nome e endereco do registrador, dado, PSLVERR e RESPOSTA=PASS/FAIL.
As leituras de STATUS tambem mostram BUSY, DONE e ERROR. Cada leitura
do polling gera sua propria linha.

RESPOSTA=PASS indica PSLVERR=0 naquela transferencia; o valor de RESULT
e verificado separadamente pela assertion `RSA_RESULT_VALUE`, com
EXPECTED e ACTUAL. `SVA_DEBUG` identifica as verificacoes de ordem,
conclusao e STATUS de soft reset que passaram. Falhas continuam sendo
reportadas como UVM_ERROR com o identificador da assertion.

`SEQ_BEGIN` marca o inicio de cada sequence. Quando ela retorna,
`SEQ_RESULT` informa PASS, FAIL ou INCOMPLETO, incluindo falhas SVA de
protocolo observadas durante aquele cenario e verificacoes especificas
que ficaram sem resultado. Um fatal interrompe o fluxo antes desse
retorno; nesse caso a tabela final continua apresentando o estado das SVAs.
Nenhuma bancada auxiliar ou runner adicional e necessario para os logs.

As execucoes anteriores, com expoentes de 32 e 16 bits, atingiram o
limite de polling enquanto o nucleo ainda decrementava o expoente.
Na validacao com EXP de 8 bits, seed 1, a operacao usou EXP=241 e
concluiu: EXPECTED=ACTUAL=`0x73A563DA`. O soft_reset tambem concluiu,
com STATUS=0 depois de SRST. A simulacao terminou em 331,75 us, com
19 verificacoes PASS, zero FAIL e zero UVM_ERROR/UVM_FATAL. Somente
APB_WAIT_HOLD ficou nao exercitada, pois nao houve wait states.
Essa execucao valida os dois cenarios para esse vetor; outras seeds
e casos de fronteira continuam sendo parte da ampliacao da cobertura.

**Corners de EXP: SVAs revisadas pelo datasheet.**

`sequence_corners_exp` ja esta incluida no package. O checker
`corners_exp_sva.sv` recebe a mesma interface APB e e instanciado no
harness, sem modificacoes no RTL. As verificacoes temporais usam
`assert property`; nao foi criada uma maquina de estados de comparacao.

| Identificador | Verificacao |
| --- | --- |
| CORNERS_EXP_WIDTH | Escrita de EXP respeita a largura selecionada: 4/8/12/16/32 bits. |
| CORNERS_RESPONSE | PSLVERR e zero no trafego valido destes casos; escritas em RESULT/ID exigem um, independentemente da categoria (6.7). |
| CORNERS_READBACK | Leitura do operando retorna o endereco e o valor originalmente solicitados pela sequence. |
| CORNERS_READ_DELAY | Existe o ciclo adicional de espera antes da leitura. Com o driver atual, sao duas amostras IDLE depois da conclusao da escrita. |
| CORNERS_STATUS | Durante polling, STATUS e BUSY=0x01 ou o final esperado: 0x02 para operacao valida, 0x04 para MOD zero (4.1/4.4/6.2). |
| CORNERS_COMPLETION | START aceito exige uma leitura terminal antes de encerrar ou recuperar o caso; nao fixa latencia do RSA (4.1). |
| CORNERS_RESULT_VALUE | RESULT coincide com a referencia matematica independente (4.1). |
| CORNERS_ERROR_RESULT | MOD zero preserva o RESULT lido antes de START (4.4/6.5). |
| CORNERS_RO_PRESERVED | Escrita rejeitada em RESULT/ID preserva o valor anterior (6.7). |
| CORNERS_W1C | Limpar os dois eventos de STATUS com W1C, sem operacao pendente, resulta em leitura zero (4.4/6.2). |

A sequence publica ID, largura, categoria e o par endereco/dado esperado
durante cada write/readback. O contexto permanece estavel ate a leitura.
Na operacao valida, o esperado matematico e independente de PRDATA.
Nas verificacoes de retencao, o esperado e o valor observado antes da
operacao ou escrita rejeitada. Cada novo ID identifica um
caso, inclusive quando nao existe uma borda de clock entre o fim de um
caso e o inicio do seguinte. Durante SRST/W1C de recuperacao, somente as
checagens de dados normais ficam desabilitadas; a verificacao de resposta
continua ativa. Uma conclusao pendente que seja abandonada gera falha,
e falhas ja registradas permanecem no resultado.

Resposta, readback, STATUS, resultado matematico, retencao e limpeza W1C
sao verificados por `assert property`, sem duplicar comparacoes procedurais.
A sequence publica somente o contexto esperado e as janelas de observacao.
Ela considera os erros UVM emitidos durante o caso para interromper a
carga, recuperar o nucleo e registrar FAIL. Se STATUS terminal estiver
incorreto, ainda faz a leitura de RESULT para detectar ambas as divergencias.
O timeout configuravel continua sendo controle de execucao da sequence;
o datasheet nao especifica um numero maximo de ciclos de calculo.

As verificacoes de ordem, largura randomizada e atraso extra de readback
sao requisitos dos testcases. A espera extra nao e uma exigencia temporal
do dispositivo no datasheet. As regras de resposta, dados e eventos sao
requisitos funcionais do dispositivo.

A cobertura ainda depende dos estimulos: retencao de MSG/EXP/MOD/IER/RESULT
apos SRST exige leituras adicionais; escritas durante BUSY, W1C individual,
IRQ habilitada e enderecos com bits baixos diferentes devem ter cenarios
dedicados nas sequences existentes. Nao se deve interpretar PASS das
observacoes atuais como cobertura de todas essas situacoes.

O scoreboard existente registra os grupos `corners4_OK`, `corners8_INV`,
`corners32_ERR`, etc., conforme largura e categoria observadas. Os grupos
sao registrados quando exercitados. As mensagens incluem o ID do caso,
e a tabela acumula acertos/falhas de cada assertion por grupo. PASS e
registrado por `cover property` de eventos efetivos, sem implicacoes
vacuosas. No SEQ_DEBUG, PSLVERR=1 aparece como RESPOSTA=PASS quando essa
rejeicao foi solicitada pelo caso INVALID_APB.

A virtual sequence executa `rsa_operation`, `soft_reset`, `test_id`,
`corners_exp` e `xz_values` em sequencia. Cada chamada start aguarda o retorno
da anterior. Nao e necessario `+CORNERS_EXP`. As selecoes explicitas
`+TEST_ID_ONLY=1` e `+XZ_VALUES_ONLY=1` executam somente o cenario escolhido
e nao podem ser combinadas. A campanha de corners usa as quantidades do header,
com orcamento por operacao em ciclos. `+CORNERS_CASES` seleciona um prefixo
ate o total configurado no header; `+CORNERS_MAX_READS` e somente um cap diagnostico opcional.

A importacao da sequence e das assertions de ID, suas adaptacoes e os
comandos de validacao estao em [integracao_uvm_test_id.md](integracao_uvm_test_id.md).

Exemplo de verificacao reduzida do controle e das primeiras SVAs:

```bash
bash scripts/bash/xezim_uvm.sh --no-waves -- \
  +CORNERS_MAX_READS=100
```

Esse exemplo provoca timeouts por usar somente 100 leituras; nao e uma
campanha de aprovacao funcional. Na validacao do perfil anterior, os 55 casos chegaram ao
resumo sem fatal, e as novas SVAs das combinacoes exercitadas ficaram
PASS. Os casos de MOD zero
continuaram acusando as divergencias de STATUS/RESULT nas comparacoes
procedurais. Falhas injetadas, uma por vez, em copias temporarias da
bancada foram detectadas por cada uma das quatro assertions, sem erros
duplicados dessas mesmas verificacoes. Nenhuma bancada auxiliar ou
runner de testes foi adicionado ao projeto.

Na revisao pelo datasheet, a rodada real de dez casos de 4 bits, seed 1,
terminou com nove PASS e um FAIL por MOD zero, sem timeout/fatal. As duas
divergencias agora aparecem diretamente nas SVAs: `CORNERS_STATUS`
(0x06 observado em vez de 0x04) e `CORNERS_ERROR_RESULT` (0xFFFFFFFF em
vez do resultado anterior 0x7B1005AC). O resumo foi 43 linhas PASS, duas
FAIL e quatro nao exercitadas. A linha de W1C do grupo de erro nao foi
exercitada porque esse caso seguiu pela recuperacao apos falhar.

Uma rodada de diagnostico em copia temporaria da mesma bancada exercitou
as leituras de CTRL/IER/ID, IRQ habilitada e um corner valido, sem erros.
Falhas de resposta/dados foram injetadas separadamente nessa copia e
detectadas por APB_ZERO_WAIT, APB_CTRL_READ_ZERO, APB_ID_VALUE,
APB_STATUS_RESERVED, APB_IER_RESERVED, APB_IRQ_STATUS, CORNERS_RESULT_VALUE,
CORNERS_W1C, CORNERS_COMPLETION e CORNERS_RO_PRESERVED. Um encadeamento
final com EXP=1 somente na copia de rsa_operation confirmou as tres
sequences e reproduziu apenas as duas falhas conhecidas de MOD zero.
Esses diagnosticos nao alteram os estimulos nem as cotas do projeto.

**Perfil extenso: temporizacao e encerramento.**

O exemplo de configuracao abaixo executa dez casos de EXP de 4/8/12 bits e um
unico caso de 16 bits. Os valores randomizados ocupam toda a faixa permitida
pela constraint; a largura de 32 bits esta desabilitada por sua cota zero.
O contador de
clock de verificacao na interface tem 64 bits e nao e conectado ao DUT.

As quantidades ficam centralizadas no header `UVM/top_tb_pkg.svh`:

```systemverilog
parameter integer CORNERS_CASES_EXP_4  = 10;
parameter integer CORNERS_CASES_EXP_8  = 10;
parameter integer CORNERS_CASES_EXP_12 = 10;
parameter integer CORNERS_CASES_EXP_16 = 1;
parameter integer CORNERS_CASES_EXP_32 = 0;
```

Edite somente esses cinco valores, usando inteiros decimais nao negativos.
Zero desabilita uma largura; ao menos uma cota deve ser positiva.
`CORNERS_TOTAL_CASES` soma as cotas automaticamente. A sequence usa esses
parametros importados do package, e o launcher le os mesmos valores do
header para calcular seu watchdog. Nao e preciso alterar a sequence ou o
script quando as quantidades mudam. A proxima execucao recompila o header.
`+CORNERS_CASES=N` continua disponivel para executar somente os primeiros N
casos, sem aumentar as cotas do header.

A distribuicao desse exemplo e:

| EXP | Total | Validos | Escritas proibidas | MOD zero |
| --- | --- | --- | --- | --- |
| 4 bits | 10 | 8 | 1 | 1 |
| 8 bits | 10 | 8 | 1 | 1 |
| 12 bits | 10 | 8 | 1 | 1 |
| 16 bits | 1 | 1 | 0 | 0 |
| 32 bits | 0 | 0 | 0 | 0 |
| Total | 31 | 25 | 3 | 3 |

O escalonamento inicia com uma rodada de 4, 8, 12 e 16 bits. Depois,
intercala somente 4, 8 e 12 bits em mais nove rodadas. Por largura, os
primeiros oito casos sao operacoes validas, o nono exercita escrita proibida
e o decimo exercita MOD zero. O unico caso de 16 bits e uma operacao valida.
Um prefixo reduzido pode nao exercitar todas as categorias.
Ao editar as cotas, o escalonamento intercala as larguras habilitadas e
retira cada uma assim que sua quantidade se esgota. O ciclo de oito
operacoes validas, uma escrita proibida e um MOD zero se repete por largura.
`CORNERS_PLAN` informa a quantidade efetiva por largura antes dos casos.
O launcher calcula seu watchdog com o mesmo escalonamento. Pedidos acima
de `CORNERS_TOTAL_CASES` sao rejeitados para preservar as cotas por largura.

Para operacoes validas, o orcamento default e
`1024 + 256 * (EXP + 1)` ciclos. O produto e calculado em 64 bits antes
da soma, inclusive para EXP=`0xFFFFFFFF`. O caso MOD zero tem um limite
fixo de 1024 ciclos; escrita proibida usa a espera limitada da transacao
APB. Esses parametros sao estimativas conservadoras ajustaveis, baseadas
na latencia observada, e nao um limite formal de desempenho do RTL.

| Argumento | Default | Finalidade |
| --- | --- | --- |
| +CORNERS_CASES=N | CORNERS_TOTAL_CASES | Prefixo da campanha, entre 1 e o total do header. |
| +CORNERS_BASE_CYCLES=N | 1024 | Margem inicial e orcamento do caso MOD zero. |
| +CORNERS_CYCLES_PER_EXP=N | 256 | Coeficiente do orcamento de operacao valida. |
| +CORNERS_POLL_CYCLES=N | 16 | Intervalo minimo entre consultas. |
| +CORNERS_MAX_READS=N | 0 | Cap opcional de leituras para diagnostico; zero desabilita. |

O primeiro polling ocorre apos START. Nas operacoes longas, o intervalo
e aumentado para aproximadamente `orcamento/1024`, mantendo cerca de
1024 amostras no pior caso. DONE/ERROR persistem ate sua limpeza. O cap
diagnostico explicito mantem o intervalo minimo para possibilitar testes
curtos. A deadline continua baseada em ciclos; uma transferencia APB e
concluida antes de avaliar a deadline, sem abandonar um item no driver.
Uma leitura concluida depois do limite nao aprova a operacao.

`CORNERS_BUDGET` mostra limite em ciclos, intervalo de polling e cap de
leituras. `CORNERS_POLL` mostra ciclos consumidos e quantidade de leituras.
Timeouts continuam sendo falhas sem resultado matematico validado e
mantem a recuperacao SRST/W1C.

O launcher calcula o orcamento global pelo numero de casos, escalonamento
das categorias, maior EXP de cada faixa e CLOCK_PERIOD_NS do package.
Acrescenta 25000 ciclos por caso para transferencias/recuperacao,
100000 ciclos para as duas sequences iniciais e 25% de margem global.
Instala `+UVM_TIMEOUT` antes do inicio das fases. Com `MAX_TIME=auto`
(default), o limite externo do Xezim fica 10% acima do watchdog UVM.

`MAX_TIME` explicito e respeitado: sem um `+UVM_TIMEOUT` fornecido pelo
usuario, o watchdog e antecipado para no maximo 90% desse limite externo.
Um `+UVM_TIMEOUT` explicito substitui o calculo automatico e e preservado.
Os limites sao verificados contra o intervalo de 64 bits com precisao
de 1 ps. O exemplo de 31 casos gera um teto conservador de
0,3328319 segundos de tempo simulado; esse teto nao e uma previsao de
duracao real. A execucao real depende do desempenho do simulador.

Uma execucao extensa completa e solicitada pelo comando normal:

```bash
bash scripts/bash/xezim_uvm.sh --no-waves
```

Para validar o encadeamento com somente um caso corners:

```bash
bash scripts/bash/xezim_uvm.sh --no-waves -- +CORNERS_CASES=1
```

O topo passa o progresso da campanha ao resumo final: planejados,
concluidos, caso interrompido e nao iniciados. A flag de conclusao so e
marcada depois do retorno das tres sequences. Um corte por `--max-time`,
mesmo sem UVM_FATAL, aparece como EXECUCAO INTERROMPIDA; o relatorio HTML
o classifica como EXECUCAO INCOMPLETA. Falhas funcionais numa campanha
que chegou ao fim continuam distintas dessa interrupcao.

**Medicao de tempo para avaliar uma futura rodada de 32 bits.**

O launcher mede o tempo real do Xezim com relogio monotonico, incluindo
elaboracao, simulacao e escrita dos logs. Salva o valor em segundos em
`simulate.walltime_seconds`, no diretorio da execucao, antes de gerar o
relatorio de cobertura. O bloco final do topo imprime o tempo simulado
global em ns, inclusive quando a execucao e interrompida.

O relatorio inclui ambos os tempos em `index.html` e `summary.txt`.
`timing.csv` lista ID, largura, categoria, valor efetivo de EXP, resultado
e duracao simulada de cada caso concluido. O resumo tambem mostra a media
simulada das operacoes validas PASS por largura; casos INVALID_APB e
ERROR_MOD_ZERO nao entram nessa media.

A comparacao da rodada de 31 casos deve usar o tempo real global medido
e a latencia por valor numerico de EXP. Somente apos sua conclusao sera
possivel revisar a viabilidade de 32 bits com dados dessa rodada. O teto
do watchdog continua sendo apenas uma protecao de encerramento.
