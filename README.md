
# RSA_APB

Periférico RSA com interface AMBA 3 APB (APB3), descrito em SystemVerilog.
O projeto contém RTL do periférico, um núcleo RSA, testbenches estruturais e
scripts auxiliares de síntese, LEC e simulação.

Os fluxos ativos de simulação e síntese têm como alvo exclusivamente
`amba_3_apb_rsa_apb_top`. Os fluxos individuais dos sub-blocos e seus
artefatos estão arquivados em [`legacy/`](legacy/README.md).

## Diagrama de topo da arquitetura

**[Abrir o diagrama interativo conectado ao Drive](https://mattgrossi12.github.io/RSA_APB_32-bit/#arquitetura)**

O visualizador da página consulta o XML original do Google Drive, com
atualização automática a cada minuto enquanto a aba está visível. As edições
salvas no diagrams.net aparecem sem exportar imagens ou reconstruir o site.

[Editar no diagrams.net](https://app.diagrams.net/#G1pJmIWxV6VePdHCURcpEqT6SSo5kHxkri#%7B%22pageId%22%3A%22MEHrRE8WjDQsoYR0GH0S%22%7D)
· [Arquivo original no Drive](https://drive.google.com/file/d/1pJmIWxV6VePdHCURcpEqT6SSo5kHxkri/view)



## Estrutura do repositório

```text
.
├── constraints/                 # Restrições do top
├── docs/                        # Especificações e material de referência
├── images/                      # Diagramas e imagens do projeto
├── legacy/                      # Fluxos individuais e artefatos dos sub-blocos
│   ├── scripts/
│   ├── reports/
│   ├── logs/
│   ├── ps_files/
│   └── testbenchs/
├── logs/amba_3_apb_rsa_apb_top*/  # Simulação e síntese por PDK
├── ps_files/rsa_apb_top*/        # Resultados do top por tecnologia
├── reports/amba_3_apb_rsa_apb_top*/
├── scripts/
│   ├── bash/                   # Entradas Bash de simulação e ferramentas EDA
│   ├── tcl/                    # Fluxos Tcl e configurações dos PDKs
│   ├── pages/                  # Geração da documentação
│   ├── validation/             # Relatórios de cobertura
│   └── clean.sh                # Limpeza de artefatos do top
├── src/
│   ├── amba_3_apb/              # RTL APB e wrapper RSA
│   │   ├── legacy/              # RTL legado, fora do fluxo ativo
│   │   └── amba_3_apb_rsa_apb_top.sv
│   └── rsa32/
│       ├── v1/                 # Núcleo RSA original
│       └── v2/                 # Núcleo RSA modular
├── testbenchs/rsa_apb_top/       # Bancadas integradas
├── UVM/                        # Verificação UVM do top
└── waveforms/
```

## Imagens do projeto

### Sequência de controle do wrapper RSA

<div align="center">
  <img src="images/img1.svg" alt="Diagrama de estados do controle do wrapper RSA: START, carregamento de mensagem, expoente e módulo, espera por core_done ou core_err, e retorno por DONE ou ERROR.">
  <p><em>Figura 1 — Estados e transições do controle do wrapper RSA, incluindo reset síncrono e conclusão ou erro do núcleo.</em></p>
</div>

### Transferência de dados para o núcleo

<div align="center">
  <img src="images/img2.svg" alt="Diagrama temporal dos ciclos C0 a C5 com START, LOAD, BUSY, DONE e DIN para mensagem, expoente e módulo.">
  <p><em>Figura 2 — Sequência temporal de inicialização, carregamento dos operandos e sinalização de ocupado/concluído do núcleo RSA.</em></p>
</div>

### Máquina de estados do protocolo APB

<div align="center">
  <img src="images/img3.png" alt="Diagrama da máquina APB com os estados IDLE, SETUP e ACCESS, e transições controladas por PSELx, PENABLE e PREADY.">
  <p><em>Figura 3 — Fases IDLE, SETUP e ACCESS de uma transferência APB, incluindo espera quando PREADY está baixo.</em></p>
</div>

### Exemplo de escrita APB

<div align="center">
  <img src="images/img4.svg" alt="Diagrama temporal de uma escrita APB para o endereço 0x0C com o dado 0x12345678, passando por SETUP e ACCESS.">
  <p><em>Figura 4 — Exemplo de transferência de escrita APB e captura dos dados na borda final do acesso.</em></p>
</div>

### Geração da interrupção

<div align="center">
  <img src="images/img5.svg" alt="Diagrama lógico da IRQ combinando STATUS.DONE e STATUS.ERROR com IER.DONE_IE e IER.ERR_IE.">
  <p><em>Figura 5 — Lógica de interrupção: flags DONE e ERROR habilitadas pelos bits correspondentes do registrador IER.</em></p>
</div>

## Artefatos legados

O diretório [`legacy/`](legacy/README.md), na raiz, reúne scripts,
relatórios, logs, resultados de síntese e testbenches individuais dos
sub-blocos. Seus arquivos preservam o conteúdo e os caminhos internos
históricos; esses scripts não fazem parte do fluxo ativo.

O RTL dos sub-blocos permanece em `src/`, pois é necessário à integração
do top. O RTL `src/amba_3_apb/legacy/amba_3_apb_data_i_demux.sv` continua
legado e não faz parte dos blocos ativos do projeto.

## Síntese por PDK

Genus e Innovus aceitam `-p sky130|gpdk45|free45|ics55`; o padrão é
`gpdk45`.

```bash
./scripts/bash/genus_no_gui.sh -p sky130
./scripts/bash/innovus_no_gui.sh -p sky130
```

Os resultados ficam separados por execução e PDK, com sufixos nos arquivos
de síntese e relatórios. Consulte o [guia dos fluxos por PDK](scripts/README.md)
para os quatro PDKs, caminhos e seleção de execuções anteriores.

## Módulos RTL

| Módulo e fonte | Responsabilidade |
|---|---|
| `amba_3_apb_control`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_control.sv) | Controle APB e habilitações<br>de escrita e IRQ. |
| `amba_3_apb_data_io_top`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_data_io_top.sv) | Redução e validação do endereço;<br>caminho de leitura. |
| `amba_3_apb_data_o_mux`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_data_o_mux.sv) | Multiplexação combinacional<br>dos dados de leitura. |
| `amba_3_apb_regbank`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_regbank.sv) | Registradores de controle, status,<br>operandos e resultado. |
| `amba_3_apb_reset`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_reset.sv) | Sincronização de reset<br>e reset do núcleo. |
| `amba_3_apb_rsa_wrapper_control`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_rsa_wrapper_control.sv) | FSM de controle<br>do wrapper RSA. |
| `amba_3_apb_rsa_wrapper_data`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_rsa_wrapper_data.sv) | Caminho de dados e carregamento<br>dos operandos do núcleo. |
| `amba_3_apb_rsa_wrapper_top`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_rsa_wrapper_top.sv) | Integração do controle, dados<br>e núcleo RSA. |
| `amba_3_apb_rsa_apb_top`<br>[Fonte RTL](src/amba_3_apb/amba_3_apb_rsa_apb_top.sv) | Topo do periférico<br>com interface APB. |
| `rsa_core` e auxiliares<br>[Fonte RTL](src/rsa32/rsa_core_32.sv) | Núcleo RSA e módulos<br>`rsa_core_mult`, `rsa_core_mod`, `rsa_core_ctrl`. |

O topo atual está em `src/amba_3_apb/amba_3_apb_rsa_apb_top.sv` e declara
`amba_3_apb_rsa_apb_top`. O testbench correspondente fica em
[`testbenchs/rsa_apb_top/testbench.sv`](testbenchs/rsa_apb_top/testbench.sv):
aplica reset físico, envia CTRL.SRST, aguarda cinco ciclos e verifica as
escritas/leitura dos registradores RW em dez rodadas com scoreboard. Ao final,
executa dez operações RSA, conferindo STATUS, IRQ, RESULT e preservação de
MSG/EXP/MOD. A instância usa `LOAD_GAP=1`, conforme o protocolo do núcleo real.
Os testbenches individuais estão arquivados em
`legacy/testbenchs/<nome_do_modulo>/`.

### Simulação integrada com Icarus Verilog

Com `iverilog` e `vvp` no `PATH`, execute:

```bash
./scripts/bash/iverilog.sh
# Opcional: escolher o valor genérico de 32 bits.
./scripts/bash/iverilog.sh +DATA=DEADBEEF
```

O cenário aprovado termina com `TEST PASS: 238 checks, 0 errors`. Logs ficam em
`logs/amba_3_apb_rsa_apb_top/iverilog/` e o VCD em
`waveforms/amba_3_apb_rsa_apb_top/testbench.vcd`.
O [plano de teste](docs/plano_teste_amba_3_apb_rsa_apb_top.md) detalha a
sequência, as tasks, o mapa de registradores e os critérios de aprovação.

### Simulação e cobertura com Verilator

Com Verilator, `verilator_coverage`, Make e G++ com suporte a C++20 no `PATH`:

```bash
./scripts/bash/verilator.sh
./scripts/bash/verilator.sh +DATA=DEADBEEF
```

O script executa a mesma bancada e gera o resumo em
`reports/amba_3_apb_rsa_apb_top/verilator/coverage_summary.txt`, fontes anotadas
e `coverage.info` (LCOV). Com `genhtml` instalado (pacote LCOV), também gera
`reports/amba_3_apb_rsa_apb_top/verilator/html/index.html`.
Os logs ficam em `logs/amba_3_apb_rsa_apb_top/verilator/` e o VCD em
`waveforms/amba_3_apb_rsa_apb_top/verilator/testbench.vcd`.
Use `VERILATOR_JOBS=4` para alterar o paralelismo de compilação (padrão: 2).

### Simulação com Xcelium

Com Xcelium no `PATH`, execute a simulação integrada em batch ou abra
SimVision:

```bash
./scripts/bash/xrun.sh
./scripts/bash/xrun_wgui.sh
```

Os scripts executam a bancada integrada com Xcelium; o fluxo gráfico também
abre SimVision e salva as formas de onda.

Os scripts do topo podem ser chamados de qualquer diretório. Cada ferramenta
executa em sua pasta de logs, incluindo os arquivos auxiliares que ela gera
no diretório atual:

| Ferramenta | Diretório relativo a `logs/` |
| --- | --- |
| Genus, batch | `amba_3_apb_rsa_apb_top_<flag>/genus/<RUN>/` |
| Genus GUI | `amba_3_apb_rsa_apb_top_<flag>/genus/gui/<RUN>/` |
| Conformal LEC e lint | `amba_3_apb_rsa_apb_top/lec/` |
| Xcelium e SimVision | `amba_3_apb_rsa_apb_top/xrun/` |
| IMC, standalone ou chamado pelo Xcelium | `amba_3_apb_rsa_apb_top/imc/` |
| Innovus, etapas 0 a 9 | `amba_3_apb_rsa_apb_top_<flag>/innovus/rsa32_v2/<SYNTH_RUN>/<etapa>/` |
| Innovus GUI | `amba_3_apb_rsa_apb_top_<flag>/innovus/rsa32_v2/<SYNTH_RUN>/gui/` |
| Icarus Verilog | `amba_3_apb_rsa_apb_top/iverilog/` |
| Verilator | `amba_3_apb_rsa_apb_top/verilator/` |

Assim, `imc.log`, `imc.key`, `mdv.log`, `innovus.log`, `innovus.cmd` e
`xcelium.d/` ficam nos diretórios das ferramentas. Relatórios, bancos,
netlists, cobertura e formas de onda com caminhos explícitos continuam em
`reports/`, `ps_files/`, `coverage/` e `waveforms/`.

O [fluxo Innovus da RSA32 v2](docs/fluxo_innovus_rsa32_v2.md) seleciona a
netlist e o SDC da mesma síntese, mantém as etapas nessa execução e separa
os bancos físicos por `SYNTH_RUN`.

## Diagrama de arquitetura de topo

O diagrama abaixo representa a arquitetura-alvo e a relação entre os blocos:

```mermaid
flowchart TD
    EXT["APB3 externo"] --> IO["data_io_top / data_o_mux"]
    EXT --> C["apb_control"]
    EXT --> R["regbank"]
    IO -->|"oaddr + addr_valid"| C
    R -->|"dados de leitura"| IO
    C -->|"WE"| R
    R -->|"START + operandos"| WT["rsa_wrapper_top"]
    WT --> WC["rsa_wrapper_control"]
    WT --> WD["rsa_wrapper_data"]
    WT --> CORE["rsa_core"]
    WC --> WD
    WD --> CORE
    CORE --> WC
    WT -->|"BUSY, DONE, ERROR, DOUT"| R
    WT -->|"BUSY"| C
    R -->|"SRST"| RESET["reset"]
    EXT --> RESET
    RESET -->|"rsa_rst"| WT
```

Este é um diagrama de referência da arquitetura; ele não afirma que todas as
instâncias e conexões já estejam completas no RTL de `rsa_apb_top`.

Documentação detalhada dos blocos APB:
[`src/amba_3_apb/`](src/amba_3_apb/).
O [README do topo atual](src/amba_3_apb/README_amba_3_apb_rsa_apb_top.md) e o
[README do núcleo RSA](src/rsa32/README_rsa_core.md) descrevem a integração
usada pela bancada. A análise em `src/rsa32/README_rsa_apb_top.md` é histórica.

## Organização dos resultados

A [página GitHub Pages](site/README.md) reúne os resumos e diagramas dos dez
módulos, trechos dos logs e os resultados LCOV. Para gerar com os artefatos
locais existentes, execute `python3 scripts/pages/build.py`; a saída fica em
`_site/`. O workflow `.github/workflows/pages.yml` recria as simulações e
publica a página quando GitHub Pages está configurado para GitHub Actions.

- O SDC do top está em `constraints/amba_3_apb_rsa_apb_top.sdc`.
- Os resultados de síntese são separados em
  `ps_files/rsa_apb_top*/`, conforme a tecnologia e a execução.
- Os relatórios de síntese ficam em `reports/amba_3_apb_rsa_apb_top_<flag>/`;
  LEC também usa a flag do PDK. Lint e cobertura IMC usam
  `reports/amba_3_apb_rsa_apb_top_rtl/<ferramenta>/<RUN>/`, com sufixo `_rtl`
  nos relatórios. A [metodologia dos Tcl](scripts/README.md#metodologia-comum-de-relatórios)
  detalha os caminhos e a preservação de execuções anteriores. Os relatórios
  Verilator e os resultados históricos mantêm seus caminhos existentes.
- Os logs de síntese ficam em `logs/amba_3_apb_rsa_apb_top_<flag>/`;
  os de LEC também usam a flag do PDK. Lint e IMC usam
  `logs/amba_3_apb_rsa_apb_top_rtl/<ferramenta>/<RUN>/`; os de simulação
  continuam em `logs/amba_3_apb_rsa_apb_top/<ferramenta>/`.
- Formas de onda são armazenadas em `waveforms/`.
- Os artefatos individuais dos sub-blocos ficam nas categorias de `legacy/`.

Os arquivos `insira_aqui.txt` mantêm pastas vazias rastreáveis pelo Git até que
sejam gerados os respectivos resultados.

## Melhorias recomendadas

1. **Completar e validar a integração de `rsa_apb_top`:** confirmar que as
   instâncias e conexões usam as interfaces RTL atuais e que todas as saídas APB
   têm drivers.
2. **Criar listas de fontes para o top:** os Tcl de síntese referenciam
   `filelist.f`; manter listas explícitas e versionadas evita depender de
   arquivos externos ou de diretórios de execução implícitos.
3. **Centralizar a configuração do top:** compartilhar caminhos e opções
   entre os scripts ativos reduz divergências entre ferramentas.
4. **Adicionar verificação automatizada:** elaborar os testbenches com clock,
   reset, estímulos e assertions; executar lint, compilação/elaboração e testes
   em CI antes de considerar o fluxo funcional.
5. **Manter o isolamento do legado:** direcionar novos relatórios e resultados
   ao top e preservar os artefatos dos sub-blocos em `legacy/`.
6. **Documentar e versionar requisitos das ferramentas:** registrar versões de
   simulador, Genus/LEC, bibliotecas e variáveis de ambiente necessárias para
   reproduzir os fluxos.

As sugestões acima são propostas de trabalho; não alteram o comportamento do
RTL nem afirmam que os fluxos proprietários foram executados.
