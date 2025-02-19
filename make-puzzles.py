#!/usr/bin/python3

import sys

PUZZLE_SIZE = 48

FIRST_LETTER = ord("𐑐")
N_LETTERS = 48

N_TILES = 5 * 3 + 3 * 2
N_SPACES = 5 * 5

PADDING = bytes([0] * (PUZZLE_SIZE - N_TILES * 2))

with open("puzzles.bin", "wb") as f:
    for (line_num, line) in enumerate(sys.stdin):
        for ch in line[0:N_TILES]:
            letter_num = ord(ch) - FIRST_LETTER

            if letter_num < 0 or letter_num >= N_LETTERS:
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
