INCLUDE "hardware.inc"
INCLUDE "utils.inc"
INCLUDE "globals.inc"

DEF TITLE_SCREEN_LCDC EQU \
        LCDCF_ON | \
        LCDCF_BG8000 | \
        LCDCF_BG9800

SECTION "TitleScreenCode", ROM0

TitleScreen::
        di

        call TurnOffLcd

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

        ;; Load the tile data
        xor a, a
        ldh [rVBK], a
        select_bank TileData
        ld de, TileData
        ld hl, $8000
        ld bc, TileData.end - TileData
        call MemCpy

        ;; Load the tile map
        select_bank TileMap
        ld de, TileMap
        ld hl, $9800
        call CopyScreenMap

        ;; Load the attributes
        ld a, 1
        ldh [rVBK], a
        select_bank TileAttributes
        ld de, TileAttributes
        ld hl, $9800
        call CopyScreenMap

        ;; Clear any pending interrupts
        xor a, a
        ldh [rIF], a

        ;; Enable the vblank interrupt
        ld a, IEF_VBLANK
        ldh [rIE], a
        ei

        ; Enable the LCD
        ld a, TITLE_SCREEN_LCDC
        ldh [rLCDC], a

MainLoop:
        call WaitVBlank

        call UpdateKeys

        ld a, [NewKeys]
        and a, BUTTON_A | BUTTON_START ; is start or a pressed?
        jp nz, LevelSelect

        jr MainLoop

SECTION "TitleScreenPalettes", ROMX
BackgroundPalettes:
        incbin "title-screen-palettes.bin"
.end:

SECTION "TitleScreenTileData", ROMX
TileData:
        incbin "title-screen-tiles.bin"
.end:

SECTION "TitleScreenTileMap", ROMX
TileMap:
        incbin "title-screen-map.bin"
.end:

SECTION "TitleScreenTileAttributes", ROMX
TileAttributes:
        incbin "title-screen-attributes.bin"
.end:
