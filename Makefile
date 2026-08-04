SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

POWERTERMINAL_HOME := $(CURDIR)

# Emite pares "canonical_src\thome_dst" para cada path gerenciado.
# Carrega os módulos e invoca toda função declarada como mod_*_links — assim
# novos módulos com manifesto são detectados automaticamente.
# Filtra entradas cuja origem está fora do repo (ex.: binários do kitty em
# ~/.local/kitty.app, que não fazem parte do estado canônico).
define MANIFEST
export POWERTERMINAL_HOME="$(POWERTERMINAL_HOME)"; \
export POWERTERMINAL_NOTES_FILE=/dev/null POWERTERMINAL_ANSWERS_FILE=/dev/null; \
. "$(POWERTERMINAL_HOME)/lib/core.sh" >/dev/null; \
for m in "$(POWERTERMINAL_HOME)"/lib/modules/*.sh; do . "$$m"; done; \
declare -F | awk '$$3 ~ /^mod_.*_links$$/ {print $$3}' | while read -r fn; do "$$fn"; done \
  | awk -F'\t' -v root="$(POWERTERMINAL_HOME)/" 'substr($$1, 1, length(root)) == root'
endef

.PHONY: help sync sync-check status

help:
	@echo "PowerTerminal — atalhos Make"
	@echo ""
	@echo "  make sync         Copia HOME → canônico do PowerTerminal para todos os paths gerenciados"
	@echo "  make sync-check   Lista o que seria copiado, sem modificar nada (dry-run)"
	@echo "  make status       Atalho para 'powerterminal status'"

sync:
	@$(MANIFEST) | while IFS=$$'\t' read -r src dst; do \
	  [[ -z "$$src" || -z "$$dst" ]] && continue; \
	  if [[ ! -e "$$dst" ]]; then \
	    printf '  [skip] %s (não existe no HOME)\n' "$$dst"; \
	    continue; \
	  fi; \
	  if [[ -d "$$dst" ]]; then \
	    mkdir -p "$$src"; \
	    rsync -ac --delete "$$dst/" "$$src/"; \
	    printf '  [dir]  %s\n' "$$src"; \
	  else \
	    mkdir -p "$$(dirname "$$src")"; \
	    cp -p "$$dst" "$$src"; \
	    printf '  [file] %s\n' "$$src"; \
	  fi; \
	done
	@echo
	@echo "Mudanças pendentes no repo:"
	@git -C "$(POWERTERMINAL_HOME)" status --short 2>/dev/null || true

sync-check:
	@$(MANIFEST) | while IFS=$$'\t' read -r src dst; do \
	  [[ -z "$$src" || -z "$$dst" ]] && continue; \
	  if [[ ! -e "$$dst" ]]; then \
	    printf '  [skip] %s (não existe no HOME)\n' "$$dst"; \
	    continue; \
	  fi; \
	  if [[ -d "$$dst" ]]; then \
	    out=$$(rsync -ac --delete --dry-run --itemize-changes "$$dst/" "$$src/" 2>&1 || true); \
	    diff_lines=$$(printf '%s\n' "$$out" | awk 'NF && $$0 !~ /^\./'); \
	    if [[ -z "$$diff_lines" ]]; then \
	      printf '  [ok]   %s\n' "$$src"; \
	    else \
	      printf '  [diff] %s\n' "$$src"; \
	      printf '%s\n' "$$diff_lines" | sed 's/^/         /'; \
	    fi; \
	  else \
	    if cmp -s "$$src" "$$dst" 2>/dev/null; then \
	      printf '  [ok]   %s\n' "$$src"; \
	    else \
	      printf '  [diff] %s ⇐ %s\n' "$$src" "$$dst"; \
	    fi; \
	  fi; \
	done

status:
	@"$(POWERTERMINAL_HOME)/bin/powerterminal" status
