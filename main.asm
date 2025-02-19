INCLUDE "hardware.inc"

SECTION "Header", ROM0[$0000]

        ds $40 - @, 0           ; Skip to vblank interrupt
        jp Vblank

        ds $100 - @, 0          ; Skip to the entry point
        nop
        jp Init

        ds $150 - @, 0          ; Make room for the header

MACRO select_bank
        ld a, BANK(\1)
        ld [$2000], a
ENDM

SECTION "Code", ROM0

Init:
	; Shut down audio circuitry
	xor a, a
	ldh [rNR52], a

	; Do not turn the LCD off outside of VBlank
.wait_vblank:
	ldh a, [rLY]
	cp 144
	jr nz, .wait_vblank
        ; Turn the LCD off
	xor a, a
	ldh [rLCDC], a

        ;; Set up the OamDma transfer in HRAM
        ld de, OamDmaCode
        ld hl, OamDma
        ld bc, OamDmaCode.end - OamDmaCode
        call MemCpy

        ;; clear the OAM mirror
        ld hl, OamMirror
        ld b, $a0
        xor a, a
.clear_oam_loop:
        ld [hli], a
        dec b
        jr nz, .clear_oam_loop
        call OamDma

        ;; Initialise variables
        xor a, a
        ld [VblankOccured], a
        ld [FrameCount], a
        ld [ScrollX], a
        ldh [rSCX], a
        ld [ScrollY], a
        ldh [rSCY], a

        ;; Clear any pending interrupts
        xor a, a
        ldh [rIF], a

        ;; Enable the vblank and stat interrupts
        ld a, IEF_VBLANK
        ldh [rIE], a
        ei

        ; Enable the LCD
        ld a, LCDCF_ON | LCDCF_BG8800 | LCDCF_OBJON | LCDCF_OBJ8
        ldh [rLCDC], a

MainLoop:
        nop
        halt
        nop

        ;; Keep waiting until a VBlank interrupt occurs
        ld a, [VblankOccured]
        and a, a
        jr z, MainLoop

        dec a
        ld [VblankOccured], a   ; reset the VBlankOccured flag
        ld hl, FrameCount
        inc [hl]
        jr MainLoop


Vblank:
        push af
        ;; Copy the OAM mirror using DMA
        call OamDma
        ;; update the scroll position
        ld a, [ScrollX]
        ldh [rSCX], a
        ld a, [ScrollY]
        ldh [rSCY], a
        ;; let the main loop know a vblank occured
        ld a, 1
        ld [VblankOccured], a
        pop af
        reti

OamDmaCode:
        LOAD "OamDmaCode", HRAM
OamDma:
        ld a, HIGH(OamMirror)
        ldh [rDMA], a   ; start DMA transfer (starts right after instruction)
        ld a, 40        ; delay for a total of 4×40 = 160 M-cycles
.wait:
        dec a           ; 1 M-cycle
        jr nz, .wait    ; 3 M-cycles
        ret
        ENDL
.end:

MemCpy: 
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jr nz, MemCpy
        ret

SECTION "Variables", WRAM0
VblankOccured: db
FrameCount:      db
ScrollX:         db
ScrollY:         db       

SECTION "OamMirror", WRAM0, ALIGN[8]
OamMirror:
        ds 0xa0
.end:
        
SECTION "LetterTiles", ROMX
LetterTiles:
        incbin "letter-tiles.bin"
