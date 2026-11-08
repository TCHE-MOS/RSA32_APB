# Plano de teste — amba_3_apb_rsa_apb_top

## Objetivo e arquivos

Validar pelo barramento APB3 a gravação e a leitura dos registradores graváveis
do periférico de 32 bits em dez rodadas, após reset e espera de cinco ciclos de clock.
A etapa original é preservada e seguida por dez operações RSA completas.
A scoreboard compara valores lidos com referências de armazenamento e, na
segunda etapa, com uma referência matemática de `MSG^EXP mod MOD`.

- DUT: `src/amba_3_apb/amba_3_apb_rsa_apb_top.sv`.
- Bancada: `testbenchs/rsa_apb_top/testbench.sv`.
- Execução: `scripts/bash/iverilog.sh`.
- Execução com cobertura: `scripts/bash/verilator.sh`.

O nome declarado no RTL atual é `amba_3_apb_rsa_apb_top`. A bancada permanece
no diretório existente `testbenchs/rsa_apb_top`, mas instancia esse módulo atual.
Este plano considera as interfaces e conexões do RTL atual; a análise histórica
em `src/rsa32/README_rsa_apb_top.md` descreve uma versão anterior do topo.

## Condições e temporização

Configuração: `DATA_WIDTH=32`, `ADDR_WIDTH=12`, `LOAD_GAP=1` e
`RESET_LATENCY=2`. Clock de 10 ns (100 MHz), com `timescale 1ns/1ps` na bancada.

A instância da bancada configura explicitamente `LOAD_GAP=1`: o núcleo real
`rsa_core_ctrl` precisa observar LOAD baixo entre mensagem, expoente e módulo.
O padrão zero do topo mantém LOAD alto nos três ciclos consecutivos e não
atende a esse protocolo de carga. O RTL permanece inalterado; as dez rodadas
originais de armazenamento mantêm seus estímulos e comparações.

1. Inicializar o barramento em IDLE e aplicar `presetn_i=0` por duas bordas de
   subida. O reset físico inicializa o banco e as máquinas de estados.
2. Liberar `presetn_i` em uma borda de descida e aguardar cinco bordas de subida,
   permitindo a liberação do sincronizador antes da primeira transação APB.
3. Enviar a transação de reset: escrita APB de `0x00000002` em `CTRL` (`0x000`),
   acionando `SRST`, com `START=0`.
4. Encerrar a transação em IDLE e aguardar **cinco bordas de subida** sem novos
   acessos. As leituras e escritas do cenário começam após essa espera.
5. Ler os oito registradores e comparar os valores iniciais.
6. Gravar e ler imediatamente `IER`, `MSG`, `EXP` e `MOD`.
7. Reler os quatro registradores após todas as escritas, verificando retenção
   e independência entre endereços.
8. Repetir os passos 6 e 7 por dez rodadas, variando os dados a cada rodada,
   sem reaplicar reset entre elas.
9. Executar as dez operações da etapa RSA descrita abaixo, sem novo reset.
10. Emitir o resultado acumulado e encerrar a simulação.

`SRST` reinicializa o caminho RSA e limpa flags; não zera `IER`, `MSG`, `EXP`,
`MOD` nem `RESULT` no RTL atual. Os valores iniciais esperados neste cenário
decorrem do reset físico anterior. A sequência não testa retenção sob `SRST`
com o banco previamente preenchido.

Cada transferência utiliza SETUP (`PSEL=1`, `PENABLE=0`) por um ciclo, seguido
de ACCESS (`PSEL=1`, `PENABLE=1`). Endereço, direção e dado permanecem estáveis
até a borda de subida com `PREADY=1`. O driver altera entradas em bordas de
descida e o monitor captura `PRDATA`/`PSLVERR` na borda de conclusão, antes de
retornar a IDLE. O DUT atual responde sem wait states; a task admite espera
limitada a 20 ciclos, abortando em timeout ou `PSLVERR` diferente de zero.

## Mapa e dados do teste

O valor genérico de 32 bits é `0x1234567B` por padrão, configurável por
`+DATA=<hexadecimal>`. Para cada rodada `r` de 1 a 10, o valor `V` usado na
tabela abaixo é `(DATA + 0x9E3779B9 * (r - 1)) mod 2^32`. A primeira rodada
usa DATA sem alterações; as seguintes sobrescrevem os valores anteriores com
padrões distintos e reproduzíveis. Os dois bits de IER percorrem todas as
quatro combinações. Os padrões distintos dos operandos ajudam a detectar
aliasing de endereço ou sobrescrita de outro registrador.

| Registrador | Endereço | Semântica | Estímulo e comparação |
|---|---|---|---|
| CTRL | `0x000` | Comandos sem armazenamento; leitura zero | Escrever `0x2` para SRST e depois ler zero. |
| STATUS | `0x004` | BUSY somente leitura; DONE/ERROR W1C | Ler zero após reset. Não recebe valor genérico. |
| IER | `0x008` | RW, somente bits `[1:0]` implementados | Escrever `V`; esperar `V & 0x00000003`. |
| MSG | `0x00C` | RW de 32 bits | Escrever e esperar `V`. |
| EXP | `0x010` | RW de 32 bits | Escrever e esperar `V ^ 0xA5A5A5A5`. |
| MOD | `0x014` | RW de 32 bits | Escrever e esperar `V ^ 0x5A5A5A5A`. |
| RESULT | `0x018` | Somente leitura via APB | Ler zero após reset físico. |
| ID | `0x01C` | Somente leitura, constante | Ler `0x52530200`. |

Não se espera armazenamento genérico em CTRL, STATUS, RESULT ou ID: suas
semânticas não são RW. Rejeição de escritas nos registradores somente leitura,
cenários de módulo zero/erro e endereços inválidos ficam para testes posteriores.
START, cálculo RSA, BUSY, IRQ e W1C com DONE ativo são exercitados na segunda
etapa. Nenhum sinal interno é forçado para produzir dados.

## Segunda etapa: dez operações RSA

`RESULT` é somente leitura via APB. Para gerar seu conteúdo, a bancada grava
os operandos MSG, EXP e MOD e envia `CTRL.START=1`. Cada operação segue:

1. Selecionar o vetor e calcular o resultado com `reference_modexp`.
2. Habilitar DONE/ERROR em IER (`0x3`) e gravar os três operandos, conferindo
   os quatro registradores por leitura imediata.
3. Conferir STATUS em repouso (`0x0`) e IRQ baixa; enviar START.
4. Ler STATUS e exigir BUSY ativo, com DONE/ERROR limpos (`0x1`).
5. Consultar STATUS até BUSY baixar e DONE ou ERROR subir. A consulta não
   acrescenta linhas à scoreboard; o limite é de 10000 leituras por operação.
6. Exigir STATUS final `0x2` (DONE=1, ERROR=0, BUSY=0), IRQ alta e RESULT
   igual à referência matemática.
7. Reler MSG, EXP e MOD, verificando preservação após o cálculo.
8. Escrever `0x6` em STATUS (W1C), exigir STATUS zero e IRQ baixa. Prosseguir
   para o próximo vetor sem reset, testando a reutilização do núcleo.

São **15 comparações por operação**: quatro na carga, duas no repouso, uma
de BUSY, três na conclusão (STATUS, IRQ, RESULT), três de preservação e duas
na limpeza. A conformidade de MSG/EXP/MOD é observada tanto pelas leituras
APB quanto pelo resultado matemático produzido pelo núcleo real.

Os vetores são fixos e independentes de `+DATA`, que continua controlando a
primeira etapa. Todos usam módulo diferente de zero; os expoentes pequenos
limitam a duração do núcleo, que executa multiplicações sucessivas.

| Rodada | MSG | EXP | MOD | RESULT esperado |
|---|---|---|---|---|
| 1 | `0x00000041` | 17 | `0x00000CA1` | `0x00000AE6` |
| 2 | `0x0000007B` | 7 | `0x00000CA1` | `0x00000B34` |
| 3 | `0x00000000` | 5 | `0x00000061` | `0x00000000` |
| 4 | `0x00000001` | 13 | `0x00000101` | `0x00000001` |
| 5 | `0x0000002A` | 0 | `0x00000061` | `0x00000001` |
| 6 | `0x12345678` | 1 | `0x0000FFF1` | `0x00006793` |
| 7 | `0x80000001` | 2 | `0xFFFFFFFB` | `0x4000000B` |
| 8 | `0xFFFFFFFF` | 3 | `0xFFFFFFFB` | `0x00000040` |
| 9 | `0x075BCD15` | 7 | `0x00010001` | `0x00008A8E` |
| 10 | `0xFEDCBA98` | 17 | `0x8000000B` | `0x14ADADFC` |

A função de referência usa exponenciação binária modular e produtos de 64
bits para evitar truncamento dos produtos de operandos de 32 bits. Seu
algoritmo é diferente das multiplicações sucessivas do RTL. Mensagem zero,
mensagem um, expoentes zero/um, mensagem maior que módulo e operandos com
bit 31 ativo estão incluídos; esses vetores não constituem cobertura exaustiva.

## Tasks e responsabilidades

A separação por atividade segue a organização de sequência, driver, monitor e
scoreboard usada em UVM. A implementação é procedural em SystemVerilog,
compatível com Icarus, sem dependência da biblioteca UVM.

| Papel | Task | Atividade |
|---|---|---|
| Sequência | `run_test` | Selecionar o valor e ordenar o cenário. |
| Reset | `apply_hardware_reset` | Aplicar e liberar o reset físico. |
| Reset | `apply_software_reset` | Enviar CTRL.SRST e esperar cinco ciclos. |
| Temporização | `wait_clock_cycles` | Contar bordas de subida e aguardar estabilização. |
| Driver | `drive_bus_idle` | Inicializar ou encerrar o acesso em IDLE. |
| Driver | `drive_apb_setup` | Apresentar endereço, direção e dado em SETUP. |
| Driver | `drive_apb_access` | Iniciar ACCESS após um ciclo de SETUP. |
| Monitor | `monitor_apb_completion` | Esperar PREADY, capturar a resposta e detectar erro/timeout. |
| Driver | `apb_write` | Executar uma escrita completa. |
| Driver | `apb_read` | Executar uma leitura completa. |
| Sequência | `check_reset_values` | Inicializar as referências e conferir os oito registradores. |
| Sequência | `write_and_check_register` | Escrever, atualizar a referência com máscara e conferir. |
| Sequência | `test_register_writes` | Gerar o dado da rodada e exercitar os quatro registradores RW. |
| Sequência | `read_and_check_register` | Ler um endereço e encaminhar dado à scoreboard. |
| Sequência | `check_register_retention` | Conferir os quatro valores após todas as escritas. |
| Scoreboard | `initialize_scoreboard` | Limpar contadores e histórico de escritas. |
| Scoreboard | `scoreboard_begin_phase` | Abrir a tabela da fase de reset, escrita ou retenção. |
| Scoreboard | `scoreboard_check` | Comparar esperado/lido e contar acertos e falhas. |
| Sequência | `select_rsa_vector` | Selecionar MSG, EXP e MOD para cada operação RSA. |
| Sequência | `test_rsa_operation` | Ordenar carga, cálculo, preservação e limpeza de uma operação. |
| Sequência | `start_rsa_operation` | Conferir repouso/IRQ, enviar START e conferir BUSY. |
| Monitor | `wait_rsa_completion` | Consultar STATUS com limite e conferir DONE, ERROR, IRQ e RESULT. |
| Sequência | `clear_rsa_status` | Limpar flags por W1C e conferir STATUS/IRQ. |
| Scoreboard | `check_irq` | Comparar a saída IRQ com o nível esperado. |
| Resultado | `report_results` | Exigir 238 comparações, zero divergências e emitir PASS/FAIL. |

`reference_modexp` é uma função sem avanço de tempo para calcular a referência
matemática; as atividades de estímulo e observação permanecem encapsuladas em tasks.

## Scoreboard e critério de aprovação

O array `expected_registers` mantém referências por endereço de palavra. Para
escritas RW, a referência é calculada a partir do estímulo enviado, aplicando
somente a máscara dos bits implementados. O valor observado vem de uma leitura
APB subsequente; a scoreboard não consulta o armazenamento interno do DUT.

A comparação usa `!==` para que X/Z também produzam divergência. O log agrupa
as comparações em tabelas de reset, escrita/leitura e retenção. As duas últimas
identificam a rodada atual, de 01/10 a 10/10. Cada linha
mostra número da comparação, instante da conferência em ns, registrador,
endereço, último dado enviado ao endereço, esperado, lido e PASS/FAIL.
`--` na coluna Enviado indica que ainda não houve escrita naquele endereço.
Essa coluna mantém o dado completo enviado a IER, enquanto Esperado mostra
o valor após a máscara dos bits implementados. Em CTRL, o comando SRST enviado
aparece ao lado do valor esperado de leitura zero. Para IRQ, a coluna End.
também usa `--`, pois é uma saída física sem endereço APB. Na etapa RSA, os
cabeçalhos identificam RSA 01/10 a 10/10 e a atividade de cada tabela.

O resumo informa o número de rodadas, comparações previstas/realizadas, acertos,
falhas e tempo total. Divergências são detalhadas ao final com fase e rodada
(quando aplicável), registrador, endereço, esperado,
lido e XOR; valores lidos contendo X/Z recebem uma indicação explícita.

Aprovação: **238 comparações concluídas e zero divergências**: as 88 originais
(`8 + 10 * 8`) e 150 da etapa RSA (`10 * 15`).
Uma divergência, erro APB, timeout de acesso/cálculo ou watchdog global
gera `$fatal(1)` e código de saída diferente de zero. O script usa `pipefail`
para propagar falhas do compilador e do simulador mesmo com logs via `tee`.
O watchdog global considera o orçamento das dez operações: 302000 ciclos
(`1000 + RSA_ROUNDS * (RSA_TIMEOUT_POLLS * 3 + 100)`).

## Simulação com Icarus

Pré-requisitos: Bash, `iverilog` com suporte a SystemVerilog (`-g2012`) e `vvp`
no `PATH`. A lista explícita de fontes inclui o núcleo RSA real e todos os
blocos do topo; não depende de Xcelium nem de `filelist.f` externo.

Na raiz do projeto:

```bash
./scripts/bash/iverilog.sh
./scripts/bash/iverilog.sh +DATA=DEADBEEF
```

Também é possível chamar o script por caminho absoluto a partir de outro
diretório. Os argumentos são encaminhados a `vvp`.

Saídas, sobrescritas a cada execução:

- Compilação: `logs/amba_3_apb_rsa_apb_top/iverilog/compile.log`.
- Simulação: `logs/amba_3_apb_rsa_apb_top/iverilog/simulation.log`.
- Executável: `logs/amba_3_apb_rsa_apb_top/iverilog/testbench.vvp`.
- Formas de onda: `waveforms/amba_3_apb_rsa_apb_top/testbench.vcd`.

Resultado esperado: `TEST PASS: 238 checks, 0 errors`.
O Icarus pode emitir avisos sobre ausência de timescale nos módulos RTL e
sensibilidade de seleções constantes em `always_comb`; conferir o resultado
da compilação e o resumo da bancada para determinar aprovação.

## Simulação e cobertura com Verilator

O script `scripts/bash/verilator.sh` compila e executa
a mesma bancada usando `--binary --timing --assert --coverage --trace`.
As temporizações, tasks e as duas etapas do teste são preservadas.
O fluxo usa os comandos de relatório do Verilator 5.052, versão validada
neste ambiente. Requer `verilator`, `verilator_coverage`, Make e G++ com
suporte a corrotinas C++20 no PATH. `genhtml`, fornecido pelo pacote LCOV,
é opcional para a apresentação em HTML.

```bash
./scripts/bash/verilator.sh
./scripts/bash/verilator.sh +DATA=DEADBEEF
VERILATOR_JOBS=4 ./scripts/bash/verilator.sh
```

Os argumentos são encaminhados ao executável. O script também pode ser
chamado por caminho absoluto a partir de outro diretório. Cada execução
substitui os dados e relatórios da execução anterior; não acumula cobertura
de diferentes valores de DATA.

Saídas:

| Artefato | Caminho relativo à raiz |
|---|---|
| Compilação e avisos | `logs/amba_3_apb_rsa_apb_top/verilator/compile.log` |
| Scoreboard e simulação | `logs/amba_3_apb_rsa_apb_top/verilator/simulation.log` |
| Executável | `logs/amba_3_apb_rsa_apb_top/verilator/obj_dir/simulation` |
| Contadores brutos | `logs/amba_3_apb_rsa_apb_top/verilator/coverage.dat` |
| Resumo por tipo e hierarquia | `reports/amba_3_apb_rsa_apb_top/verilator/coverage_summary.txt` |
| Fontes com contagens por ponto | `reports/amba_3_apb_rsa_apb_top/verilator/annotated/` |
| Exportação LCOV | `reports/amba_3_apb_rsa_apb_top/verilator/coverage.info` |
| Relatório HTML, com genhtml | `reports/amba_3_apb_rsa_apb_top/verilator/html/index.html` |
| Formas de onda VCD | `waveforms/amba_3_apb_rsa_apb_top/verilator/testbench.vcd` |

`--coverage` habilita a instrumentação de cobertura suportada pela ferramenta,
incluindo linhas/blocos, branches, expressões, transições de sinais e FSMs
reconhecidas. A bancada não define covergroups. A configuração `coverage.vlt`,
gerada no diretório de logs, exclui `testbench.sv`: as métricas referem-se ao
RTL do DUT. As fontes anotadas usam limite de um hit por ponto. O arquivo
LCOV/HTML apresenta as métricas exportadas por esse formato; o resumo nativo
preserva a separação dos tipos e da hierarquia.

O script preserva os avisos no compile.log e usa `-Wno-fatal` para permitir
a simulação com os avisos existentes do RTL. Erros de compilação, simulação
ou relatório interrompem a execução com código diferente de zero.
O resumo da scoreboard deve apresentar `TEST PASS: 238 checks, 0 errors`;
a cobertura informa quais pontos foram atingidos, sem impor percentual mínimo.

Verilator simula os sinais desta bancada em dois estados; a detecção de X/Z
é verificada com Icarus, que mantém os quatro estados.

Referências oficiais do fluxo:
[coleta de cobertura](https://verilator.org/guide/latest/simulating.html#coverage-collection)
e [relatórios com verilator_coverage](https://verilator.org/guide/latest/exe_verilator_coverage.html).

## Validação realizada

Executado com Icarus Verilog 13.0: valor padrão e `+DATA=DEADBEEF`, ambos com
as dez rodadas originais seguidas pelas dez operações RSA, 238 comparações e
zero erros. Os dez resultados também foram comparados com `pow(MSG, EXP, MOD)`
em Python, independente da função de referência da bancada. Em cópias
temporárias, resultado incorreto e ausência de DONE foram usados para conferir
a detecção de divergência e timeout. A sintaxe Bash e a execução a partir de
outro diretório foram verificadas na versão inicial do script.

O fluxo Verilator 5.052 também foi executado: 238 comparações aprovadas e
relatórios nativo, anotado, LCOV e HTML gerados. A cobertura nativa da execução
padrão foi 87,8% de linhas/blocos, 82,9% de branches, 81,0% de toggle, 84,8%
de expressões e 92,3% dos estados de FSM reconhecidos. A exportação inclui os
dez arquivos RTL e exclui a bancada. O executável também passou com
`+DATA=DEADBEEF` a partir de outro diretório, gerando novos contadores em uma
pasta temporária. Os percentuais do HTML podem diferir do resumo nativo,
pois a exportação LCOV agrupa pontos de diferentes tipos em linhas e branches.
