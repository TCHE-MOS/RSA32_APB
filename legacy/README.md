# Fluxos legados dos sub-blocos

As simulações e sínteses ativas têm como alvo apenas
`amba_3_apb_rsa_apb_top`. Esta pasta preserva os fluxos individuais dos
sub-blocos e seus artefatos, mantendo a organização original por categoria:

```text
legacy/
├── scripts/<sub-bloco>/      # Scripts Bash e Tcl dos fluxos individuais
├── reports/<sub-bloco>/      # Relatórios históricos
├── logs/<sub-bloco>/         # Logs e arquivos auxiliares das ferramentas
├── ps_files/<sub-bloco>/     # Bancos, netlists, SDCs e outros resultados
└── testbenchs/<sub-bloco>/   # Bancadas individuais
```

Foram arquivadas as pastas existentes de `amba_3_apb_adrec`,
`amba_3_apb_control`, `amba_3_apb_data_i_demux`, `amba_3_apb_data_io_top`,
`amba_3_apb_data_o_mux`, `amba_3_apb_regbank`, `amba_3_apb_reset`,
`amba_3_apb_rsa_wrapper_control`, `amba_3_apb_rsa_wrapper_data` e
`amba_3_apb_rsa_wrapper_top`. Nem todo bloco possui artefatos em todas as
categorias.

Os arquivos foram movidos sem alterar seu conteúdo ou suas permissões.
Os scripts preservam caminhos históricos e não são entradas do fluxo ativo;
uma eventual reutilização exige revisar esses caminhos e as dependências.

Os fontes RTL e sua documentação permanecem em `src/`, pois os sub-blocos
continuam compondo o top. Os scripts ativos ficam em
`scripts/`, a bancada integrada em
`testbenchs/rsa_apb_top/` e a verificação UVM em `UVM/`.
Os artefatos do top, incluindo suas variantes de tecnologia, permanecem nas
pastas originais da raiz. `scripts/pages/` continua gerando a documentação
e pode disponibilizar bancadas legadas como referência histórica.
