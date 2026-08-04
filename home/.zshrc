# ~/.zshrc — template do PowerTerminal.
# Personalização da máquina (aliases, toolchains, tokens) vai em ~/.zshrc.local,
# que é carregado no final e pode sobrescrever qualquer coisa daqui.

# Powerlevel10k instant prompt. Deve ficar no topo: qualquer coisa que peça
# entrada no console (senha, [y/n]) precisa vir ANTES deste bloco.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── PATH base ────────────────────────────────────────────────────────────────
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ── Powerlevel10k ────────────────────────────────────────────────────────────
# Rode `p10k configure` para regerar o ~/.p10k.zsh.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ── Editor ───────────────────────────────────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'

# ── Neovim (módulo `nvim` instala em /opt) ───────────────────────────────────
# O install também cria /usr/local/bin/nvim; este PATH cobre o caso do symlink
# não existir.
[[ -d /opt/nvim-linux-x86_64/bin ]] && export PATH="$PATH:/opt/nvim-linux-x86_64/bin"

# ── Node (módulo `node` instala nvm OU n) ────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

[[ -d "$HOME/n/bin" ]] && export PATH="$HOME/n/bin:$PATH"

# ── Container (módulo `container` instala Docker OU Podman) ──────────────────
# Só o Podman rootless expõe esse socket. A guarda mantém a linha inerte para
# quem escolheu Docker, onde um DOCKER_HOST definido apontaria para o lugar
# errado e quebraria o cliente que já fala com /var/run/docker.sock.
[[ -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock" ]] \
  && export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock"

# ── fzf ──────────────────────────────────────────────────────────────────────
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# ── Yazi (módulo `tools`) ────────────────────────────────────────────────────
# `y` abre o yazi e, ao sair com `q`, deixa o terminal no diretório navegado.
# https://yazi-rs.github.io/docs/quick-start
function y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -- cwd < "$tmp"
  [[ -n "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# ── Kitty: comandos de sessão (ksave/kload) ──────────────────────────────────
[[ -f ~/.config/kitty/session.zsh ]] && source ~/.config/kitty/session.zsh

# ── Personalização local ─────────────────────────────────────────────────────
# Copie o template: cp ~/PowerTerminal/home.local.example/.zshrc.local ~/
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
