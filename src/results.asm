;;-------------------------------------------------------------------------------------------------------------------------------;;
;; results.asm : Pantalla de puntuacion final
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; Se muestra tras superar la ultima fase (VICTORIA) o al perder todas las vidas (GAME OVER). Lineas, de arriba abajo:
;;      titulo
;;      PUNTOS      puntos conseguidos con las bajas (la puntuacion del HUD)
;;      FASES       BONUS_PHASE_K miles de puntos por cada fase superada
;;      CORAZONES   BONUS_HEART_K miles de puntos por cada corazon que queda
;;      TOTAL       la suma (satura en 99999); parte de PUNTOS y sube hasta el total final
;;      PULSA START
;; Las lineas aparecen una a una (RES_WAIT fotogramas entre ellas). START durante la animacion la salta hasta el final.
;;
;; Se dibuja en el mapa de fondo 1 ($9C00), asi no gasta sprites (la OAM solo admite 40 y 10 por linea) y se activa de golpe
;; con el bit 3 de LCDC (Game_ApplyFade). El juego prepara una fila entera en RAM (wRowBuf) y Results_Blit la copia a
;; la VRAM al principio del VBlank (la VRAM no se puede tocar con la pantalla dibujandose).
;;
;; Los numeros son listas de 5 cifras decimales (una por byte, la mas significativa primero), como wScore.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

DEF RES_STAGE_CLEAR  EQU 0   ;; Borra las filas que se van a usar (por si quedaba texto de una partida anterior)
DEF RES_STAGE_TITLE  EQU 1
DEF RES_STAGE_POINTS EQU 2
DEF RES_STAGE_PHASES EQU 3
DEF RES_STAGE_HEARTS EQU 4
DEF RES_STAGE_TOTAL  EQU 5   ;; Escribe el TOTAL inicial (= PUNTOS)
DEF RES_STAGE_COUNT  EQU 6   ;; Sube el TOTAL de 500 en 500 hasta el valor final
DEF RES_STAGE_PRESS  EQU 7   ;; "PULSA START"
DEF RES_STAGE_DONE   EQU 8   ;; Fin de la animacion: se espera START

DEF RES_COUNT_INDEX  EQU 2   ;; El recuento suma 5 en la cifra de las centenas (indice 2 de 0 a 4): de 500 en 500
DEF RES_COUNT_AMOUNT EQU 5

SECTION "Results Variables", WRAM0

wRowBuf:      ds SCREEN_TILES_W   ;; Fila preparada para copiar al mapa de fondo
wRowIdx:      db                  ;; Fila del mapa (0-17) donde copiarla
wRowPending:  db                  ;; 1 = hay una fila esperando al proximo VBlank
wResStage::   db
wResTimer:    db                  ;; Fotogramas de espera hasta la proxima etapa
wResSkip:     db                  ;; 1 = el jugador ha pulsado START para saltar la animacion
wResIndex:    db                  ;; Filas ya borradas en la etapa CLEAR
wResSteps:    db                  ;; Pasos de 500 puntos que faltan en el recuento
wResBonusB:   db                  ;; Bonus total, en miles de puntos
wResPhases:   ds SCORE_DIGITS     ;; Bonus de fases superadas
wResHearts:   ds SCORE_DIGITS     ;; Bonus de corazones
wResTotal:    ds SCORE_DIGITS     ;; Total mostrado (sube durante el recuento)

SECTION "Results", ROM0

ResultRows:                       ;; Filas que usa la pantalla
   db RES_ROW_TITLE, RES_ROW_POINTS, RES_ROW_PHASES, RES_ROW_HEARTS, RES_ROW_TOTAL, RES_ROW_PRESS
DEF RESULT_ROW_COUNT EQU @ - ResultRows

;;-----------------------------------------------------------------
;; Results_Init: Descarta cualquier fila pendiente (llamar al empezar la partida)
;;    Destruye: A
Results_Init::
   xor  a
   ld   [wRowPending], a
   ret

;;=================================================================
;; Utilidades de numeros de 5 cifras (HL = lista de cifras)
;;=================================================================

;;-----------------------------------------------------------------
;; Dec5_Add: Suma A (1-9) a la cifra de indice C (0 = la de mas a la izquierda) con acarreo. Si se pasa de 99999, deja 99999.
;;    Entrada: HL = lista, C = indice, A = cantidad
;;    Destruye: A, C, DE, HL
Dec5_Add:
   ld   e, c
   ld   d, 0
   add  hl, de               ;; HL -> la cifra
   add  [hl]
.carry:
   cp   10
   jr   c, .store
   sub  10
   ld   [hl], a              ;; La cifra se queda con el resto...
   ld   a, c
   and  a
   jr   z, .saturate         ;; ...pero no hay cifra a la izquierda: desbordamiento
   dec  c
   dec  hl
   ld   a, [hl]
   inc  a                    ;; Acarreo a la cifra de la izquierda
   jr   .carry
.store:
   ld   [hl], a
   ret
.saturate:                   ;; HL apunta al principio de la lista
   ld   c, SCORE_DIGITS
   ld   a, 9
.fill:
   ld   [hl+], a
   dec  c
   jr   nz, .fill
   ret

;;-----------------------------------------------------------------
;; Dec5_SetThousands: Escribe en la lista el valor A miles (A = 0 a 99): cifras [A/10, A%10, 0, 0, 0]
;;    Entrada: HL = lista, A = miles
;;    Destruye: A, C, HL
Dec5_SetThousands:
   ld   c, 0
.tens:
   cp   10
   jr   c, .units
   sub  10
   inc  c
   jr   .tens
.units:
   ld   [hl], c              ;; Decenas de millar
   inc  hl
   ld   [hl+], a             ;; Unidades de millar
   xor  a
   ld   [hl+], a
   ld   [hl+], a
   ld   [hl], a
   ret

;;-----------------------------------------------------------------
;; Dec5_AddThousands: Suma A miles (0 a 99) a la lista, con saturacion
;;    Entrada: HL = lista, A = miles
;;    Destruye: A, BC, DE, HL
Dec5_AddThousands:
   ld   c, 0
.tens:
   cp   10
   jr   c, .units
   sub  10
   inc  c
   jr   .tens
.units:
   push hl                   ;; Inicio de la lista
   push bc                   ;; C = decenas
   and  a
   jr   z, .noUnits
   ld   c, 1                 ;; Indice 1: unidades de millar
   call Dec5_Add             ;; (A ya son las unidades)
.noUnits:
   pop  bc
   pop  hl
   ld   a, c
   and  a
   ret  z
   ld   c, 0                 ;; Indice 0: decenas de millar
   jp   Dec5_Add

;;=================================================================
;; Construccion de una fila (wRowBuf) para el mapa de fondo
;;=================================================================

;;-----------------------------------------------------------------
;; Row_Clear: Rellena la fila de tiles vacios (se ven negros)
;;    Destruye: A, BC, D, HL
Row_Clear:
   ld   hl, wRowBuf
   ld   bc, SCREEN_TILES_W
   ld   a, TILE_BLANK
   jp   MemSet

;;-----------------------------------------------------------------
;; Row_Commit: Marca la fila como lista: se copiara a la fila A del mapa en el proximo VBlank
;;    Entrada: A = fila del mapa (0-17)
;;    Destruye: A
Row_Commit:
   ld   [wRowIdx], a
   ld   a, 1
   ld   [wRowPending], a
   ret

;;-----------------------------------------------------------------
;; Row_PutString: Escribe una cadena (acabada en TEXT_END) en la fila a partir de la columna B
;;    Entrada: HL = cadena, B = columna
;;    Destruye: A, DE, HL
Row_PutString:
   ld   de, wRowBuf
   ld   a, e
   add  b
   ld   e, a
   ld   a, d
   adc  0
   ld   d, a                 ;; DE = wRowBuf + columna
.loop:
   ld   a, [hl+]
   cp   TEXT_END
   ret  z
   ld   [de], a
   inc  de
   jr   .loop

;;-----------------------------------------------------------------
;; Row_PutCentered: Escribe una cadena centrada en la fila
;;    Entrada: HL = cadena
;;    Destruye: A, B, DE, HL
Row_PutCentered:
   push hl
   ld   b, 0                 ;; B = longitud
.count:
   ld   a, [hl+]
   cp   TEXT_END
   jr   z, .counted
   inc  b
   jr   .count
.counted:
   ld   a, SCREEN_TILES_W
   sub  b
   srl  a                    ;; (ancho - longitud) / 2
   ld   b, a
   pop  hl
   jr   Row_PutString

;;-----------------------------------------------------------------
;; Row_PutDec5: Escribe una lista de 5 cifras en la fila a partir de la columna B, sin ceros a la izquierda
;;    (la ultima cifra se escribe siempre, aunque sea 0)
;;    Entrada: HL = lista, B = columna
;;    Destruye: A, BC, DE, HL
Row_PutDec5:
   ld   de, wRowBuf
   ld   a, e
   add  b
   ld   e, a
   ld   a, d
   adc  0
   ld   d, a                 ;; DE = wRowBuf + columna
   ld   c, SCORE_DIGITS      ;; C = cifras que faltan
   ld   b, 0                 ;; B = 1 cuando ya ha salido una cifra distinta de 0
.loop:
   ld   a, [hl+]
   and  a
   jr   nz, .digit
   ld   a, c
   dec  a
   jr   z, .zero             ;; Ultima cifra: se escribe siempre
   ld   a, b
   and  a
   jr   nz, .zero            ;; Ya habia cifras significativas: este 0 cuenta
   ld   a, TILE_BLANK        ;; Cero a la izquierda: hueco
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
;; Results_Blit: Si hay una fila preparada, la copia al mapa de fondo 1 ($9C00)
;;    IMPORTANTE: solo llamar al principio del VBlank (o con la LCD apagada)
;;    Destruye: A, B, DE, HL
Results_Blit::
   ld   a, [wRowPending]
   and  a
   ret  z
   xor  a
   ld   [wRowPending], a
   ld   a, [wRowIdx]
   ld   l, a
   ld   h, 0
   REPT 5
      add  hl, hl            ;; Fila * 32 (cada fila del mapa tiene 32 tiles)
   ENDR
   ld   de, _SCRN1
   add  hl, de
   ld   de, wRowBuf
   ld   b, SCREEN_TILES_W
.copy:
   ld   a, [de]
   inc  de
   ld   [hl+], a
   dec  b
   jr   nz, .copy
   ret

;;=================================================================
;; Logica de la pantalla
;;=================================================================

;;-----------------------------------------------------------------
;; Mul8: A = A * C (el resultado debe caber en 8 bits)
;;    Destruye: A, B
Mul8:
   ld   b, a
   xor  a
   inc  b
   dec  b
   ret  z                    ;; A * C con A = 0
.loop:
   add  c
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Results_Begin: Calcula los bonus y deja lista la animacion. Llamar cuando la pantalla ya esta en negro.
;;    Usa wEndKind (END_WIN / END_LOSE), wPhase, wLives y wScore.
;;    Destruye: A, BC, DE, HL
Results_Begin::
   xor  a
   ld   [wResStage], a
   ld   [wResTimer], a
   ld   [wResSkip], a
   ld   [wResIndex], a
   ld   [wRowPending], a

   ;;-- Fases superadas: todas si se gano; si se perdio, las anteriores a la actual
   ld   a, [wEndKind]
   cp   END_WIN
   ld   a, PHASE_COUNT       ;; (ld no toca los flags)
   jr   z, .phasesKnown
   ld   a, [wPhase]
   dec  a
.phasesKnown:
   ld   c, BONUS_PHASE_K
   call Mul8                 ;; A = miles de puntos por las fases
   ld   [wResBonusB], a
   ld   hl, wResPhases
   call Dec5_SetThousands

   ;;-- Corazones que quedan
   ld   a, [wLives]
   ld   c, BONUS_HEART_K
   call Mul8                 ;; A = miles de puntos por los corazones
   ld   b, a
   ld   a, [wResBonusB]
   add  b
   ld   [wResBonusB], a      ;; Bonus total, en miles
   ld   a, b
   ld   hl, wResHearts
   call Dec5_SetThousands

   ;;-- El total empieza siendo la puntuacion de las bajas y sube de 500 en 500 (2 pasos por cada mil)
   ld   de, wScore
   ld   hl, wResTotal
   ld   bc, SCORE_DIGITS
   call MemCopy
   ld   a, [wResBonusB]
   add  a
   ld   [wResSteps], a
   ret

;;-----------------------------------------------------------------
;; Results_Update: Un fotograma de la animacion (STATE_RESULTS). Al terminar, START empieza una partida nueva.
;;    Destruye: A, BC, DE, HL
Results_Update::
   ld   a, [wResStage]
   cp   RES_STAGE_DONE
   jr   z, .waitStart

   ldh  a, [hInputNew]
   bit  BTNB_START, a
   jr   z, .noSkip
   ld   a, 1
   ld   [wResSkip], a        ;; START: saltar la animacion (se acaba de golpe)
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
   jp   Game_Start

;;-- Pasa a la siguiente etapa. Entrada: B = fotogramas de espera (con la animacion saltada, ninguno)
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

.clear:                      ;; Borra una de las filas de ResultRows por fotograma
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
   jr   z, .countEnd         ;; Nada (mas) que sumar
   dec  a
   ld   [wResSteps], a
   ld   hl, wResTotal
   ld   c, RES_COUNT_INDEX
   ld   a, RES_COUNT_AMOUNT
   call Dec5_Add             ;; +500
   jr   .countDraw
.finishNow:                  ;; Animacion saltada: el total final de golpe = PUNTOS + bonus
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
   ret  nz                   ;; Sigue el recuento
.countEnd:
   ld   b, 15
   jp   .advance

.drawTotal:                  ;; Prepara y encola la fila del TOTAL
   call Row_Clear
   ld   hl, StrTotal
   ld   b, RES_LABEL_COL
   call Row_PutString
   ld   hl, wResTotal
   ld   b, RES_VALUE_COL
   call Row_PutDec5
   ld   a, RES_ROW_TOTAL
   jp   Row_Commit
