;;-------------------------------------------------------------------------------------------------------------------------------;;
;; title.asm : Pantalla de titulo
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; "PROJECT N.I.C.C" en letras grandes (tiles de src/sprites/titulo.z80, 2x2 tiles por letra) y "PULSA START" parpadeando.
;; Se dibuja en el mapa de fondo 1 ($9C00) con la LCD apagada (al arrancar), igual que la pantalla de puntuacion; se activa con
;; wResultsView = 2 (ver Game_ApplyFade). El parpadeo reescribe la fila de "PULSA START" con las rutinas de results.asm.
;; START empieza la partida. Para volver al titulo se reinicia el juego entero (results.asm salta a "main").
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Title Variables", WRAM0

wTitleTimer: db       ;; Fotogramas que faltan para cambiar entre visible / oculto
wTitleShow:  db       ;; 1 = "PULSA START" visible

SECTION "Title", ROM0

;;-----------------------------------------------------------------
;; Title_PutWord: Dibuja una palabra de letras grandes en el mapa de fondo 1
;;    Entrada: HL = palabra (indices de letra 0-8 = P,R,O,J,E,C,T,N,I o TITLE_DOT; acabada en TEXT_END),
;;             DE = direccion del mapa donde va la esquina superior izquierda
;;    Cada letra son 4 tiles (arriba-izq, arriba-der, abajo-izq, abajo-der); el punto son 2 (arriba, abajo).
;;    Destruye: A, BC, DE, HL
DEF TITLE_DOT EQU 9
Title_PutWord:
.next:
   ld   a, [hl+]
   cp   TEXT_END
   ret  z
   cp   TITLE_DOT
   jr   z, .dot
   add  a
   add  a                    ;; 4 tiles por letra
   add  TILE_TITLE
   ld   c, a                 ;; C = primer tile de la letra
   ld   a, c
   ld   [de], a              ;; arriba-izquierda
   inc  de
   inc  a
   ld   [de], a              ;; arriba-derecha
   push de
   ld   a, e
   add  31
   ld   e, a
   ld   a, d
   adc  0
   ld   d, a                 ;; DE -> fila de abajo, columna izquierda (31 = 32 - 1)
   ld   a, c
   add  2
   ld   [de], a              ;; abajo-izquierda
   inc  de
   inc  a
   ld   [de], a              ;; abajo-derecha
   pop  de
   inc  de                   ;; siguiente letra: 2 columnas mas alla de la izquierda
   jr   .next
.dot:
   ld   a, TILE_TITLE + 36
   ld   [de], a              ;; arriba (vacio)
   push de
   ld   a, e
   add  32
   ld   e, a
   ld   a, d
   adc  0
   ld   d, a
   ld   a, TILE_TITLE + 37
   ld   [de], a              ;; abajo (el punto)
   pop  de
   inc  de
   jr   .next

;;-----------------------------------------------------------------
;; Palabras (letra: P=0 R=1 O=2 J=3 E=4 C=5 T=6 N=7 I=8)
TitleWord1: db 0, 1, 2, 3, 4, 5, 6, TEXT_END                     ;; PROJECT
TitleWord2: db 7, TITLE_DOT, 8, TITLE_DOT, 5, TITLE_DOT, 5, TEXT_END   ;; N.I.C.C

;;-----------------------------------------------------------------
;; Title_Begin: Prepara la pantalla de titulo. Llamar con la LCD apagada (escribe directamente en la VRAM).
;;    Destruye: A, BC, DE, HL
Title_Begin::
   call Results_Init         ;; Sin filas pendientes
   xor  a
   ld   [wHudDirty], a       ;; (la WRAM arranca con basura: aun no hay partida que dibujar en el HUD)
   ld   [wEndKind], a
   ld   a, 2
   ld   [wResultsView], a    ;; El fondo es el mapa 1 con la paleta invertida
   ld   a, STATE_TITLE
   ld   [wGameState], a
   ld   a, 1
   ld   [wTitleShow], a
   ld   a, TITLE_BLINK
   ld   [wTitleTimer], a
   ld   hl, TitleWord1
   ld   de, _SCRN1 + TITLE_ROW1 * 32 + 3      ;; 7 letras * 2 = 14 columnas: de la 3 a la 16
   call Title_PutWord
   ld   hl, TitleWord2
   ld   de, _SCRN1 + TITLE_ROW2 * 32 + 5      ;; 4 letras * 2 + 3 puntos = 11 columnas
   call Title_PutWord
   call Title_BuildPress     ;; "PULSA START" visible desde el principio
   ld   a, TITLE_ROW_PRESS
   call Row_Commit
   jp   Results_Blit

;;-----------------------------------------------------------------
;; Title_BuildPress: Prepara en wRowBuf la fila de "PULSA START" (visible u oculta segun wTitleShow)
;;    Destruye: A, BC, DE, HL
Title_BuildPress:
   call Row_Clear
   ld   a, [wTitleShow]
   and  a
   ret  z
   ld   hl, StrPress
   jp   Row_PutCentered

;;-----------------------------------------------------------------
;; Title_Update: Un fotograma de la pantalla de titulo: parpadeo y espera de START (que empieza la partida)
;;    Destruye: A, BC, DE, HL
Title_Update::
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   jr   z, .blink
   call Random_Init          ;; Semilla distinta en cada partida: depende de cuando se pulse START
   jp   Game_Start
.blink:
   ld   a, [wTitleTimer]
   dec  a
   ld   [wTitleTimer], a
   ret  nz
   ld   a, TITLE_BLINK
   ld   [wTitleTimer], a
   ld   a, [wTitleShow]
   xor  1
   ld   [wTitleShow], a
   call Title_BuildPress
   ld   a, TITLE_ROW_PRESS
   jp   Row_Commit
