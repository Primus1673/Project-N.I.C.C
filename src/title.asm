;;-------------------------------------------------------------------------------------------------------------------------------;;
;; title.asm : Menu del titulo, tabla de puntuaciones y eleccion de nombre
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; Todas estas pantallas se dibujan en el mapa de fondo 1 ($9C00) con la paleta invertida (fondo negro, letras blancas), igual
;; que la de resultados: wResultsView = 2 (ver Game_ApplyFade). Cada pantalla se prepara fila a fila con Row_Clear, Row_Put* y
;; Row_Commit (results.asm); Results_Blit las copia a la VRAM, 2 por VBlank, asi que una pantalla nueva "se barre" en ~9 fotogramas.
;; Mientras quedan filas por copiar (wDirtyCount > 0) los botones se ignoran.
;;
;;   Menu (STATE_TITLE)  : arriba/abajo cambian de opcion, A o START la eligen: JUGAR / PUNTUACIONES
;;   Puntuaciones        : la tabla; A, B o START vuelven (al menu, o a reiniciar el juego si se viene de una partida)
;;   Nombre (STATE_NAME) : tras una partida que entra en la tabla: arriba/abajo cambian la letra, izquierda/derecha la posicion,
;;                         A o START aceptan
;; Para volver al menu desde los resultados se reinicia el juego entero (results.asm salta a "main").
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

DEF TITLE_DOT EQU 9          ;; En las palabras del titulo, el indice del punto (las letras son 0-8: P,R,O,J,E,C,T,N,I)

SECTION "Title Variables", WRAM0

wMenuSel:    db       ;; Opcion elegida del menu (0 = JUGAR, 1 = PUNTUACIONES)
wScoresFrom: db       ;; 0 = la tabla se ha abierto desde el menu; 1 = viene de acabar una partida
wListIdx:    db       ;; Entrada que se esta dibujando en la tabla
wNameIdx:    db       ;; Letra del nombre que se esta editando (0-2)
wNameTimer:  db       ;; Fotogramas que faltan para el siguiente parpadeo de la letra
wNameOn:     db       ;; 1 = la letra elegida se ve

SECTION "Title", ROM0

;;-----------------------------------------------------------------
;; Title_PutWordRow: Escribe en wRowBuf una mitad (fila superior o inferior) de una palabra de letras grandes
;;    Entrada: HL = palabra (indices de letra, acabada en TEXT_END), DE = destino en wRowBuf, B = 0 (arriba) o 1 (abajo)
;;    Cada letra son 4 tiles (arriba-izq, arriba-der, abajo-izq, abajo-der); el punto, 2 (arriba, abajo).
;;    Destruye: A, C, DE, HL
Title_PutWordRow:
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
   ld   a, b
   add  a                    ;; 0 (arriba) o 2 (abajo)
   add  c
   ld   [de], a
   inc  de
   inc  a
   ld   [de], a
   inc  de
   jr   .next
.dot:
   ld   a, TILE_TITLE + 36   ;; Tile de arriba (vacio); el de abajo es el siguiente
   add  b
   ld   [de], a
   inc  de
   jr   .next

TitleWord1: db 0, 1, 2, 3, 4, 5, 6, TEXT_END                          ;; PROJECT
TitleWord2: db 7, TITLE_DOT, 8, TITLE_DOT, 5, TITLE_DOT, 5, TEXT_END  ;; N.I.C.C

;; TitleWordRows palabra, columna, fila: dibuja las 2 filas de una palabra grande
MACRO TitleWordRows
   FOR _h, 2
      ld   a, \3 + _h
      call Row_ClearBg
      ld   hl, \1
      ld   de, wRowBuf + \2
      ld   b, _h
      call Title_PutWordRow
      ld   a, \3 + _h
      call Row_Commit
   ENDR
ENDM

;; MenuOption indice, texto, fila: dibuja una opcion del menu (con la flecha si es la elegida)
MACRO MenuOption
   ld   a, \3
   call Row_ClearBg
   ld   a, [wMenuSel]
   cp   \1
   jr   nz, .noCursor\@
   ld   a, TILE_ARROW
   ld   [wRowBuf + MENU_CURSOR_COL], a
.noCursor\@:
   ld   hl, \2
   ld   b, MENU_TEXT_COL
   call Row_PutString
   ld   a, \3
   call Row_Commit
ENDM

;; CenteredRow texto, fila: una fila con un texto centrado
MACRO CenteredRow
   call Row_Clear
   ld   hl, \1
   call Row_PutCentered
   ld   a, \2
   call Row_Commit
ENDM

;;-----------------------------------------------------------------
;; Row_ClearBg: Rellena wRowBuf con la fila A del fondo decorativo del titulo (TitleBg, en titlebg.asm) en vez de en blanco
;;    Entrada: A = fila (0-17)     Conserva: BC     Destruye: A, DE, HL
Row_ClearBg:
   push bc
   ld   l, a
   ld   h, 0
   add  hl, hl
   add  hl, hl               ;; fila * 4
   ld   d, h
   ld   e, l
   add  hl, hl
   add  hl, hl               ;; fila * 16
   add  hl, de               ;; fila * 20
   ld   de, TitleBg
   add  hl, de
   ld   de, wRowBuf
   ld   b, SCREEN_TILES_W
.copy:
   ld   a, [hl+]
   ld   [de], a
   inc  de
   dec  b
   jr   nz, .copy
   pop  bc
   ret

;;-----------------------------------------------------------------
;; Screen_Enter: Empieza una pantalla nueva: cambia de estado, activa el fondo del mapa 1 y lo borra
;;    Entrada: A = estado
;;    Destruye: A, BC, HL
Screen_Enter:
   ld   [wGameState], a
   ld   a, 2
   ld   [wResultsView], a    ;; Mapa 1 con la paleta invertida
   jp   Scr_Clear

;;-----------------------------------------------------------------
;; Title_Begin: Prepara el menu del titulo al arrancar. Llamar con la LCD apagada.
;;    Destruye: A, BC, DE, HL
Title_Begin::
   call Save_Load            ;; Lee la tabla de puntuaciones
   call Results_Init         ;; Sin filas pendientes
   xor  a
   ld   [wHudDirty], a       ;; (la WRAM arranca con basura: aun no hay partida que dibujar en el HUD)
   ld   [wEndKind], a
   ld   [wMenuSel], a
   ld   [wScoresFrom], a
   ld   [wTextDark], a       ;; El texto con sprites sale en blanco (se pone en negro solo en la pausa)
   ld   a, SCORE_SLOTS
   ld   [wNewPos], a
   call Menu_Show
.flush:                      ;; Con la LCD apagada se puede copiar todo ya
   call Results_Blit
   ld   a, [wDirtyCount]
   and  a
   jr   nz, .flush
   ret

;;-----------------------------------------------------------------
;; Menu_Show: Dibuja el menu del titulo
;;    Destruye: A, BC, DE, HL
Menu_Show:
   ld   a, STATE_TITLE
   call Screen_Enter
   ld   b, 0                 ;; Primero todo el fondo decorativo (celulas), fila a fila; luego el titulo y las opciones encima
.bg:
   ld   a, b
   call Row_ClearBg
   ld   a, b
   call Row_Commit
   inc  b
   ld   a, b
   cp   SCREEN_TILES_H
   jr   nz, .bg
   TitleWordRows TitleWord1, 3, TITLE_ROW1
   TitleWordRows TitleWord2, 5, TITLE_ROW2
   ;; sigue en Menu_PaintOptions

;;-----------------------------------------------------------------
;; Menu_PaintOptions: Dibuja las 3 opciones del menu, con la flecha en la elegida
;;    Destruye: A, BC, DE, HL
Menu_PaintOptions:
   MenuOption 0, StrPlay, MENU_ROW0
   MenuOption 1, StrScores, MENU_ROW0 + 2
   ret

;;-----------------------------------------------------------------
;; Menu_Update: Un fotograma de las pantallas del titulo (estados >= STATE_TITLE)
;;    Destruye: A, BC, DE, HL
Menu_Update::
   ld   a, [wGameState]
   cp   STATE_SCORES
   jp   z, Scores_Update
   cp   STATE_NAME
   jp   z, Name_Update
   ld   a, [wDirtyCount]
   and  a
   ret  nz                   ;; La pantalla aun se esta dibujando
   ldh  a, [hInputNew]
   ld   b, a
   bit  BTNB_UP, b
   jr   nz, .up
   bit  BTNB_DOWN, b
   jr   nz, .down
   bit  BTNB_A, b
   jr   nz, .choose
   bit  BTNB_START, b
   ret  z
.choose:
   ld   a, [wMenuSel]
   and  a
   jr   nz, .scores
.play:
   call Random_Init          ;; Semilla distinta en cada partida: depende de cuando se pulse el boton
   jp   Game_Start
.scores:
   xor  a
   ld   [wScoresFrom], a
   jp   Scores_Show
.up:
.down:                       ;; Con 2 opciones, arriba y abajo hacen lo mismo: pasar a la otra
   ld   a, [wMenuSel]
   xor  1
   ld   [wMenuSel], a
   jp   Menu_PaintOptions

;;=================================================================
;; Tabla de puntuaciones
;;=================================================================

;;-----------------------------------------------------------------
;; Scores_IsZero: Mira si una lista de 5 cifras vale 0
;;    Entrada: HL = lista     Salida: Z = 1 si todas son 0     Destruye: A, B, HL
Scores_IsZero:
   ld   b, SCORE_DIGITS
   xor  a
.loop:
   or   [hl]
   inc  hl
   dec  b
   jr   nz, .loop
   and  a
   ret

;;-----------------------------------------------------------------
;; Scores_Show: Dibuja la tabla (wScoresFrom = 1: marca con una flecha la entrada que acaba de entrar)
;;    Destruye: A, BC, DE, HL
Scores_Show::
   ld   a, STATE_SCORES
   call Screen_Enter
   CenteredRow StrScores, SCORES_ROW_TITLE
   xor  a
   ld   [wListIdx], a
.row:
   call Row_Clear
   ld   a, [wListIdx]
   add  TILE_FONT_DIGIT0 + 1
   ld   [wRowBuf + SCORES_POS_COL], a        ;; Puesto
   ld   a, [wScoresFrom]
   and  a
   jr   z, .noMark
   ld   a, [wListIdx]
   ld   b, a
   ld   a, [wNewPos]
   cp   b
   jr   nz, .noMark
   ld   a, TILE_ARROW
   ld   [wRowBuf + SCORES_MARK_COL], a       ;; Tu puntuacion
.noMark:
   ld   a, [wListIdx]
   add  a
   add  a
   add  a
   ld   e, a
   ld   d, 0
   ld   hl, wScores
   add  hl, de               ;; HL = entrada
   push hl
   ld   de, 3
   add  hl, de               ;; HL = sus cifras
   push hl
   call Scores_IsZero
   pop  hl
   pop  de                   ;; DE = entrada, HL = cifras (pop no cambia las banderas de IsZero)
   jr   z, .empty
   push hl
   ld   hl, wRowBuf + SCORES_NAME_COL
   ld   b, 3
.name:
   ld   a, [de]
   inc  de
   add  TILE_FONT_A
   ld   [hl+], a
   dec  b
   jr   nz, .name
   pop  hl
   ld   b, SCORES_VALUE_COL
   call Row_PutDec5
   jr   .commit
.empty:                      ;; Hueco vacio: "---"
   ld   hl, wRowBuf + SCORES_NAME_COL
   ld   a, TILE_DASH
   ld   [hl+], a
   ld   [hl+], a
   ld   [hl], a
.commit:
   ld   a, [wListIdx]
   add  SCORES_ROW0
   call Row_Commit
   ld   hl, wListIdx
   inc  [hl]
   ld   a, [hl]
   cp   SCORE_SLOTS
   jr   nz, .row
   CenteredRow StrPress, SCORES_ROW_PRESS
   ret

;;-----------------------------------------------------------------
;; Scores_Update: A, B o START: vuelve al menu (o reinicia el juego si se viene de una partida)
;;    Destruye: A, BC, DE, HL
Scores_Update:
   ld   a, [wDirtyCount]
   and  a
   ret  nz
   ldh  a, [hInputNew]
   and  (1 << BTNB_A) | (1 << BTNB_B) | (1 << BTNB_START)
   ret  z
   ld   a, [wScoresFrom]
   and  a
   jp   nz, main             ;; Reinicio completo: titulo
   jp   Menu_Show

;;=================================================================
;; Eleccion del nombre
;;=================================================================

;;-----------------------------------------------------------------
;; Name_EntryPtr: HL = la entrada de la tabla que acaba de entrar (su nombre se edita ahi)
;;    Destruye: A, DE, HL
Name_EntryPtr:
   ld   a, [wNewPos]
   add  a
   add  a
   add  a
   ld   e, a
   ld   d, 0
   ld   hl, wScores
   add  hl, de
   ret

;;-----------------------------------------------------------------
;; Name_Begin: Pantalla para elegir las 3 letras del nombre de la puntuacion que ha entrado en la tabla
;;    Destruye: A, BC, DE, HL
Name_Begin::
   ld   a, STATE_NAME
   call Screen_Enter
   xor  a
   ld   [wNameIdx], a
   ld   a, 1
   ld   [wNameOn], a
   ld   a, NAME_BLINK
   ld   [wNameTimer], a
   call Row_Clear            ;; "NUEVO RECORD" o "PUESTO n"
   ld   a, [wNewPos]
   and  a
   jr   nz, .place
   ld   hl, StrNewRecord
   call Row_PutCentered
   jr   .titleRow
.place:
   push af
   ld   hl, StrPlace
   ld   b, 6
   call Row_PutString
   pop  af
   add  TILE_FONT_DIGIT0 + 1
   ld   [wRowBuf + 13], a
.titleRow:
   ld   a, NAME_ROW_TITLE
   call Row_Commit
   call Row_Clear            ;; Puntos
   ld   hl, StrPoints
   ld   b, RES_LABEL_COL
   call Row_PutString
   ld   hl, wFinalScore
   ld   b, RES_VALUE_COL
   call Row_PutDec5
   ld   a, NAME_ROW_POINTS
   call Row_Commit
   ;; sigue en Name_DrawRow

;;-----------------------------------------------------------------
;; Name_DrawRow: Dibuja "NOMBRE" y las 3 letras (la elegida desaparece cuando toca parpadear)
;;    Destruye: A, BC, DE, HL
Name_DrawRow:
   call Row_Clear
   ld   hl, StrName
   ld   b, 3
   call Row_PutString
   call Name_EntryPtr        ;; HL = letras
   ld   de, wRowBuf + NAME_COL
   ld   b, 0
.letter:
   ld   a, [wNameIdx]
   cp   b
   jr   nz, .show
   ld   a, [wNameOn]
   and  a
   jr   z, .hide
.show:
   ld   a, [hl]
   add  TILE_FONT_A
   jr   .put
.hide:
   xor  a
.put:
   ld   [de], a
   inc  hl
   inc  de
   inc  de
   inc  b
   ld   a, b
   cp   3
   jr   nz, .letter
   ld   a, NAME_ROW
   jp   Row_Commit

;;-----------------------------------------------------------------
;; Name_Update: Un fotograma de la eleccion del nombre
;;    Destruye: A, BC, DE, HL
Name_Update:
   ld   a, [wDirtyCount]
   and  a
   ret  nz
   ldh  a, [hInputNew]
   ld   b, a
   bit  BTNB_A, b
   jr   nz, .accept
   bit  BTNB_START, b
   jr   nz, .accept
   bit  BTNB_UP, b
   jr   nz, .up
   bit  BTNB_DOWN, b
   jr   nz, .down
   bit  BTNB_LEFT, b
   jr   nz, .left
   bit  BTNB_RIGHT, b
   jr   nz, .right
   ld   a, [wNameTimer]      ;; Sin botones: parpadeo
   dec  a
   ld   [wNameTimer], a
   ret  nz
   ld   a, NAME_BLINK
   ld   [wNameTimer], a
   ld   a, [wNameOn]
   xor  1
   ld   [wNameOn], a
   jr   Name_DrawRow
.accept:
   call Save_Store           ;; El nombre ya esta en la tabla: se guarda
   ld   a, 1
   ld   [wScoresFrom], a
   jp   Scores_Show
.up:
   call .letterPtr
   ld   a, [hl]
   inc  a
   cp   NAME_LETTERS
   jr   nz, .store
   xor  a
   jr   .store
.down:
   call .letterPtr
   ld   a, [hl]
   and  a
   jr   nz, .dec
   ld   a, NAME_LETTERS
.dec:
   dec  a
.store:
   ld   [hl], a
   jr   .redraw
.left:
   ld   a, [wNameIdx]
   and  a
   ret  z
   dec  a
   jr   .setIdx
.right:
   ld   a, [wNameIdx]
   cp   2
   ret  nc
   inc  a
.setIdx:
   ld   [wNameIdx], a
.redraw:                     ;; Tras tocar un boton la letra se ve y el parpadeo vuelve a empezar
   ld   a, 1
   ld   [wNameOn], a
   ld   a, NAME_BLINK
   ld   [wNameTimer], a
   jp   Name_DrawRow
.letterPtr:                  ;; HL = la letra que se esta editando
   call Name_EntryPtr
   ld   a, [wNameIdx]
   ld   e, a
   ld   d, 0
   add  hl, de
   ret
