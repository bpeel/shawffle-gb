MACRO select_bank
        ld a, BANK(\1)
        ld [$2000], a
ENDM

MACRO select_sram_bank
        ld a, BANK(\1)
        ld [$4000], a
ENDM

MACRO enable_sram
        ld a, $0a
        ld [$0000], a
ENDM

MACRO disable_sram
        ld a, $00
        ld [$0000], a
ENDM
