;;-------------------------------------------------------------------------------------------------------------------------------;;
;; title.asm : Menu del titulo, tabla de puntuaciones y eleccion de nombre
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

DEF TITLE_DOT EQU 9

SECTION "Title Variables", WRAM0

wMenuSel:    db
wScoresFrom: db
wListIdx:    db
wNameIdx:    db
wNameTimer:  db
wNameOn:     db

wVicTimer:   db
wVicPal:     db
wVicShow:    db

SECTION "Title", ROM0

;;-----------------------------------------------------------------
;; Title_PutWordRow: Escribe en wRowBuf una mitad de una palabra de letras grandes
Title_PutWordRow:
.next:
   ld   a, [hl+]
   cp   TEXT_END
   ret  z
   cp   TITLE_DOT
   jr   z, .dot
   add  a
   add  a
   add  TILE_TITLE
   ld   c, a
   ld   a, b
   add  a
   add  c
   ld   [de], a
   inc  de
   inc  a
   ld   [de], a
   inc  de
   jr   .next
.dot:
   ld   a, TILE_TITLE + 36
   add  b
   ld   [de], a
   inc  de
   jr   .next

TitleWord1: db 0, 1, 2, 3, 4, 5, 6, TEXT_END
TitleWord2: db 7, TITLE_DOT, 8, TITLE_DOT, 5, TITLE_DOT, 5, TEXT_END

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

MACRO CenteredRow
   call Row_Clear
   ld   hl, \1
   call Row_PutCentered
   ld   a, \2
   call Row_Commit
ENDM

;;-----------------------------------------------------------------
;; Row_ClearBg: Rellena wRowBuf con la fila A del fondo decorativo del titulo en vez de en blanco
Row_ClearBg:
   push bc
   ld   l, a
   ld   h, 0
   add  hl, hl
   add  hl, hl
   ld   d, h
   ld   e, l
   add  hl, hl
   add  hl, hl
   add  hl, de
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
Screen_Enter:
   ld   [wGameState], a
   ld   a, 2
   ld   [wResultsView], a
   jp   Scr_Clear

;;-----------------------------------------------------------------
;; Title_Begin: Prepara el menu del titulo al arrancar
Title_Begin::
   call Save_Load
   call Results_Init
   xor  a
   ld   [wHudDirty], a
   ld   [wEndKind], a
   ld   [wMenuSel], a
   ld   [wScoresFrom], a
   ld   [wTextDark], a
   ld   a, SCORE_SLOTS
   ld   [wNewPos], a
   call Menu_Show
.flush:
   call Results_Blit
   ld   a, [wDirtyCount]
   and  a
   jr   nz, .flush
   ret

;;-----------------------------------------------------------------
;; Menu_Show: Dibuja el menu del titulo
Menu_Show:
   ld   a, STATE_TITLE
   call Screen_Enter
   ld   b, 0
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
Menu_PaintOptions:
   MenuOption 0, StrPlay, MENU_ROW0
   MenuOption 1, StrScores, MENU_ROW0 + 2
   ret

;;-----------------------------------------------------------------
;; Victory_Begin: Empieza la pantalla de victoria
Victory_Begin::
   ld   a, STATE_VICTORY
   call Screen_Enter
   xor  a
   ld   [wVicTimer], a
   inc  a
   ld   [wVicShow], a
   ld   a, 2
   ld   [wVicPal], a
   CenteredRow StrWin, VIC_ROW_TITLE
   CenteredRow StrInfection, VIC_ROW_L1
   CenteredRow StrEradicated, VIC_ROW_L2
   jp   Sprites_Clear

;;-----------------------------------------------------------------
;; Victory_Update: Un fotograma de la pantalla de victoria
Victory_Update:
   ld   a, [wDirtyCount]
   and  a
   ret  nz
   ld   a, [wVicTimer]
   inc  a
   jr   nz, .store
   dec  a
.store:
   ld   [wVicTimer], a
   ld   b, a
   cp   VIC_FLASH_FRAMES
   jr   nc, .steady
   and  %00001000
   jr   z, .pal0
   ld   a, 1
   jr   .setPal
.steady:
.pal0:
   xor  a
.setPal:
   ld   [wVicPal], a
   ld   a, b
   cp   VIC_FLASH_FRAMES
   jr   c, .ret
   jr   nz, .afterPress
   call Row_Clear
   ld   hl, StrPress
   call Row_PutCentered
   ld   a, VIC_ROW_PRESS
   call Row_Commit
   ret
.afterPress:
   ld   a, b
   cp   VIC_FLASH_FRAMES + 32
   jr   c, .input
   and  VIC_BLINK_MASK
   jr   nz, .input
   ld   a, [wVicShow]
   xor  1
   ld   [wVicShow], a
   call Row_Clear
   ld   a, [wVicShow]
   and  a
   jr   z, .commitTitle
   ld   hl, StrWin
   call Row_PutCentered
.commitTitle:
   ld   a, VIC_ROW_TITLE
   call Row_Commit
.input:
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   ret  z
   jp   Game_ToResults
.ret:
   ret

;;-----------------------------------------------------------------
;; Menu_Update: Un fotograma de las pantallas del titulo (estados >= STATE_TITLE)
Menu_Update::
   ld   a, [wGameState]
   cp   STATE_VICTORY
   jp   z, Victory_Update
   cp   STATE_SCORES
   jp   z, Scores_Update
   cp   STATE_NAME
   jp   z, Name_Update
   ld   a, [wDirtyCount]
   and  a
   ret  nz
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
   call Random_Init
   jp   Game_Start
.scores:
   xor  a
   ld   [wScoresFrom], a
   jp   Scores_Show
.up:
.down:
   ld   a, [wMenuSel]
   xor  1
   ld   [wMenuSel], a
   jp   Menu_PaintOptions

;;-----------------------------------------------------------------
;; Scores_IsZero: Mira si una lista de 5 cifras vale 0
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
   ld   [wRowBuf + SCORES_POS_COL], a
   ld   a, [wScoresFrom]
   and  a
   jr   z, .noMark
   ld   a, [wListIdx]
   ld   b, a
   ld   a, [wNewPos]
   cp   b
   jr   nz, .noMark
   ld   a, TILE_ARROW
   ld   [wRowBuf + SCORES_MARK_COL], a
.noMark:
   ld   a, [wListIdx]
   add  a
   add  a
   add  a
   ld   e, a
   ld   d, 0
   ld   hl, wScores
   add  hl, de
   push hl
   ld   de, 3
   add  hl, de
   push hl
   call Scores_IsZero
   pop  hl
   pop  de
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
.empty:
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
Scores_Update:
   ld   a, [wDirtyCount]
   and  a
   ret  nz
   ldh  a, [hInputNew]
   and  (1 << BTNB_A) | (1 << BTNB_B) | (1 << BTNB_START)
   ret  z
   ld   a, [wScoresFrom]
   and  a
   jp   nz, main
   jp   Menu_Show

;;-----------------------------------------------------------------
;; Name_EntryPtr: HL = la entrada de la tabla que acaba de entrar (su nombre se edita ahi)
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
Name_Begin::
   ld   a, STATE_NAME
   call Screen_Enter
   xor  a
   ld   [wNameIdx], a
   ld   a, 1
   ld   [wNameOn], a
   ld   a, NAME_BLINK
   ld   [wNameTimer], a
   call Row_Clear
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
   call Row_Clear
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
Name_DrawRow:
   call Row_Clear
   ld   hl, StrName
   ld   b, 3
   call Row_PutString
   call Name_EntryPtr
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
   ld   a, [wNameTimer]
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
   call Save_Store
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
.redraw:
   ld   a, 1
   ld   [wNameOn], a
   ld   a, NAME_BLINK
   ld   [wNameTimer], a
   jp   Name_DrawRow
.letterPtr:
   call Name_EntryPtr
   ld   a, [wNameIdx]
   ld   e, a
   ld   d, 0
   add  hl, de
   ret
