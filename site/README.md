# Página de documentação e verificação

O processo reutilizável de concepção, redação, implementação e revisão está
registrado em [Metodologia para sites de portfólio técnico](README_METODOLOGIA.md).

A página reúne a arquitetura do periférico APB–RSA, as representações do
circuito e os resultados de simulação e cobertura. O conteúdo está organizado
na seguinte ordem, precedido por uma landing page com o título do projeto,
uma breve descrição técnica e um índice de navegação:

1. **Diagrama de topo:** o arquivo do draw.io conectado ao Drive.
2. **Síntese:** uma descrição breve da conversão do RTL em uma netlist
   mapeada para células da biblioteca de tecnologia, acompanhada da vista
   de topo do circuito (`img5.png`).
3. **Representações do circuito:** visão em blocos (`img6.png`), expansões no
   SimVision (`img7.png` e `img8.png`), esquemático do Genus (`img13.png`) e cinco
   expansões no Conformal (`img16.png` a `img20.png`).
4. **Cobertura:** capturas do Incisive e do comparativo IMC × LCOV/Verilator
   (`img11.png` e `img12.png`), métricas calculadas na geração do site e acesso ao
   relatório HTML do Verilator.
5. **Simulações:** formas de onda RTL (`img9.png` e `img10.png`), simulação
   da netlist com SDF (`img14.png`) e comparação RTL × estrutural
   (`img15.png`), além dos resultados das bancadas locais.
6. **Materiais de apoio:** testbench, scripts, READMEs, plano de teste e PDFs.
7. **Diagramas e blocos:** as quatro imagens de controle e transações
   (`img1.png` a `img4.png`), todos os diagramas Mermaid dos módulos e o
   detalhamento de cada bloco.

As vinte imagens estão em `images/img1.png` até `images/img20.png`. O script
de geração verifica a presença dos arquivos e os copia para
`_site/assets/images/`. Três deles (`img1.png`, `img2.png` e `img4.png`)
contêm SVG, apesar da extensão `.png`; suas cópias publicadas recebem a
extensão `.svg` para que o servidor identifique o formato corretamente.

As capturas registram resultados obtidos nas ferramentas do projeto. As
métricas apresentadas nos painéis e os trechos de log são extraídos dos
artefatos locais de simulação durante a geração do site.

## Landing page

A abertura integra o próprio `index.html` e apresenta o projeto RSA_APB antes
do conteúdo técnico. Seu índice leva às nove seções por âncoras: diagrama de
topo (`#rtl`), síntese (`#sintese`), representações (`#representacoes`),
cobertura (`#cobertura`), simulações (`#resultados-simulacao`), testbench
(`#testbench`), scripts (`#scripts`), documentação (`#docs`) e módulos
(`#modulos`). A navegação usa links HTML e funciona sem JavaScript. Os
endereços anteriores e os links diretos para as seções são preservados.

O fundo reúne nove imagens existentes do projeto (`img5.png`, `img7.png`,
`img9.png`, `img11.png`, `img13.png`, `img16.png`, `img19.png`, `img14.png` e
`img12.png`) em um mosaico com sobreposição escura para manter o contraste
do texto. O estilo responsivo da abertura está em `assets/landing.css`,
copiado junto aos demais recursos pelo processo de geração existente.

## Diagrama de topo conectado ao Drive

O visualizador oficial do diagrams.net lê o XML público do arquivo
`1pJmIWxV6VePdHCURcpEqT6SSo5kHxkri` no Drive ao carregar a página. O arquivo
remoto é a fonte do diagrama; o build não precisa exportá-lo. A conexão está
em `assets/live-diagram.js`. A altura da área do diagrama foi reduzida em
40%, tanto em desktop quanto em dispositivos móveis.

Depois que uma edição é salva no diagrams.net, as alterações ficam
disponíveis conforme o cache do provedor. Recarregar a página realiza uma
nova consulta ao arquivo público.

O diagrama pode ser atualizado sem uma nova publicação do site. O arquivo precisa
continuar público para leitura por link. **Editar diagrama** abre o
original e respeita as permissões do Drive. **Abrir no Drive** oferece
acesso direto ao arquivo, inclusive se a incorporação não carregar.

## Cobertura no mesmo tema da página

O fundo da página e do relatório HTML de cobertura usa a cor `#050b16`.
As tabelas seguem a mesma paleta, com destaque para faixas de cobertura e
linhas executadas. O tema está em `assets/lcov.css`; o script do Verilator
o aplica após a execução do genhtml. A geração do site também aplica o tema
à cópia em `_site/coverage/`.

O relatório completo está disponível por link e em uma área incorporada à
página. Os links da tabela de cobertura são gerados a partir dos caminhos
de fontes registrados no LCOV e apontam para as páginas com linhas anotadas,
em `coverage/src/...sv.gcov.html`. A geração verifica se esses destinos
existem. Os caminhos relativos permitem a navegação no subdiretório do
GitHub Pages.

Para reaplicar o tema a um relatório existente, execute na raiz:

```bash
python3 scripts/pages/coverage_theme.py reports/amba_3_apb_rsa_apb_top/verilator/html
```

## Leitura dos READMEs

Os links de documentação abrem versões HTML dos READMEs, com o tema do site,
índice, tabelas, código, imagens e diagramas Mermaid. O plano de teste
usa o mesmo formato. **Baixar .md** abre o arquivo Markdown, e
**Voltar à documentação** retorna à página principal.

A conversão usa `scripts/pages/documents.py` e Python-Markdown. Os links
entre READMEs são redirecionados para as páginas locais; as imagens existentes
são copiadas para os recursos do site; os links de código apontam para o repositório.
Texto e tabelas continuam disponíveis sem JavaScript. Os diagramas Mermaid
são desenhados pelo navegador, com seu código disponível caso a biblioteca
não carregue.

O README principal contém referências antigas a arquivos SVG. A conversão
para HTML corrige os links das imagens 1, 2 e 4. A referência ao desenho de
IRQ, cujo arquivo não está disponível, é substituída por uma explicação e
um link para a documentação do controle APB. O arquivo `img5.png` apresenta
a vista do circuito. Essas adaptações não alteram o Markdown de origem.

## Gerar localmente

Na raiz do repositório, com Icarus Verilog, Verilator e genhtml instalados:

```bash
python3 -m venv /tmp/rsa-apb-pages-env
/tmp/rsa-apb-pages-env/bin/pip install -r scripts/pages/requirements.txt
./scripts/bash/iverilog.sh
./scripts/bash/verilator.sh
/tmp/rsa-apb-pages-env/bin/python scripts/pages/build.py
python3 -m http.server 8000 --directory _site
```

A página fica disponível em `http://localhost:8000`. Quando os logs e
relatórios correspondem à versão que será publicada, a geração do site
pode ser executada diretamente, sem repetir as simulações. As dependências
Python estão em `scripts/pages/requirements.txt`. O diretório `_site/`
contém os arquivos gerados e é ignorado pelo Git.

## Fontes da página

- `modules.json`: nomes, fontes RTL e resumos dos módulos.
- READMEs dos módulos: documentação completa e diagramas Mermaid.
  Na ausência de um resumo no catálogo, a geração usa o parágrafo de Objetivo.
- `README.md` e `src/rsa32/README_rsa_apb_top.md`: diagramas complementares
  de visão geral e integração, incluídos em `supplementalDiagrams`.
- `images/img1.png` a `images/img20.png`: as imagens descritas acima.
- `index.html` e `assets/`: interface responsiva em HTML, CSS e JavaScript.
- `scripts/pages/build.py`: leitura dos artefatos e geração do site.
- `scripts/pages/documents.py` e `document.html`: conversão dos documentos
  para `_site/reference/*.html`.
- Os dois `simulation.log` do topo: resultados e trechos de reset, banco de
  registradores e execução RSA.
- `coverage.info`: cobertura LCOV total e por arquivo, calculada dos registros
  DA/BRDA.
- `coverage_summary.txt`: métricas nativas do Verilator, segundo os critérios
  de instrumentação da ferramenta.
- O HTML do genhtml: relatório completo em `_site/coverage/`, com páginas
  anotadas e recursos.
- Testbenches, scripts, READMEs, plano de teste e PDFs: materiais disponíveis
  em `_site/reference/`.

A geração é interrompida se faltar uma imagem, documento, diagrama ou
relatório obrigatório, se os logs estiverem incompletos ou se uma fonte do
catálogo não tiver registros no LCOV. Os logs de Icarus e Verilator também
devem apresentar a mesma quantidade de comparações. As cópias de log e LCOV
disponíveis para download têm os caminhos absolutos do repositório
normalizados. A página apresenta o horário de modificação do log do
Verilator no fuso de Brasília e o commit do repositório usado na geração;
alterações locais são indicadas como workspace.

O Mermaid é carregado de jsDelivr. Se a conexão falhar, o restante da página
continua disponível. O diagrama de topo depende do visualizador remoto do
diagrams.net e do arquivo público no Drive.

## Publicar no GitHub Pages

1. Envie os arquivos atualizados ao repositório.
2. Em **Settings → Pages → Build and deployment → Source**, selecione
   **GitHub Actions**.
3. Execute **Actions → Documentação e cobertura — GitHub Pages → Run workflow**
   na branch de publicação, ou envie um commit para `main`/`master`.

O workflow instala as ferramentas e as dependências Python, prepara o
Verilator 5.052 com cache, executa as duas bancadas e gera o site. Os logs e
relatórios são produzidos no ambiente de execução do GitHub Actions. O job
de deploy publica o artefato gerado e informa a URL final.

O endereço padrão é
`https://mattgrossi12.github.io/RSA_APB_32-bit/`. Os caminhos relativos dos
assets, documentos e relatórios funcionam nesse subdiretório.

## Verificar a página

Após a geração, a revisão deve verificar a ordem das seções, o carregamento
das vinte imagens e a navegação do relatório LCOV pela tabela de arquivos
e pela área incorporada. Em telas menores, as imagens devem se ajustar à
largura da página e os controles de navegação devem permanecer acessíveis.

Na landing page, a revisão inclui o contraste do título e da descrição sobre
o mosaico, a disposição do índice em desktop e celular e os destinos dos
nove links, inclusive com JavaScript desabilitado.

Os diagramas Mermaid e o detalhamento dos onze módulos aparecem ao final.
A revisão inclui as versões HTML dos READMEs e os controles do diagrama
remoto, que depende do acesso ao Drive. A publicação requer o envio dos
arquivos e a habilitação do GitHub Pages no repositório.
