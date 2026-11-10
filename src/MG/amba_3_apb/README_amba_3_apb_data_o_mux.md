# `amba_3_apb_data_o_mux` — Multiplexador de leitura

**Projeto:** RSA_APB · **Fonte analisada:** `amba_3_apb_data_o_mux.sv`  
**Estado:** lógica combinacional descrita; não validada por simulação/síntese.

## 1. Objetivo

Selecionar o conteúdo de um dos registradores legíveis do `regbank`, a partir do índice reduzido de endereço `paddr_i[3:0]`. CTRL, embora possua endereço, é um registrador de comando **WO** e por isso a seleção CTRL retorna `'0`.

Este módulo **não recebe endereço APB completo**, não valida janela, não interpreta fases APB, não gera `PSLVERR` e não implementa registradores físicos.

## 2. Entradas e saída

| Porta | Direção | Largura | Origem ou destino |
|---|---|---|---|
| `paddr_i` | Entrada | 4 | Índice reduzido vindo de `data_io_top`. |
| `op_sts_i` | Entrada | `DATA_WIDTH` | STATUS do regbank. |
| `op_ier_i` | Entrada | `DATA_WIDTH` | IER do regbank. |
| `op_msg_i` | Entrada | `DATA_WIDTH` | MSG do regbank. |
| `op_exp_i` | Entrada | `DATA_WIDTH` | EXP do regbank. |
| `op_mod_i` | Entrada | `DATA_WIDTH` | MOD do regbank. |
| `op_res_i` | Entrada | `DATA_WIDTH` | RESULT do regbank. |
| `op_idr_i` | Entrada | `DATA_WIDTH` | ID do regbank. |
| `prdata_o` | Saída | `DATA_WIDTH` | Dado escolhido para o `data_io_top`. |

Parâmetros públicos: `DATA_WIDTH = 32` e `D_WID = DATA_WIDTH - 1`.

## 3. Decodificação do endereço

| Código | Nome | Saída de leitura |
|---|---|---|
| `0000` | CTRL | `'0` |
| `0001` | STATUS | `op_sts_i` |
| `0010` | IER | `op_ier_i` |
| `0011` | MSG | `op_msg_i` |
| `0100` | EXP | `op_exp_i` |
| `0101` | MOD | `op_mod_i` |
| `0110` | RESULT | `op_res_i` |
| `0111` | ID | `op_idr_i` |
| `1000` a `1111` | Não mapeado | `INVALID_DATA` |

A codificação interna coincide com as constantes utilizadas em `apb_control` e `regbank`. Essa duplicação é nominal: **o MUX usa seu próprio conjunto de constantes locais**.

## 4. Implementação combinacional

O RTL utiliza `always_comb`, com `case (paddr_i)` e atribuição a `prdata_o` para cada possibilidade (inclusive `default`). Como nenhuma condição deixa a saída sem valor, não há necessidade de retenção e não se pretende inferir latch.

```systemverilog
CTRL_R:    prdata_o = '0;
STATUS_R:  prdata_o = op_sts_i;
// ...
ID_R:      prdata_o = op_idr_i;
default:   prdata_o = INVALID_DATA;
```

`INVALID_DATA` tem o valor literal `32'h0000_000F`. É um valor **escolhido pela implementação**, não um código de erro imposto pelo protocolo APB ou pelo mapa de registradores.

## 5. Exemplo de leitura

Considere `op_msg_i = 32'h1234_ABCD` e índice reduzido `0011`. O MUX retorna esse valor combinacionalmente. Se o endereço completo fosse `0x04C`, o índice reduzido também corresponderia a MSG, mas **`data_io_top` mascara a saída com zero** porque esse endereço está fora da janela implementada.

Dessa forma existem duas validações distintas:

1. `data_o_mux`: seleção **pelo índice**.
2. `data_io_top`: validação **da faixa do endereço completo** e mascaramento final.

O `apb_control` é o bloco que produz `PSLVERR` na transferência inválida.

## 6. Por que não há entrada CTRL?

CTRL é um registrador **write-only** de comandos START e SRST; sua leitura deve ser zero. Não há necessidade de armazenar/encaminhar um `op_ctl_i` para a lógica de seleção. O tratamento é feito diretamente no `case`.

Os bits reservados de STATUS e IER também já são forçados a zero pelo `regbank`, portanto o MUX não precisa aplicar máscaras adicionais a esses campos.

## 7. Propriedades de implementação

- Sem clock e sem reset.
- Sem flip-flops ou lógica de escrita.
- Barramento de saída determinado unicamente pelo índice e pelas sete entradas de dados.
- Valor `'0` apropriado para leitura de CTRL; não se utiliza `'Z`.
- Possível inferência de lógica de seleção combinacional pela síntese.

## 8. Limitações e pendências

- `INVALID_DATA` é definido como literal de 32 bits mesmo quando `DATA_WIDTH` é parametrizável; parametrizações diferentes de 32 bits podem truncar ou estender o literal.
- Índices inválidos geram `0xF` **dentro deste módulo**, mas o `data_io_top` entrega zero se o endereço completo for inválido. Distinguir os dois níveis ao depurar.
- Não há qualificação por fase APB; PRDATA só é consumido pela interface nos momentos válidos do protocolo.
- A integração antiga do `rsa_apb_top.sv` ainda referencia `op_ctl_i`; essa porta já não existe.
- Nenhuma verificação de compilação, lint, simulação ou síntese foi executada para validar as hipóteses descritas.

## 9. Resumo operacional

O MUX é uma tabela de seleção de leitura entre sete registradores físicos/lógicos e o zero de CTRL. Recebe `paddr_i[3:0]` já reduzido, produz `prdata_o` combinacionalmente e deixa a validação de região/endereço e a sinalização de erro para os blocos externos.

## 10. Diagrama de leitura

```mermaid
flowchart LR
    ADDR["Índice paddr_i de 4 bits"] --> MUX["Seleção combinacional"]
    REGS["STATUS, IER, MSG, EXP\nMOD, RESULT, ID"] --> MUX
    ZERO["CTRL: zero"] --> MUX
    INVALID["Índice não mapeado: 0xF"] --> MUX
    MUX --> DATA["prdata_o"]
```
