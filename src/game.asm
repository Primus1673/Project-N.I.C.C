;;-------------------------------------------------------------------------------------------------------------------------------;;
;; game.asm : Estado de la partida: vidas, invulnerabilidad, puntuacion, fin de partida y reinicio
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Game Variables", WRAM0

wGameState::  db                ;; STATE_PLAYING o STATE_GAMEOVER
wLives::      db                ;; Vidas que quedan
wInvuln::     db                ;; Fotogramas de invulnerabilidad que quedan (0 = vulnerable)
wScore::      ds SCORE_DIGITS   ;; Puntuacion: una cifra decimal (0-9) por byte, la mas significativa primero
wHudDirty::   db                ;; A 1 si hay que redibujar el HUD en el proximo VBlank

SECTION "Game", ROM0

;;-----------------------------------------------------------------
;; Game_Start: Empieza una partida nueva (tambien sirve para reiniciar tras perder)
;;    Destruye: A, BC, DE, HL
Game_Start::
   call Player_Init
   call Bullets_Init
   call Enemies_Init
   ld   a, STATE_PLAYING
   ld   [wGameState], a
   ld   a, PLAYER_LIVES
   ld   [wLives], a
   xor  a
   ld   [wInvuln], a
   ld   hl, wScore
   ld   bc, SCORE_DIGITS
   call MemSet               ;; Puntuacion a 0
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Game_Update: Un fotograma de juego. Jugando: mueve todo y cuenta la invulnerabilidad.
;;    Con la partida perdida todo queda congelado y START empieza otra.
;;    Destruye: A, BC, DE, HL
Game_Update::
   ld   a, [wGameState]
   and  a
   jr   nz, .gameOver

   call Player_Update
   call Bullets_Update
   call Enemies_Update       ;; Incluye los choques con el jugador (Game_PlayerHit)
   ld   a, [wInvuln]
   and  a
   ret  z
   dec  a
   ld   [wInvuln], a
   ret

.gameOver:
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   ret  z
   jp   Game_Start

;;-----------------------------------------------------------------
;; Game_PlayerHit: El jugador ha sido golpeado: pierde una vida y queda invulnerable; sin vidas, fin de la partida
;;    Destruye: A
Game_PlayerHit::
   ld   a, [wLives]
   dec  a
   ld   [wLives], a
   ld   a, 1
   ld   [wHudDirty], a
   ld   a, [wLives]
   and  a
   jr   z, .dead
   ld   a, INVULN_FRAMES
   ld   [wInvuln], a
   ret
.dead:
   ld   a, STATE_GAMEOVER
   ld   [wGameState], a
   ret

;;-----------------------------------------------------------------
;; Score_AddTens: Suma A decenas a la puntuacion (A=5 -> +50 puntos). Se satura en 99999.
;;    Entrada: A = decenas a sumar
;;    Conserva todos los registros menos A y los flags
Score_AddTens::
   push bc
   push hl
   and  a
   jr   z, .end
   ld   b, a
.again:
   ld   hl, wScore + SCORE_DIGITS - 2   ;; Cifra de las decenas
   ld   c, SCORE_DIGITS - 1             ;; Cifras que pueden recibir acarreo (decenas hacia la izquierda)
.carry:
   inc  [hl]
   ld   a, [hl]
   cp   10
   jr   c, .added
   xor  a
   ld   [hl], a                         ;; 10 -> 0 y acarreo a la cifra de la izquierda
   dec  hl
   dec  c
   jr   nz, .carry
   ;; Se ha pasado de 99999: dejamos 99999
   ld   hl, wScore
   ld   c, SCORE_DIGITS
   ld   a, 9
.sat:
   ld   [hl+], a
   dec  c
   jr   nz, .sat
   jr   .end
.added:
   dec  b
   jr   nz, .again
.end:
   ld   a, 1
   ld   [wHudDirty], a
   pop  hl
   pop  bc
   ret
