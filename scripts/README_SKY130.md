# Migração do fluxo para Sky130

Este documento registra as correções realizadas para tornar o PDK Sky130 utilizável no Genus e no Innovus do topo `amba_3_apb_rsa_apb_top`.

Os resultados finais dessa rodada foram preservados em `ps_files/rsa_apb_top_sky130/`.
As correções abaixo são um registro histórico. O fluxo atual seleciona o PDK
por argumento, conforme o [guia de execução](README.md).

## Problema original

O fluxo estava preparado para GPDK45/GSCLib045 e, posteriormente, para ICsprout55. Os scripts usavam:

- Liberty `typical.lib` ou `ics55_LLSC_H7CR_typ_tt_1p2_25_nldm.lib`;
- LEFs do GPDK45 ou ICS55;
- nó de processo 45/55 nm;
- camadas de power planning `M9` e `M10`;
- site de placement `CoreSite`.

Essas referências não correspondiam ao PDK disponível no `rock8`.

## Correções realizadas

### Genus

No [run_genus.tcl](tcl/run_genus.tcl):

- as seções GPDK45, TSMC28 e ICS55 foram preservadas apenas como comentários;
- o fluxo ativo foi alterado para SkyWater 130 nm;
- a biblioteca usada é `sky130_fd_sc_hd`;
- a Liberty correta é a versão compactada:

  ```text
  sky130_fd_sc_hd__tt_025C_1v80.lib.gz
  ```

- o LEF tecnológico correto é:

  ```text
  sky130/base/apr/sky130_fd_sc.tlef
  ```

- o LEF das células é `sky130_fd_sc_hd_merged.lef`;
- os modelos Verilog são `primitives.v` e `sky130_fd_sc_hd.v`.

### Innovus

Nos scripts TCL do Innovus:

- as referências ICS55 e GPDK45 foram comentadas;
- o nó tecnológico foi alterado para `130` em [innovus_init.tcl](tcl/innovus_init.tcl);
- o MMMC passou a usar a mesma Liberty Sky130 compactada do Genus em [innovus_mmmc.tcl](tcl/innovus_mmmc.tcl);
- os LEFs foram centralizados em [innovus_common.tcl](tcl/innovus_common.tcl);
- o site do floorplan foi alterado para `unithd` em [2.innovus_floorplan.tcl](tcl/2.innovus_floorplan.tcl);
- as camadas legadas `M9/M10` foram substituídas por `met4/met5` em [3.innovus_power.tcl](tcl/3.innovus_power.tcl).

## Validação do PDK

O script [sky130_check.sh](bash/sky130_check.sh) verifica os arquivos necessários para o Genus e o Innovus:

```bash
./scripts/bash/sky130_check.sh
```

Para usar outra montagem do PDK:

```bash
SKY130_PDK_BASE=/caminho/para/dataroot \
./scripts/bash/sky130_check.sh
```

O GDS das células é reportado como aviso porque não é necessário para a síntese nem para a inicialização/place-and-route. Ele passa a ser necessário para um stream-out GDSII válido.

## Reprodução da rodada Sky130

Para executar o fluxo atual com Sky130, selecione `-p sky130`:

Depois de carregar o ambiente Cadence:

```bash
setup
./scripts/bash/sky130_check.sh
./scripts/bash/genus_no_gui.sh -p sky130
./scripts/bash/innovus_no_gui.sh -p sky130
```

## Warnings esperados da Liberty

O Genus pode emitir warnings como `LBR-702`, `LBR-40` e `LBR-9` para células físicas auxiliares, decap, diodo e variantes de power-domain. Esses avisos não impediram a leitura da Liberty. O erro bloqueador observado anteriormente era o caminho incorreto do LEF tecnológico, já corrigido para `sky130_fd_sc.tlef`.
