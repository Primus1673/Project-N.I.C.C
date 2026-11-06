;;-------------------------------------------------------------------------------------------------------------------------------;;
;; player.asm : El jugador (nanomaquina N.I.C.C): posicion, movimiento y dibujado
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Player Variables", WRAM0

wPlayerX:: db
wPlayerY:: db

SECTION "Player", ROM0

;;-----------------------------------------------------------------
;; Player_Init: Coloca al jugador en el centro de la pantalla
Player_Init::
   ld   a, PLAYER_START_X
   ld   [wPlayerX], a
   ld   a, PLAYER_START_Y
   ld   [wPlayerY], a
   ret

;;-----------------------------------------------------------------
;; Player_Update: Mueve al jugador segun la cruceta, sin dejar que salga de los limites de la pantalla
Player_Update::
   ldh  a, [hInput]
   ld   b, a

   ;;--------------------------------------
;; -- Eje horizontal
   bit  BTNB_RIGHT, b
   jr   z, .noRight
   ld   a, [wPlayerX]
   add  PLAYER_SPEED
   cp   PLAYER_MAX_X + 1
   jr   c, .storeRight
   ld   a, PLAYER_MAX_X
.storeRight:
   ld   [wPlayerX], a
.noRight:

   bit  BTNB_LEFT, b
   jr   z, .noLeft
   ld   a, [wPlayerX]
   sub  PLAYER_SPEED
   jr   c, .clampLeft
   cp   PLAYER_MIN_X
   jr   nc, .storeLeft
.clampLeft:
   ld   a, PLAYER_MIN_X
.storeLeft:
   ld   [wPlayerX], a
.noLeft:

   ;;--------------------------------------
;; -- Eje vertical
   bit  BTNB_DOWN, b
   jr   z, .noDown
   ld   a, [wPlayerY]
   add  PLAYER_SPEED
   cp   PLAYER_MAX_Y + 1
   jr   c, .storeDown
   ld   a, PLAYER_MAX_Y
.storeDown:
   ld   [wPlayerY], a
.noDown:

   bit  BTNB_UP, b
   jr   z, .noUp
   ld   a, [wPlayerY]
   sub  PLAYER_SPEED
   jr   c, .clampUp
   cp   PLAYER_MIN_Y
   jr   nc, .storeUp
.clampUp:
   ld   a, PLAYER_MIN_Y
.storeUp:
   ld   [wPlayerY], a
.noUp:
   ret

;;-----------------------------------------------------------------
;; Player_Draw: Escribe el sprite del jugador en la OAM en sombra (sprite numero 0)
Player_Draw::
   ld   a, [wGameState]
   cp   STATE_GAMEOVER
   jr   z, .hide
   ld   a, [wInvuln]
   and  BLINK_MASK
   jr   nz, .hide
   ld   a, [wChargeHide]
   and  a
   jr   nz, .hide
   ld   hl, wShadowOAM
   ld   a, [wPlayerY]
   add  OAM_Y_OFFSET
   ld   [hl+], a
   ld   a, [wPlayerX]
   add  OAM_X_OFFSET
   ld   [hl+], a
   ld   a, TILE_PLAYER
   ld   [hl+], a
   xor  a
   ld   [hl], a
   ret
.hide:
   ld   hl, wShadowOAM
   xor  a
   ld   [hl+], a
   ld   [hl+], a
   ld   [hl+], a
   ld   [hl], a
   ret
