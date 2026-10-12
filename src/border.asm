;;-------------------------------------------------------------------------------------------------------------------------------;;
;; border.asm : Marco (borde) de la pantalla de juego
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; El marco se dibuja en el mapa de fondo (BG), no con sprites. La pantalla tiene 20x18 tiles, asi que el contorno
;; son 72 tiles; la Game Boy solo permite 40 sprites en total y 10 por linea, por lo que no cabria. Ademas, el
;; fondo no consume sprites, que quedan libres para el jugador, los enemigos y los disparos.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Border", ROM0

;;-----------------------------------------------------------------
;; Border_Draw: Dibuja el marco de 1 tile de grosor en el borde de la zona visible del mapa de fondo 0
;;    Supone que el mapa ya esta limpio (main.asm lo rellena con TILE_BLANK antes de llamar aqui)
;;    IMPORTANTE: solo llamar con la LCD apagada o durante el VBlank
;;    Destruye: A, BC, DE, HL
Border_Draw::
   ;;--------------------------------------
   ;;-- Fila superior (fila 0)
   ld   hl, _SCRN0
   ld   bc, SCREEN_TILES_W
   ld   a, TILE_BORDER
   call MemSet

   ;;--------------------------------------
   ;;-- Fila inferior (ultima fila visible)
   ld   hl, _SCRN0 + (SCREEN_TILES_H - 1) * MAP_STRIDE
   ld   bc, SCREEN_TILES_W
   ld   a, TILE_BORDER
   call MemSet

   ;;--------------------------------------
   ;;-- Columnas izquierda y derecha, en las filas intermedias (de la 1 a la penultima)
   ld   hl, _SCRN0 + MAP_STRIDE         ;; Primer tile de la fila 1
   ld   b, SCREEN_TILES_H - 2           ;; Numero de filas intermedias
   ld   a, TILE_BORDER
.row:
   ld   [hl], a                         ;; Tile de la columna izquierda
   ld   de, SCREEN_TILES_W - 1
   add  hl, de
   ld   [hl], a                         ;; Tile de la columna derecha
   ld   de, MAP_STRIDE - (SCREEN_TILES_W - 1)
   add  hl, de                          ;; Primer tile de la fila siguiente
   dec  b
   jr   nz, .row
   ret
