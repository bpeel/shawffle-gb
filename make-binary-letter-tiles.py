#!/usr/bin/python3

import cairo
import sys

surface = cairo.ImageSurface.create_from_png(sys.argv[1])
data = surface.get_data()
stride = surface.get_stride()

with open(sys.argv[2], "bw") as f:
    for x_tile in range(surface.get_width() // 8):
        for y in range(surface.get_height()):
            bits = 0

            for x in range(8):
                v = data[(x_tile * 8 + x) * 4 + y * stride + 1] < 128
                bits = (bits << 1) | int(v)

            f.write(bytes([bits]))
