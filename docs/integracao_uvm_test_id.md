# Integracao do teste de ID

Origem: branch [FEAT-UVM-MILENA-3-test_id](https://github.com/TCHE-MOS/RSA32_APB/tree/FEAT-UVM-MILENA-3-test_id),
commit `4a268df401286b451da100880b18bff7d275323b`. Foram importados
`UVM/uvm_sequence_test_id.sv` e `UVM/assertions/test_id_sva.sv`, com as
adaptacoes de integracao descritas abaixo.

## Execucao

O fluxo padrao agora executa, aguardando cada sequence terminar:

```text
rsa_operation -> soft_reset -> test_id -> corners_exp -> xz_values
```

Na raiz do projeto:

```bash
./scripts/MG/bash/xezim_uvm.sh
./scripts/MG/bash/xezim_uvm.sh -- +TEST_ID_ONLY=1
```

O segundo comando executa somente o teste de ID. Ele nao executa operacoes
RSA nem a campanha X/Z. `+TEST_ID_ONLY=1` e `+XZ_VALUES_ONLY=1` sao mutuamente
exclusivos. O script rejeita a combinacao antes de iniciar o simulador.
Os scripts Xrun recebem os mesmos plusargs atraves da virtual sequence.

## Estimulo e conexoes

`sequence_test_id` continua derivada de `apb_base_sequence` e realiza:

1. READ em `ID_ADDR` (`0x01C`).
2. WRITE de `0xFFFF_FFFF` no mesmo endereco.
3. READ do ID novamente.

O package de sequences inclui a classe; `assertions.svh` inclui o checker;
`top_th` instancia `test_id_sva`. A virtual sequence controla
`sva_test_id_active` somente durante esse cenario. O parametro compartilhado
`EXPECTED_ID_VALUE = 32'h5253_0200` alimenta o checker especifico e o checker
APB geral.

O scoreboard registra o grupo `test_id`, conta suas tres transferencias e
imprime a resposta da escrita como PASS quando `PSLVERR=1`: essa rejeicao e
esperada para um registrador somente leitura. `ID_OBSERVATION` mostra o ID
antes/depois, o dado enviado, o valor esperado e as respostas R/W/R.

## Assertions integradas

| Identificador | Verificacao |
| --- | --- |
| ID_SCENARIO_RUN | Ordem READ -> WRITE 0xFFFFFFFF -> READ e conclusao do cenario. |
| ID_READ_RESPONSE | Leitura responde com PSLVERR=0. |
| ID_READ_KNOWN | ID conhecido e igual a EXPECTED_ID_VALUE. |
| ID_READ_STABLE | Leitura posterior repete o ID observado antes da escrita. |
| ID_WRITE_RESPONSE | Tentativa de escrita responde com PSLVERR=1. |

As quatro linhas originais foram mantidas. `ID_WRITE_RESPONSE` foi acrescentada
para conferir explicitamente a rejeicao da escrita. A cobertura da ordem foi
acompanhada de uma assertion forte: omitir um passo ou mudar o dado exigido
agora gera erro, em vez de deixar apenas uma cobertura sem resultado.

A referencia da primeira leitura e descartada fora da janela de ID, para
que leituras feitas por outros testes nao a inicializem. O checker usa o
endereco de palavra, acompanhando os aliases de byte ja aceitos pelo slave.
A checagem geral de exclusividade inclui os cinco contextos: operacao RSA,
soft reset, ID, corners EXP e observacao X/Z. Depois de encerrar a janela
de ID, a virtual sequence aguarda um ciclo para amostrar seu fechamento
antes de emitir o resultado.

## Validacao

O teste isolado concluiu em 200 ns simulados, com tres transferencias,
cinco verificacoes de ID em PASS e zero UVM_ERROR/UVM_FATAL. Foram conferidos
o valor `0x52530200` antes/depois e a resposta `PSLVERR R/W/R=0/1/0`.
O [log completo](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_18-24-18_rc2U1e/simulate.log)
e o [relatorio HTML](../reports/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_18-24-18_rc2U1e/index.html)
registram essa execucao com seed 1.

Foram exercitados nove casos dirigidos do checker sobre a interface APB:
caso nominal, ID alterado, ID desconhecido, erro de leitura, escrita aceita
indevidamente, cenario com dado de escrita incorreto/incompleto, conflito de
enables, checker desativado e leitura por alias de byte. As falhas injetadas
foram detectadas pelos identificadores esperados; os casos nominal e alias
concluiram sem falha; o checker de ID nao contou resultados quando desativado.

Tambem foram conferidos o calculo do watchdog, a selecao isolada com cotas
EXP zeradas e a rejeicao de selecoes conflitantes ou invalidas.

A regressao encadeada foi executada com:

```bash
./scripts/MG/bash/xezim_uvm.sh --no-waves -- +CORNERS_CASES=1
```

O [log da integracao](../logs/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_18-24-42_n7nzXX/simulate.log)
e o [relatorio HTML](../reports/amba_3_apb_rsa_apb_top/xezim_uvm/2026-11-08_18-24-42_n7nzXX/index.html)
registram codigo de saida zero, zero UVM_ERROR/UVM_FATAL e o fluxo completo
RSA -> soft reset -> ID -> um corner EXP de 4 bits -> oito rotinas X/Z.
O tempo simulado foi 3,621460 ms; o tempo real do Xezim foi 803,486 s.

A auditoria confirmou as 32768 linhas de endereco, 32 leituras de retencao
e 98381 transferencias da campanha X/Z. As contagens de ID permaneceram
iguais as do teste isolado: duas leituras verificadas, uma verificacao de
estabilidade, uma rejeicao de escrita e um cenario completo. Portanto,
nenhum acesso dos outros cenarios foi contabilizado nas assertions de ID.
