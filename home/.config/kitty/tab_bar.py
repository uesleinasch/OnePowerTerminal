# =====================================================================
# Tab bar custom — cada aba ganha uma cor da paleta, ciclada pelo índice.
# Reutiliza o desenho powerline padrão do kitty; só troca as cores.
# Ativado por `tab_bar_style custom` no kitty.conf.
#
# A paleta acompanha o flavor Catppuccin em vigor (`powerterminal theme`):
# o flavor é identificado pelo `background` do tema já carregado, então não
# há estado duplicado aqui nem passo extra no comando.
# =====================================================================
from typing import Dict, NamedTuple, Tuple

from kitty.fast_data_types import Color, Screen, get_options
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    draw_tab_with_powerline,
)


def _c(h: str) -> Color:
    return Color(int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16))


class Palette(NamedTuple):
    base: Color   # fundo do tema — identifica o flavor
    text: Color   # texto da aba inativa
    crust: Color  # texto da aba ativa (contrasta com a matiz viva)
    hues: Tuple[Color, ...]


def _palette(base: str, text: str, crust: str, *hues: str) -> Palette:
    return Palette(_c(base), _c(text), _c(crust), tuple(_c(h) for h in hues))


# Ordem das matizes: red, peach, yellow, green, teal, sky, blue, mauve, pink,
# lavender. Aba 1 usa a 1ª, aba 2 a 2ª, … a 11ª aba volta ao começo.
FLAVORS: Tuple[Palette, ...] = (
    _palette(  # latte
        "#eff1f5", "#4c4f69", "#dce0e8",
        "#d20f39", "#fe640b", "#df8e1d", "#40a02b", "#179299",
        "#04a5e5", "#1e66f5", "#8839ef", "#ea76cb", "#7287fd",
    ),
    _palette(  # frappe
        "#303446", "#c6d0f5", "#232634",
        "#e78284", "#ef9f76", "#e5c890", "#a6d189", "#81c8be",
        "#99d1db", "#8caaee", "#ca9ee6", "#f4b8e4", "#babbf1",
    ),
    _palette(  # macchiato
        "#24273a", "#cad3f5", "#181926",
        "#ed8796", "#f5a97f", "#eed49f", "#a6da95", "#8bd5ca",
        "#91d7e3", "#8aadf4", "#c6a0f6", "#f5bde6", "#b7bdf8",
    ),
    _palette(  # mocha
        "#1e1e2e", "#cdd6f4", "#11111b",
        "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5",
        "#89dceb", "#89b4fa", "#cba6f7", "#f5c2e7", "#b4befe",
    ),
)

BY_BACKGROUND: Dict[Tuple[int, int, int], Palette] = {
    (p.base.red, p.base.green, p.base.blue): p for p in FLAVORS
}

LATTE, MOCHA = FLAVORS[0], FLAVORS[-1]

# Quanto a aba inativa se aproxima do fundo. Blend rumo ao `base`, não
# multiplicação rumo ao preto: escurecer só legibiliza em tema escuro — no
# latte a aba inativa tem de clarear para o texto escuro continuar legível.
INACTIVE_BLEND = 0.55


def _luma(c: Color) -> float:
    return 0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue


def _blend(src: Color, dst: Color, amount: float) -> Color:
    return Color(
        int(src.red + (dst.red - src.red) * amount),
        int(src.green + (dst.green - src.green) * amount),
        int(src.blue + (dst.blue - src.blue) * amount),
    )


def _active_palette() -> Palette:
    bg = get_options().background
    found = BY_BACKGROUND.get((bg.red, bg.green, bg.blue))
    if found is not None:
        return found
    # Tema fora do Catppuccin: escolhe pela claridade do fundo para que a aba
    # inativa e seu texto continuem legíveis.
    return LATTE if _luma(bg) > 127 else MOCHA


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
    palette = _active_palette()
    color = palette.hues[(index - 1) % len(palette.hues)]
    tinted = draw_data._replace(
        active_bg=color,
        active_fg=palette.crust,
        inactive_bg=_blend(color, palette.base, INACTIVE_BLEND),
        inactive_fg=palette.text,
    )
    return draw_tab_with_powerline(
        tinted, screen, tab, before, max_tab_length, index, is_last, extra_data
    )
