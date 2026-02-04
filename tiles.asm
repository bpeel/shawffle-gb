;;; Shawffle GB – A puzzle game for the Gameboy Color
;;; Copyright (C) 2025  Neil Roberts
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

INCLUDE "utils.inc"
INCLUDE "hardware.inc"

SECTION "Tiles", ROMX
Tiles::
        ;; first tile empty
        ds 16, $00
        incbin "background-tiles.bin"
        incbin "sprite-tiles.bin"
.end::

SECTION "Font", ROMX
Font:
        incbin "font.bin"
.end:

SECTION "LoadSharedTilesCode", ROM0
LoadSharedTiles::
        select_bank Tiles
        xor a, a
        ldh [rVBK], a
        ld de, Tiles
        ld bc, Tiles.end - Tiles
        ld hl, $8000
        call MemCpy

        ;; Copy the font and expand to 4bpp
        select_bank Font
        ld de, Font
        ld bc, Font.end - Font
:       ld a, [de]
        inc de
        ld [hli], a
        ld [hli], a
        dec bc
        ld a, b
        or a, c
        jr nz, :-

        ret
