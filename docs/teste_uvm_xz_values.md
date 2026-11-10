# Corner de dados X/Z no regbank

`sequence_xz_values`, derivada de `apb_base_sequence`, encapsula a campanha.
A virtual sequence a executa depois de `rsa_operation`, `soft_reset`,
`test_id` e `corners_exp`. Para desenvolver este corner sem executar os testes RSA:

```bash
./scripts/MG/bash/xezim_uvm.sh -- +XZ_VALUES_ONLY=1
```

O mesmo plusarg funciona nos scripts Xrun UVM. O fluxo Xezim inclui a campanha
no calculo do watchdog, tanto no modo isolado quanto na execucao completa.

A rotina nao envia START, nao calcula referencia modular, nao espera DONE
e nao prepara operandos para tentar atingir o RSA. Ela escreve dados invalidos
em todos os enderecos, inclusive CTRL, STATUS, RO e reservados. Os bits de
comando de CTRL recebem o proprio padrao X/Z, sem mascara; os efeitos
incidentais da propagacao sao parte da observacao.

## Varredura

Cada rotina percorre **todos os 4096 enderecos de byte**, de `0x000` a `0xFFF`,
com passo 1. Os oito registradores ocupam `0x000..0x01F`; seus aliases de byte
tambem sao exercitados, pois o slave ignora `PADDR[1:0]`. Os outros 4064
enderecos sao reservados. Os enderecos e os sinais de controle APB continuam
conhecidos; a injecao de X/Z ocorre exclusivamente em `PWDATA`.

| Ordem | Rotina | PWDATA, de bit 31 a bit 0 |
| --- | --- | --- |
| 1 | ALL_X | 32 bits X |
| 2 | ALL_Z | 32 bits Z |
| 3 | BIT_XZ | `xz` repetido 16 vezes |
| 4 | BIT_ZX | `zx` repetido 16 vezes |
| 5 | NIBBLE_XZ | `xxxxzzzz` repetido 4 vezes |
| 6 | NIBBLE_ZX | `zzzzxxxx` repetido 4 vezes |
| 7 | BYTE_XZ | `xxxxxxxxzzzzzzzz` repetido 2 vezes |
| 8 | BYTE_ZX | `zzzzzzzzxxxxxxxx` repetido 2 vezes |

Cada endereco recebe uma leitura anterior, uma escrita e uma leitura posterior,
com um ciclo adicional entre a escrita e a leitura posterior. Depois de todas
as escritas reservadas, a sequencia rele IER, MSG, EXP e MOD para observar a
retencao. Antes de cada rotina e no encerramento, escreve zero nesses quatro
registradores e W1C (`0x6`) em STATUS. Nao aplica reset entre as rotinas.

Sao **32768 exercitacoes de endereco e 98381 transferencias APB**:
`8 * (4096 * 3 + 5 + 4) + 5`. As contagens precisam estar completas para
a sequencia emitir `XZ_RESULT CONCLUIDO`.

## Logs e ondas

Os identificadores `XZ_BEGIN`, `XZ_TABLE`, `XZ_ROW`, `XZ_RETENTION`,
`XZ_SUMMARY` e `XZ_RESULT` ficam visiveis em `UVM_LOW`, inclusive na
verbosidade padrao. Cada linha de endereco mostra:

- instante em ns, rotina, endereco exato e nome do registrador;
- valores anterior, enviado e posterior com todos os 32 bits em binario;
- `PSLVERR` da leitura anterior, escrita e leitura posterior;
- quantidades de X e Z na leitura posterior;
- `PRESERVADO` ou `ALTERADO`, usando igualdade de quatro estados.

O resumo por rotina conta enderecos, reservados, alteracoes e leituras contendo
X/Z. Essas classificacoes descrevem o comportamento observado; nao declaram
que o DUT precisa armazenar ou rejeitar dados invalidos. O log detalhado do
monitor (`SEQ_DEBUG`) continua disponivel em `UVM_HIGH` neste cenario.

As ondas existentes incluem `xz_values_active`, `xz_pattern_id`, `xz_address`
e `xz_payload` na interface `top_tb.th.apb_rsa_if`. `xz_pattern_id` segue a
ordem da tabela, com indices 0 a 7. Os sinais servem somente para depuracao.

## Verificacao nesta etapa

Nao foram criadas nem alteradas propriedades SVA. A sequencia confere a
conclusao da varredura, a preservacao exata de X/Z em `PWDATA` depois de
`item_done` e a resposta APB: enderecos reservados geram erro em leitura e
escrita; RESULT e ID geram erro de escrita. As demais transferencias devem
terminar sem erro, partindo do regbank em repouso. O driver continua impondo
limite de espera por `PREADY`.

Somente durante o cenario `xz_values`, o scoreboard classifica as violacoes
das regras nominais `APB_KNOWN_WRITE_DATA` e `APB_KNOWN_READ_DATA` como
observacoes intencionais. As contagens aparecem separadamente no resumo
`[XZ][OBSERVACAO_NOMINAL]`, sem somar PASS ou FAIL das assertions. Todas as
outras regras SVA continuam ativas e reportam falhas normalmente. Fora desse
cenario, as duas regras de dados conhecidos tambem continuam gerando erro.

`apb_write` agora recebe `logic [31:0]` e atribui diretamente o dado dirigido,
evitando a conversao para `bit` e a tentativa de resolver X/Z por constraints.
Leituras dirigidas tambem dispensam randomizacao para atingir reservados.
O modo opcional de escrita aleatoria mantem a randomizacao de dados.

As SVAs especificas de comportamento com X/Z ficam para a proxima etapa,
depois da analise das observacoes desta campanha.

## Validacao e observacoes

Validado no Xezim 0.11.4, seed 1, em duas execucoes:

- [Campanha isolada](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_16-59-31_FaELaU/simulate.log):
  `+XZ_VALUES_ONLY=1`, com ondas FST.
- [Encadeamento](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_16-59-41_sxEY1i/simulate.log):
  `rsa_operation -> soft_reset -> corners_exp -> xz_values`, com
  `+CORNERS_CASES=1`. Os tres cenarios anteriores tambem passaram.

Cada campanha concluiu as oito rotinas, 32768 exercitacoes de endereco,
32 leituras de retencao e 98381 transferencias, sem UVM_ERROR/UVM_FATAL.
Uma auditoria dos logs conferiu a ordem e a unicidade dos 4096 enderecos em
cada rotina, os oito padroes enviados, as respostas R/W/R, as contagens de
X/Z e a classificacao PRESERVADO/ALTERADO de cada linha.

| Destino | Comportamento observado nas oito rotinas |
| --- | --- |
| CTRL e STATUS | Leitura zero; nao foi observada ativacao de BUSY, DONE ou ERROR nessas leituras. |
| IER | Retem os dois bits inferiores do padrao; bits reservados leem zero. |
| MSG, EXP e MOD | Retem os 32 bits do padrao, inclusive Z, apos os acessos reservados. |
| RESULT e ID | Escritas geram PSLVERR e preservam o valor anterior. |
| `0x020..0xFFF` | Leitura zero com PSLVERR; escritas tambem geram PSLVERR. |

As duas regras nominais de dados conhecidos registraram, separadamente,
65536 observacoes de escrita e 256 de leitura em cada campanha. Esses
numeros nao sao falhas SVA nem aprovacao funcional dos dados invalidos.

O ajuste final de impressao materializa o enum em uma variavel tipada antes
de chamar `name()`: nessa versao do Xezim, chamar `name()` diretamente em um
elemento de array pode imprimir nomes de outros enums importados. Os nomes
no XZ_BEGIN/XZ_ROW/XZ_RETENTION dos logs acima estao corretos; os nomes do
XZ_SUMMARY dessas execucoes precedem o ajuste. A correcao dos oito rotulos
foi validada separadamente, e a bancada final recompilou sem erros ou avisos.

Os relatorios [isolado](../reports/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_16-59-31_FaELaU/index.html)
e [encadeado](../reports/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_16-59-41_sxEY1i/index.html)
foram recuperados dos bancos e logs originais depois de uma edicao do script
durante sua execucao interromper somente o pos-processamento Bash. Os logs
e as ondas nao foram reescritos; o tempo real do wrapper ficou indisponivel.
