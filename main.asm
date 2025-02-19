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

        ;; Set up the bg palette
        select_bank TilePalettes
        ld a, BCPSF_AUTOINC
        ldh [rBCPS], a
        ld b, TilePalettes.end - TilePalettes
        ld hl, TilePalettes
:       ld a, [hli]
        ldh [rBCPD], a
        dec b
        jr nz, :-

        select_bank TileTiles
        ld de, TileTiles
        ld bc, TileTiles.end - TileTiles
        ld hl, $8800
        call MemCpy

        ld b, $0
        call ExtractLetterTiles
        ld b, $1
        call ExtractLetterTiles
        ld b, $2
        call ExtractLetterTiles
        ld b, 47
        call ExtractLetterTiles

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

ExtractLetterTiles:
        ;; b = tile to extract
        ;; hl = address to store tile
        ;; leaves hl pointing at next tile
        ;; corrupts de, a and b
        ld d, 0
        ld a, b
        ;; da = b * 16
        REPT 4
        sla a
        rl d
        ENDR
        ;; multiply b by 8 into eb
        ld e, 0
        REPT 3
        sla b
        rl e
        ENDR
        ;; add eb to da to get da = b * 24
        add a, b
        jr nc, :+
        inc d
:
        add a, LOW(LetterTiles)
        jr nc, :+
        inc d
:

        ld b, e
        ld e, a
        ld a, b
        add a, d

        add a, HIGH(LetterTiles)
        ld d, a

        ld b, 8 * 3
        select_bank LetterTiles
.loop:
        ld a, $ff
        ld [hli], a
        ld a, [de]
        ld [hli], a
        inc de
        dec b
        jr nz, .loop

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

SECTION "TileTiles", ROMX
TileTiles:
        ;; first tile empty
        ds 16, $00
        incbin "tile-tiles.bin"
.end:

SECTION "TilePalettes", ROMX
TilePalettes:
        incbin "tile-palettes.bin"
.end:
