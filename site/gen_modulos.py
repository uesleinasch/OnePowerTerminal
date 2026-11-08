#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = Path(__file__).resolve().parent / "content" / "modulos.md"

CATEGORIAS = [
    ("base", "Base"),
    ("shell", "Shell"),
    ("editor", "Editores"),
    ("terminal", "Terminal"),
    ("dev", "Ferramentas de desenvolvimento"),
    ("extras", "Extras"),
]


def catalogo():
    with tempfile.TemporaryDirectory() as home:
        env = {**os.environ, "HOME": home, "POWERTERMINAL_UI": "text"}
        env.pop("POWERTERMINAL_HOME", None)
        saida = subprocess.run(
            [str(RAIZ / "bin" / "powerterminal"), "catalog", "--json"],
            env=env, check=True, capture_output=True, text=True,
        ).stdout
    return json.loads(saida)


def codigos(itens):
    return ", ".join(f"`{i}`" for i in itens)


def secao_modulo(m, perfis):
    em = [p for p, ids in perfis.items() if m["id"] in ids]
    sudo = "pede sudo" if m["sudo"] else "sem sudo"
    linhas = [f"### {m['name']} (`{m['id']}`)", "", m["about"], ""]
    linhas.append(f"- **Custo estimado:** {m['minutes']} min, {m['mb']} MB, {sudo}")
    linhas.append(f"- **Perfis:** {codigos(em) if em else 'nenhum, só com `--module`'}")
    if m["needs"]:
        linhas.append(f"- **Depende de:** {codigos(m['needs'])}")
    if m["requires"]:
        linhas.append(f"- **Pré-requisitos do sistema:** {codigos(m['requires'])}")
    if m["provides"]:
        linhas += ["", "O que instala:", ""]
        linhas += [f"- `{p['value']}` ({p['kind']})" for p in m["provides"]]
    linhas.append("")
    return linhas


def main():
    cat = catalogo()
    perfis = cat["profiles"]
    linhas = [
        "# Módulos",
        "",
        f"O PowerTerminal {cat['version']} tem {len(cat['modules'])} módulos independentes e "
        "idempotentes. Esta página é gerada a partir de `powerterminal catalog --json`.",
        "",
    ]
    for chave, titulo in CATEGORIAS:
        mods = [m for m in cat["modules"] if m["category"] == chave]
        if not mods:
            continue
        linhas += [f"## {titulo}", ""]
        for m in mods:
            linhas += secao_modulo(m, perfis)
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    SAIDA.write_text("\n".join(linhas), encoding="utf-8")


if __name__ == "__main__":
    main()
