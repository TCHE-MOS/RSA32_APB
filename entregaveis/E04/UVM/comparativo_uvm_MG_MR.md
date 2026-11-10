# Comparativo da campanha UVM: RTL MG × RTL MR

Execução da bancada UVM completa (`top_tb`) sobre as duas implementações de
`amba_3_apb_rsa_apb_top`, em 2026-11-10, com Xcelium 24.03-s013.

## Resumo

| | MG | MR |
|---|---|---|
| RTL | `src/MG/rsa32/v2` + `src/MG/amba_3_apb` (15 arquivos) | `src/MR/RSA_APB` (2 arquivos) |
| `rsa_operation` | PASS | PASS |
| `soft_reset` | PASS | PASS |
| `test_id` | PASS | PASS |
| `corners_exp` (12 casos) | 12 PASS / 0 FAIL | 12 PASS / 0 FAIL |
| `xz_values` | 0 falhas de resposta | **97.536 falhas de resposta** |
| SVA | 63 PASS, 0 FAIL, 1 não exercitada | 63 PASS, 0 FAIL, 1 não exercitada |
| `UVM_ERROR` / `UVM_FATAL` | 0 / 0 | 97.536 / 0 |
| Veredito da UVM | **Aprovado** | **Reprovado**, somente em `xz_values` |

As duas versões têm o mesmo comportamento funcional em todos os cenários,
exceto em um: **o MR não sinaliza `PSLVERR` em acessos a endereços
reservados (0x020–0xFFF)**, e a bancada exige isso. Na
[especificação](#divergência-com-a-especificação), esse requisito não aparece
na lista de condições de `PSLVERR` (seção 6.7).

## Condições de execução

As duas campanhas usaram o mesmo lançador (`scripts/MG|MR/bash/xrun_uvm_nogui.sh`),
na configuração padrão e uma após a outra:

| Parâmetro | Valor |
|---|---|
| Teste | `test_rsa_operation` |
| Seed (`-svseed`) | 1 |
| Verbosidade | `UVM_MEDIUM` |
| Sequences | rsa_operation → soft_reset → test_id → corners_exp → xz_values |
| Watchdog UVM (automático) | 236.427.090 ns |
| Bancada | `UVM/testbench.svh` (a mesma nas duas execuções) |

```bash
source ~/setup_env.sh          # alias "setup"
./scripts/MG/bash/xrun_uvm_nogui.sh
./scripts/MR/bash/xrun_uvm_nogui.sh
```

As duas versões têm portas idênticas. A bancada só sobrescreve `LOAD_GAP`, que
existe nas duas, e não acessa sinais internos do DUT. Por isso foi possível
usar a mesma UVM sem nenhuma modificação.

## Resultados por sequence

### rsa_operation, soft_reset e test_id

| Sequence | MG | MR |
|---|---|---|
| rsa_operation | PASS, 10.616 transações, resultado `0x07c5db67` correto | PASS, 10.617 transações, resultado `0x07c5db67` correto |
| soft_reset | PASS, 7 transações | PASS, 7 transações |
| test_id | PASS, ID `0x52530200` preservado; PSLVERR R/W/R = 0/1/0 | idem |

O MR conclui a primeira operação RSA 30 ns depois do MG (318.605 ns contra
318.575 ns). Essa diferença equivale a uma leitura de polling a mais e
desloca em +30 ns todos os instantes posteriores da campanha.

### corners_exp

Duração dos 12 casos, todos `VALID_OPERATION`:

| Caso | EXP | MG (ns) | MR (ns) |
|---|---|---|---|
| 1 | 4 bits | 10.280 | 10.280 |
| 2 | 8 bits | 157.570 | 157.570 |
| 3 | 12 bits | 1.728.050 | 1.728.050 |
| 4 | 16 bits | 3.651.250 | 3.651.250 |
| 5 | 4 bits | 7.430 | 7.430 |
| 6 | 8 bits | 62.720 | 62.720 |
| 7 | 4 bits | 3.440 | 3.440 |
| 8 | 8 bits | 145.980 | 145.980 |
| 9 | 4 bits | 6.290 | 6.290 |
| 10 | 8 bits | 54.170 | 54.170 |
| 11 | 4 bits | 10.280 | 10.280 |
| 12 | 8 bits | 47.140 | 47.140 |

As durações são idênticas em todos os casos, e a latência medida por
polling é a mesma nas duas versões.

### xz_values

São 8 padrões (ALL_X, ALL_Z, BIT_XZ, BIT_ZX, NIBBLE_XZ, NIBBLE_ZX, BYTE_XZ e
BYTE_ZX) aplicados aos 4.096 endereços, com 98.381 transações em cada versão.

| | MG | MR |
|---|---|---|
| Linhas `XZ_ROW` | 32.768 | 32.768 |
| Linhas idênticas, ignorando o instante e a coluna `PSLVERR R/W/R` | 32.768 | 32.768 |
| Registradores alterados por padrão | 4 | 4 |
| Leituras com X/Z (por padrão) | iguais | iguais |
| `PSLVERR R/W/R` em endereço reservado | **1/1/1** | **0/0/0** |
| `PSLVERR R/W/R` em RESULT e ID | 0/1/0 | 0/1/0 |
| `PSLVERR R/W/R` nos demais registradores | 0/0/0 | 0/0/0 |
| Falhas de resposta | 0 | 97.536 |

O tratamento de dados X/Z é o mesmo nas duas versões: os mesmos valores
antes e depois de cada escrita, a mesma retenção de IER, MSG, EXP e MOD e a
mesma classificação PRESERVADO/ALTERADO. A única diferença é a resposta de
erro nos endereços reservados. A conta das falhas fecha: 4.064 endereços
reservados × 8 padrões × 3 transações (leitura, escrita, leitura) = 97.536
`UVM_ERROR [XZ_RESPONSE]`, todos com `PSLVERR=0 esperado=1`.

### Asserções SVA

As tabelas finais das duas execuções têm as mesmas 64 asserções, com o mesmo
estado:

- 63 PASS e 0 FAIL nas duas versões.
- `APB_WAIT_HOLD` não é exercitada em nenhuma das duas, porque `PREADY` é
  fixo em 1.
- As contagens diferem em 1 a 3 avaliações em algumas asserções APB
  (`APB_SETUP_ACCESS`, `APB_KNOWN_PHASE` etc.), por causa da leitura de
  polling a mais no MR.

As 33.024 mensagens `*E,ASRTST` de `ap_known_write_data` (32.768) e
`ap_known_read_data` (256) aparecem iguais nas duas execuções. Elas vêm do
estímulo X/Z intencional e o log as classifica como
`[XZ][OBSERVACAO_NOMINAL]`, fora do critério PASS/FAIL. Elas também fazem o
`xrun` retornar código diferente de 0, por isso o lançador do MG termina com
status 1 mesmo com 0 `UVM_ERROR`. É o mesmo comportamento das execuções
anteriores do MG.

## Cobertura (IMC, cumulativa no DUT)

| Métrica | MG | MR |
|---|---|---|
| Código (total) | 84,70% (3730/4404) | 96,13% (1961/2040) |
| Block | 88,58% (194/219) | 91,01% (162/178) |
| Expression | 96,67% (29/30) | 100,00% (18/18) |
| Toggle | 84,40% (3507/4155) | 96,58% (1781/1844) |
| FSM | 82,72% (67/81) | 85,19% (69/81) |
| Covergroups (UVM) | 100,00% (2/2) | 100,00% (2/2) |

A bancada e os estímulos são os mesmos, mas as percentagens não medem a
mesma coisa, porque os dois RTLs têm estruturas diferentes. O MG tem 2,2
vezes mais itens de código, a maior parte toggle dos somadores Kogge-Stone
do núcleo v2 e do datapath APB em vários blocos. Os FSMs do núcleo
`rsa_core` têm a mesma cobertura nas duas versões (53/65), porque os dois
derivam do mesmo `rsa_core` de referência. A diferença no FSM total
(67 × 69 de 81) vem das máquinas do wrapper APB.

## Desempenho da simulação

| | MG | MR |
|---|---|---|
| Tempo simulado | 9.482.630 ns | 9.482.660 ns |
| Tempo de parede do `xrun` (compilação + simulação) | 43 s | 10 s |
| Tempo de parede total (com IMC) | 46 s | 13 s |
| Tamanho do log | 20,6 MB | 40,4 MB (por causa dos `UVM_ERROR`) |

Com o mesmo tempo simulado, o MR roda cerca de 4 vezes mais rápido. Ele
tem menos lógica para simular (2.040 contra 4.404 itens de código).

## Divergência com a especificação

`docs/apb_integration.pdf` diz:

- **Seção 5:** "Offsets 0x20 to 0xFFC are reserved."
- **Seção 6.7, condições de PSLVERR:** "PSLVERR is asserted in the access
  phase, and the transfer has no effect, when any of these is true:
  a write targets RESULT or ID; a write to CTRL with START = 1, or to MSG,
  EXP or MOD, occurs while BUSY = 1."

A lista da seção 6.7 não inclui acessos a endereços reservados. O RTL do MR
implementa exatamente essa lista (`ro_write || busy_write` em `rsa_apb_regs`).
O MG e a bancada (`check_response` em `UVM/uvm_sequence_xz_values.sv`,
descrito em `docs/teste_uvm_xz_values.md`) acrescentam uma regra:
`addr >= 0x020` gera erro em leitura e escrita.

A reprovação do MR em `xz_values` vem dessa regra adicional, não de um
desvio da especificação. A equipe precisa definir qual comportamento vale:

1. **PSLVERR em endereços reservados é requisito do projeto:** registrar a
   regra no plano de verificação como extensão da seção 6.7 e corrigir o
   decodificador do MR.
2. **Vale só a seção 6.7:** tornar a regra configurável na bancada, ou
   restringi-la a RESULT e ID e a escritas com BUSY, e revisar o MG, que
   então sinaliza erros não previstos na especificação.

## Artefatos

| | MG | MR |
|---|---|---|
| Log | `logs/amba_3_apb_rsa_apb_top/xrun_uvm/nogui/amba_3_apb_rsa_apb_top_uvm_2026-11-10_09-18-25.log` | `logs/MR/amba_3_apb_rsa_apb_top/xrun_uvm/nogui/amba_3_apb_rsa_apb_top_uvm_2026-11-10_09-19-11.log` |
| Cobertura | `coverage/amba_3_apb_rsa_apb_top/uvm/scope/amba_3_apb_rsa_apb_top_uvm_2026-11-10_09-18-25` | `coverage/MR/amba_3_apb_rsa_apb_top/uvm/scope/amba_3_apb_rsa_apb_top_uvm_2026-11-10_09-19-11` |
| Relatórios IMC | `reports/amba_3_apb_rsa_apb_top_rtl/imc/amba_3_apb_rsa_apb_top_2026-11-10_09-19-08_125877943_rtl/` | `reports/MR/amba_3_apb_rsa_apb_top_rtl/imc/amba_3_apb_rsa_apb_top_2026-11-10_09-19-21_917287806_rtl/` |
| Ondas | `waveforms/amba_3_apb_rsa_apb_top/uvm/amba_3_apb_rsa_apb_top_uvm_2026-11-10_09-18-25.{shm,vcd}` | `waveforms/MR/amba_3_apb_rsa_apb_top/uvm/amba_3_apb_rsa_apb_top_uvm_2026-11-10_09-19-11.{shm,vcd}` |
