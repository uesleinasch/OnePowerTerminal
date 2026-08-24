# Faz o prompt acompanhar o flavor Catppuccin em vigor (`powerterminal theme`).
#
# O ~/.p10k.zsh é gerado por `p10k configure` e define 208 cores; 195 delas
# usam índices ANSI 0-15, que o kitty remapeia por flavor — essas seguem o tema
# sozinhas. As três abaixo eram as únicas presas a cores fixas do cubo 256, que
# não mudam com o tema e perdem contraste em fundo claro. Precisa ser sourceado
# DEPOIS do ~/.p10k.zsh para sobrescrever.
#
# Não há valor por flavor de propósito: trocar a cor fixa pelo índice ANSI
# equivalente resolve os quatro de uma vez.

# Era 76 (verde-limão fixo) e 196 (vermelho puro): ilegíveis sobre o latte.
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=2
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=1

# Era 238 (cinza-escuro fixo): num fundo claro o pontilhado do gap ficava mais
# marcado que o próprio prompt.
typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND=8
