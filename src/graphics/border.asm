;;-------------------------------------------------------------------------------------------------------------------------------;;
;; border.asm : Marco (borde) de la pantalla de juego
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Border", ROM0

;;-----------------------------------------------------------------
;; Border_Draw: Dibuja el marco de 1 tile de grosor en el borde de la zona visible del mapa de fondo 0
Border_Draw::
   ;;--------------------------------------
;; -- Fila superior (fila 0)
   ld   hl, _SCRN0
   ld   bc, SCREEN_TILES_W
   ld   a, TILE_BORDER
   call MemSet

   ;;--------------------------------------
;; -- Fila inferior (ultima fila visible)
   ld   hl, _SCRN0 + (SCREEN_TILES_H - 1) * MAP_STRIDE
   ld   bc, SCREEN_TILES_W
   ld   a, TILE_BORDER
   call MemSet

   ;;--------------------------------------
;; -- Columnas izquierda y derecha, en las filas intermedias (de la 1 a la penultima)
   ld   hl, _SCRN0 + MAP_STRIDE
   ld   b, SCREEN_TILES_H - 2
   ld   a, TILE_BORDER
.row:
   ld   [hl], a
   ld   de, SCREEN_TILES_W - 1
   add  hl, de
   ld   [hl], a
   ld   de, MAP_STRIDE - (SCREEN_TILES_W - 1)
   add  hl, de
   dec  b
   jr   nz, .row
   ret
