# Fluxo Innovus para RSA32 v2

O Innovus implementa `amba_3_apb_rsa_apb_top` a partir da netlist mapeada
pelo Genus. Os módulos de `src/rsa32/v2` já estão contidos nessa netlist.
O período de clock e os delays de interface vêm do SDC da mesma síntese.

## Execução por PDK

```bash
./scripts/MG/bash/genus_no_gui.sh -p gpdk45
./scripts/MG/bash/innovus_no_gui.sh -p gpdk45
```

As opções são `sky130`, `gpdk45`, `free45` e `ics55`; o padrão é
`gpdk45`.
`innovus_full_flow.sh` é uma entrada equivalente a `innovus_no_gui.sh`.

O fluxo completo seleciona a netlist mais recente do PDK escolhido e exige
o SDC com o mesmo identificador. Essa seleção fica fixa nas dez etapas:

| Etapa | Script |
|---|---|
| Inicialização | `0.innovus_init.sh` |
| Verificações iniciais | `1.innovus_check.sh` |
| Floorplan | `2.innovus_floorplan.sh` |
| Alimentação | `3.innovus_power.sh` |
| Placement | `4.innovus_place.sh` |
| CTS | `5.innovus_cts.sh` |
| Roteamento | `6.innovus_route.sh` |
| Otimização pós-roteamento | `7.innovus_postroute.sh` |
| Verificação física | `8.innovus_verify.sh` |
| Exportação | `9.innovus_export.sh` |

Os scripts individuais também aceitam `-p`. A etapa 0 grava `active_run`
após inicializar com sucesso. Etapas individuais posteriores usam esse
marcador do mesmo PDK, ou a seleção explícita em `SYNTH_RUN`:

```bash
SYNTH_RUN=amba_3_apb_rsa_apb_top_2026-10-29_16-00-00_123456789_free45 \
  ./scripts/MG/bash/innovus_no_gui.sh -p free45
```

Uma seleção incompatível com o PDK é rejeitada. Uma etapa que falha
interrompe o fluxo completo; os bancos anteriores ficam disponíveis.

## Bancos e resultados

| Artefato | Diretório |
|---|---|
| Bancos físicos | `ps_files/rsa_apb_top_<flag>/innovus/rsa32_v2/<SYNTH_RUN>/` |
| Relatórios | `reports/amba_3_apb_rsa_apb_top_<flag>/innovus/rsa32_v2/<SYNTH_RUN>/` |
| Logs | `logs/amba_3_apb_rsa_apb_top_<flag>/innovus/rsa32_v2/<SYNTH_RUN>/<etapa>/` |
| Exportação | `ps_files/rsa_apb_top_<flag>/innovus/rsa32_v2/<SYNTH_RUN>/export/` |

`SYNTH_RUN` inclui data, hora, nanossegundos e sufixo do PDK.
Os bancos têm nomes como `postroute_amba_3_apb_rsa_apb_top_gpdk45`.
Os relatórios explícitos e as exportações também recebem o sufixo.
`synthesis_inputs_<flag>.txt` registra a origem dos arquivos e as bibliotecas.
Cada PDK mantém seu marcador em
`ps_files/rsa_apb_top_<flag>/innovus/rsa32_v2/active_run`.

Os parâmetros de tecnologia são compartilhados com o Genus em
`scripts/MG/tcl/pdks/`: nó, Liberty, LEFs, site,
camadas de pinos/alimentação e células de CTS. O floorplan mantém densidade
de 60%; SKY130 usa dimensões de anel adequadas ao mínimo de largura de met5.
O MMMC usa o corner typical e RC dos LEFs. O GDS exportado permanece
experimental, sem GDS das células e sem mapa de camadas validado.

## GUI

```bash
./scripts/MG/bash/innovus_gui.sh -p sky130
./scripts/MG/bash/innovus_gui.sh place -p sky130
./scripts/MG/bash/genus_gui.sh -p sky130
```

A GUI Innovus abre a etapa mais avançada disponível por padrão, ou a etapa
informada antes de `-p`. Também aceita `INNOVUS_DB_STAGE` e `SYNTH_RUN`.
A GUI Genus abre o banco mais recente do PDK escolhido.

Os scripts podem ser chamados de qualquer diretório. `GENUS_BIN` e
`INNOVUS_BIN` permitem indicar os executáveis. Os caminhos dos PDKs podem
ser configurados pelas variáveis descritas no
[guia de síntese por PDK](../scripts/README.md).
Os scripts de simulação pós-síntese e LEC mantêm suas configurações próprias.
