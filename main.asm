;;; Shawffle GB – A puzzle game for the Gameboy Color
;;; Copyright (C) 2025  Neil Roberts
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

INCLUDE "hardware.inc"
INCLUDE "utils.inc"
INCLUDE "globals.inc"

DEF SAVE_STATE_CHECK_SIZE EQU 16

SECTION "Header", ROM0[$0000]

        ds $40 - @, 0           ; Skip to vblank interrupt
        jp Vblank

        ds $48 - @, 0           ; Skip to stat interrupt
        jp StatJumpInstruction

        ds $100 - @, 0          ; Skip to the entry point
        nop
        jp Init

        ds $150 - @, 0          ; Make room for the header

SECTION "Init", ROM0

Init:
        ;; Move the stack to WRAM
        ld sp, Stack.end

        ;; Save a to detect GB type later
        push af

	; Shut down audio circuitry
	xor a, a
	ldh [rNR52], a

        call TurnOffLcd

        ;; Prepare stat interrupt jump instruction
        ld a, $c3               ; jp n16
        ld [StatJumpInstruction], a

        ;; Set up the OamDma transfer in HRAM
        ld de, OamDmaCode
        ld hl, OamDma
        ld bc, OamDmaCode.end - OamDmaCode
        call MemCpy

        ;; Are we running on a CGB?
        pop af
        cp a, BOOTUP_A_CGB
        jp nz, WrongGameBoy

        ;; Initialise variables
        xor a, a
        ld [CurKeys], a
        ld [NewKeys], a

        call InitialiseSaveState

        call FindCurrentLevel

        jp TitleScreen

Vblank:
        push af
        ;; Copy the OAM mirror using DMA
        call OamDma
        ;; let the main loop know a vblank occured
        ld a, 1
        ld [VblankOccured], a
        pop af
        reti

InitialiseSaveState:
        select_bank SaveStateCheckValue
        select_sram_bank SaveStateCheck
        enable_sram

        ld b, SAVE_STATE_CHECK_SIZE
        ld hl, SaveStateCheck
        ld de, SaveStateCheckValue
.checksum_loop:
        ld a, [de]
        inc de
        cp a, [hl]
        inc hl
        jr nz, .bad_checksum
        dec b
        jr nz, .checksum_loop
        jr .out                 ; checksum fine, don’t need to clear
.bad_checksum:
        ld hl, SaveStateCheck
        ld de, SaveStateCheckValue
        ld bc, SAVE_STATE_CHECK_SIZE
        call MemCpy
        ;; Clear the remaining memory
:       xor a, a
        ld [hli], a
        ld a, h
        cp a, HIGH(_SRAM + 8192)
        jr c, :-
.out:
        disable_sram
        ret

FindCurrentLevel:
        enable_sram
        select_sram_bank LevelStars
        ld hl, LevelStars
        ld de, 0
        ld bc, N_PUZZLES - 1
        ;; Find the first zero level
.loop:
        ld a, [hli]
        or a, a
        jr z, .out
        inc de
        dec bc
        ld a, c
        or a, b
        jr nz, .loop
.out:
        ld a, e
        ld [CurrentPuzzle], a
        ld a, d
        ld [CurrentPuzzle + 1], a
        disable_sram
        ret

SECTION "SaveStateCheckValue", ROMX
SaveStateCheckValue:
        ;; Ensure we’re encoding the bytes directly and not using a charmap
        PUSHC
        NEWCHARMAP ASCII
        db "Shawffle SRAM :)"
        POPC
        assert @ - SaveStateCheckValue == SAVE_STATE_CHECK_SIZE

SECTION "SaveState", SRAM[$A000]
SaveStateCheck::
        ds SAVE_STATE_CHECK_SIZE

SECTION "Stack", WRAM0
Stack:
        ds 256
.end:
