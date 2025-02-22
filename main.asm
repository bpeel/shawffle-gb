INCLUDE "hardware.inc"
INCLUDE "utils.inc"

DEF SAVE_STATE_CHECK_SIZE EQU 16

SECTION "Header", ROM0[$0000]

        ds $40 - @, 0           ; Skip to vblank interrupt
        jp Vblank

        ds $48 - @, 0           ; Skip to stat interrupt
        jp StatJumpInstruction

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

        ;; Prepare stat interrupt jump instruction
        ld a, $c3               ; jp n16
        ld [StatJumpInstruction], a

        ;; Set up the OamDma transfer in HRAM
        ld de, OamDmaCode
        ld hl, OamDma
        ld bc, OamDmaCode.end - OamDmaCode
        call MemCpy

        call InitialiseSaveState

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

InitialiseSaveState:
        select_bank SaveStateCheckValue
        select_sram_bank SaveStateCheck
        enable_sram

        ld b, SAVE_STATE_CHECK_SIZE
        ld hl, SaveStateCheck
        ld de, SaveStateCheckValue
.checksum_loop:
        ld a, [de]
        inc de
        cp a, [hl]
        inc hl
        jr nz, .bad_checksum
        dec b
        jr nz, .checksum_loop
        jr .out                 ; checksum fine, don’t need to clear
.bad_checksum:
        ld hl, SaveStateCheck
        ld de, SaveStateCheckValue
        ld bc, SAVE_STATE_CHECK_SIZE
        call MemCpy
        ;; Clear the remaining memory
:       xor a, a
        ld [hli], a
        ld a, h
        cp a, HIGH(_SRAM + 8192)
        jr c, :-
.out:
        disable_sram
        ret

SECTION "Font", ROMX
Font:
        incbin "font.bin"
.end:

SECTION "SaveStateCheckValue", ROMX
SaveStateCheckValue:
        ;; Ensure we’re encoding the bytes directly and not using a charmap
        PUSHC
        NEWCHARMAP ASCII
        db "Shawffle SRAM :)"
        POPC
        assert @ - SaveStateCheckValue == SAVE_STATE_CHECK_SIZE

SECTION "SaveState", SRAM[$A000]
SaveStateCheck::
        ds SAVE_STATE_CHECK_SIZE
