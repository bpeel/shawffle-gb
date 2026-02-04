#!/usr/bin/python3

# Shawffle GB – A puzzle game for the Gameboy Color
# Copyright (C) 2025  Neil Roberts
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import sys
import re

PUZZLE_SIZE = 48

N_TILES = 5 * 3 + 3 * 2
N_SPACES = 5 * 5

PADDING = bytes([0] * (PUZZLE_SIZE - N_TILES * 2))

CHAR_RE = re.compile(r'^\s*charmap\s+"(.)"\s*,\s*FIRST_FONT_TILE\s*\+\s*'
                     r'([0-9]+)')

charmap = {}

with open("charmap.inc", "r", encoding="utf-8") as f:
    for line in f:
        md = CHAR_RE.match(line)

        if md is None:
            continue

        charmap[md.group(1)] = int(md.group(2))

with open("puzzles.bin", "wb") as f:
    for (line_num, line) in enumerate(sys.stdin):
        for ch in line[0:N_TILES]:
            try:
                letter_num = charmap[ch]
            except KeyError:
                print(f"invalid letter {ch} on line {line_num + 1}",
                      file=sys.stderr)
                sys.exit(1)

            f.write(bytes([letter_num]))

        for ch in line[N_TILES:N_TILES * 2]:
            tile_num = ord(ch) - ord("a")

            y = tile_num // 5
            x = tile_num % 5

            tile_num -= 2 * (y // 2)
            if y & 1 != 0:
                tile_num -= x // 2

            if tile_num < 0 or tile_num >= N_SPACES:
                print(f"invalid tile letter {ch} on line {line_num + 1}",
                      file=sys.stderr)
                sys.exit(1)

            f.write(bytes([tile_num]))

        f.write(PADDING)
