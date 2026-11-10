# Comparativo arquitetural: MG × MR

Comparação, em nível de blocos e de organização do RTL, entre as duas implementações
do coprocessador RSA de 32 bits com interface AMBA 3 APB (`amba_3_apb_rsa_apb_top`).

| | MG | MR |
|---|---|---|
| RTL | [`src/MG/amba_3_apb`](../src/MG/amba_3_apb) + [`src/MG/rsa32/v2`](../src/MG/rsa32/v2) | [`src/MR/RSA_APB`](../src/MR/RSA_APB) |
| Arquivos sintetizados | 15 (10 APB + 5 núcleo) | 2 (`rsa_apb_top.sv`, `rsa_core_32bits.sv`) |
| Módulos | 15 | 8 |
| Níveis de hierarquia abaixo do top | 4 (top → wrapper → `rsa_core` → `mult`/`mod`/`ctrl` → `kogge_stone_adder`) | 2 (top → `rsa_core` → `mult`/`mod`/`ctrl`) |

Este documento trata só da arquitetura. Os resultados de síntese, timing, potência,
SDF e UVM estão em [`comparativo_projeto_MG_MR.md`](comparativo_projeto_MG_MR.md).
As afirmações abaixo vêm da leitura do RTL; quando há confirmação em log, a fonte é
citada.

---

## 1. Visão geral dos blocos

As duas implementações têm as **mesmas portas no top** e o **mesmo núcleo
algorítmico** (FSMs `ctrl`/`mult`/`mod` com os mesmos estados). A diferença está em
como a interface APB e o sequenciador em volta do núcleo foram particionados.

### MG: um módulo por função

```
amba_3_apb_rsa_apb_top
├── amba_3_apb_data_io_top            caminho de endereço e de leitura
│   ├── amba_3_apb_adrec              paddr[5:2] → índice de 4 bits + addr_valid
│   └── amba_3_apb_data_o_mux         mux de PRDATA (case no índice)
├── amba_3_apb_control                decodificador de fase APB, PSLVERR, IRQ, write enables
├── amba_3_apb_regbank                armazenamento + STATUS + comandos START/SRST
├── amba_3_apb_reset                  sincronizador de reset (RESET_LATENCY) + OU com SRST
└── amba_3_apb_rsa_wrapper_top
    ├── amba_3_apb_rsa_wrapper_control   registrador de estado + contador de GAP
    ├── amba_3_apb_rsa_wrapper_data      decodificação do estado → core_load, core_din, busy
    └── rsa_core (v2)
        ├── rsa_core_ctrl  + kogge_stone_adder (32 b, decremento do expoente)
        ├── rsa_core_mult  + kogge_stone_adder (64 b, shift-add)
        └── rsa_core_mod   + kogge_stone_adder (64 b, subtração) + kogge_stone_adder (33 b, contador)
```

### MR: escravo APB monolítico + sequenciador

```
amba_3_apb_rsa_apb_top                 também contém: contador de SRST, core_hold e mux de operando
├── rsa_apb_rst_sync                  sincronizador de 2 flops
├── rsa_apb_regs                      escravo APB completo: decodificação, PSLVERR, registradores, PRDATA, IRQ
├── rsa_apb_seq                       FSM de START (com estado PREP) + contador de GAP
└── rsa_core                          núcleo de referência
    ├── rsa_core_ctrl
    ├── rsa_core_mult
    └── rsa_core_mod
```

### Correspondência entre os blocos

| Função | MG | MR |
|---|---|---|
| Decodificação de endereço | `amba_3_apb_adrec` | dentro de `rsa_apb_regs` (`word == W_x`) |
| Multiplexador de PRDATA | `amba_3_apb_data_o_mux` + gate em `data_io_top` | `always_comb` em `rsa_apb_regs` |
| Fase APB, PSLVERR, write enables | `amba_3_apb_control` | expressões `wr_acc`, `wr_ok`, `pslverr` em `rsa_apb_regs` |
| IRQ | `amba_3_apb_control` | `rsa_apb_regs` |
| Registradores e STATUS | `amba_3_apb_regbank` | `rsa_apb_regs` (um único `always_ff`) |
| Comandos START/SRST | `amba_3_apb_regbank` (combinacional) | `rsa_apb_regs` (`start_req`, `srst_req`) |
| Reset do núcleo | `amba_3_apb_reset` | `rsa_apb_rst_sync` + contador `srst_cnt` no top |
| Sequenciador de cargas | `wrapper_control` (estado) + `wrapper_data` (saídas) | `rsa_apb_seq` |
| Seleção do operando | `core_din_o` decodificado do estado em `wrapper_data` | `operand_sel` + mux no top |
| Somadores do núcleo | `kogge_stone_adder` explícito (4 instâncias) | operadores `+`/`-` (o Genus escolhe) |

---

## 2. Fase APB

- **MG** tem um decodificador de fase explícito (`IDLE`/`SETUP`/`ACCESS`, codificação
  de 4 bits) em `amba_3_apb_control`. É **combinacional**, não uma FSM registrada:
  a fase é recalculada a cada ciclo a partir de `psel` e `penable`.
- **MR** não nomeia fases: usa direto `wr_acc = psel && penable && pwrite`.

Nas duas, `PREADY = 1` fixo (sem wait states), o que explica `APB_WAIT_HOLD` não
exercitada na UVM.

---

## 3. Política de PSLVERR

| Condição | MG | MR |
|---|---|---|
| Endereço reservado (leitura ou escrita) | 1 | 0 |
| Escrita em RESULT/ID | 1 | 1 |
| Escrita em MSG/EXP/MOD com BUSY | 1 | 1 |
| Escrita de START com BUSY | **0**, START ignorado (pela leitura do RTL) | 1, sem efeito |
| Escrita de SRST com BUSY | 0, SRST executado (confirmado em log) | 0, SRST executado |

No MG, o ramo que trata CTRL ([control:131](../src/MG/amba_3_apb/amba_3_apb_control.sv#L131))
testa `ctrl_pwdata == 2'b10 && busy`, ou seja, **SRST** com BUSY, embora o comentário
diga "reject START while BUSY". Esse ramo não chega a disparar: o próprio SRST força
`rsa_rst` no mesmo ciclo ([reset:37](../src/MG/amba_3_apb/amba_3_apb_reset.sv#L37)),
e `wrapper_data` zera BUSY combinacionalmente quando `rsa_rst = 1`. A UVM confirma
PSLVERR = 0 para SRST com BUSY = 1 (`soft_reset`, transação 6, log
`xrun_uvm/nogui/…_2026-11-10_10-24-56.log`). START com BUSY é só descartado no
`regbank` (`start_o` exige `!rsa_wp_busy_i`,
[regbank:239](../src/MG/amba_3_apb/amba_3_apb_regbank.sv#L239)), sem PSLVERR.
Nenhuma bancada exercita START com BUSY, então essa linha da tabela ainda não foi
verificada em simulação. A tabela do §3.1 do
[`comparativo_projeto_MG_MR.md`](comparativo_projeto_MG_MR.md) dá PSLVERR = 1 para
as duas implementações nesse caso e precisa ser revista.
