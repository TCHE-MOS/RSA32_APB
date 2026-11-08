**Sistema de SVA da bancada UVM.**

Os checkers estao implementados sobre a base consolidada no commit
`3ac1530` e sao validados no Xezim. As assertions agora alimentam uma
tabela de resultados no log da propria simulacao. Os checkers observam o reset definido pelas rotinas;
nao aplicam novos resets entre os cenarios.

**Conexao e ativacao.**

Os tres modulos de `UVM/assertions/` sao incluidos por
`assertions/assertions.svh` e instanciados em `top_th.svh`. Eles recebem
somente a interface APB. Nenhum sinal interno do DUT e utilizado.
`top_tb_pkg.svh` e incluido antes das classes que usam seus enderecos.

As verificacoes gerais de APB ficam ativas sempre que PRESETn esta
liberado. A virtual sequence ativa e desativa, ao redor de cada
sequence, os controles exclusivos da bancada:

- `sva_rsa_operation_active`: ordem e resposta da operacao RSA.
- `sva_soft_reset_active`: ordem e resposta do soft reset.

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
| SVA_SCENARIO_CONFLICT | Os dois cenarios especificos nao podem estar ativos simultaneamente. |

Transferencia concluida significa `PSEL && PENABLE && PREADY`, com reset
liberado. Uma leitura com PSLVERR pode retornar dado desconhecido; nao
se exige PRDATA conhecido fora das leituras validas. Transferencias
consecutivas com PSEL mantido alto tambem sao aceitas.

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

Nas operacoes randomizadas de `sequence_rsa_operation`, EXP usa apenas
os 8 bits inferiores; `data[31:8]` e restrito a zero na chamada
`item.randomize()`. A faixa resultante e de 0 a 255.

`max_status_reads` conta leituras APB, e nao ciclos de clock. Nao foi
introduzido um limite de latencia interna em ciclos sem especificacao.
A sequence permite ate 25.000 leituras, e o script Xezim permite
ate 2,5 ms de tempo simulado por padrao (`MAX_TIME=2.5ms`), ambos
aumentados em 25% em relacao aos limites anteriores. O timeout curto de
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
e o mapa de STATUS de `docs/apb_integration.pdf`. O valor pode ser
configurado pelo parametro `EXPECTED_STATUS_AFTER_SRST` do checker.

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
fortes ainda pendentes. Um fatal aparece como EXECUCAO ABORTADA no
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
