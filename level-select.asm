INCLUDE "hardware.inc"
INCLUDE "charmap.inc"
INCLUDE "utils.inc"
INCLUDE "globals.inc"

DEF LEVEL_SELECT_LCDC EQU \
        LCDCF_ON | \
        LCDCF_BG8000 | \
        LCDCF_OBJON | \
        LCDCF_OBJ8 | \
        LCDCF_BG9800 | \
        LCDCF_WIN9C00 | \
        LCDCF_WINON

DEF FIRST_BORDER_TILE EQU 12
DEF TOP_LEFT_BORDER_TILE EQU FIRST_BORDER_TILE + 0
DEF TOP_RIGHT_BORDER_TILE EQU FIRST_BORDER_TILE + 1
DEF BOTTOM_LEFT_BORDER_TILE EQU FIRST_BORDER_TILE + 2
DEF BOTTOM_RIGHT_BORDER_TILE EQU FIRST_BORDER_TILE + 3
DEF VERTICAL_BORDER_TILE EQU FIRST_BORDER_TILE + 4
DEF HORIZONTAL_BORDER_TILE EQU FIRST_BORDER_TILE + 5

DEF MULTI_STAR_START_TILE EQU 8
DEF ODD_STARS_END_TILE EQU 9
DEF EVEN_STARS_END_TILE EQU 10
DEF CONTINUE_STARS_TILE EQU 11
DEF TICK_TILE EQU 18

DEF BORDER_PALETTE EQU 1

SECTION "LevelSelectCode", ROM0

LevelSelect::
        di

        call TurnOffLcd

        ;; clear the OAM mirror
        ld hl, OamMirror
        ld b, OAM_COUNT * 4
        xor a, a
.clear_oam_loop:
        ld [hli], a
        dec b
        jr nz, .clear_oam_loop
        call OamDma

        ;; Set up the bg palette
        select_bank BackgroundPalettes
        ld b, BackgroundPalettes.end - BackgroundPalettes
        ld hl, BackgroundPalettes
        call LoadBackgroundPalettes

        ;; Initialise variables
        xor a, a
        ld [VblankOccured], a
        ldh [rSCX], a
        ldh [rSCY], a
        ldh [rWY], a
        ld [CurKeys], a
        ld [NewKeys], a

        ;; Prepare the stat interrupt
        ld a, LOW(Stat)
        ld [StatJumpAddress], a
        ld a, HIGH(Stat)
        ld [StatJumpAddress + 1], a
        ld a, STATF_LYC
        ldh [rSTAT], a
        call PrepareStat

        ;; Clear the tile attributes in the main tile map
        ld a, 1
        ldh [rVBK], a
        ld hl, $9800
        xor a, a
        ld bc, SCRN_VX_B * SCRN_VY_B
:       xor a, a
        ld [hli], a
        dec bc
        ld a, c
        or a, b
        jr nz, :-

        call FillWindow

        ;; Draw the vertical bars in the background tile map
        xor a, a
        ldh [rVBK], a
        ld b, VERTICAL_BORDER_TILE
        call FillSideBars
        ld a, 1
        ldh [rVBK], a
        ld b, BORDER_PALETTE
        call FillSideBars

        call DrawInitialScreen

        ;; Clear any pending interrupts
        xor a, a
        ldh [rIF], a

        ;; Enable the vblank and stat interrupts
        ld a, IEF_VBLANK | IEF_STAT
        ldh [rIE], a
        ei

        ; Enable the LCD
        ld a, LEVEL_SELECT_LCDC
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

        call PrepareStat

        jr MainLoop

Stat:
        push af
        ;; busy-wait for the horizontal blank
:       ldh a, [rSTAT]
        bit BITWIDTH(STATF_BUSY) - 1, a
        jr nz, :-
        ;; Hide or display the window
        ld a, [NextWXValue]
        ldh [rWX], a
        ;; Next time set the window to visible
        ld a, 7
        ld [NextWXValue], a
        ;; Interrupt one line before the last row of tiles
        ld a, SCRN_Y - 9
        ldh [rLYC], a
        pop af
        reti

PrepareStat:
        ;; Prepares the stat interrupt for the next frame
        ld a, 7
        ldh [rLYC], a
        ldh [rWX], a
        ld a, $ff               ; hide the window
        ld [NextWXValue], a
        ret

FillWindow:
        xor a, a
        ldh [rVBK], a
        ;; Fill top row
        ld hl, _SCRN1
        ld a, TOP_LEFT_BORDER_TILE
        ld [hli], a
        call .fill_middle
        ld a, TOP_RIGHT_BORDER_TILE
        ld [hl], a
        ;; The next row will get displayed at the bottom of the screen
        ;; because the window will be disabled in the middle and that
        ;; seems to stop the hardware from counting window lines
        ld hl, _SCRN1 + SCRN_VX_B
        ld a, BOTTOM_LEFT_BORDER_TILE
        ld [hli], a
        call .fill_middle
        ld a, BOTTOM_RIGHT_BORDER_TILE
        ld [hl], a

        ;; Set the palette for the visible tiles
        ld a, 1
        ldh [rVBK], a
        ld a, BORDER_PALETTE
        ld hl, _SCRN1
        call .fill_attribute_row
        ld hl, _SCRN1 + SCRN_VY_B
.fill_attribute_row:
        ld b, SCRN_X_B
:       ld [hli], a
        dec b
        jr nz, :-
        ret
.fill_middle:
        ld a, HORIZONTAL_BORDER_TILE
        ld b, SCRN_X_B - 2
:       ld [hli], a
        dec b
        jr nz, :-
        ret

FillSideBars:
        ld hl, _SCRN0
        ld a, l
        ld c, SCRN_VY_B
.loop:
        ld [hl], b
        add a, SCRN_X_B - 1
        ld l, a
        ld [hl], b
        add a, SCRN_VX_B + 1 - SCRN_X_B
        ld l, a
        jr nc, :+
        inc h
:       dec c
        jr nz, .loop
        ret

DrawInitialScreen:
        select_sram_bank LevelStars
        enable_sram
        select_bank StarPatterns

        xor a, a
        ldh [rVBK], a

        ld hl, _SCRN0 + SCRN_VY_B + 1
        ld bc, 1                ; level number in BCD in bc
        ld de, LevelStars

.loop:
        ;; Draw the three digits of the level number
        ld a, b
        add a, "0"
        ld [hli], a
        ld a, c
        swap a
        and a, $0F
        add a, "0"
        ld [hli], a
        ld a, c
        and a, $0F
        add a, "0"
        ld [hli], a

        ;; Add the star pattern
        ld a, [de]
        inc de
        sla a
        sla a
        push de
        ld d, HIGH(StarPatterns)
        add a, LOW(StarPatterns)
        ld e, a
        jr nc, :+
        inc d
:
        REPT 3
        ld a, [de]
        inc de
        ld [hli], a
        ENDR
        pop de

        ;; Next number
        ld a, c
        add a, 1
        daa
        ld c, a
        jr nc, :+
        inc b
:
        ld a, l
        and a, SCRN_VX_B - 1
        cp a, SCRN_X_B - 1
        jr c, .loop

        ;; Move to next row
        ld a, l
        add a, SCRN_VX_B - SCRN_X_B + 2
        ld l, a
        jr nc, :+
        inc h
:
        ld a, h
        cp a, $9a
        jr c, .loop
        ld a, l
        cp a, $20
        jr c, .loop

        ret

        

SECTION "LevelSelectPalettes", ROMX
BackgroundPalettes:
        incbin "level-select-palettes.bin"
.end:   

SECTION "StarPatterns", ROMX
StarPatterns:   
        ;; never played this level before
        db 0, 0, 0, 0
        ;; zero stars
        db TICK_TILE, 0, 0, 0
        ;; one star
        db STAR_TILE, 0, 0, 0
        ;; two stars
        db MULTI_STAR_START_TILE, EVEN_STARS_END_TILE, 0, 0
        ;; three stars
        db MULTI_STAR_START_TILE, ODD_STARS_END_TILE, 0, 0
        ;; four stars
        db MULTI_STAR_START_TILE, CONTINUE_STARS_TILE, EVEN_STARS_END_TILE, 0
        ;; five stars
        db MULTI_STAR_START_TILE, CONTINUE_STARS_TILE, ODD_STARS_END_TILE, 0

SECTION "LevelSelectVariables", WRAM0
NextWXValue:    db              ; the value to set rWX to in the stat int

SECTION "LevelStars", SRAM
LevelStars::
        ds N_PUZZLES
