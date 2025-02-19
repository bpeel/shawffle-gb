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

MACRO add_constant_to_de
        ld a, LOW(\1)
        add a, e
        ld e, a
        jr nc, :+
        inc d
:       ld a, d
        add a, HIGH(\1)
        ld d, a
ENDM

        ;; Offset from TileTiles to the three tiles that form the
        ;; background of a letter
DEF LETTER_TEMPLATE_OFFSET EQU 16 * 4

DEF PUZZLES_PER_BANK EQU 341
DEF BYTES_PER_PUZZLE EQU 48

DEF TILES_PER_PUZZLE EQU 5 * 3 + 3 * 2

DEF FIRST_LETTER_TILE EQU 7

DEF TILE_INCORRECT EQU 0
DEF TILE_WRONG_POS EQU 1
DEF TILE_CORRECT EQU 2

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

        select_bank TileMap
        xor a, a
        ldh [rVBK], a
        ld de, TileMap
        ld hl, _SCRN0
        call CopyScreenMap
        ld a, 1
        ldh [rVBK], a
        ld de, TileMapAttribs
        ld hl, _SCRN0
        call CopyScreenMap

        select_bank TileTiles
        xor a, a
        ldh [rVBK], a
        ld de, TileTiles
        ld bc, TileTiles.end - TileTiles
        ld hl, $8000
        call MemCpy

        ld bc, 0
        call LoadPuzzle
        call ExtractPuzzleTiles
        call PositionTiles
        call InitTileStates
        call SetTilePalettes

        ;; Clear any pending interrupts
        xor a, a
        ldh [rIF], a

        ;; Enable the vblank and stat interrupts
        ld a, IEF_VBLANK
        ldh [rIE], a
        ei

        ; Enable the LCD
        ld a, LCDCF_ON | LCDCF_BG8000 | LCDCF_OBJON | LCDCF_OBJ8
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

CopyScreenMap:
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

ExtractPuzzleTiles:
        ld hl, $8000 + FIRST_LETTER_TILE * 16
        ld c, TILES_PER_PUZZLE
        ld de, PuzzleLetters
.loop:
        ld a, [de]
        inc de
        ld b, a
        push bc
        push de
        call ExtractLetterTiles
        pop de
        pop bc
        dec c
        jr nz, .loop
        ret

ExtractLetterTiles:
        ;; b = tile to extract
        ;; hl = address to store tile
        ;; leaves hl pointing at next tile
        ;; corrupts de, a and b

        ;; copy the template into the tile
        push hl
        select_bank TileTiles
        ld de, TileTiles + LETTER_TEMPLATE_OFFSET
        ld c, 16 * 3
:       ld a, [de]
        ld [hli], a
        inc de
        dec c
        jr nz, :-
        pop hl

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
        REPT 2
        ld a, [de]
        or a, [hl]
        ld [hli], a
        ENDR
        inc de
        dec b
        jr nz, .loop

        ret

LoadPuzzle:
        ;; Fills PuzzleLetters and TilePositions with the puzzle data
        ;; bc = puzzle number
        ;; get puzzle number * 48 into de (= num * 32 + num * 16)
        ld d, b
        ld e, c
        ;; de = bc * 32
        REPT 5
        sla e
        rl d
        ENDR
        ld h, b
        ld a, c
        ;; ha = b * 16
        REPT 4
        sla a
        rl h
        ENDR
        add a, e
        jr nc, :+
        inc h
:       ld e, a
        ld a, d
        add h
        ld d, a

        ld a, b
        and a, a
        jr z, .first_bank
        ld a, c
        cp a, LOW(PUZZLES_PER_BANK)
        jr nc, .second_bank
.first_bank:
        select_bank Puzzles
        add_constant_to_de Puzzles
        jr .got_addr
.second_bank:
        select_bank Puzzles2
        add_constant_to_de Puzzles2 - PUZZLES_PER_BANK * BYTES_PER_PUZZLE
.got_addr:
        ld hl, PuzzleLetters
        assert TilePositions == PuzzleLetters + TILES_PER_PUZZLE
        ld c, TILES_PER_PUZZLE * 2
:       ld a, [de]
        ld [hli], a
        inc de
        dec c
        jr nz, :-
        ret

PositionTiles:
        ;; Update the tile map to reflect the positions in TilePositions
        xor a, a
        ldh [rVBK], a
        ld hl, _SCRN0 + 32 + 2
        ld de, TilePositions
        ld b, 5
.loop:
        ld c, 5
.row_loop:
        ld a, c
        or a, b
        bit 0, a                ; skip gaps when b and c are even
        jr nz, .not_gap
        dec c
        ld a, l
        add a, 3
        ld l, a
.not_gap:
        push bc
        ld a, [de]
        inc de
        ld b, a                 ; a *= 3
        sla b
        add a, b
        add a, FIRST_LETTER_TILE
        ld b, a
        ld [hl], b
        inc b
        ld a, l
        add a, 32
        ld l, a
        jr nc, :+
        inc h
:       ld [hl], b
        inc b
        ld a, l
        add a, 32
        ld l, a
        jr nc, :+
        inc h
:       ld [hl], b
        ld a, l
        sub a, 32 * 2 - 3
        ld l, a
        jr nc, :+
        dec h
:       pop bc
        dec c
        jr nz, .row_loop
        ld a, l
        add a, 32 * 3 - 5 * 3
        ld l, a
        jr nc, :+
        inc h
:       dec b
        jr nz, .loop
        ret

InitTileStates:
        ld de, TileStates
        ld bc, TilePositions
        ld h, HIGH(PuzzleLetters)
.loop:
        ld a, [bc]
        inc c
        add a, LOW(PuzzleLetters)
        ld l, a
        ld a, [hl]
        push af
        ld a, e
        sub a, TileStates - PuzzleLetters
        ld l, a
        ld l, [hl]
        pop af
        cp a, l
        ld a, TILE_CORRECT
        jr z, :+
        ld a, TILE_INCORRECT
:       ld [de], a
        inc e
        ld a, e
        cp a, LOW(TileStates) + TILES_PER_PUZZLE
        jr c, .loop
        ret

SetTilePalettes:
        ;; Update the tile attributes to reflect the states in TileStates
        ld a, 1
        ldh [rVBK], a
        ld hl, _SCRN0 + 32 + 1
        ld de, TileStates
        ld b, 5
.loop:
        ld c, 5
.row_loop:
        ld a, c
        or a, b
        bit 0, a                ; skip gaps when b and c are even
        jr nz, .not_gap
        dec c
        ld a, l
        add a, 3
        ld l, a
.not_gap:
        push bc
        ld a, [de]
        inc de
        ld b, a
        ld c, 3
.tile_row_loop:
        REPT 3
        ld a, [hl]
        and a, $f8
        or a, b
        ld [hli], a
        ENDR
        ld a, l
        add a, 32 - 3
        ld l, a
        jr nc, :+
        inc h
:       dec c
        jr nz, .tile_row_loop
        ld a, l
        sub a, 32 * 3 - 3
        ld l, a
        jr nc, :+
        dec h
:       pop bc
        dec c
        jr nz, .row_loop
        ld a, l
        add a, 32 * 3 - 5 * 3
        ld l, a
        jr nc, :+
        inc h
:       dec b
        jr nz, .loop
        ret

SECTION "Variables", WRAM0
VblankOccured: db
FrameCount:      db
ScrollX:         db
ScrollY:         db

SECTION "GameState", WRAM0, ALIGN[BITWIDTH(TILES_PER_PUZZLE * 3 - 1)]
PuzzleLetters:  ds TILES_PER_PUZZLE
TilePositions:  ds TILES_PER_PUZZLE
TileStates:      ds TILES_PER_PUZZLE

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

SECTION "Puzzles", ROMX
Puzzles:
        incbin "puzzles.bin", 0, PUZZLES_PER_BANK * BYTES_PER_PUZZLE

SECTION "Puzzles2", ROMX
Puzzles2:
        incbin "puzzles.bin", PUZZLES_PER_BANK * BYTES_PER_PUZZLE
