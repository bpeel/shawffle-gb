INCLUDE "hardware.inc"
INCLUDE "utils.inc"
INCLUDE "charmap.inc"

DEF WRONG_GAME_BOY_LCDC EQU \
        LCDCF_ON | \
        LCDCF_BG8000 | \
        LCDCF_BG9800 | \
        LCDCF_BGON

SECTION "WrongGameBoyCode", ROM0

DEF MESSAGE1 EQUS "\"𐑴𐑯𐑤𐑦 𐑓 𐑞\""
DEF MESSAGE2 EQUS "\"·𐑜𐑱𐑥 𐑚𐑶 𐑒𐑳𐑤𐑼\""
DEF MESSAGE1_X EQU SCRN_X_B / 2 - STRLEN(MESSAGE1) / 2
DEF MESSAGE2_X EQU SCRN_X_B / 2 - STRLEN(MESSAGE2) / 2
DEF MESSAGE_Y EQU SCRN_Y_B / 2 - 1

WrongGameBoy::
        di

        call TurnOffLcd

        ;; Set up the bg palette
        ld a, %11100100
        ld [rBGP], a

        ;; Load the shared tiles to get the font
        call LoadSharedTiles

        ;; Clear the tile map
        ld hl, _SCRN0
        ld bc, SCRN_VX_B * SCRN_Y_B
:       xor a, a
        ld [hli], a
        dec bc
        ld a, b
        or a, c
        jr nz, :-

        ;; Add the message
        select_bank Message
        ld hl, _SCRN0 + MESSAGE_Y * SCRN_VX_B + MESSAGE1_X
        ld de, Message
        ld bc, STRLEN(MESSAGE1)
        call MemCpy
        ld bc, STRLEN(MESSAGE2)
        ld hl, _SCRN0 + (MESSAGE_Y + 1) * SCRN_VY_B + MESSAGE2_X
        call MemCpy

        ;; Initialise variables
        xor a, a
        ld [VblankOccured], a
        ldh [rSCX], a
        ldh [rSCY], a

        ;; Clear any pending interrupts
        xor a, a
        ldh [rIF], a

        ;; Disable all interrupts
        xor a, a
        ldh [rIE], a

        ; Enable the LCD
        ld a, WRONG_GAME_BOY_LCDC
        ldh [rLCDC], a

MainLoop:
        nop
        halt
        nop
        jr MainLoop

SECTION "WrongGameBoyMessage", ROMX
Message:
        db MESSAGE1
        db MESSAGE2
