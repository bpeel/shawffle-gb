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

DEF N_VISIBLE_ROWS EQU SCRN_Y_B - 2
DEF N_LEVELS_PER_ROW EQU 3
DEF N_VISIBLE_LEVELS EQU N_VISIBLE_ROWS * N_LEVELS_PER_ROW

DEF TOTAL_N_ROWS EQU (N_PUZZLES + N_LEVELS_PER_ROW - 1) / N_LEVELS_PER_ROW
DEF MAX_TOP_LEVEL EQU (TOTAL_N_ROWS - N_VISIBLE_ROWS) * N_LEVELS_PER_ROW

DEF BORDER_PALETTE EQU 1

SECTION "LevelSelectCode", ROM0

LevelSelect::
        di

        call TurnOffLcd

        ;; Set up the sprite templates
        select_bank SpritesInit
        ld de, SpritesInit
        ld hl, OamMirror
        ld bc, SpritesInit.end - SpritesInit
        call MemCpy

        ;; clear the rest of the OAM mirror
        ld hl, OamMirror + SpritesInit.end - SpritesInit
        ld b, 40 * 4 - (SpritesInit.end - SpritesInit)
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

        ;; Set up the obj palette
        ld b, SpritePalettes.end - SpritePalettes
        ld hl, SpritePalettes
        call LoadObjectPalettes

        ;; Initialise variables
        xor a, a
        ld [VblankOccured], a
        ldh [rSCX], a
        ld [ScrollY], a
        ldh [rWY], a
        ld [CurKeys], a
        ld [NewKeys], a
        ld [TopLevel], a
        ld [TopLevel + 1], a
        ld [TargetTopLevel], a
        ld [TargetTopLevel + 1], a
        ld [TopLevelBCD + 1], a
        ld [CursorX], a
        ld [CursorY], a
        ld a, 1
        ld [TopLevelBCD], a
        ld a, -8
        ldh [rSCY], a

        call UpdateCursorSprites

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

        call CheckScroll

        ld a, [ScrollY]
        sub a, 8
        ldh [rSCY], a

        call UpdateKeys
        call HandleKeyPresses

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

DrawRowInternal:
        ;; hl = address in VRAM tile map data to write to
        ;; bc = first level number of row in BCD
        ;; de = pointer to level stars for first row
.loop
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

        ret

DrawRow:
        select_sram_bank LevelStars
        enable_sram
        select_bank StarPatterns

        xor a, a
        ldh [rVBK], a

        call DrawRowInternal

        disable_sram

        ret

DrawInitialScreen:
        select_sram_bank LevelStars
        enable_sram
        select_bank StarPatterns

        xor a, a
        ldh [rVBK], a

        ld hl, _SCRN0 + 1
        ld bc, 1                ; level number in BCD in bc
        ld de, LevelStars

.loop:
        call DrawRowInternal

        ;; Move to next row
        ld a, l
        add a, SCRN_VX_B - SCRN_X_B + 2
        ld l, a
        jr nc, :+
        inc h
:
        ld a, h
        cp a, HIGH(_SCRN0 + N_VISIBLE_ROWS * SCRN_VX_B)
        jr c, .loop
        ld a, l
        cp a, LOW(_SCRN0 + N_VISIBLE_ROWS * SCRN_VX_B)
        jr c, .loop

        disable_sram

        ret

DecrementTopLevel:
        ;; Decrement the two top level variables
        ld a, [TopLevel]
        sub a, N_LEVELS_PER_ROW
        ld [TopLevel], a
        jr nc, :+
        ld a, [TopLevel + 1]
        dec a
        ld [TopLevel + 1], a
:       ld a, [TopLevelBCD]
        sub a, N_LEVELS_PER_ROW
        daa
        ld [TopLevelBCD], a
        ret nc
        ld a, [TopLevelBCD + 1]
        sub a, 1
        daa
        ld [TopLevelBCD + 1], a
        ret

NextTopLine:
        ;; bc = top level for new line in BCD
        ld a, [TopLevelBCD]
        sub a, N_LEVELS_PER_ROW
        daa
        ld c, a
        ld a, [TopLevelBCD + 1]
        sbc a, 0
        daa
        ld b, a

        ;; Get a pointer to the level stars for this row in de
        ld a, [TopLevel]
        add a, LOW(LevelStars)
        ld e, a
        ld a, [TopLevel + 1]
        adc a, HIGH(LevelStars)
        ld d, a

        ;; Point hl into the VRAM where we want to write the row
        ld h, 0
        ld a, [ScrollY]
        and a, ~7
        add a, (SCRN_VY_B - 1) * 8
        ;; we don’t want to carry into h so that it will wrap around at 32
        sla a
        rl h
        sla a
        rl h
        ;; ha = (ScrollY / tile_height - 1) % 32 * 32
        inc a
        ld l, a
        ld a, h
        add a, HIGH(_SCRN0)
        ld h, a

        jp DrawRow

IncrementTopLevel:
        ;; Increment the two top level variables
        ld a, [TopLevel]
        add a, N_LEVELS_PER_ROW
        ld [TopLevel], a
        jr nc, :+
        ld a, [TopLevel + 1]
        inc a
        ld [TopLevel + 1], a
:       ld a, [TopLevelBCD]
        add a, N_LEVELS_PER_ROW
        daa
        ld [TopLevelBCD], a
        ret nc
        ld a, [TopLevelBCD + 1]
        add a, 1
        daa
        ld [TopLevelBCD + 1], a
        ret

NextBottomLine:
        ;; Get the BCD level number of the bottom row into bc
        ld a, [TopLevelBCD]
        add a, ((N_VISIBLE_LEVELS / 10) << 4) | (N_VISIBLE_LEVELS % 10)
        daa
        ld c, a
        ld a, [TopLevelBCD + 1]
        jr nc, :+
        add a, 1
        daa
:       ld b, a

        ;; Get a pointer to the level stars for this row in de
        ld a, [TopLevel]
        add a, LOW(N_VISIBLE_LEVELS + LevelStars)
        ld e, a
        ld a, [TopLevel + 1]
        adc a, HIGH(N_VISIBLE_LEVELS + LevelStars)
        ld d, a

        ;; Point hl into the VRAM where we want to write the row
        ld h, 0
        ld a, [ScrollY]
        and a, ~7
        add a, N_VISIBLE_ROWS * 8
        ;; we don’t want to carry into h so that it will wrap around at 32
        sla a
        rl h
        sla a
        rl h
        ;; ha = (ScrollY / tile_height + N_VISIBLE_ROWS) % 32 * 32
        inc a
        ld l, a
        ld a, h
        add a, HIGH(_SCRN0)
        ld h, a

        jp DrawRow

CheckScroll:
        ld a, [TopLevel]
        ld c, a
        ld a, [TopLevel + 1]
        ld hl, TargetTopLevel + 1
        cp a, [hl]
        jr c, .less
        jr nz, .greater
        dec hl
        ld a, c
        cp a, [hl]
        jr c, .less
        ret z
.greater:
        ld a, [ScrollY]
        and a, 7
        ;; If the next row of levels is about to become visible then
        ;; load it in
        call z, NextTopLine
        ld a, [ScrollY]
        dec a
        ld [ScrollY], a
        and a, 7
        ;; If we’ve reached a full tile then decrement the top level
        and a, 7
        jp z, DecrementTopLevel
        ret
.less:
        ld a, [ScrollY]
        and a, 7
        ;; If the next row of levels is about to become visible then
        ;; load it in
        call z, NextBottomLine
        ld a, [ScrollY]
        inc a
        ld [ScrollY], a
        ;; If we’ve reached a full tile then increment the top level
        and a, 7
        jp z, IncrementTopLevel
        ret

HandleKeyPresses:
        ld a, [NewKeys]
        cp a, $40
        jp z, HandleUp
        cp a, $80
        jp z, HandleDown
        cp a, $01
        jp z, HandleA
        ret

HandleUp:
        ld a, [TargetTopLevel]
        sub a, N_LEVELS_PER_ROW
        ld c, a
        ld a, [TargetTopLevel + 1]
        sbc a, 0
        ret c                   ; don’t go below 0
        ld [TargetTopLevel + 1], a
        ld a, c
        ld [TargetTopLevel], a
        ret

HandleDown:
        ld a, [TargetTopLevel]
        add a, N_LEVELS_PER_ROW
        ld c, a
        ld a, [TargetTopLevel + 1]
        adc a, 0
        cp a, HIGH(MAX_TOP_LEVEL + 1)
        jr c, .ok
        ld b, a
        ld a, c
        cp a, LOW(MAX_TOP_LEVEL + 1)
        ret nc
        ld a, b
.ok:
        ld [TargetTopLevel + 1], a
        ld a, c
        ld [TargetTopLevel], a
        ret

HandleA:
        ;; Pop return address
        pop af
        jp Game

UpdateCursorSprites:
        ld a, [CursorX]
        ;; multiply by 48 (= a*32+a*16)
        sla a
        sla a
        sla a
        sla a
        ld b, a
        sla a
        add a, b
        add a, 8 + 8 - 4
        ld [OamMirror + 0 * 4 + 1], a
        ld [OamMirror + 2 * 4 + 1], a
        add a, 3 * 8
        ld [OamMirror + 1 * 4 + 1], a
        ld [OamMirror + 3 * 4 + 1], a

        ld a, [CursorY]
        ;; multiply by 8
        sla a
        sla a
        sla a
        add a, 16 + 8 - 4
        ld [OamMirror + 0 * 4], a
        ld [OamMirror + 1 * 4], a
        add a, 8
        ld [OamMirror + 2 * 4], a
        ld [OamMirror + 3 * 4], a

        ret

SECTION "LevelSelectPalettes", ROMX
BackgroundPalettes:
        incbin "level-select-palettes.bin"
.end:   
SpritePalettes:
        incbin "level-select-sprite-palettes.bin"
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
        ;; Level number at the top of the screen in binary (first = 0)
TopLevel:       dw
        ;; Same number but plus one and in BCD
TopLevelBCD:    dw
        ;; Number that we want TopLevel to be. If this isn’t the same
        ;; as TopLevel then the screen will slowly scroll in the right
        ;; direction.
TargetTopLevel: dw
        ;; Scroll position of the top of the list. This will be
        ;; subtracted by 8 and then copied into rSCY to compensate for
        ;; the top border.
ScrollY:        db
CursorX:        db
CursorY:        db

SECTION "LevelSelectSpritesInit", ROMX
SpritesInit:
        ;; Main cursor
        db 0, 0
        db CURSOR_TILE
        db 0

        db 0, 0
        db CURSOR_TILE
        db OAMF_XFLIP

        db 0, 0
        db CURSOR_TILE
        db OAMF_YFLIP

        db 0, 0
        db CURSOR_TILE
        db OAMF_XFLIP | OAMF_YFLIP
.end:
