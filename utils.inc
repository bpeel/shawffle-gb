MACRO select_bank
        ld a, BANK(\1)
        ld [$2000], a
ENDM

