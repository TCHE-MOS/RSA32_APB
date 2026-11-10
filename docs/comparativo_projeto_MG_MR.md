# Diferenças de projeto entre as implementações MG e MR

Este documento consolida as diferenças observadas entre as duas implementações do
coprocessador RSA de 32 bits com interface AMBA 3 APB (`amba_3_apb_rsa_apb_top`),
a partir da leitura do RTL, da síntese (Genus), da simulação pós-síntese com SDF
(Xcelium) e da campanha UVM. Todas as execuções são de 10/11/2026, exceto a síntese
MG em GPDK45, que é de 05/11/2026.

| | MG | MR |
|---|---|---|
| RTL | `src/MG/rsa32/v2` + `src/MG/amba_3_apb` | `src/MR/RSA_APB` |
| Especificação de referência | `docs/apb_integration.pdf` | `docs/apb_integration.pdf` |

## Resumo

| Aspecto | MG | MR |
|---|---|---|
| Organização | 15 arquivos, 15 módulos, hierárquico | 2 arquivos, 8 módulos, plano |
| Linhas de RTL | 2.028 (819 núcleo + 1.209 APB) | 1.003 (483 núcleo + 520 APB) |
| Portas do top | idênticas | idênticas |
| Somadores do núcleo | Kogge-Stone explícito (4 instâncias) | operadores `+`/`-` (o Genus escolhe a arquitetura) |
| Ciclos por operação RSA | iguais | iguais |
| `PSLVERR` em endereço reservado (0x020–0xFFF) | **sim**, em leitura e escrita | **não** (segue a lista da seção 6.7) |
| Flops | 706 | 706 |
| Área TSMC28 / GPDK45 | 2.808 / 12.519 µm² | 2.694 / 11.649 µm² (−4% / −7%) |
| Caminho crítico do núcleo (TSMC28) | 1.114 ps | 1.547 ps (+39%) |
| Caminho mais longo da interface APB (TSMC28) | 429 ps | 232 ps (−46%) |
| Potência estimada TSMC28 | 529 µW | 500 µW (−5,5%) |
| Pior slack TSMC28 / GPDK45 | +5.470 / +2.612 ps | +3.153 / +980 ps |
| Netlist com SDF (`testbench.sv`) | PASS, 0 violações | PASS, 0 violações |
| UVM (seed 1) | aprovado | reprovado só em `xz_values` (`PSLVERR` reservado) |

## 1. Arquitetura

### MG: hierárquico, um bloco por função

```
amba_3_apb_rsa_apb_top
├── amba_3_apb_reset              sincronizador de reset (RESET_LATENCY estágios)
├── amba_3_apb_data_io_top
│   ├── amba_3_apb_adrec          validação/decodificação de endereço
│   └── amba_3_apb_data_o_mux     multiplexador de PRDATA
├── amba_3_apb_control            FSM APB (IDLE/SETUP/ACCESS), PSLVERR, write enables
├── amba_3_apb_regbank            registradores CTRL/STATUS/IER/MSG/EXP/MOD/RESULT/ID
└── amba_3_apb_rsa_wrapper_top
    ├── amba_3_apb_rsa_wrapper_control   sequenciador de cargas (LOAD_GAP)
    ├── amba_3_apb_rsa_wrapper_data
    └── rsa_core (v2)
        ├── rsa_core_ctrl  + kogge_stone_adder (expoente)
        ├── rsa_core_mult  + kogge_stone_adder
        └── rsa_core_mod   + kogge_stone_adder (×2, dado e contador)
```

### MR: plano, decodificação centralizada

```
amba_3_apb_rsa_apb_top
├── rsa_apb_rst_sync      sincronizador de 2 flops para core_rst (PRESETn OU SRST)
├── rsa_apb_regs          escravo APB completo: mapa, PSLVERR, IRQ, registradores
├── rsa_apb_seq           sequenciador de START: PREP, cargas M/e/n, LOAD_GAP
└── rsa_core              núcleo de referência (rsa_core_ctrl, _mult, _mod)
```

O RTL do MR traz no cabeçalho (`rsa_apb_top.sv`, linhas 1–48) as decisões de
integração tomadas ao ler o `rsa_core` de referência: o `LOAD_GAP` mínimo de 1, a
interpretação de `core_done`/`core_err`, a duração do SRST e a limpeza de BUSY no
mesmo ciclo de DONE/ERROR.

## 2. Interface e parâmetros

As portas do top são idênticas: `pclk_i`, `presetn_i`, `psel_i`, `penable_i`,
`pwrite_i`, `paddr_i[11:0]`, `pwdata_i[31:0]`, `prdata_o[31:0]`, `pready_o`,
`pslverr_o` e `irq_o`. Por isso as duas usam a mesma UVM e o mesmo `testbench.sv`
sem modificação.

| Parâmetro | MG | MR |
|---|---|---|
| `DATA_WIDTH` | 32 (sem tipo) | 32 (`int`) |
| `ADDR_WIDTH` | 12 | 12 |
| `LOAD_GAP` | 1 no top (0 no wrapper) | 1; valores < 1 são elevados a 1 (`rsa_apb_top.sv:109`) |
| Específico | `RESET_LATENCY = 2`: estágios do sincronizador de reset | `SRST_CYCLES = 2`: duração do pulso de `core_rst` gerado por CTRL.SRST (`rsa_apb_top.sv:378`) |
| Derivados | `D_WID`, `A_WID` expostos como parâmetros | internos (`localparam`) |

O único parâmetro que as bancadas sobrescrevem é `LOAD_GAP`, que existe nas duas.
A especificação dá `LOAD_GAP` padrão 0, mas as duas implementações usam 1, porque
o `rsa_core` de referência não aceita cargas consecutivas.

## 3. Comportamento funcional

### 3.1 Diferença: `PSLVERR` em endereços reservados

| | MG | MR |
|---|---|---|
| Regra | `addr_valid = ~|paddr[11:5]` (`amba_3_apb_adrec.sv:17`); endereço inválido gera erro em qualquer acesso (`amba_3_apb_control.sv:113`) | `pslverr = wr_acc && (ro_write \|\| busy_write)` (`rsa_apb_top.sv:274-278`) |
| Leitura de 0x020–0xFFF | PSLVERR = 1 | PSLVERR = 0 |
| Escrita em 0x020–0xFFF | PSLVERR = 1 | PSLVERR = 0 |
| Escrita em RESULT/ID | PSLVERR = 1 | PSLVERR = 1 |
| Escrita em MSG/EXP/MOD ou START com BUSY | PSLVERR = 1 | PSLVERR = 1 |

A seção 6.7 da especificação lista apenas as duas últimas condições. O MR implementa
exatamente essa lista. O MG, e com ele a bancada UVM, acrescenta o erro em endereço
reservado. Essa é a causa dos 97.536 `UVM_ERROR [XZ_RESPONSE]` do MR
(4.064 endereços × 8 padrões × 3 transações). A equipe precisa definir qual regra
vale (ver `UVM/comparativo_uvm_MG_MR.md`).

### 3.2 Comportamentos equivalentes, confirmados por simulação

- **Mapa de registradores e valores de reset:** idênticos, inclusive `ID = 0x5253_0200`
  e bits reservados lidos como 0.
- **Decodificação de endereço:** as duas ignoram `paddr[1:0]`.
- **Tratamento de X/Z nos dados:** as 32.768 linhas da tabela `xz_values` são
  idênticas (antes, enviado, depois, efeito), descontada a coluna `PSLVERR`.
- **Operação RSA e corners:** os 12 casos de `corners_exp` têm duração idêntica,
  porque os dois núcleos têm o mesmo algoritmo e a mesma contagem de ciclos.
  O MR conclui a primeira operação da campanha 30 ns depois (uma leitura de polling a
  mais), sem impacto nas demais.
- **SVA:** 63 PASS, 0 FAIL e 1 não exercitada (`APB_WAIT_HOLD`) nas duas.

## 4. Núcleo RSA

| | MG (`src/MG/rsa32/v2`) | MR (`rsa_core_32bits.sv`) |
|---|---|---|
| Algoritmo, FSMs e ciclos | mesmos (cobertura FSM do `rsa_core` idêntica: 53/65) | mesmos |
| Somadores | `kogge_stone_adder` instanciado no mult, no mod (dado e contador) e no ctrl (expoente) | operadores `+`/`-` (ex.: `t_reg <= t_reg - n_reg`) |
| Caminho crítico reg→reg | `rsa_core_mult/p_reg[0→63]`, 65 células | `rsa_core_mod/t_reg[0→63]`, 66 células |
| Atraso (TSMC28 / GPDK45) | 1.114 ps / 6.395 ps | 1.547 ps / 7.956 ps |
| Frequência indicativa pelo núcleo* | ~870 MHz / ~155 MHz | ~640 MHz / ~125 MHz |

\* Atraso mais setup, sem incerteza, extraído de sínteses feitas a 100 MHz. Com folga,
o Genus não otimiza além do necessário, então a frequência máxima real exige uma
varredura de período.

## 5. Síntese, área, slack e timing (Genus, 100 MHz)

Sínteses comparadas, todas com `syn_generic`/`syn_map`/`syn_opt` em esforço alto:

| PDK | MG | MR |
|---|---|---|
| TSMC28 (HPC+, TT 1,0 V/25 °C, sem LEF) | `amba_3_apb_rsa_apb_top_2026-11-10_09-21-01_905568368_tsmc28` | `amba_3_apb_rsa_apb_top_2026-11-10_09-31-35_358650711_tsmc28` |
| GPDK45 | `amba_3_apb_rsa_apb_top_2026-11-05_14-30-30_264505466_gpdk45` | `amba_3_apb_rsa_apb_top_2026-11-10_09-18-20_416848093_gpdk45` |

Relatórios em `reports/[MR/]amba_3_apb_rsa_apb_top_<pdk>/genus/<execução>/`;
netlists, SDF e bancos em `ps_files/[MR/]rsa_apb_top_<pdk>/`.

### 5.1 Área e células

| Métrica | MG TSMC28 | MR TSMC28 | Δ MR | MG GPDK45 | MR GPDK45 | Δ MR |
|---|---|---|---|---|---|---|
| Células (total) | 2.562 | 2.129 | −16,9% | 2.492 | 2.196 | −11,9% |
| Sequenciais | 706 | 706 | 0 | 706 | 706 | 0 |
| Inversores | 176 | 99 | −43,8% | 111 | 77 | −30,6% |
| Lógica combinacional | 1.680 | 1.324 | −21,2% | 1.675 | 1.413 | −15,6% |
| Área sequencial (µm²) | 1.747,5 | 1.704,4 | −2,5% | 5.696,0 | 5.343,1 | −6,2% |
| Área de inversores (µm²) | 44,4 | 24,9 | −43,7% | 75,9 | 52,7 | −30,6% |
| Área combinacional (µm²) | 1.016,3 | 965,0 | −5,0% | 3.428,9 | 3.233,6 | −5,7% |
| Área de células (µm²) | 2.808,2 | 2.694,4 | **−4,1%** | 9.200,8 | 8.629,3 | **−6,2%** |
| Área de nets (µm²) | — (zero wireload) | — | | 3.318,5 | 3.020,0 | −9,0% |
| Área total (µm²) | 2.808,2 | 2.694,4 | **−4,1%** | 12.519,3 | 11.649,3 | **−6,9%** |
| Fanout médio | 3,0 | 2,9 | | 2,6 | 2,6 | |
| Tempo de síntese | 43 s | 44 s | | 37 s | 39 s | |

Os registradores dominam a área: cerca de 62% nas duas implementações. A diferença
de área está quase toda na lógica combinacional. O MR tem 21% menos células
combinacionais em TSMC28, mas só 5% menos área combinacional. Isso indica que o MG
usa mais células pequenas (os prefixos Kogge-Stone e a decodificação distribuída),
e o MR usa menos células, porém maiores.

### 5.2 Potência (estimativa do Genus, sem vetores de atividade)

| Potência (µW) | MG TSMC28 | MR TSMC28 | Δ MR | MG GPDK45 | MR GPDK45 | Δ MR |
|---|---|---|---|---|---|---|
| Fuga (leakage) | 20,3 | 18,7 | −7,5% | 0,50 | 0,47 | −5,0% |
| Interna | 424,0 | 413,0 | −2,6% | 1.000,4 | 917,4 | −8,3% |
| Chaveamento | 85,1 | 68,4 | −19,6% | 309,6 | 260,2 | −15,9% |
| **Total** | **529,4** | **500,1** | **−5,5%** | **1.310,5** | **1.178,1** | **−10,1%** |
| Registradores | 405,6 | 405,9 | 0% | 978,0 | 908,2 | −7,1% |
| Lógica | 82,1 | 54,8 | −33,3% | 263,9 | 202,8 | −23,2% |
| Clock | 41,6 | 39,4 | −5,3% | 68,6 | 67,1 | −2,2% |

As estimativas usam a atividade padrão do Genus, não a de uma simulação, e servem
só para comparação relativa. A economia do MR vem da lógica combinacional, que
chaveia menos. A potência dos registradores e do clock é praticamente a mesma,
porque as duas têm os mesmos 706 flops.

### 5.3 Slack

| Métrica | MG TSMC28 | MR TSMC28 | MG GPDK45 | MR GPDK45 |
|---|---|---|---|---|
| Violações de setup (TNS) | 0 (0) | 0 (0) | 0 (0) | 0 (0) |
| Pior slack (WNS) | +5.470 ps | +3.153 ps | +2.612 ps | +980 ps |
| Endpoint do pior slack | `pslverr_o` | `prdata_o[1]` | `prdata_o[0]` | `prdata_o[*]` (8 empatadas) |
| Melhor slack | +9.753 ps | +9.442 ps | +9.608 ps | +9.304 ps |
| Endpoints com restrição | 1.949 | 1.734 | 1.336 | 1.168 |
| Slack médio / mediano | 9.100 / 9.505 ps | 8.734 / 9.223 ps | 6.789 / 7.090 ps | 6.808 / 7.152 ps |

Distribuição dos endpoints por slack:

| Faixa de slack | MG TSMC28 | MR TSMC28 | MG GPDK45 | MR GPDK45 |
|---|---|---|---|---|
| < 2 ns | 0 | 0 | 0 | 37 |
| 2–5 ns | 0 | 33 | 303 | 184 |
| 5–8 ns | 410 | 240 | 667 | 637 |
| ≥ 8 ns | 1.539 | 1.461 | 366 | 310 |

Os dois endpoints sem restrição em cada síntese (o primeiro flop do sincronizador de
reset e `pready_o`, constante 1) ficaram fora da conta. Os slacks extremos e a
distribuição vêm do slack de cada endpoint nos bancos `.db`. Os relatórios
`timing_max` só listam os 100 piores caminhos.

### 5.4 Timing por tipo de caminho

Pior caminho de cada tipo, reportado nos bancos `.db`. "Atraso" é o atraso do
caminho de dados, sem os orçamentos de I/O do SDC; "células" é o número de células
no caminho.

**TSMC28**

| Tipo | MG: slack / atraso / células | MR: slack / atraso / células | Caminho MG | Caminho MR |
|---|---|---|---|---|
| reg → reg (núcleo) | +8.656 / **1.114** ps / 65 | +7.942 / **1.547** ps / 66 | `rsa_core_mult/p_reg[1]` → `p_reg[63]` | `rsa_core_mod/t_reg[0]` → `t_reg[63]` |
| entrada → reg | +7.338 / 429 ps / 18 | +6.203 / 232 ps / 6 | `paddr_i[6]` → `regbank/exp_reg[18]` | `psel_i` → `u_regs/result_reg[31]` |
| reg → saída | +7.510 / 290 ps / 12 | +6.192 / 308 ps / 5 | `reset_sync_reg[1]` → `pslverr_o` | `u_seq/state_reg[0]` → `pslverr_o` |
| entrada → saída | +5.470 / 330 ps / 18 | +3.153 / 347 ps / 6 | `paddr_i[6]` → `pslverr_o` | `psel_i` → `prdata_o[1]` |

**GPDK45**

| Tipo | MG: slack / atraso / células | MR: slack / atraso / células | Caminho MG | Caminho MR |
|---|---|---|---|---|
| reg → reg (núcleo) | +3.286 / **6.395** ps / 65 | +1.498 / **7.956** ps / 66 | `rsa_core_mult/p_reg[0]` → `p_reg[63]` | `rsa_core_mod/t_reg[0]` → `t_reg[63]` |
| entrada → reg | +3.428 / 4.307 ps / 15 | +4.378 / 2.128 ps / 7 | `paddr_i[5]` → `regbank/msg_reg[13]` | `paddr_i[6]` → `u_regs/mod_reg[31]` |
| reg → saída | +5.311 / 2.489 ps / 11 | +5.138 / 1.362 ps / 3 | `reset_sync_reg[1]` → `pslverr_o` | `u_regs/exp_reg[9]` → `prdata_o[9]` |
| entrada → saída | +2.612 / 3.188 ps / 14 | +980 / 2.520 ps / 8 | `paddr_i[5]` → `prdata_o[0]` | `paddr_i[11]` → `prdata_o[9]` |

Leitura dos resultados:

- **Núcleo (reg → reg):** o MG é 28% (TSMC28) e 20% (GPDK45) mais rápido. O
  Kogge-Stone explícito encurta a soma de 64 bits do multiplicador. No MR, o caminho
  crítico passa para a subtração de 64 bits do bloco de módulo.
- **Interface APB:** o MR é mais rasa, com 3 a 8 células contra 11 a 18 do MG, e
  mais rápida nos caminhos que terminam em registrador ou que partem dele. Nos
  caminhos de entrada a saída em TSMC28 os atrasos se igualam, porque cerca de
  150 ps do atraso do MR vêm da carga de 50 fF que só o SDC dele define.
- **Slack versus atraso:** o pior slack do MR é menor mesmo com caminhos de
  interface mais curtos. Isso acontece porque o SDC do MR reserva 6 ns de I/O e
  0,5 ns de incerteza, contra 4 ns e 0,2 ns no MG (seção 6).

### 5.5 Frequência indicativa

| | MG TSMC28 | MR TSMC28 | MG GPDK45 | MR GPDK45 |
|---|---|---|---|---|
| Atraso + setup do núcleo | 1.144 ps | 1.558 ps | 6.514 ps | 8.002 ps |
| Frequência pelo núcleo | ~874 MHz | ~642 MHz | ~154 MHz | ~125 MHz |

Esses valores não incluem incerteza nem os caminhos de I/O. Como as sínteses foram
feitas a 100 MHz, com folga, o Genus não otimizou além do necessário. A frequência
máxima real exige ressintetizar as duas com o mesmo SDC e reduzir o período até
surgir violação.

### 5.6 Hold

Hold não foi analisado na síntese: o `report_timing` do Genus 22.1 não tem modo
`-early`, e o clock é ideal antes do CTS. O único dado de hold real é do MG, num
P&R arquivado de 23/10 (GPDK45, anterior ao RTL atual): WNS de hold +0,095 ns e de
setup +3,38 ns, sem violações em 1.306 caminhos. O MR nunca passou pelo Innovus.

## 6. Restrições (SDC)

| | MG (`constraints/MG/amba_3_apb_rsa_apb_top.sdc`) | MR (`constraints/MR/rsa_apb.sdc`) |
|---|---|---|
| Clock | `pclk_i`, 10 ns | `PCLK`, `CLK_PERIOD` (padrão 10 ns) |
| Incerteza | 0,2 ns (setup) | 5% do período (0,5 ns) |
| Transição do clock | — | 0,1 ns |
| Atraso de entrada | 2,0 ns máx. / 0 ns mín. | 30% do período (3 ns), também em `presetn_i` |
| Atraso de saída | 2,0 ns máx. / 0 ns mín. | 30% do período (3 ns) |
| Carga nas saídas | — | 50 fF |

Por causa dessas diferenças, os slacks das duas sínteses não são diretamente
comparáveis. Uma comparação justa de frequência exige sintetizar as duas com o
mesmo SDC.

## 7. Simulação pós-síntese com SDF (TSMC28)

Com a mesma bancada (`testbenchs/rsa_apb_top/testbench.sv`):

| | MG | MR |
|---|---|---|
| Resultado | TEST PASS, 398 checks | TEST PASS, 398 checks |
| Violações de setup/hold | 0 | 0 |
| Atrasos de caminho anotados | 100% (14.871) | 100% (15.852) |
| Avisos `*W,NTCNNC` na elaboração | 132 flops (quase só no `regbank`) | 559 flops (registradores largos do núcleo) |

Os `NTCNNC` são avisos de elaboração: os tempos negativos de setup/hold de certas
células não convergiram e foram trocados por 0, o que deixa a checagem mais
conservadora. Não são violações. A diferença na contagem reflete as células que o
Genus escolheu em cada implementação.

## 8. Bancadas dirigidas

| | `testbench.sv` (MG) | `rsa_apb_tb.sv` (MR) |
|---|---|---|
| Top / instância | `testbench` / `testbench.dut` | `tb` / `tb.dut` |
| Checagens | 398 | 2.236 |
| Borda de estímulo APB | descida (longe da amostragem do DUT) | subida, sem atraso |
| Netlist (`POST_SYNTHESIS`) | suportado | suportado (adicionado em 10/11) |
| Clock parametrizável | `CLOCK_PERIOD_NS` | `CLOCK_PERIOD_NS` (adicionado em 10/11) |
| Mensagem de aprovação | `TEST PASS: N checks, 0 errors` | `PASS: N checks` |
| Ondas | `+VCD=` | gravadas pelo simulador (SHM) |

O `rsa_apb_tb.sv` passa no RTL do MR (2.236 checks). Na netlist com SDF, porém, gera
332 violações de setup/hold e termina em `FAIL: watchdog`. A causa está no próprio
TB: nas escritas consecutivas com `PSEL` mantido alto, ele troca endereço e dado na
mesma borda que captura a escrita anterior, desrespeitando o atraso de entrada de
3 ns do SDC. Com o `testbench.sv` a mesma netlist fica limpa. Por isso o fluxo
`scripts/MR/bash/xrun_ps_tsmc28.sh` usa o `testbench.sv`.

## 9. Verificação UVM (seed 1, campanha completa)

| | MG | MR |
|---|---|---|
| rsa_operation / soft_reset / test_id | PASS | PASS |
| corners_exp | 12/12 | 12/12 |
| xz_values | 0 falhas | 97.536 falhas (`PSLVERR` reservado) |
| Cobertura de código | 84,70% (3.730/4.404) | 96,13% (1.961/2.040) |
| Cobertura de FSM | 82,72% (67/81) | 85,19% (69/81) |
| Tempo de execução | 46 s | 13 s |

As percentagens de cobertura não são comparáveis diretamente, porque o MG tem 2,2
vezes mais itens de código, a maior parte toggle dos somadores Kogge-Stone. O
detalhamento completo está em `UVM/comparativo_uvm_MG_MR.md`.

## 10. Pontos em aberto

1. **Regra de `PSLVERR` para endereços reservados:** decidir entre o comportamento
   do MG (erro) e o da especificação seção 6.7, seguida pelo MR (sem erro). Depois,
   ajustar o RTL divergente ou a bancada UVM.
2. **`rsa_apb_tb.sv` na netlist:** atrasar o estímulo APB quando `POST_SYNTHESIS`
   estiver definido (por exemplo, 30% do período, como no SDC) para que o TB do MR
   também valide a netlist.
3. **Comparação de frequência:** sintetizar as duas com o mesmo SDC e varrer o período.
4. **Hold real:** rodar o Innovus para as duas em GPDK45 (`innovus_full_flow.sh`).
   O MR nunca passou por P&R, e o dado do MG é anterior ao RTL atual.
