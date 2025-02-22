INCLUDE "globals.inc"

SECTION "Globals", WRAM0
VblankOccured:: db
CurKeys::       db
NewKeys::       db
StatJumpInstruction:: db
StatJumpAddress:: dw
CurrentPuzzle:: dw

SECTION "LevelStars", SRAM
LevelStars::
        ds N_PUZZLES
