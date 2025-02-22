SECTION "Tiles", ROMX
Tiles::
        ;; first tile empty
        ds 16, $00
        incbin "background-tiles.bin"
        incbin "sprite-tiles.bin"
.end::

