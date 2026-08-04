# =====================================================================
# Tab bar custom — cada aba ganha uma cor da paleta, ciclada pelo índice.
# Reutiliza o desenho powerline padrão do kitty; só troca as cores.
# Ativado por `tab_bar_style custom` no kitty.conf.
# =====================================================================
from kitty.fast_data_types import Color, Screen
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    draw_tab_with_powerline,
)

# Paleta Catppuccin Mocha — uma matiz por aba, na ordem abaixo.
# Aba 1 usa a 1ª cor, aba 2 a 2ª, ... a 11ª aba volta ao começo.
PALETTE = [
    Color(0xf3, 0x8b, 0xa8),  # red
    Color(0xfa, 0xb3, 0x87),  # peach
    Color(0xf9, 0xe2, 0xaf),  # yellow
    Color(0xa6, 0xe3, 0xa1),  # green
    Color(0x94, 0xe2, 0xd5),  # teal
    Color(0x89, 0xdc, 0xeb),  # sky
    Color(0x89, 0xb4, 0xfa),  # blue
    Color(0xcb, 0xa6, 0xf7),  # mauve
    Color(0xf5, 0xc2, 0xe7),  # pink
    Color(0xb4, 0xbe, 0xfe),  # lavender
]

DARK_FG = Color(0x11, 0x11, 0x1b)   # texto escuro sobre aba ativa (viva)
LIGHT_FG = Color(0xcd, 0xd6, 0xf4)  # texto claro sobre aba inativa (escurecida)
INACTIVE_DIM = 0.45                 # fator de escurecimento da aba inativa


def dim(c: Color, factor: float) -> Color:
    return Color(int(c.red * factor), int(c.green * factor), int(c.blue * factor))


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    color = PALETTE[(index - 1) % len(PALETTE)]
    tinted = draw_data._replace(
        active_bg=color,
        active_fg=DARK_FG,
        inactive_bg=dim(color, INACTIVE_DIM),
        inactive_fg=LIGHT_FG,
    )
    return draw_tab_with_powerline(
        tinted, screen, tab, before, max_tab_length, index, is_last, extra_data
    )
