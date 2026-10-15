;;-------------------------------------------------------------------------------------------------------------------------------;;
;; hud.asm : HUD (vidas y puntuacion) dibujado con tiles del fondo en la fila superior del marco
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; Corazones a la izquierda (uno por vida posible: llenos = vidas que quedan) y 5 cifras de puntuacion a la derecha.
;; Solo se escribe en la VRAM cuando algo ha cambiado (wHudDirty), y siempre al empezar el VBlank (o con la LCD apagada).
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "HUD", ROM0

;;-----------------------------------------------------------------
;; Hud_Update: Si hace falta, redibuja corazones y puntuacion
;;    IMPORTANTE: solo llamar con la LCD apagada o al principio del VBlank
;;    Destruye: A, B, C, DE, HL
Hud_Update::
   ld   a, [wHudDirty]
   and  a
   ret  z
   xor  a
   ld   [wHudDirty], a

   ;;--------------------------------------
   ;;-- Corazones: PLAYER_LIVES huecos; los primeros "wLives" llenos, el resto vacios
   ld   hl, _SCRN0 + HUD_HEARTS_COL
   ld   a, [wLives]
   ld   c, a
   ld   b, PLAYER_LIVES
.heart:
   ld   a, c
   and  a
   ld   a, TILE_HEART_EMPTY  ;; (ld no toca los flags: seguimos con el resultado de "and a")
   jr   z, .putHeart
   dec  c
   ld   a, TILE_HEART_FULL
.putHeart:
   ld   [hl+], a
   dec  b
   jr   nz, .heart

   ;;--------------------------------------
   ;;-- Puntuacion: una cifra por tile
   ld   hl, _SCRN0 + HUD_SCORE_COL
   ld   de, wScore
   ld   b, SCORE_DIGITS
.digit:
   ld   a, [de]
   inc  de
   add  TILE_DIGIT0
   ld   [hl+], a
   dec  b
   jr   nz, .digit
   ret
