;;-------------------------------------------------------------------------------------------------------------------------------;;
;; results.asm : Pantalla de puntuacion final
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

DEF RES_STAGE_CLEAR  EQU 0
DEF RES_STAGE_TITLE  EQU 1
DEF RES_STAGE_POINTS EQU 2
DEF RES_STAGE_PHASES EQU 3
DEF RES_STAGE_HEARTS EQU 4
DEF RES_STAGE_TOTAL  EQU 5
DEF RES_STAGE_COUNT  EQU 6
DEF RES_STAGE_RECORD EQU 7
DEF RES_STAGE_PRESS  EQU 8
DEF RES_STAGE_DONE   EQU 9

DEF RES_COUNT_INDEX  EQU 2
DEF RES_COUNT_AMOUNT EQU 5

SECTION "Results Variables", WRAM0

wRowBuf::     ds SCREEN_TILES_W
wScrBuf:      ds SCREEN_TILES_W * SCREEN_TILES_H
wRowDirty:    ds SCREEN_TILES_H
wDirtyCount:: db
wResStage::   db
wResTimer:    db
wResSkip:     db
wResIndex:    db
wResSteps:    db
wResBonusB:   db
wResPhases:   ds SCORE_DIGITS
wResHearts:   ds SCORE_DIGITS
wResTotal:    ds SCORE_DIGITS

SECTION "Results", ROM0

ResultRows:
   db RES_ROW_TITLE, RES_ROW_POINTS, RES_ROW_PHASES, RES_ROW_HEARTS, RES_ROW_TOTAL, RES_ROW_RECORD, RES_ROW_PRESS
DEF RESULT_ROW_COUNT EQU @ - ResultRows

;;-----------------------------------------------------------------
;; Results_Init: Descarta cualquier fila pendiente (llamar al empezar la partida)
Results_Init::
   ld   hl, wRowDirty
   ld   bc, SCREEN_TILES_H
   xor  a
   call MemSet
   xor  a
   ld   [wDirtyCount], a
   ret

;;-----------------------------------------------------------------
;; Scr_Clear: Borra la pantalla del mapa 1
Scr_Clear::
   ld   hl, wScrBuf
   ld   bc, SCREEN_TILES_W * SCREEN_TILES_H
   xor  a
   call MemSet
   ld   hl, wRowDirty
   ld   bc, SCREEN_TILES_H
   ld   a, 1
   call MemSet
   ld   a, SCREEN_TILES_H
   ld   [wDirtyCount], a
   ret

;;-----------------------------------------------------------------
;; Dec5_Add: Suma A (1-9) a la cifra de indice C (0 = la de mas a la izquierda) con acarreo
Dec5_Add:
   ld   e, c
   ld   d, 0
   add  hl, de
   add  [hl]
.carry:
   cp   10
   jr   c, .store
   sub  10
   ld   [hl], a
   ld   a, c
   and  a
   jr   z, .saturate
   dec  c
   dec  hl
   ld   a, [hl]
   inc  a
   jr   .carry
.store:
   ld   [hl], a
   ret
.saturate:
   ld   c, SCORE_DIGITS
   ld   a, 9
.fill:
   ld   [hl+], a
   dec  c
   jr   nz, .fill
   ret

;;-----------------------------------------------------------------
;; Dec5_SetThousands: Escribe en la lista el valor A miles (A = 0 a 99): cifras [A/10, A%10, 0, 0, 0]
Dec5_SetThousands:
   ld   c, 0
.tens:
   cp   10
   jr   c, .units
   sub  10
   inc  c
   jr   .tens
.units:
   ld   [hl], c
   inc  hl
   ld   [hl+], a
   xor  a
   ld   [hl+], a
   ld   [hl+], a
   ld   [hl], a
   ret

;;-----------------------------------------------------------------
;; Dec5_AddThousands: Suma A miles (0 a 99) a la lista, con saturacion
Dec5_AddThousands:
   ld   c, 0
.tens:
   cp   10
   jr   c, .units
   sub  10
   inc  c
   jr   .tens
.units:
   push hl
   push bc
   and  a
   jr   z, .noUnits
   ld   c, 1
   call Dec5_Add
.noUnits:
   pop  bc
   pop  hl
   ld   a, c
   and  a
   ret  z
   ld   c, 0
   jp   Dec5_Add

;;-----------------------------------------------------------------
;; Row_Clear: Rellena la fila de tiles vacios (se ven negros)
Row_Clear::
   ld   hl, wRowBuf
   ld   bc, SCREEN_TILES_W
   ld   a, TILE_BLANK
   jp   MemSet

;;-----------------------------------------------------------------
;; Row_Commit: Guarda wRowBuf como la fila A de la pantalla y la marca para copiarla a la VRAM
Row_Commit::
   push bc
   push de
   push hl
   ld   c, a
   ld   l, a
   ld   h, 0
   add  hl, hl
   add  hl, hl
   ld   d, h
   ld   e, l
   add  hl, hl
   add  hl, hl
   add  hl, de
   ld   de, wScrBuf
   add  hl, de
   ld   d, h
   ld   e, l
   ld   hl, wRowBuf
   ld   b, SCREEN_TILES_W
.copy:
   ld   a, [hl+]
   ld   [de], a
   inc  de
   dec  b
   jr   nz, .copy
   ld   hl, wRowDirty
   ld   b, 0
   add  hl, bc
   ld   a, [hl]
   and  a
   jr   nz, .done
   ld   a, 1
   ld   [hl], a
   ld   hl, wDirtyCount
   inc  [hl]
.done:
   pop  hl
   pop  de
   pop  bc
   ret

;;-----------------------------------------------------------------
;; Row_PutString: Escribe una cadena (acabada en TEXT_END) en la fila a partir de la columna B
Row_PutString::
   ld   de, wRowBuf
   ld   a, e
   add  b
   ld   e, a
   ld   a, d
   adc  0
   ld   d, a
.loop:
   ld   a, [hl+]
   cp   TEXT_END
   ret  z
   ld   [de], a
   inc  de
   jr   .loop

;;-----------------------------------------------------------------
;; Row_PutCentered: Escribe una cadena centrada en la fila
Row_PutCentered::
   push hl
   ld   b, 0
.count:
   ld   a, [hl+]
   cp   TEXT_END
   jr   z, .counted
   inc  b
   jr   .count
.counted:
   ld   a, SCREEN_TILES_W
   sub  b
   srl  a
   ld   b, a
   pop  hl
   jr   Row_PutString

;;-----------------------------------------------------------------
;; Row_PutDec5: Escribe una lista de 5 cifras en la fila a partir de la columna B
Row_PutDec5::
   ld   de, wRowBuf
   ld   a, e
   add  b
   ld   e, a
   ld   a, d
   adc  0
   ld   d, a
   ld   c, SCORE_DIGITS
   ld   b, 0
.loop:
   ld   a, [hl+]
   and  a
   jr   nz, .digit
   ld   a, c
   dec  a
   jr   z, .zero
   ld   a, b
   and  a
   jr   nz, .zero
   ld   a, TILE_BLANK
   jr   .put
.zero:
   xor  a
.digit:
   ld   b, 1
   add  TILE_FONT_DIGIT0
.put:
   ld   [de], a
   inc  de
   dec  c
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Results_Blit: Copia a la VRAM hasta 2 de las filas marcadas, de arriba abajo
Results_Blit::
   ld   a, [wDirtyCount]
   and  a
   ret  z
   ld   c, 2
   ld   hl, wRowDirty
   ld   b, 0
.scan:
   ld   a, [hl]
   and  a
   jr   nz, .found
.next:
   inc  hl
   inc  b
   ld   a, b
   cp   SCREEN_TILES_H
   jr   nz, .scan
   ret
.found:
   xor  a
   ld   [hl], a
   push hl
   push bc
   ld   hl, wDirtyCount
   dec  [hl]
   ld   l, b
   ld   h, 0
   add  hl, hl
   add  hl, hl
   ld   d, h
   ld   e, l
   add  hl, hl
   add  hl, hl
   add  hl, de
   ld   de, wScrBuf
   add  hl, de
   push hl
   ld   l, b
   ld   h, 0
   REPT 5
      add  hl, hl
   ENDR
   ld   de, _SCRN1
   add  hl, de
   ld   d, h
   ld   e, l
   pop  hl
   REPT SCREEN_TILES_W
      ld   a, [hl+]
      ld   [de], a
      inc  de
   ENDR
   pop  bc
   pop  hl
   dec  c
   ret  z
   jr   .next

;;-----------------------------------------------------------------
;; Mul8: A = A * C (el resultado debe caber en 8 bits)
Mul8:
   ld   b, a
   xor  a
   inc  b
   dec  b
   ret  z
.loop:
   add  c
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Results_Begin: Calcula los bonus y deja lista la animacion
Results_Begin::
   xor  a
   ld   [wResStage], a
   ld   [wResTimer], a
   ld   [wResSkip], a
   ld   [wResIndex], a
   call Scr_Clear

   ld   a, [wEndKind]
   cp   END_WIN
   ld   a, PHASE_COUNT
   jr   z, .phasesKnown
   ld   a, [wPhase]
   dec  a
.phasesKnown:
   ld   c, BONUS_PHASE_K
   call Mul8
   ld   [wResBonusB], a
   ld   hl, wResPhases
   call Dec5_SetThousands

   ;;-- Baterias (vidas) que quedan
   ld   a, [wLives]
   ld   c, BONUS_HEART_K
   call Mul8
   ld   b, a
   ld   a, [wResBonusB]
   add  b
   ld   [wResBonusB], a
   ld   a, b
   ld   hl, wResHearts
   call Dec5_SetThousands

   ld   de, wScore
   ld   hl, wResTotal
   ld   bc, SCORE_DIGITS
   call MemCopy
   ld   a, [wResBonusB]
   add  a
   ld   [wResSteps], a

   ld   de, wScore
   ld   hl, wFinalScore
   ld   bc, SCORE_DIGITS
   call MemCopy
   ld   hl, wFinalScore
   ld   a, [wResBonusB]
   call Dec5_AddThousands
   jp   Save_Update

;;-----------------------------------------------------------------
;; Results_Update: Un fotograma de la animacion (STATE_RESULTS)
Results_Update::
   ld   a, [wResStage]
   cp   RES_STAGE_DONE
   jr   z, .waitStart

   ldh  a, [hInputNew]
   bit  BTNB_START, a
   jr   z, .noSkip
   ld   a, 1
   ld   [wResSkip], a
.noSkip:
   ld   a, [wResTimer]
   and  a
   jr   z, .act
   dec  a
   ld   [wResTimer], a
   ret

.act:
   ld   a, [wResStage]
   cp   RES_STAGE_CLEAR
   jp   z, .clear
   cp   RES_STAGE_TITLE
   jp   z, .title
   cp   RES_STAGE_POINTS
   jp   z, .points
   cp   RES_STAGE_PHASES
   jp   z, .phases
   cp   RES_STAGE_HEARTS
   jp   z, .hearts
   cp   RES_STAGE_TOTAL
   jp   z, .total
   cp   RES_STAGE_COUNT
   jp   z, .count
   cp   RES_STAGE_RECORD
   jp   z, .record
   ;; RES_STAGE_PRESS
   call Row_Clear
   ld   hl, StrPress
   call Row_PutCentered
   ld   a, RES_ROW_PRESS
   call Row_Commit
   ld   a, RES_STAGE_DONE
   ld   [wResStage], a
   ret

.waitStart:
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   ret  z
   ld   a, [wNewPos]
   cp   SCORE_SLOTS
   jp   c, Name_Begin
   jp   main

.advance:
   ld   a, [wResSkip]
   and  a
   jr   z, .setTimer
   ld   b, 0
.setTimer:
   ld   a, b
   ld   [wResTimer], a
   ld   hl, wResStage
   inc  [hl]
   ret

.clear:
   ld   a, [wResIndex]
   ld   e, a
   ld   d, 0
   ld   hl, ResultRows
   add  hl, de
   ld   a, [hl]
   push af
   call Row_Clear
   pop  af
   call Row_Commit
   ld   a, [wResIndex]
   inc  a
   ld   [wResIndex], a
   cp   RESULT_ROW_COUNT
   ret  nz
   ld   b, 10
   jp   .advance

.title:
   call Row_Clear
   ld   a, [wEndKind]
   cp   END_WIN
   ld   hl, StrWin
   jr   z, .titleText
   ld   hl, StrLose
.titleText:
   call Row_PutCentered
   ld   a, RES_ROW_TITLE
   call Row_Commit
   ld   b, RES_WAIT
   jp   .advance

.points:
   call Row_Clear
   ld   hl, StrPoints
   ld   b, RES_LABEL_COL
   call Row_PutString
   ld   hl, wScore
   ld   b, RES_VALUE_COL
   call Row_PutDec5
   ld   a, RES_ROW_POINTS
   call Row_Commit
   ld   b, RES_WAIT
   jp   .advance

.phases:
   call Row_Clear
   ld   hl, StrPhases
   ld   b, RES_LABEL_COL
   call Row_PutString
   ld   hl, wResPhases
   ld   b, RES_VALUE_COL
   call Row_PutDec5
   ld   a, RES_ROW_PHASES
   call Row_Commit
   ld   b, RES_WAIT
   jp   .advance

.hearts:
   call Row_Clear
   ld   hl, StrHearts
   ld   b, RES_LABEL_COL
   call Row_PutString
   ld   hl, wResHearts
   ld   b, RES_VALUE_COL
   call Row_PutDec5
   ld   a, RES_ROW_HEARTS
   call Row_Commit
   ld   b, RES_WAIT
   jp   .advance

.total:
   call .drawTotal
   ld   b, 20
   jp   .advance

.count:
   ld   a, [wResSkip]
   and  a
   jr   nz, .finishNow
   ld   a, [wResSteps]
   and  a
   jr   z, .countEnd
   dec  a
   ld   [wResSteps], a
   ld   hl, wResTotal
   ld   c, RES_COUNT_INDEX
   ld   a, RES_COUNT_AMOUNT
   call Dec5_Add
   jr   .countDraw
.finishNow:
   ld   de, wScore
   ld   hl, wResTotal
   ld   bc, SCORE_DIGITS
   call MemCopy
   ld   hl, wResTotal
   ld   a, [wResBonusB]
   call Dec5_AddThousands
   xor  a
   ld   [wResSteps], a
.countDraw:
   call .drawTotal
   ld   a, [wResSteps]
   and  a
   ret  nz
.countEnd:
   ld   b, 15
   jp   .advance

.record:
   call Row_Clear
   ld   a, [wNewPos]
   cp   SCORE_SLOTS
   jr   nc, .oldRecord
   and  a
   jr   nz, .place
   ld   hl, StrNewRecord
   call Row_PutCentered
   jr   .recordRow
.place:
   push af
   ld   hl, StrPlace
   ld   b, 6
   call Row_PutString
   pop  af
   add  TILE_FONT_DIGIT0 + 1
   ld   [wRowBuf + 13], a
   jr   .recordRow
.oldRecord:
   ld   hl, StrRecord
   ld   b, RES_RECORD_COL
   call Row_PutString
   ld   hl, wScores + 3
   ld   b, RES_RECORD_COL + 7
   call Row_PutDec5
.recordRow:
   ld   a, RES_ROW_RECORD
   call Row_Commit
   ld   b, RES_WAIT
   jp   .advance

.drawTotal:
   call Row_Clear
   ld   hl, StrTotal
   ld   b, RES_LABEL_COL
   call Row_PutString
   ld   hl, wResTotal
   ld   b, RES_VALUE_COL
   call Row_PutDec5
   ld   a, RES_ROW_TOTAL
   jp   Row_Commit
