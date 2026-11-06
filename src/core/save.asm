;;-------------------------------------------------------------------------------------------------------------------------------;;
;; save.asm : Tabla de puntuaciones, guardada en la RAM del cartucho (SRAM, con bateria)
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

DEF SAVE_MAGIC0  EQU $4E
DEF SAVE_MAGIC1  EQU $54
DEF SAVE_XOR     EQU $A5
DEF SAVE_SUM0    EQU (SAVE_MAGIC0 + SAVE_MAGIC1) & $FF
DEF SAVE_SRAM_ON EQU $0A
DEF SAVE_TABLE_BYTES EQU SCORE_SLOTS * SCORE_ENTRY_SIZE

SECTION "Save Variables", WRAM0

wScores::     ds SAVE_TABLE_BYTES
wFinalScore:: ds SCORE_DIGITS
wNewPos::     db

SECTION "Save", ROM0

;;-----------------------------------------------------------------
;; Save_Load: Lee la tabla de la SRAM a wScores (o la deja vacia si no es valida)
Save_Load::
   ld   a, SAVE_SRAM_ON
   ld   [$0000], a
   ld   hl, _SRAM
   ld   a, [hl+]
   cp   SAVE_MAGIC0
   jr   nz, .invalid
   ld   a, [hl+]
   cp   SAVE_MAGIC1
   jr   nz, .invalid
   ld   b, SAVE_TABLE_BYTES
   ld   c, SAVE_SUM0
.sum:
   ld   a, [hl+]
   add  c
   ld   c, a
   dec  b
   jr   nz, .sum
   ld   a, [hl]
   ld   b, a
   ld   a, c
   xor  SAVE_XOR
   cp   b
   jr   nz, .invalid
   ld   hl, _SRAM + 2
   ld   de, wScores
   ld   b, SAVE_TABLE_BYTES
.copy:
   ld   a, [hl+]
   ld   [de], a
   inc  de
   dec  b
   jr   nz, .copy
   jr   .end
.invalid:
   ld   hl, wScores
   ld   bc, SAVE_TABLE_BYTES
   xor  a
   call MemSet
.end:
   xor  a
   ld   [$0000], a
   ret

;;-----------------------------------------------------------------
;; Save_Store: Escribe wScores en la SRAM
Save_Store::
   ld   a, SAVE_SRAM_ON
   ld   [$0000], a
   ld   hl, _SRAM
   ld   a, SAVE_MAGIC0
   ld   [hl+], a
   ld   a, SAVE_MAGIC1
   ld   [hl+], a
   ld   de, wScores
   ld   b, SAVE_TABLE_BYTES
   ld   c, SAVE_SUM0
.copy:
   ld   a, [de]
   inc  de
   ld   [hl+], a
   add  c
   ld   c, a
   dec  b
   jr   nz, .copy
   ld   a, c
   xor  SAVE_XOR
   ld   [hl], a
   xor  a
   ld   [$0000], a
   ret

;;-----------------------------------------------------------------
;; Save_Cmp5: Compara dos listas de 5 cifras
Save_Cmp5:
   ld   b, SCORE_DIGITS
.loop:
   ld   a, [de]
   ld   c, a
   ld   a, [hl+]
   cp   c
   ret  nz
   inc  de
   dec  b
   jr   nz, .loop
   xor  a
   ret

;;-----------------------------------------------------------------
;; Save_Update: Busca el puesto de wFinalScore en la tabla (un empate queda por debajo)
Save_Update::
   ld   a, SCORE_SLOTS
   ld   [wNewPos], a
   ld   c, 0
   ld   de, wScores + 3
.entry:
   push bc
   push de
   ld   hl, wFinalScore
   call Save_Cmp5
   pop  de
   pop  bc
   jr   z, .next
   jr   nc, .found
.next:
   ld   a, e
   add  SCORE_ENTRY_SIZE
   ld   e, a
   ld   a, d
   adc  0
   ld   d, a
   inc  c
   ld   a, c
   cp   SCORE_SLOTS
   jr   nz, .entry
   ret
.found:
   ld   a, c
   ld   [wNewPos], a
   ld   a, SCORE_SLOTS - 1
   sub  c
   jr   z, .write
   add  a
   add  a
   add  a
   ld   b, a
   ld   hl, wScores + (SCORE_SLOTS - 1) * SCORE_ENTRY_SIZE - 1
   ld   de, wScores + SCORE_SLOTS * SCORE_ENTRY_SIZE - 1
.move:
   ld   a, [hl-]
   ld   [de], a
   dec  de
   dec  b
   jr   nz, .move
.write:
   ld   a, c
   add  a
   add  a
   add  a
   ld   e, a
   ld   d, 0
   ld   hl, wScores
   add  hl, de
   xor  a
   ld   [hl+], a
   ld   [hl+], a
   ld   [hl+], a
   ld   de, wFinalScore
   ld   b, SCORE_DIGITS
.digits:
   ld   a, [de]
   inc  de
   ld   [hl+], a
   dec  b
   jr   nz, .digits
   jp   Save_Store
