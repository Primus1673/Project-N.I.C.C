;;-------------------------------------------------------------------------------------------------------------------------------;;
;; player.asm : El jugador (nanomaquina N.I.C.C): posicion, movimiento y dibujado
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Player Variables", WRAM0

wPlayerX:: db        ;; Posicion X en pantalla (esquina superior izquierda del sprite, 0..159)
wPlayerY:: db        ;; Posicion Y en pantalla (esquina superior izquierda del sprite, 0..143)

SECTION "Player", ROM0

;;-----------------------------------------------------------------
;; Player_Init: Coloca al jugador en el centro de la pantalla
;;    Destruye: A
Player_Init::
   ld   a, PLAYER_START_X
   ld   [wPlayerX], a
   ld   a, PLAYER_START_Y
   ld   [wPlayerY], a
   ret

;;-----------------------------------------------------------------
;; Player_Update: Mueve al jugador segun la cruceta, sin dejar que salga de los limites de la pantalla
;;    Destruye: A, B
Player_Update::
   ldh  a, [hInput]
   ld   b, a

   ;;--------------------------------------
   ;;-- Eje horizontal
   bit  BTNB_RIGHT, b
   jr   z, .noRight
   ld   a, [wPlayerX]
   add  PLAYER_SPEED
   cp   PLAYER_MAX_X + 1
   jr   c, .storeRight       ;; Si X <= maximo, valido
   ld   a, PLAYER_MAX_X      ;; Si no, lo dejamos en el borde derecho
.storeRight:
   ld   [wPlayerX], a
.noRight:

   bit  BTNB_LEFT, b
   jr   z, .noLeft
   ld   a, [wPlayerX]
   sub  PLAYER_SPEED
   jr   c, .clampLeft        ;; Si ha dado la vuelta por debajo de 0
   cp   PLAYER_MIN_X
   jr   nc, .storeLeft       ;; Si X >= minimo, valido
.clampLeft:
   ld   a, PLAYER_MIN_X      ;; Si no, lo dejamos en el borde izquierdo
.storeLeft:
   ld   [wPlayerX], a
.noLeft:

   ;;--------------------------------------
   ;;-- Eje vertical
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
;;    El DMA lo copiara a la OAM real en el proximo VBlank
;;    - Con la partida perdida la nave desaparece.
;;    - Durante la invulnerabilidad parpadea (oculta mientras el bit BLINK_MASK de wInvuln vale 1).
;;    Destruye: A, HL
Player_Draw::
   ld   a, [wGameState]
   and  a
   jr   nz, .hide            ;; Partida perdida
   ld   a, [wInvuln]
   and  BLINK_MASK
   jr   nz, .hide            ;; Fase "apagada" del parpadeo
   ld   hl, wShadowOAM
   ld   a, [wPlayerY]
   add  OAM_Y_OFFSET
   ld   [hl+], a             ;; Byte 0: Y
   ld   a, [wPlayerX]
   add  OAM_X_OFFSET
   ld   [hl+], a             ;; Byte 1: X
   ld   a, TILE_PLAYER
   ld   [hl+], a             ;; Byte 2: numero de tile
   xor  a
   ld   [hl], a              ;; Byte 3: atributos (paleta OBP0, sin volteos, delante del fondo)
   ret
.hide:
   ld   hl, wShadowOAM
   xor  a
   ld   [hl+], a             ;; Y = 0: sprite oculto
   ld   [hl+], a
   ld   [hl+], a
   ld   [hl], a
   ret
