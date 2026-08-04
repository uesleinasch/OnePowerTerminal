#!/usr/bin/env python3
"""Salva o estado atual do kitty (OS windows, abas, splits, cwd e programas)
num arquivo de sessão que o startup_session carrega ao abrir o kitty.

Uso:
  - via atalho no kitty (ctrl+shift+s), ou
  - manualmente dentro de um terminal kitty: ~/.config/kitty/save-session.py
"""
import json
import os
import shlex
import subprocess
import sys

CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
SESSION_FILE = os.path.join(CONFIG_DIR, "last-session.kitty")

# Processos tratados como "shell": relançamos só o shell padrão, sem comando.
SHELLS = {"bash", "zsh", "fish", "sh", "dash", "tcsh", "ksh", "nu", "elvish", "xonsh"}


def window_command(w):
    """Comando a relançar na janela. None => deixa o kitty abrir o shell padrão."""
    fps = w.get("foreground_processes") or []
    cmd = None
    if fps and fps[-1].get("cmdline"):
        cmd = fps[-1]["cmdline"]      # processo em primeiro plano (vim, etc.)
    elif w.get("cmdline"):
        cmd = w["cmdline"]            # processo raiz da janela (normalmente o shell)
    if not cmd:
        return None
    base = os.path.basename(cmd[0]).lstrip("-")  # "-zsh" -> "zsh"
    if base in SHELLS:
        return None
    return cmd


def main():
    res = subprocess.run(["kitty", "@", "ls"], capture_output=True, text=True)
    if res.returncode != 0:
        sys.stderr.write("kitty @ ls falhou. allow_remote_control está ligado?\n")
        sys.stderr.write(res.stderr)
        sys.exit(1)

    os_windows = json.loads(res.stdout)
    lines = []

    for oi, osw in enumerate(os_windows):
        if oi > 0:
            lines.append("")
            lines.append("new_os_window")

        tabs = osw.get("tabs", [])
        emitted_tab = False
        for tab in tabs:
            wins = [w for w in tab.get("windows", []) if not w.get("is_self")]
            if not wins:
                continue

            title = (tab.get("title") or "").strip()
            # 1a aba de uma OS window adicional já existe (criada por new_os_window):
            # não emitimos new_tab pra ela, evitando aba duplicada.
            if oi > 0 and not emitted_tab:
                pass
            else:
                lines.append(f"new_tab {title}" if title else "new_tab")
            emitted_tab = True

            layout = tab.get("layout")
            if layout:
                lines.append(f"layout {layout}")

            for w in wins:
                cwd = w.get("cwd") or ""
                cmd = window_command(w)
                parts = ["launch"]
                if cwd:
                    parts.append(f"--cwd={shlex.quote(cwd)}")
                if cmd:
                    parts.append("--")
                    parts.extend(shlex.quote(c) for c in cmd)
                lines.append(" ".join(parts))
                if w.get("is_focused"):
                    lines.append("focus")

    content = "\n".join(lines).strip() + "\n"
    with open(SESSION_FILE, "w") as f:
        f.write(content)

    msg = f"Sessão salva: {SESSION_FILE}"
    print(msg)
    # Notificação de desktop, se disponível (silencioso se não existir).
    try:
        subprocess.run(["notify-send", "Kitty", msg],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        pass


if __name__ == "__main__":
    main()
