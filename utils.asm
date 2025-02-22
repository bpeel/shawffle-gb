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

        ;; Copied from https://gbdev.io/gb-asm-tutorial/part2/input.html
UpdateKeys::
        ; Poll half the controller
        ld a, P1F_GET_BTN
        call .onenibble
        ld b, a ; B7-4 = 1; B3-0 = unpressed buttons

        ; Poll the other half
        ld a, P1F_GET_DPAD
        call .onenibble
        swap a ; A3-0 = unpressed directions; A7-4 = 1
        xor a, b ; A = pressed buttons + directions
        ld b, a ; B = pressed buttons + directions

        ; And release the controller
        ld a, P1F_GET_NONE
        ldh [rP1], a

        ; Combine with previous wCurKeys to make wNewKeys
        ld a, [CurKeys]
        xor a, b ; A = keys that changed state
        and a, b ; A = keys that changed to pressed
        ld [NewKeys], a
        ld a, b
        ld [CurKeys], a
        ret

.onenibble:     
        ldh [rP1], a ; switch the key matrix
        call .knownret ; burn 10 cycles calling a known ret
        ldh a, [rP1] ; ignore value while waiting for the key matrix to settle
        ldh a, [rP1]
        ldh a, [rP1] ; this read counts
        or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret:      
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
