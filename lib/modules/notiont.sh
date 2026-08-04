# shellcheck shell=bash
# Module: notiont — notion-t (CLI interativo para notas no Notion) via pipx.

mod_notiont_meta() {
  echo "notion-t (CLI interativo para notas no Notion via pipx)"
}

mod_notiont_cost() { printf '1\t20\t0\n'; }

_PN_NOTIONT_GIT="git+https://github.com/uesleinasch/notion-t.git"

mod_notiont_install() {
  if has_cmd notion-t; then
    log_info "OK: notion-t presente ($(command -v notion-t))"
    return 0
  fi
  _vf_ensure_pipx || { log_warn "pipx ausente — pulando notion-t."; return 0; }

  log_info "Instalando notion-t via pipx (a partir do GitHub)…"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "pipx install $_PN_NOTIONT_GIT"
    return 0
  fi
  pipx install "$_PN_NOTIONT_GIT" || die "Falha ao instalar notion-t."
  post_install_note "Rode 'notion-t' para iniciar o setup wizard (token Notion + database)."
}

# Garante pipx no PATH. Em Ubuntu 22.04+/Debian 12/Pop!_OS o apt já provê;
# distros mais antigas precisam instalar pipx manualmente (PEP 668 inviabiliza
# pip --user sem flags adicionais que não queremos enterrar aqui).
_vf_ensure_pipx() {
  has_cmd pipx && return 0
  log_info "Instalando pipx via apt…"
  apt_update_once
  apt_install pipx && return 0
  log_warn "pipx indisponível via apt nesta distro — instale manualmente e rode novamente."
  return 1
}

mod_notiont_doctor() {
  if has_cmd pipx; then
    status_line 1 "pipx: $(command -v pipx)"
  else
    status_line 0 "pipx: ausente"
  fi
  if has_cmd notion-t; then
    status_line 1 "notion-t: $(command -v notion-t)"
  else
    status_line 0 "notion-t: ausente"
  fi
}
