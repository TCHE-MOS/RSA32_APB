"""Render project Markdown with local navigation and repository-relative assets."""

from html import escape
from html.parser import HTMLParser
from pathlib import Path
import re
import shutil
from urllib.parse import quote, unquote, urlsplit, urlunsplit

try:
    import markdown
except ImportError as error:
    raise SystemExit("Instale as dependências da página: python3 -m pip install -r scripts/pages/requirements.txt") from error


class DocumentLinks(HTMLParser):
    def __init__(self, root, output, source, documents, references, repository, revision):
        super().__init__(convert_charrefs=False)
        self.root = root
        self.output = output
        self.source = source
        self.documents = documents
        self.references = references
        self.repository = repository
        self.revision = revision
        self.parts = []

    def rewrite(self, value):
        url = urlsplit(value)
        if url.scheme or url.netloc or not url.path:
            return value
        target = (self.source.parent / unquote(url.path)).resolve()
        if not target.is_relative_to(self.root):
            raise ValueError(f"Link fora do repositório em {self.source.name}: {value}")
        relative = target.relative_to(self.root).as_posix()
        if relative in {"images/img1.svg", "images/img2.svg", "images/img4.svg"} and not target.is_file():
            # The README uses the SVG suffix, while the repository stores these
            # SVG sources under .png names; build.py publishes the corrected names.
            path = "../assets/" + relative
        elif relative in self.documents:
            path = self.documents[relative]
        elif relative in self.references:
            path = self.references[relative]
        elif target.is_file() and target.suffix.lower() in {".svg", ".png", ".jpg", ".jpeg", ".gif", ".webp"}:
            destination = self.output / "assets" / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(target, destination)
            path = "../assets/" + relative
        else:
            kind = "tree" if target.is_dir() or url.path.endswith("/") else "blob"
            path = f"{self.repository}/{kind}/{self.revision}/{relative}"
        return urlunsplit(("", "", quote(path, safe="/:@"), url.query, url.fragment))

    def start_tag(self, tag, attrs, closing):
        if (tag == "img" and self.source == self.root / "README.md"
                and dict(attrs).get("src") == "images/img5.svg"
                and not (self.root / "images/img5.svg").is_file()):
            # img5.png now shows the chip. Keep the IRQ explanation without
            # substituting an unrelated image for the old, unavailable SVG.
            self.parts.append('<span>IRQ combina as flags DONE/ERROR com suas habilitações no IER. '
                              '<a href="README_amba_3_apb_control.html#8-interrupcao-e-latencia">'
                              'Veja os detalhes no controle APB.</a></span>')
            return
        if tag == "table":
            self.parts.append('<div class="table-scroll">')
        attributes = []
        for name, value in attrs:
            if value is None:
                attributes.append(name)
                continue
            if name in {"href", "src"}:
                value = self.rewrite(value)
            attributes.append(f'{name}="{escape(value, quote=True)}"')
        self.parts.append("<" + tag + (" " + " ".join(attributes) if attributes else "") + closing)

    def handle_starttag(self, tag, attrs):
        self.start_tag(tag, attrs, ">")

    def handle_startendtag(self, tag, attrs):
        self.start_tag(tag, attrs, " />")

    def handle_endtag(self, tag):
        self.parts.append(f"</{tag}>")
        if tag == "table":
            self.parts.append("</div>")

    def handle_data(self, data):
        self.parts.append(data)

    def handle_entityref(self, name):
        self.parts.append(f"&{name};")

    def handle_charref(self, name):
        self.parts.append(f"&#{name};")

    def handle_comment(self, data):
        self.parts.append(f"<!--{data}-->")


def build_documents(root, output, repository, revision, references):
    documents = {
        "README.md": "README.html",
        "site/README.md": "README_site.html",
        "docs/plano_teste_amba_3_apb_rsa_apb_top.md": "plano_teste.html",
    }
    for path in sorted((root / "src").rglob("README*.md")):
        documents[path.relative_to(root).as_posix()] = path.with_suffix(".html").name
    if len(set(documents.values())) != len(documents):
        raise ValueError("READMEs com nomes repetidos no diretório de documentação.")

    template = (root / "site/document.html").read_text(encoding="utf-8")
    for relative, name in documents.items():
        source = root / relative
        text = source.read_text(encoding="utf-8")
        renderer = markdown.Markdown(extensions=["tables", "fenced_code", "toc", "sane_lists"],
                                     extension_configs={"toc": {"toc_depth": "2-3"}})
        content = renderer.convert(text)
        links = DocumentLinks(root, output, source, documents, references, repository, revision)
        links.feed(content)
        links.close()
        title = re.search(r"^#\s+(.+)", text, re.M)
        title = title[1].replace("`", "") if title else source.stem
        raw_name = Path(name).with_suffix(".md").name
        shutil.copyfile(source, output / "reference" / raw_name)
        values = {
            "TITLE": escape(title), "CONTENT": "".join(links.parts), "TOC": renderer.toc,
            "SOURCE": escape(relative), "RAW": escape(raw_name),
            "GITHUB": escape(f"{repository}/blob/{revision}/{relative}"),
        }
        page = re.sub(r"\{\{(\w+)\}\}", lambda match: values[match[1]], template)
        (output / "reference" / name).write_text(page, encoding="utf-8")
    return len(documents)
