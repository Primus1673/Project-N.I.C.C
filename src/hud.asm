;;-------------------------------------------------------------------------------------------------------------------------------;;
;; hud.asm : HUD (vidas y puntuacion) dibujado con tiles del fondo en la fila superior del marco
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; Corazones a la izquierda (uno por vida posible: llenos = vidas que quedan), la barra de energia, el multiplicador de combo ("X3") en el centro
;; y 5 cifras de puntuacion a la derecha.
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
   ;;-- Barra de energia: HUD_BAR_TILES tiles; cada uno muestra 0 a 8 pixeles rellenos (tiles TILE_BAR + n).
   ;;   Llena y sin activar, parpadea (se ve cuando el bit 4 de wEnergyBlink vale 1).
   ld   hl, _SCRN0 + HUD_BAR_COL
   ld   a, [wMissileMode]
   and  a
   jr   nz, .barShow
   ld   a, [wEnergy]
   cp   ENERGY_MAX
   jr   nz, .barShow
   ld   a, [wEnergyBlink]
   bit  4, a
   jr   nz, .barShow
   ld   c, 0                    ;; Fase oculta del parpadeo: barra vacia
   jr   .barDraw
.barShow:
   ld   a, [wEnergy]
   ld   c, a                    ;; C = pixeles que quedan por dibujar
.barDraw:
   ld   b, HUD_BAR_TILES
.bar:
   ld   a, c
   cp   TILE_SIZE
   jr   c, .part
   sub  TILE_SIZE
   ld   c, a
   ld   a, TILE_SIZE            ;; Tile lleno
   jr   .putBar
.part:
   ld   c, 0                    ;; A = pixeles de este tile (menos de 8)
.putBar:
   add  TILE_BAR
   ld   [hl+], a
   dec  b
   jr   nz, .bar

   ;;--------------------------------------
   ;;-- Multiplicador de combo ("X3"): solo con x2 o mas y en la fase visible del parpadeo; si no, se restaura el marco
   ld   hl, _SCRN0 + HUD_COMBO_COL
   ld   a, [wMult]
   cp   2
   jr   c, .noCombo
   ld   a, [wComboShow]
   and  a
   jr   z, .noCombo
   ld   a, TILE_HUD_X
   ld   [hl+], a
   ld   a, [wMult]
   add  TILE_DIGIT0
   ld   [hl], a
   jr   .comboDone
.noCombo:
   ld   a, TILE_BORDER
   ld   [hl+], a
   ld   [hl], a
.comboDone:

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
