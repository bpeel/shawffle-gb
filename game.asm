INCLUDE "hardware.inc"
INCLUDE "charmap.inc"
INCLUDE "utils.inc"
INCLUDE "globals.inc"

MACRO multiply_by_tile_size
        ;; multiply a by 24 (= three tiles, the size of a letter tile)
        sla a
        sla a
        sla a
        ld b, a
        sla a
        add a, b
ENDM

MACRO update_cursor_sprites
        ;; arg1: Sprite number
        ld a, [CursorX]
        multiply_by_tile_size
        add a, BOARD_X * 8 - CURSOR_X_OFFSET + 8
        ld [OamMirror + (\1) * 4 + 1], a
        ld [OamMirror + ((\1) + 2) * 4 + 1], a
        add a, CURSOR_RIGHT_OFFSET
        ld [OamMirror + ((\1) + 1) * 4 + 1], a
        ld [OamMirror + ((\1) + 3) * 4 + 1], a

        ld a, [CursorY]
        multiply_by_tile_size
        add a, BOARD_Y * 8 - CURSOR_Y_OFFSET + 16
        ld [OamMirror + (\1) * 4], a
        ld [OamMirror + ((\1) + 1) * 4], a
        add a, CURSOR_BOTTOM_OFFSET
        ld [OamMirror + ((\1) + 2) * 4], a
        ld [OamMirror + ((\1) + 3) * 4], a
ENDM

MACRO queue_message
        ld a, (\1 - Messages) / MESSAGE_LENGTH
        ld [QueuedMessage], a
ENDM

        ;; Offset from BackgroundTiles to the three tiles that form the
        ;; background of a letter
DEF LETTER_TEMPLATE_OFFSET EQU 16 * 4

DEF PUZZLES_PER_BANK EQU 341
DEF BYTES_PER_PUZZLE EQU 48

DEF TILES_PER_PUZZLE EQU 5 * 3 + 3 * 2

DEF TILE_INCORRECT EQU 0
DEF TILE_WRONG_POS EQU 1
DEF TILE_CORRECT EQU 2

DEF GAME_LCDC EQU \
        LCDCF_ON | \
        LCDCF_BG8000 | \
        LCDCF_OBJON | \
        LCDCF_OBJ8 | \
        LCDCF_BG9800 | \
        LCDCF_WIN9C00 | \
        LCDCF_WINON

DEF CURSOR_X_OFFSET EQU 1
DEF CURSOR_Y_OFFSET EQU 1
DEF CURSOR_RIGHT_OFFSET EQU 18
DEF CURSOR_BOTTOM_OFFSET EQU 17

DEF BOARD_X EQU 1               ; Position of the board in tiles
DEF BOARD_Y EQU 1

DEF CURSOR_SPRITE_NUM EQU 0
DEF SELECTION_SPRITE_NUM EQU 4
DEF STAR_SPRITE_NUM EQU 8

DEF MESSAGE_X EQU BOARD_X
DEF MESSAGE_Y EQU SCRN_Y_B - 1

DEF SWAPS_REMAINING_X EQU MESSAGE_X + 1
DEF SWAPS_REMAINING_Y EQU MESSAGE_Y

DEF INITIAL_SWAPS EQU 15

DEF MESSAGE_LENGTH EQU 16

DEF FILLED_STAR_PALETTE EQU 2
DEF EMPTY_STAR_PALETTE EQU 3
DEF STARS_X EQU BOARD_X * 8 + (5 * 3 * 8) / 2 - (5 * 2 - 1) * 8 / 2
DEF STARS_Y EQU (MESSAGE_Y - 1) * 8

DEF PUZZLE_NUMBER_X EQU 17
DEF PUZZLE_NUMBER_Y EQU 6

DEF VISIBLE_WINDOW_POS EQU SCRN_Y - 4 * 8
DEF N_MENU_OPTIONS EQU 3
DEF MENU_CURSOR_X EQU 3

SECTION "GameCode", ROM0

Game::
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

        ;; Initialise variables
        xor a, a
        ld [VblankOccured], a
        ldh [rSCX], a
        ldh [rSCY], a
        ld [CursorX], a
        ld [CursorY], a
        ld [WindowVisible], a
        ld [MenuCursor], a
        ld a, 1
        ld [SwapsRemainingQueued], a
        ld [MenuCursorDirty], a
        ld a, $ff
        ld [SelectionPos], a
        ld [QueuedSwap], a
        ld [NextPaletteLine], a
        ld [QueuedMessage], a
        ld a, (INITIAL_SWAPS / 10 << 4) | (INITIAL_SWAPS % 10)
        ld [SwapsRemaining], a
        ld a, 7
        ld [rWX], a
        ld a, SCRN_Y
        ldh [rWY], a
        ld [WindowY], a
        ldh [rLYC], a

        ;; Set up the bg palette
        select_bank BackgroundPalettes
        ld b, BackgroundPalettes.end - BackgroundPalettes
        ld hl, BackgroundPalettes
        call LoadBackgroundPalettes

        ;; Set up the obj palette
        ld b, SpritePalettes.end - SpritePalettes
        ld hl, SpritePalettes
        call LoadObjectPalettes

        call LoadSharedTiles

        ;; Load the background data
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

        ;; Load the window data
        select_bank MenuTileMap
        xor a, a
        ldh [rVBK], a
        ld de, MenuTileMap
        ld hl, _SCRN1
        ld b, (MenuTileMap.end - MenuTileMap) / SCRN_X_B
        call CopyScreenMapRows
        ld a, 1
        ldh [rVBK], a
        ld de, MenuTileAttribs
        ld hl, _SCRN1
        ld b, (MenuTileAttribs.end - MenuTileAttribs) / SCRN_X_B
        call CopyScreenMapRows

        call DrawPuzzleNumber

        ld a, [CurrentPuzzle]
        ld c, a
        ld a, [CurrentPuzzle + 1]
        ld b, a
        call SetPuzzle

        ;; Prepare the stat interrupt
        ld a, LOW(Stat)
        ld [StatJumpAddress], a
        ld a, HIGH(Stat)
        ld [StatJumpAddress + 1], a
        ld a, STATF_LYC
        ldh [rSTAT], a

        ;; Clear any pending interrupts
        xor a, a
        ldh [rIF], a

        ;; Enable the vblank and stat interrupts
        ld a, IEF_VBLANK | IEF_STAT
        ldh [rIE], a
        ei

        ; Enable the LCD
        ld a, GAME_LCDC
        ldh [rLCDC], a

MainLoop:
        call WaitVBlank

        ld a, [WindowY]
        ldh [rWY], a
        ldh [rLYC], a
        ld a, GAME_LCDC
        ldh [rLCDC], a

        ld a, [QueuedSwap]
        cp a, $ff
        jr z, .handled_swap
        call HandleSwap
        jr .did_work            ; only do one thing per vblank
.handled_swap:

        ld a, [NextPaletteLine]
        cp a, 5
        jr nc, .handled_palettes
        inc a
        ld [NextPaletteLine], a
        dec a
        call SetTilePalettesForRow
        jr .did_work
.handled_palettes:

        ld a, [QueuedMessage]
        cp a, $ff
        jr z, .handled_message
        call FlushMessage
        jr .did_work
.handled_message:

        ld a, [SwapsRemainingQueued]
        or a, a
        jr z, .handled_swaps_remaining
        call FlushSwapsRemaining
        jr .did_work
.handled_swaps_remaining:

        ld a, [MenuCursorDirty]
        or a, a
        jr z, .handled_menu_cursor
        call UpdateMenuCursor
        jr .did_work
.handled_menu_cursor

.did_work:       
        call UpdateKeys
        call HandleKeyPresses
        call UpdateWindow

        jr MainLoop

SetPuzzle:
        ;; bc = puzzle
        call LoadPuzzle
        call ExtractPuzzleTiles
        call PositionTiles
        call InitTileStates
        call FindWrongPositions
        jp SetTilePalettes

ExtractPuzzleTiles:
        xor a, a
        ldh [rVBK], a
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
        select_bank Tiles
        ld de, Tiles + LETTER_TEMPLATE_OFFSET
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
        ;; de = bc * 16
        ld d, b
        ld e, c
        REPT 4
        sla e
        rl d
        ENDR
        ld h, d
        ld a, e                 ; store bc * 16 in ha
        sla e
        rl d                    ; de = bc * 32
        add a, e                ; add the two multiplications to get bc * 48
        ld e, a
        ld a, d
        adc h
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
        ld hl, _SCRN0 + (BOARD_Y * 32) + BOARD_X + 1
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

HandleSwap:
        xor a, a
        ldh [rVBK], a
        ld a, [QueuedSwap]
        call .update_letter_tile
        ld a, $ff
        ld [QueuedSwap], a
        ld a, [QueuedSwap + 1]
.update_letter_tile:
        ld e, a
        add a, LOW(TilePositions)
        ld l, a
        ld h, HIGH(TilePositions)
        ld a, [hl]
        ld b, a
        sla a
        add a, b                ; a *= 3
        add a, FIRST_LETTER_TILE
        ld d, a

        ld a, e
        call PosToXY
        ld b, a
        sla a
        add a, b                ; a *= 3
        add a, BOARD_X + 1
        ld b, a
        ld a, c
        sla a
        add a, c                ; a = y_pos * 3
        add a, BOARD_Y
        ld h, 0
        REPT 5
        sla a
        rl h
        ENDR                    ; ha = a * 32
        add a, b
        jr nc, :+
        inc h
:       ld l, a
        ld a, h
        add a, HIGH(_SCRN0)
        ld h, a
        ld [hl], d
        inc d
        ld a, l
        add a, 32
        ld l, a
        jr nc, :+
        inc h
:       ld [hl], d
        inc d
        add a, 32
        ld l, a
        jr nc, :+
        inc h
:       ld [hl], d
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

FindWrongPositionsForWord:
        ;; de = pointer to list of word offsets
        ;; leaves de after end of list of offsets
        xor a, a
        ld [UsedLetters], a
        ;; Find letters that are already in the correct position and
        ;; mark them as used
        ld h, HIGH(TileStates)
        ld bc, $0105            ; b = bit for letter, c = counter
        push de
.find_used_letters_loop:
        ld a, [de]
        inc de
        add a, LOW(TileStates)
        ld l, a
        ld a, [hl]
        cp a, TILE_CORRECT
        jr nz, .not_correct
        ld a, [UsedLetters]
        or a, b
        ld [UsedLetters], a
.not_correct:
        sla b
        dec c
        jr nz, .find_used_letters_loop
        pop de
        ld a, [UsedLetters]
        ld [CorrectLetters], a

        ;; Iterate through each letter to check if there is a matching
        ;; unused tile
        ld bc, $0100            ; b = bit for letter, c = counter
.outer_loop:
        ld a, [CorrectLetters]  ; skip letters that are already correct
        and a, b
        jr nz, .next_letter
        ;; extract the letter that we’re looking for and store it in
        ;; SearchLetter
        ld a, [de]
        add a, LOW(PuzzleLetters)
        ld l, a
        ld h, HIGH(PuzzleLetters)
        ld a, [hl]
        ld [SearchLetter], a
        ;; look for an unused letter matching it
        push bc
        push de
        ld a, e
        sub a, c                ; put de back to start
        ld e, a
        jr nc, :+
        dec d
:       ld bc, $0105            ; b = bit, c = counter
.inner_loop:
        ld a, [UsedLetters]
        and a, b
        jr nz, .next_inner_letter
        ld a, [de]
        add a, LOW(TilePositions)
        ld l, a
        ld h, HIGH(TilePositions)
        ld a, [hl]
        add a, LOW(PuzzleLetters)
        ld l, a
        ld h, HIGH(PuzzleLetters)
        ld l, [hl]
        ld a, [SearchLetter]
        cp a, l
        jr nz, .next_inner_letter
        ;; we’ve found a letter, so mark it as used
        ld a, [UsedLetters]
        or a, b
        ld [UsedLetters], a
        ;; change the state of the letter
        ld a, [de]
        add a, LOW(TileStates)
        ld l, a
        ld h, HIGH(TileStates)
        ld a, TILE_WRONG_POS
        ld [hl], a
        jr .end_inner_loop

.next_inner_letter:
        inc de
        sla b
        dec c
        jr nz, .inner_loop
.end_inner_loop:
        pop de
        pop bc

.next_letter:
        inc de
        sla b
        ld a, c
        inc a
        ld c, a
        cp a, 5
        jr c, .outer_loop
        ret

FindWrongPositions:
        select_bank WordPositions
        ld de, WordPositions
        REPT 5
        call FindWrongPositionsForWord
        ENDR
        jp FindWrongPositionsForWord

SetTilePalettesForRow:
        ;; a = row

        ;; get index of first tile in row into a
        ld b, a
        sla a
        sla a
        add a, b                ; a = y * 5
        ld c, b
        res 0, c                ; mask out bottom bit of c
        sub a, c                ; a -= 2 * (y / 2) to compensate for gaps
        ld d, HIGH(TileStates)
        add a, LOW(TileStates)
        ld e, a
        jr nc, :+
        inc d
:
        ;; get b*96 into ha
        ld h, 0
        ld a, b
        REPT 5
        sla a
        ENDR
        ld c, a                 ; c = row*32 (should fit in a byte)
        sla a
        rl h                    ; ha = row*64 (might overflow a byte)
        add a, c
        jr nc, :+
        inc h
:
        ;; add the address of the first tile of the grid
        DEF first_tile = _SCRN0 + (BOARD_Y * 32) + BOARD_X
        add a, LOW(first_tile)
        ld l, a
        ld a, h
        adc a, HIGH(first_tile)
        ld h, a
        PURGE first_tile
        
        ld a, 1
        ldh [rVBK], a

        ld c, 5
.loop:  
        ld a, c
        xor a, 1
        and a, b
        bit 0, a                ; skip gaps when c is even and b is odd
        jr z, .not_gap
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
        jr nz, .loop
        ret

SetTilePalettes:
        ld a, 4
.loop:
        push af
        call SetTilePalettesForRow
        pop af
        sub a, 1
        jr nc, .loop
        ret        

HandleKeyPresses:
        ld a, [NewKeys]
        cp a, BUTTON_RIGHT
        jp z, HandleRight
        cp a, BUTTON_LEFT
        jp z, HandleLeft
        cp a, BUTTON_UP
        jp z, HandleUp
        cp a, BUTTON_DOWN
        jp z, HandleDown
        cp a, BUTTON_A
        jp z, HandleA
        cp a, BUTTON_B
        jp z, HandleB
        cp a, BUTTON_START
        jp z, HandleStart
        cp a, BUTTON_SELECT
        jp z, HandleSelect
        ret

HandleRight:
        ld a, [WindowVisible]
        or a, a
        ret nz
        ld a, [CursorX]
        cp a, 4
        ret nc
        inc a
        ld [CursorX], a
        ld b, a
        ld a, [CursorY]
        and a, b
        bit 0, a                ; if both are odd then we’re on a gap
        jp z, UpdateCursorSprites
        ld a, b
        inc a
        ld [CursorX], a
        jp UpdateCursorSprites

HandleLeft:
        ld a, [WindowVisible]
        or a, a
        ret nz
        ld a, [CursorX]
        or a, a
        ret z
        dec a
        ld [CursorX], a
        ld b, a
        ld a, [CursorY]
        and a, b
        bit 0, a                ; if both are odd then we’re on a gap
        jp z, UpdateCursorSprites
        ld a, b
        dec a
        ld [CursorX], a
        jp UpdateCursorSprites

HandleUp:
        ld a, [WindowVisible]
        or a, a
        jr nz, .window
        ld a, [CursorY]
        or a, a
        ret z
        dec a
        ld [CursorY], a
        ld b, a
        ld a, [CursorX]
        and a, b
        bit 0, a                ; if both are odd then we’re on a gap
        jp z, UpdateCursorSprites
        ld a, b
        dec a
        ld [CursorY], a
        jp UpdateCursorSprites

.window:
        ld a, [MenuCursor]
        sub a, 1
        jr nc, :+
        ld a, N_MENU_OPTIONS - 1
:       ld [MenuCursor], a
        ld a, 1
        ld [MenuCursorDirty], a
        ret

HandleDown:
        ld a, [WindowVisible]
        or a, a
        jp nz, NextMenuOption
        ld a, [CursorY]
        cp a, 4
        ret nc
        inc a
        ld [CursorY], a
        ld b, a
        ld a, [CursorX]
        and a, b
        bit 0, a                ; if both are odd then we’re on a gap
        jp z, UpdateCursorSprites
        ld a, b
        inc a
        ld [CursorY], a
        jp UpdateCursorSprites

HandleA:
        ld a, [WindowVisible]
        or a, a
        jp nz, .window

        ld a, [SwapsRemaining]
        or a, a
        ret z                   ; don’t allowing swapping if no swaps remain

        ld a, [CursorX]
        ld b, a
        ld a, [CursorY]
        ld c, a
        call XYToPos
        ld b, a
        add a, LOW(TileStates)
        ld l, a
        ld h, HIGH(TileStates)
        ld a, [hl]
        cp a, TILE_CORRECT
        ret z                    ; don’t allow selecting tiles in correct pos

        ld a, [SelectionPos]
        cp a, $ff
        jr z, .set_selection

        cp a, b
        ret z                   ; don’t allow swapping the same index

        ;; if we make it here we have two valid indices to swap in a and b
        ld hl, QueuedSwap
        ld [hli], a
        ld [hl], b

        add a, LOW(TilePositions)
        ld l, a
        ld h, HIGH(TilePositions)
        ld a, b
        add a, LOW(TilePositions)
        ld e, a
        ld d, HIGH(TilePositions)
        ;; hl and de now point to the bytes to swap
        ld a, [de]
        ld b, [hl]
        ld [hl], a
        ld a, b
        ld [de], a

        xor a, a
        ld [NextPaletteLine], a

        call InitTileStates
        call FindWrongPositions
        call RemoveSelection

        call CheckWin
        jp nz, DecrementSwapsRemaining
        jp ShowWinMessage

.set_selection:
        ld a, b
        ld [SelectionPos], a
        update_cursor_sprites SELECTION_SPRITE_NUM
        ret

.window:
        ld a, [MenuCursor]
        or a, a
        jr z, .continue
        pop bc                  ; pop the return address
        cp a, 1
        jp z, Game              ; Restart the puzzle
        jp LevelSelect          ; back to puzzle select screen
.restart:
        pop af                  ; pop the return address
.continue:
        ld [WindowVisible], a   ; set WindowVisible to 0
        ret

HandleB:
        ld a, [WindowVisible]
        or a, a
        ret nz
        jp RemoveSelection

HandleStart:
        ld a, [WindowVisible]
        xor a, 1
        ld [WindowVisible], a
        ret z
        xor a, a
        ld [MenuCursor], a
        inc a
        ld [MenuCursorDirty], a
        ret

HandleSelect:
        assert @ - NextMenuOption == 0

NextMenuOption:
        ld a, [MenuCursor]
        inc a
        cp a, N_MENU_OPTIONS
        jr c, :+
        ld a, 0                 ; wrap around to the first option
:       ld [MenuCursor], a
        ld a, 1
        ld [MenuCursorDirty], a
        ret

UpdateCursorSprites:
        update_cursor_sprites CURSOR_SPRITE_NUM
        ret

RemoveSelection:
        xor a, a
        ld [OamMirror + SELECTION_SPRITE_NUM * 4], a
        ld [OamMirror + (SELECTION_SPRITE_NUM + 1) * 4], a
        ld [OamMirror + (SELECTION_SPRITE_NUM + 2) * 4], a
        ld [OamMirror + (SELECTION_SPRITE_NUM + 3) * 4], a
        dec a
        ld [SelectionPos], a
        ret

DecrementSwapsRemaining:
        ld a, [SwapsRemaining]
        sub a, 1
        daa
        ld [SwapsRemaining], a
        jr z, .too_bad
        cp a, 1
        jr z, .one_left

        ld a, 1
        ld [SwapsRemainingQueued], a
        ret
.too_bad:
        queue_message TooBadMessage
        ld a, 1
        ld [SwapsRemainingQueued], a
        ret
.one_left:
        queue_message OneSwapLeftMessage
        ret

ShowWinMessage:
        ld a, [SwapsRemaining]
        ;; SwapsRemaining hasn’t been decremented, so it is the same
        ;; as the score value
        ld c, a

        ;; get the old score
        select_sram_bank LevelStars
        enable_sram
        ld hl, CurrentPuzzle
        ld a, LOW(LevelStars)
        add a, [hl]
        ld e, a
        inc hl
        ld a, HIGH(LevelStars)
        adc a, [hl]
        ld d, a
        ld a, [de]
        ;; is the new score better?
        cp a, c
        jr nc, :+
        ld a, c
        ld [de], a
:       disable_sram

        dec c                   ; get the number of stars (score-1)
        ld a, c
        add a, (WinMessages - Messages) / MESSAGE_LENGTH
        ld [QueuedMessage], a

        ld b, 5
        ld hl, OamMirror + (STAR_SPRITE_NUM + 5) * 4 - 1
        ld d, STARS_X + 4 * 16 + 8
        ld e, EMPTY_STAR_PALETTE
.loop:
        ld a, c
        cp a, b
        jr nz, :+
        ld e, FILLED_STAR_PALETTE
:       ld [hl], e
        dec hl
        ld [hl], STAR_TILE
        dec hl
        ld [hl], d
        dec hl
        ld a, d
        sub a, 16
        ld d, a
        ld [hl], STARS_Y + 16
        dec hl
        dec b
        jr nz, .loop
        
        ret

FlushMessage:
        xor a, a
        ldh [rVBK], a
        select_bank Messages
        ld a, [QueuedMessage]
        assert MESSAGE_LENGTH == 16
        swap a                  ; multiply a by 16
        ld h, HIGH(Messages)
        add a, LOW(Messages)
        ld l, a
        jr nc, :+
        inc h
:       ld de, _SCRN0 + MESSAGE_Y * SCRN_VY_B + MESSAGE_X
        ld c, MESSAGE_LENGTH
:       ld a, [hli]
        ld [de], a
        inc de
        dec c
        jr nz, :-

        ld a, $ff
        ld [QueuedMessage], a
        ret

FlushSwapsRemaining:
        xor a, a
        ld [SwapsRemainingQueued], a
        ld a, [SwapsRemaining]
        or a, a
        jr z, .game_over

        ld b, a
        xor a, a
        ldh [rVBK], a
        ld a, b
        swap a
        and a, $0f
        jr nz, :+
        ld a, " " - "0"
:       add a, "0"
        ld [_SCRN0 + SWAPS_REMAINING_Y * SCRN_VX_B + SWAPS_REMAINING_X], a
        ld a, b
        and a, $0f
        add a, "0"
        ld [_SCRN0 + SWAPS_REMAINING_Y * SCRN_VX_B + SWAPS_REMAINING_X + 1], a
        ret

.game_over:
        select_bank SadPalettes
        ld b, SadPalettes.end - SadPalettes
        ld hl, SadPalettes
        jp LoadBackgroundPalettes

CheckWin:
        ;; Check whether the player has put all the tiles in the right
        ;; place and return the result in the z flag
        ld b, TILES_PER_PUZZLE
        ld hl, TileStates
.loop:
        ld a, [hli]
        cp a, TILE_CORRECT
        ret nz                  ; return if not correct, zero flag is not set
        dec b
        jr nz, .loop
        ret                     ; zero flag is set

XYToPos:
        ;; Given an x,y position in b,c, return the grid position in
        ;; a. This can be used as an index into PuzzleLetters etc.
        ld a, c
        sla a
        sla a
        add a, c                ; a = y * 5
        add a, b                ; a += x
        sra c
        jp nc, :+               ; are we on an odd line?
        sra b
        sub a, b                ; a -= x/2 (to compensate for gaps on odd lines)
:       sla c
        sub a, c                ; a -= 2 * (y / 2) to compensate for gaps
        ret

PosToXY:
        ;; Given a grid index in a, return the x and y position in a,c
        ld c, 0
        REPT 2
        cp a, 5
        ret c
        inc c
        sub a, 5
        cp a, 3
        jr c, .end_on_odd_line
        sub a, 3
        inc c
        ENDR
        ret
.end_on_odd_line:
        sla a                   ; a *= 2 to compensate for gaps
        ret

DrawPuzzleNumber:
        xor a, a
        ldh [rVBK], a
        ld a, [CurrentPuzzle]
        add a, 1
        ld e, a
        ld a, [CurrentPuzzle + 1]
        adc a, 0
        ld d, a
        ld l, 10
        call Divide
        ld a, c
        add a, "0"
        ld [_SCRN0 + PUZZLE_NUMBER_Y * SCRN_VX_B + PUZZLE_NUMBER_X + 2], a
        ld e, b
        ld d, 0
        call Divide
        ld a, c
        add a, "0"
        ld [_SCRN0 + PUZZLE_NUMBER_Y * SCRN_VX_B + PUZZLE_NUMBER_X + 1], a
        ld a, b
        add a, "0"
        ld [_SCRN0 + PUZZLE_NUMBER_Y * SCRN_VX_B + PUZZLE_NUMBER_X], a
        ret

UpdateWindow:
        ld a, [WindowVisible]
        or a, a
        ld a, [WindowY]
        jr z, .invisible
        sub a, 2
        cp a, VISIBLE_WINDOW_POS
        ret c
        ld [WindowY], a
        ret
.invisible:
        cp a, SCRN_Y
        ret nc
        add a, 2
        ld [WindowY], a
        ret

UpdateMenuCursor:
        xor a, a
        ldh [rVBK], a
        ld [MenuCursorDirty], a
        FOR N, N_MENU_OPTIONS
        ld [_SCRN1 + (N + 1) * SCRN_VX_B + MENU_CURSOR_X], a
        ENDR
        ld h, HIGH(_SCRN1 + 1 * SCRN_VX_B + MENU_CURSOR_X)
        ld a, [MenuCursor]
        swap a
        sla a                   ; a *= 32
        add a, LOW(_SCRN1 + 1 * SCRN_VX_B + MENU_CURSOR_X)
        ld l, a
        jr nc, :+
        inc h
:       ld a, MENU_CURSOR_TILE
        ld [hl], a
        ret

Stat:
        push af
        ;; disable objects when we reach the window
        ld a, GAME_LCDC & ~LCDCF_OBJON
        ldh [rLCDC], a
        pop af
        reti

SECTION "GameVariables", WRAM0
UsedLetters:    db
CorrectLetters: db
SearchLetter:   db
CursorX:        db
CursorY:        db
SelectionPos:   db              ; tile index or $ff if not set
QueuedSwap:     ds 2            ; swap to do during vblank or $ff if none
QueuedMessage:  db
NextPaletteLine: db
        ;; If non-zero then we need to update the swaps remaining
        ;; during vblank, either by updating the number or by setting
        ;; the palette to sad colours.
SwapsRemainingQueued:    db
SwapsRemaining: db              ; coded in BCD
WindowY:        db              ; position to set the window to on vblank
WindowVisible:  db              ; 1 or 0
MenuCursor:     db
MenuCursorDirty: db

SECTION "GameState", WRAM0, ALIGN[BITWIDTH(TILES_PER_PUZZLE * 3 - 1)]
PuzzleLetters:  ds TILES_PER_PUZZLE
TilePositions:  ds TILES_PER_PUZZLE
TileStates:      ds TILES_PER_PUZZLE
        
SECTION "LetterTiles", ROMX
LetterTiles:
        incbin "letter-tiles.bin"

SECTION "Palettes", ROMX
BackgroundPalettes:
        incbin "background-palettes.bin"
.end:
SpritePalettes:
        incbin "sprite-palettes.bin"
.end:

SECTION "SadPalettes", ROMX
SadPalettes:
        dw 15 * %0000100001000010
        dw 12 * %0000100001000010
        dw 12 * %0000100001000010
        dw 15 * %0000100001000010
        REPT 2
        dw 15 * %0000100001000010
        dw 0 * %0000100001000010
        dw 0 * %0000100001000010
        dw 15 * %0000100001000010
        ENDR
.end:

SECTION "Puzzles", ROMX
Puzzles:
        incbin "puzzles.bin", 0, PUZZLES_PER_BANK * BYTES_PER_PUZZLE

SECTION "Puzzles2", ROMX
Puzzles2:
        incbin "puzzles.bin", PUZZLES_PER_BANK * BYTES_PER_PUZZLE
        assert (@ - Puzzles2) / BYTES_PER_PUZZLE \
               + PUZZLES_PER_BANK \
               == N_PUZZLES
.end

SECTION "WordPositions", ROMX
WordPositions:
        ;; Tile positions for each letter in each of the six words

        ;; 0  1   2  3  4
        ;; 5      6     7
        ;; 8  9  10 11 12
        ;; 13    14    15
        ;; 16 17 18 19 20

        db 0, 1, 2, 3, 4
        db 8, 9, 10, 11, 12
        db 16, 17, 18, 19, 20

        db 0, 5, 8, 13, 16
        db 2, 6, 10, 14, 18
        db 4, 7, 12, 15, 20

SECTION "SpritesInit", ROMX
SpritesInit:
        ;; Main cursor
        db BOARD_Y * 8 - CURSOR_Y_OFFSET + 16
        db BOARD_X * 8 - CURSOR_X_OFFSET + 8
        db CURSOR_TILE
        db 0

        db BOARD_Y * 8 - CURSOR_Y_OFFSET + 16
        db BOARD_X * 8 - CURSOR_X_OFFSET + CURSOR_RIGHT_OFFSET + 8
        db CURSOR_TILE
        db OAMF_XFLIP

        db BOARD_Y * 8 - CURSOR_Y_OFFSET + CURSOR_BOTTOM_OFFSET + 16
        db BOARD_X * 8 - CURSOR_X_OFFSET + 8
        db CURSOR_TILE
        db OAMF_YFLIP

        db BOARD_Y * 8 - CURSOR_Y_OFFSET + CURSOR_BOTTOM_OFFSET + 16
        db BOARD_X * 8 - CURSOR_X_OFFSET + CURSOR_RIGHT_OFFSET + 8
        db CURSOR_TILE
        db OAMF_XFLIP | OAMF_YFLIP

        ;; Selection
        db 0, 0
        db CURSOR_TILE
        db 1

        db 0, 0
        db CURSOR_TILE
        db OAMF_XFLIP | 1

        db 0, 0
        db CURSOR_TILE
        db OAMF_YFLIP | 1

        db 0, 0
        db CURSOR_TILE
        db OAMF_XFLIP | OAMF_YFLIP | 1
.end:   

SECTION "Messages", ROMX

        MACRO message
        ds (15 - STRLEN(\1)) / 2, " "
        db \1
        ds MESSAGE_LENGTH - (15 - STRLEN(\1)) / 2 - STRLEN(\1), " "
        ENDM

Messages:
OneSwapLeftMessage:
        message "1 𐑕𐑢𐑪𐑐 𐑤𐑧𐑓𐑑"
TooBadMessage:
        message "𐑑𐑵 𐑚𐑨𐑛"
WinMessages:
        message "𐑡𐑳𐑕𐑑 𐑥𐑱𐑛 𐑦𐑑!"
        message "𐑿 𐑛𐑦𐑛 𐑦𐑑!"
        message "𐑯𐑪𐑑 𐑚𐑨𐑛!"
        message "𐑝𐑧𐑮𐑦 𐑜𐑫𐑛!"
        message "𐑧𐑒𐑕𐑩𐑤𐑩𐑯𐑑!"
        message "𐑐𐑻𐑓𐑦𐑒𐑑!"
