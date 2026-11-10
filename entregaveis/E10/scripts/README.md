# Implementações MG e MR

`scripts/MG/` e `scripts/MR/` têm os mesmos lançadores (`bash/`) e fluxos
(`tcl/`): Xcelium (RTL, UVM e netlist TSMC28 com SDF), IMC, Genus, LEC/lint,
Innovus, Xezim, Verilator e Icarus. Os exemplos abaixo usam `MG/`; para a
implementação MR, troque por `MR/` (por exemplo, `./scripts/MR/bash/genus_nogui.sh -p gpdk45`).

Diferenças do MR:

- RTL: `src/MR/RSA_APB/rsa_core_32bits.sv` e `src/MR/RSA_APB/rsa_apb_top.sv`
  (top `amba_3_apb_rsa_apb_top`).
- SDC: `constraints/MR/rsa_apb.sdc`.
- Saídas em `logs/MR/`, `reports/MR/`, `waveforms/MR/`, `coverage/MR/` e
  `ps_files/MR/`, com os mesmos subdiretórios do MG; o Innovus usa
  `innovus/rsa_core_32bits` no lugar de `innovus/rsa32_v2`.
- `xezim_rsa_core_fault.sh` não recebe `v1|v2`: o MR tem um único núcleo de 32 bits.
- Bancadas compartilhadas: `testbenchs/rsa_apb_top/testbench.sv`,
  `testbenchs/rsa_core_fault/tb_rsa_core_fault.sv` e a UVM em `UVM/`.

`scripts/RSA4/` contém o LEC RTL x RTL do projeto RSA de 4 bits:
`./scripts/RSA4/bash/run_rsa_lec.sh [top]` (com `tcl/rsa_lec.tcl`) compara
`RSA4/src/vlog/rsa_core.v` (golden) com `RSA4/src/sv/rsa_core.sv` (revised) e
grava `summary.txt`, `equivalence.rpt` e `console.log` em `reports/RSA4/lec/`.

`scripts/RSA32/` contém a simulação Xcelium do núcleo `rsa_core` de 32 bits de
`RSA32_opt` (RTL em `RSA32_opt/src/v2`, bancada
`RSA32_opt/testbenches/testbench.sv`, que permanecem nessa pasta):
`bash/xrun.sh` (RTL com cobertura IMC), `bash/xrun_wgui.sh` (GUI, SHM) e
`bash/xrun_ps.sh` (pós-rota com SDF, a partir do export do Innovus em
`RSA32_opt/ps_files/rsa_core_32_opt/innovus/export`). Resultados em
`logs|coverage|reports|waveforms/RSA32/rsa_core_32_opt/`.

# Ondas da simulação UVM

Na raiz do projeto, execute um dos fluxos Xcelium:

```bash
./scripts/MG/bash/xrun_uvm_nogui.sh
./scripts/MG/bash/xrun_uvm_gui.sh
```

Ambos gravam as ondas durante a simulação em
`waveforms/amba_3_apb_rsa_apb_top/uvm/`, com o mesmo identificador de execução:

- `<RUN>.shm/`: banco nativo do SimVision.
- `<RUN>.vcd`: sinais da hierarquia estática de `top_tb`, incluindo interface
  APB e DUT, para visualizadores compatíveis com VCD.

Os caminhos são impressos no terminal antes de iniciar o Xrun. Para abrir
o VCD no GTKWave, use `gtkwave /caminho/impresso/arquivo.vcd`.
A geração começa quando a simulação inicia; compilar sem simular não gera
as ondas. Execuções anteriores continuam apenas com os arquivos já gerados.

# Watchdog e duração da campanha UVM

Os lançadores calculam o orçamento pelos casos de `UVM/top_tb_pkg.svh` e
mostram separadamente o orçamento conservador e o watchdog aplicado.
No Xcelium 24.03, o watchdog automático fica limitado a **9000 s simulados**:
essa versão apresenta overflow perto de 9223 s, mesmo com `1ns/1ps` e mesmo
dividindo o atraso em partes. Valores explícitos de `MAX_TIME` ou
`+UVM_TIMEOUT` acima de 9200 s são rejeitados antes de iniciar o Xcelium.
O Xezim mantém seu limite separado, baseado em ticks de 1 ps.

Quando o orçamento excede o limite, o lançador emite um aviso e conserva os
casos planejados. Se o watchdog expirar antes da conclusão, a execução falha
com `UVM_FATAL [PH_TIMEOUT]`. O limite não garante que uma campanha arbitrária
caiba em uma única execução. `+UVM_TIMEOUT=0` continua desabilitando o
watchdog por escolha explícita do usuário; isso não remove o limite do simulador.

`MAX_TIME=1ms ./scripts/MG/bash/xrun_uvm_nogui.sh` é um exemplo de execução com
watchdog de 0,9 ms, útil para diagnóstico. Tempo simulado não é tempo de
execução no computador. Veja a [estimativa da configuração atual](../docs/estimativa_tempo_uvm.md).

# Taxas de cobertura UVM no IMC

Após a simulação, execute na raiz do projeto:

```bash
./scripts/MG/bash/imc.sh          # gera relatórios do banco UVM mais recente
./scripts/MG/bash/imc_gui.sh      # abre esse banco na GUI
```

Ambos aceitam o diretório de uma execução como argumento para selecionar
outro banco. A seleção automática usa a data/hora no nome da execução e
exige dados `.ucd`; aguarde o fim da simulação antes de gerar os relatórios.
O fluxo `xrun_uvm_nogui.sh` já chama `imc.sh` automaticamente.

Os relatórios ficam em `reports/amba_3_apb_rsa_apb_top_rtl/imc/<RUN>/`:

| Arquivo | Conteúdo |
|---|---|
| `coverage_rates_rtl.rpt` | Percentuais cumulativos e contagens de itens cobertos/medidos por hierarquia principal; também exibidos no terminal |
| `coverage_rtl.rpt` | Todas as métricas por instância, incluindo blocos, expressões, toggle e FSM |
| `coverage_covergroups_rtl.rpt` | Detalhes dos covergroups, coverpoints e bins cobertos ou não cobertos |
| `coverage_html_rtl/index.html` | Relatório navegável para abrir no navegador |
| `coverage_inputs_rtl.txt` | Caminho do banco usado na análise |

O percentual de **covergroups** mede os cenários definidos pela bancada;
**code** e **FSM** medem estruturas do RTL exercitadas pela simulação.
`n/a` indica ausência de itens medidos naquela métrica/hierarquia.
Atualmente, `UVM/uvm_subscriber.sv` possui apenas o coverpoint
`transaction_type` (READ/WRITE): 100% nesses dois bins não representa
cobertura de todos os cenários RSA/APB. O relatório expõe esse denominador.

# Síntese do top por PDK

Os fluxos Genus e Innovus usam apenas `amba_3_apb_rsa_apb_top`.
Selecione a tecnologia com `-p`; sem esse argumento, o padrão é `gpdk45`.

| Flag e sufixo | PDK | Biblioteca | Site |
|---|---|---|---|
| `sky130` | SKY130, 130 nm | sky130_fd_sc_hd, TT 1,8 V / 25 °C | unithd |
| `gpdk45` | GPDK45, 45 nm | GSCLib045, typical | CoreSite |
| `free45` | FreePDK45, 45 nm | Nangate45, typical | FreePDK45_38x28_10R_NP_162NW_34O |
| `ics55` | ICsprout55, 55 nm | H7CR, TT 1,2 V / 25 °C | core7 |
| `tsmc28` | TSMC28 HPC+, 28 nm | BWP30P140, TT 1,0 V / 25 °C | Sem LEF; somente Genus |

ICsprout55 usa `ics55` nos comandos e nos nomes dos arquivos.
GPDK45 e FreePDK45 são configurações independentes.

## Execução

Na raiz do repositório, após configurar o ambiente e as licenças Cadence:

```bash
./scripts/MG/bash/genus_no_gui.sh -p sky130
./scripts/MG/bash/genus_no_gui.sh -p gpdk45
./scripts/MG/bash/genus_no_gui.sh -p free45
./scripts/MG/bash/genus_no_gui.sh -p ics55
./scripts/MG/bash/genus_no_gui.sh -p tsmc28

./scripts/MG/bash/innovus_no_gui.sh -p sky130
./scripts/MG/bash/innovus_no_gui.sh -p gpdk45
./scripts/MG/bash/innovus_no_gui.sh -p free45
./scripts/MG/bash/innovus_no_gui.sh -p ics55
```

Os nomes anteriores `genus_nogui.sh` e `innovus_full_flow.sh` continuam
aceitando os mesmos argumentos. `-h` mostra a ajuda; argumentos adicionais
da ferramenta devem vir depois de `--`.

### TSMC28 sem LEF

`MG/tcl/run_genus_tsmc28.tcl` usa o fluxo comum de síntese lógica do topo
`amba_3_apb_rsa_apb_top`, incluindo o wrapper e o núcleo RSA32 v2.
Executa `syn_generic`, `syn_map` e `syn_opt`, sem ler ou exigir LEFs.
Mantém o SDC comum em `constraints/MG/amba_3_apb_rsa_apb_top.sdc` (atualmente
100 MHz), os relatórios e as saídas DB, Verilog, SDC e SDF, com sufixo `tsmc28`.
Os resultados são de síntese lógica, sem parasitas extraídos de layout.
O fluxo Innovus recusa essa opção porque não há configuração física.

`TSMC28_ROOT` aponta para o diretório que contém o Liberty. O padrão é
`/tsmc28`, usando a biblioteca instalada
`tcbn28hpcplusbwp30p140tt1v25c.lib` (TT, 1,0 V, 25 °C).
Não é exigida uma biblioteca LVT. Mesmo que exista LEF nesse diretório,
ele não é lido por esta configuração.

Para a mesma biblioteca em outro diretório:

```bash
TSMC28_ROOT=/caminho/das/bibliotecas \
  ./scripts/MG/bash/genus_no_gui.sh -p tsmc28
```

Para outra versão, corner ou seleção de células, `TSMC28_LIB_FILES`
substitui a lista inteira. Informe uma lista Tcl de caminhos absolutos,
com chaves em torno de cada caminho que contenha espaços:

```bash
TSMC28_LIB_FILES='{/pdk/TSMC28/std_tt.lib} {/pdk/TSMC28/lvt_tt.lib}' \
  ./scripts/MG/bash/genus_no_gui.sh -p tsmc28
```

Use bibliotecas de um mesmo corner. Os arquivos devem existir e ser legíveis;
as bibliotecas proprietárias não são distribuídas pelo repositório.
Para abrir o banco gerado, use `genus_gui.sh -p tsmc28`.

### Simulação da netlist TSMC28 com SDF

O par `MG/bash/xrun_ps_tsmc28.sh` / `MG/tcl/xrun_ps_tsmc28.tcl` executa o Xrun
sem GUI sobre a netlist do topo `amba_3_apb_rsa_apb_top`. Na raiz do projeto,
após configurar o ambiente Cadence:

```bash
./scripts/MG/bash/xrun_ps_tsmc28.sh
```

`MG/bash/xrun_ps.sh` também chama esse fluxo TSMC28, com os mesmos argumentos
e variáveis, substituindo a referência antiga a uma síntese ASAP7.

O script seleciona a netlist TSMC28 mais recente e exige o SDF com o **mesmo
identificador de síntese**. Se esse SDF estiver ausente, a execução falha;
não é usado um SDF de outra síntese. Para fixar uma execução:

```bash
SYNTH_RUN=amba_3_apb_rsa_apb_top_2026-11-05_14-23-23_190403435_tsmc28 \
  ./scripts/MG/bash/xrun_ps_tsmc28.sh
```

A bancada é `testbenchs/rsa_apb_top/testbench.sv`, com `POST_SYNTHESIS`
para instanciar a netlist sem parâmetros RTL. O escopo de anotação é
`testbench.dut`, com `MTM_CONTROL=MAXIMUM` e `SCALE_TYPE=FROM_MTM`.
O SDF gerado pelo Genus contém os valores no campo máximo; essa seleção
não transforma o corner TT em um corner de pior caso. O fluxo usa o modelo
Verilog `/tsmc28/tcbn28hpcplusbwp30p140.v`, habilitando `NTC` e `RECREM`
para os sinais atrasados e as verificações de recovery/removal do modelo.
Os timing checks permanecem habilitados.

| Variável | Padrão / finalidade |
|---|---|
| `SYNTH_RUN` | Netlist TSMC28 mais recente; fixa o par netlist/SDF quando informado |
| `TSMC28_ROOT` | `/tsmc28`, diretório do modelo Verilog |
| `TSMC28_VERILOG_FILE` | Substitui o caminho completo do modelo Verilog |
| `XRUN_BIN` | `xrun`, executável no ambiente Cadence |
| `CLOCK_PERIOD_NS` | `10.0`, alvo de 100 MHz, com precisão de 1 ps na bancada |

O parâmetro de clock da bancada passou a aceitar valores reais; seu padrão
para os outros fluxos continua sendo 10 ns. Opções adicionais do Xrun e
plusargs da bancada devem vir depois de `--`, por exemplo `-- +DATA=1234567B`.
O Tcl executa a bancada até o fim e fecha a sessão; este lançador é batch.

Cada simulação recebe um novo `RUN`, independente de `SYNTH_RUN`:

| Artefato | Caminho |
|---|---|
| Log Xrun, comando SDF e banco compilado | `logs/amba_3_apb_rsa_apb_top_tsmc28/xrun_ps/<RUN>/` |
| Resultado e insumos | `reports/amba_3_apb_rsa_apb_top_tsmc28/xrun_ps/<RUN>/simulation{,_inputs}_tsmc28.{rpt,txt}` |
| Log detalhado da anotação | `reports/amba_3_apb_rsa_apb_top_tsmc28/xrun_ps/<RUN>/sdf_annotation_tsmc28.log` |
| Arcos/checks não anotados | `reports/amba_3_apb_rsa_apb_top_tsmc28/xrun_ps/<RUN>/sdf_unannotated_tsmc28.rpt` |
| Ondas SHM | `waveforms/amba_3_apb_rsa_apb_top_tsmc28/xrun_ps/<RUN>/waves_tsmc28.shm` |

O resumo inclui as estatísticas de anotação. O script retorna falha se o
Xrun falhar, houver erro/fatal ou violação de timing no log, faltar o log
SDF, ou a bancada não emitir `TEST PASS`. Relatórios e ondas são preservados
também nas falhas. Este fluxo não depende do IMC e não gera cobertura RTL.

Na validação da síntese `2026-11-05_09-15-51_907875919_tsmc28`, os 14.922
path delays e os 138 checks de recovery/removal foram anotados. O relatório
também registra checks não anotados e avisos de convergência NTC; isso não
constitui uma validação completa de timing. A bancada passou por 255
verificações e encontrou timeout na primeira operação RSA. A comparação
RTL reproduziu o timeout com `LOAD_GAP=0` (padrão do topo sintetizado),
enquanto `LOAD_GAP=1` completou as 398 verificações. O script mantém essa
falha visível: executar a netlist existente não altera os parâmetros que
foram fixados na síntese.

O Innovus executa as etapas 0 a 9 sobre a netlist mais recente **do PDK
selecionado**, exigindo o SDC com o mesmo identificador. O fluxo completo fixa
essa seleção antes de iniciar; outra síntese ou atualização de `active_run`
não muda a execução em andamento. Uma falha interrompe as etapas seguintes.

Para executar apenas uma etapa ou abrir a GUI:

```bash
./scripts/MG/bash/0.innovus_init.sh -p free45
./scripts/MG/bash/1.innovus_check.sh -p free45
./scripts/MG/bash/innovus_gui.sh place -p free45
./scripts/MG/bash/genus_gui.sh -p free45
```

Nas etapas individuais, informe sempre o mesmo `-p`. A GUI Innovus abre a
etapa mais avançada disponível por padrão. Para selecionar uma síntese
específica, copie seu identificador completo, incluindo o sufixo:

```bash
SYNTH_RUN=amba_3_apb_rsa_apb_top_2026-10-29_16-00-00_123456789_sky130 \
  ./scripts/MG/bash/innovus_no_gui.sh -p sky130
```

## Resultados

`RUN` tem o formato
`amba_3_apb_rsa_apb_top_<data>_<hora>_<nanossegundos>_<flag>`.
Cada síntese recebe um identificador novo, inclusive no mesmo segundo.

| Artefato | Caminho |
|---|---|
| Genus: banco, netlist, restrições e atrasos | `ps_files/rsa_apb_top_<flag>/{db,netlist,sdc,sdf}/synth_<RUN>.*` |
| Relatórios Genus | `reports/amba_3_apb_rsa_apb_top_<flag>/genus/<RUN>/*_<flag>.rpt` |
| Logs Genus | `logs/amba_3_apb_rsa_apb_top_<flag>/genus/<RUN>/` |
| Bancos Innovus | `ps_files/rsa_apb_top_<flag>/innovus/rsa32_v2/<RUN>/<etapa>_amba_3_apb_rsa_apb_top_<flag>/` |
| Relatórios Innovus | `reports/amba_3_apb_rsa_apb_top_<flag>/innovus/rsa32_v2/<RUN>/<etapa>/<execução>/` |
| Logs Innovus | `logs/amba_3_apb_rsa_apb_top_<flag>/innovus/rsa32_v2/<RUN>/<etapa>/` |
| Exportação Innovus | `ps_files/rsa_apb_top_<flag>/innovus/rsa32_v2/<RUN>/export/*_<flag>.*` |

Os relatórios explícitos têm sufixo, como `area_sky130.rpt` e
`timing_max_gpdk45.rpt`. Os relatórios automáticos de temporização do Innovus
ficam em subpastas com sufixo. Arquivos internos das ferramentas podem manter
seus nomes próprios dentro da pasta isolada de execução.
Cada PDK possui seu próprio `active_run`. O arquivo
`synthesis_inputs_<flag>.txt` registra a síntese, Liberty, LEFs, netlist e SDC.
Os resultados históricos permanecem nos caminhos anteriores e não são
selecionados automaticamente quando não seguem a nova nomenclatura.

## Metodologia comum de relatórios

Todos os Tcl ativos que geram relatórios usam `MG/tcl/report_common.tcl`:
arquivos explícitos seguem `<relatório>_<sufixo>.rpt` (ou `.txt` para
proveniência), e diretórios de relatórios automáticos seguem
`<tipo>_<sufixo>/`. O sufixo identifica o PDK; lint e cobertura de RTL
usam `rtl`, pois não dependem de uma tecnologia.

| Fluxo | Diretório de relatórios | Exemplos |
|---|---|---|
| Genus, todos os PDKs | `reports/amba_3_apb_rsa_apb_top_<pdk>/genus/<RUN>/` | `area_<pdk>.rpt`, `timing_max_<pdk>.rpt` |
| Innovus | `reports/amba_3_apb_rsa_apb_top_<pdk>/innovus/rsa32_v2/<SYNTH_RUN>/<etapa>/<execução>/` | `timing_<pdk>.rpt`, `setup_<pdk>/` |
| LEC, GUI e batch | `reports/amba_3_apb_rsa_apb_top_<pdk>/lec/<RUN>/` | `lec_verification_<pdk>.rpt`, `synthesis_inputs_<pdk>.txt` |
| Lint RTL | `reports/amba_3_apb_rsa_apb_top_rtl/lint/<RUN>/` | `rule_check_rtl.rpt`, `black_box_rtl.rpt` |
| Cobertura IMC | `reports/amba_3_apb_rsa_apb_top_rtl/imc/<RUN>/` | `coverage_rtl.rpt`, `coverage_html_rtl/`, `coverage_inputs_rtl.txt` |

Genus, LEC, lint e IMC reservam uma pasta nova por execução por meio de
`MG/bash/report_common.sh`, com data, hora, nanossegundos e sufixo. No Innovus,
cada repetição de uma etapa recebe uma subpasta com data, hora, PID,
contador de relógio e PDK, preservando os relatórios anteriores da mesma
síntese. Os bancos e netlists mantêm seus caminhos existentes em `ps_files`.
As etapas que apenas exportam artefatos ou abrem uma GUI não criam novos
relatórios de análise.

```bash
./scripts/MG/bash/lec.sh -p gpdk45
./scripts/MG/bash/lec_gui.sh -p tsmc28
./scripts/MG/bash/lint.sh
./scripts/MG/bash/imc.sh /caminho/do/banco/de/cobertura
```

O LEC inicia em modo Tcl para carregar os scripts de configuração e usa as
bibliotecas Liberty e a netlist mais recente do PDK selecionado. A seleção
usa a data/hora no nome da síntese, preservando a ordem após cópias do projeto.
Sem `-p`, o PDK é `gpdk45`; para abrir a última síntese TSMC28, use
`./scripts/MG/bash/lec_gui.sh -p tsmc28`. A GUI permanece aberta após a comparação.
O terminal informa o PDK, a síntese, a netlist, o log e a pasta de relatórios.
`SYNTH_RUN` permite fixar uma síntese específica, como no Innovus. O arquivo
`synthesis_inputs_<pdk>.txt` registra os insumos efetivamente usados. O lint
salva em arquivos os relatórios de design, black boxes e regras. A simulação
UVM sem GUI chama `imc.sh` para produzir os mesmos relatórios de cobertura;
abrir `imc_gui.sh` apenas carrega o banco. `LEC_BIN` e `IMC_BIN` permitem
selecionar os executáveis.

Os relatórios históricos não são movidos nem apagados. Scripts em `legacy/`
permanecem históricos; esta metodologia se aplica aos Tcl ativos em `scripts/`.

## Tcl e instalação dos PDKs

`MG/tcl/run_genus_<flag>.tcl` e `MG/tcl/run_innovus_<flag>.tcl` são as entradas
específicas (TSMC28 possui apenas a entrada Genus).
Os parâmetros tecnológicos ficam em `MG/tcl/pdks/<flag>.tcl`,
compartilhados pelo Genus, inicialização Innovus e MMMC.
O RTL, as etapas e o SDC de entrada são comuns para facilitar comparações.
As configurações incluem Liberty, LEFs, nó, site, camadas, alimentação e
células de CTS. Os arquivos Liberty e LEF são verificados antes da leitura;
TSMC28 configura e verifica apenas Liberty. O LEC também verifica apenas
Liberty em qualquer PDK, pois não utiliza LEF.

Os caminhos padrão correspondem aos PDKs instalados nesta máquina. Para
outra instalação, configure:

| Variável | Diretório |
|---|---|
| `PDK_BASE` | Cache dataroot dos PDKs abertos |
| `LAMBDAPDK_ROOT` | Diretório lambdapdk que contém sky130 e freepdk45 |
| `GPDK45_ROOT` | Raiz GSCLib045 com LIB e LEF; aceita também INNOVUS_TECH_DIR |
| `SKY130_ROOT` | Raiz sky130 com base e libs |
| `FREEPDK45_ROOT` | Raiz freepdk45 com base e libs |
| `ICS55_ROOT` | Raiz ICsprout55 com IP e prtech |
| `ICS55_LIB_ROOT` | Diretório do Liberty H7CR |
| `TSMC28_ROOT` | Diretório do Liberty TSMC28; padrão `/tsmc28` |
| `TSMC28_LIB_FILES` | Lista Tcl de arquivos Liberty; substitui os padrões TSMC28 |
| `GENUS_BIN`, `INNOVUS_BIN` | Executáveis das ferramentas |

O MMMC usa o corner typical e os dados RC dos LEFs, sem o QRC específico
do antigo fluxo ASAP7. O GDS exportado continua experimental, sem incorporar
GDS das células ou um mapa de camadas validado. A seleção de PDK também se
aplica ao LEC; simulação e lint RTL usam o sufixo de relatórios `rtl`.
