;;-------------------------------------------------------------------------------------------------------------------------------;;
;; hud.asm : HUD (vidas y puntuacion) dibujado con tiles del fondo en la fila superior del marco
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "HUD", ROM0

;;-----------------------------------------------------------------
;; Hud_Update: Si hace falta, redibuja baterias y puntuacion
Hud_Update::
   ld   a, [wHudDirty]
   and  a
   ret  z
   xor  a
   ld   [wHudDirty], a

   ;;--------------------------------------
;; -- Baterias (vidas): PLAYER_LIVES huecos; los primeros "wLives" llenos, el resto vacios
   ld   hl, _SCRN0 + HUD_HEARTS_COL
   ld   a, [wLives]
   ld   c, a
   ld   b, PLAYER_LIVES
.heart:
   ld   a, c
   and  a
   ld   a, TILE_HEART_EMPTY
   jr   z, .putHeart
   dec  c
   ld   a, TILE_HEART_FULL
.putHeart:
   ld   [hl+], a
   dec  b
   jr   nz, .heart

   ;;--------------------------------------
;; -- Barra de energia: HUD_BAR_TILES tiles; cada uno muestra 0 a 8 pixeles rellenos
   ld   hl, _SCRN0 + HUD_BAR_COL
   ld   a, [wShield]
   and  a
   jr   nz, .barShow
   ld   a, [wEnergy]
   cp   ENERGY_MAX
   jr   nz, .barShow
   ld   a, [wEnergyBlink]
   bit  4, a
   jr   nz, .barShow
   ld   c, 0
   jr   .barDraw
.barShow:
   ld   a, [wEnergy]
   ld   c, a
.barDraw:
   ld   b, HUD_BAR_TILES
.bar:
   ld   a, c
   cp   TILE_SIZE
   jr   c, .part
   sub  TILE_SIZE
   ld   c, a
   ld   a, TILE_SIZE
   jr   .putBar
.part:
   ld   c, 0
.putBar:
   add  TILE_BAR
   ld   [hl+], a
   dec  b
   jr   nz, .bar

   ;;--------------------------------------
;; -- Multiplicador de combo: solo con x2 o mas y en la fase visible del parpadeo
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
;; -- Cronometro de la fase: segundos que quedan, 2 cifras
   ld   hl, _SCRN0 + HUD_TIME_COL
   ld   a, [wPhase]
   cp   BOSS_PHASE
   jr   nz, .clock
   ld   a, [wBossHp]
   add  a
   add  a
   add  a
   add  14
   ld   b, 0
.hpDiv:
   cp   15
   jr   c, .hpDone
   sub  15
   inc  b
   jr   .hpDiv
.hpDone:
   ld   a, b
   cp   TILE_SIZE
   jr   c, .hpFirst
   sub  TILE_SIZE
   ld   b, a
   ld   a, TILE_SIZE
   jr   .hpPut
.hpFirst:
   ld   b, 0
.hpPut:
   add  TILE_BAR
   ld   [hl+], a
   ld   a, b
   add  TILE_BAR
   ld   [hl], a
   jr   .timeDone
.clock:
   ld   a, [wPhaseSec]
   cp   TIME_BLINK_SEC + 1
   jr   nc, .timeShow
   ld   a, [wSecFrames]
   cp   30
   jr   c, .timeHide
.timeShow:
   ld   a, [wPhaseSec]
   ld   b, 0
.tens:
   cp   10
   jr   c, .tensDone
   sub  10
   inc  b
   jr   .tens
.tensDone:
   ld   c, a
   ld   a, b
   add  TILE_DIGIT0
   ld   [hl+], a
   ld   a, c
   add  TILE_DIGIT0
   ld   [hl], a
   jr   .timeDone
.timeHide:
   ld   a, TILE_BORDER
   ld   [hl+], a
   ld   [hl], a
.timeDone:

   ;;--------------------------------------
;; -- Puntuacion: una cifra por tile
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
