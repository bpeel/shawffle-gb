#!/usr/bin/python3

import gi
gi.require_version('Pango', '1.0')
from gi.repository import Pango
gi.require_version('PangoCairo', '1.0')
from gi.repository import PangoCairo
import cairo

FIRST_LETTER = ord("𐑐")
N_LETTERS = 48

LETTER_WIDTH = 8
LETTER_HEIGHT = 24

surface = cairo.ImageSurface(cairo.FORMAT_RGB24,
                             LETTER_WIDTH * N_LETTERS,
                             LETTER_HEIGHT)
cr = cairo.Context(surface)

layout = PangoCairo.create_layout(cr)

cr.save()
cr.set_source_rgb(1.0, 1.0, 1.0)
cr.set_operator(cairo.OPERATOR_SOURCE)
cr.paint()
cr.restore()

for i in range(N_LETTERS):
    layout.set_text(chr(FIRST_LETTER + i), -1)
    (ink_rect, logical_rect) = layout.get_pixel_extents()

    cr.move_to(i * LETTER_WIDTH +
               LETTER_WIDTH / 2.0 -
               logical_rect.width / 2.0,
               -LETTER_HEIGHT * 0.1)
    PangoCairo.show_layout(cr, layout)

data = surface.get_data()

for i in range(LETTER_WIDTH * LETTER_HEIGHT * N_LETTERS):
    if data[i * 4 + 1] < 128:
        v = 0
    else:
        v = 255

    for j in range(4):
        data[i * 4 + j] = v

surface.write_to_png("letter-tiles.png")
