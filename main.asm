INCLUDE "hardware.inc"
INCLUDE "utils.inc"

SECTION "Header", ROM0[$0000]

        ds $40 - @, 0           ; Skip to vblank interrupt
        jp Vblank

        ds $100 - @, 0          ; Skip to the entry point
        nop
        jp Init

        ds $150 - @, 0          ; Make room for the header

SECTION "Init", ROM0

Init:
	; Shut down audio circuitry
	xor a, a
	ldh [rNR52], a

        call TurnOffLcd

        ;; Set up the OamDma transfer in HRAM
        ld de, OamDmaCode
        ld hl, OamDma
        ld bc, OamDmaCode.end - OamDmaCode
        call MemCpy

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

        jp Game

Vblank:
        push af
        ;; Copy the OAM mirror using DMA
        call OamDma
        ;; let the main loop know a vblank occured
        ld a, 1
        ld [VblankOccured], a
        pop af
        reti

SECTION "Font", ROMX
Font:
        incbin "font.bin"
.end:
