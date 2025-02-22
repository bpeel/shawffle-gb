INCLUDE "hardware.inc"

SECTION "Utils", ROM0
TurnOffLcd::
        ldh a, [rLCDC]
        bit BITWIDTH(LCDCF_ON) - 1, a
        ret z              ; don’t do anything if the screen is already off
	; Do not turn the LCD off outside of VBlank
.wait_vblank:
	ldh a, [rLY]
	cp 144
	jr nz, .wait_vblank
        ; Turn the LCD off
	xor a, a
	ldh [rLCDC], a
        ret

LoadBackgroundPalettes::
        ;; hl = address of palettes
        ;; b = size
        ld a, BCPSF_AUTOINC
        ldh [rBCPS], a
:       ld a, [hli]
        ldh [rBCPD], a
        dec b
        jr nz, :-
        ret

MemCpy::
        ;; de = source
        ;; hl = dest
        ;; bc = size
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jr nz, MemCpy
        ret

CopyScreenMap::
        ;; Copy one screen’s worth of tile map or attribute data. The
        ;; data is packed so that only 20 bytes are stored per row of
        ;; tiles instead of the full 32 for the large scrollable area
        ;; de = source
        ;; hl = dest
        ld b, 144 / 8
.line:
        ld c, 160 / 8
.tile:
        ld a, [de]
        ld [hli], a
        inc de
        dec c
        jr nz, .tile
        ld a, (256 - 160) / 8
        add a, l
        ld l, a
        jr nc, :+
        inc h
:       dec b
        jr nz, .line
        ret

OamDmaCode::
        LOAD "OamDmaCode", HRAM
OamDma::
        ld a, HIGH(OamMirror)
        ldh [rDMA], a   ; start DMA transfer (starts right after instruction)
        ld a, 40        ; delay for a total of 4×40 = 160 M-cycles
.wait:
        dec a           ; 1 M-cycle
        jr nz, .wait    ; 3 M-cycles
        ret
        ENDL
.end::

SECTION "OamMirror", WRAM0, ALIGN[8]
OamMirror::
        ds OAM_COUNT * 4
