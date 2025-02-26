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
