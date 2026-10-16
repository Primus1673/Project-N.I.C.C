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
wPhase::      db                ;; Fase actual (1 a PHASE_COUNT)
wPhaseTimerLo: db               ;; Fotogramas que faltan para acabar la fase (16 bits)
wPhaseTimerHi: db
wFadeLevel:   db                ;; Oscurecimiento de la pantalla: 0 normal ... FADE_BLACK negro
wStateTimer:  db                ;; Cuenta atras de los estados de transicion

SECTION "Game", ROM0

;;-----------------------------------------------------------------
;; Game_Start: Empieza una partida nueva (tambien sirve para reiniciar tras perder): fase 1, 3 vidas, 0 puntos
;;    Destruye: A, BC, DE, HL
Game_Start::
   call Player_Init
   ld   a, STATE_PLAYING
   ld   [wGameState], a
   ld   a, PLAYER_LIVES
   ld   [wLives], a
   ld   hl, wScore
   ld   bc, SCORE_DIGITS
   xor  a
   call MemSet               ;; Puntuacion a 0
   ld   a, 1
   ld   [wHudDirty], a
   ld   [wPhase], a          ;; Fase 1
   call Combo_Reset          ;; Sin cadena de bajas
   ;; sigue en Game_BeginPhase

;;-----------------------------------------------------------------
;; Game_BeginPhase: Prepara la fase wPhase: vacia balas y enemigos, carga su dificultad, pone su temporizador
;;    y muestra la pantalla negra con el texto "FASE N"
;;    Destruye: A, BC, DE, HL
Game_BeginPhase:
   call Bullets_Init
   call Enemies_Init
   ld   a, [wPhase]
   dec  a
   call Enemies_SetPhase
   ld   a, LOW(PHASE_FRAMES)
   ld   [wPhaseTimerLo], a
   ld   a, HIGH(PHASE_FRAMES)
   ld   [wPhaseTimerHi], a
   xor  a
   ld   [wInvuln], a
   ld   a, FADE_BLACK
   ld   [wFadeLevel], a
   ld   a, INTRO_FRAMES
   ld   [wStateTimer], a
   ld   a, STATE_INTRO
   ld   [wGameState], a
   jp   Sprites_Clear

;;-----------------------------------------------------------------
;; Game_StepTimer: Avanza el contador de un escalon de fundido
;;    Salida: Z = 1 si el escalon ha terminado (y el contador se recarga), Z = 0 si aun falta
;;    Destruye: A
Game_StepTimer:
   ld   a, [wStateTimer]
   dec  a
   jr   nz, .wait
   ld   a, FADE_STEP_FRAMES
   ld   [wStateTimer], a
   xor  a                    ;; Z = 1
   ret
.wait:
   ld   [wStateTimer], a     ;; (ld no toca los flags: Z sigue a 0)
   ret

;;-----------------------------------------------------------------
;; Game_Update: Un fotograma del estado de la partida (ver STATE_* en constants.inc):
;;    JUGANDO -> (fin de fase) FADE_OUT -> INTRO ("FASE N") -> FADE_IN -> JUGANDO ... -> tras la ultima fase: FINISHED
;;    Con GAMEOVER o FINISHED todo queda congelado y START empieza una partida nueva.
;;    Destruye: A, BC, DE, HL
Game_Update::
   ld   a, [wGameState]
   cp   STATE_PLAYING
   jr   z, .playing
   cp   STATE_FADE_OUT
   jr   z, .fadeOut
   cp   STATE_INTRO
   jr   z, .intro
   cp   STATE_FADE_IN
   jp   z, .fadeIn
   ;; GAMEOVER o FINISHED: esperar START
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   ret  z
   jp   Game_Start

.playing:
   call Player_Update
   call Bullets_Update
   call Enemies_Update       ;; Incluye los choques con el jugador (Game_PlayerHit)
   ld   a, [wGameState]
   cp   STATE_PLAYING
   ret  nz                   ;; Ha perdido la ultima vida en este fotograma
   call Combo_Update         ;; Cuenta atras y parpadeo del combo (solo avanza aqui: se detiene en las transiciones de fase)
   ld   a, [wInvuln]
   and  a
   jr   z, .noInvuln
   dec  a
   ld   [wInvuln], a
.noInvuln:
   ;; Temporizador de la fase (16 bits)
   ld   a, [wPhaseTimerLo]
   ld   l, a
   ld   a, [wPhaseTimerHi]
   ld   h, a
   dec  hl
   ld   a, l
   ld   [wPhaseTimerLo], a
   ld   a, h
   ld   [wPhaseTimerHi], a
   or   l
   ret  nz
   ;; La fase ha terminado: empieza a oscurecerse la pantalla (todo queda congelado)
   ld   a, STATE_FADE_OUT
   ld   [wGameState], a
   xor  a
   ld   [wFadeLevel], a
   ld   a, FADE_STEP_FRAMES
   ld   [wStateTimer], a
   ret

.fadeOut:
   call Game_StepTimer
   ret  nz
   ld   a, [wFadeLevel]
   inc  a
   ld   [wFadeLevel], a
   cp   FADE_BLACK
   ret  nz
   ld   a, [wPhase]
   cp   PHASE_COUNT
   jr   z, .finished
   inc  a
   ld   [wPhase], a
   jp   Game_BeginPhase      ;; Siguiente fase: pantalla negra con su texto
.finished:
   ld   a, STATE_FINISHED
   ld   [wGameState], a
   jp   Sprites_Clear

.intro:
   ld   a, [wStateTimer]
   dec  a
   ld   [wStateTimer], a
   ret  nz
   call Sprites_Clear        ;; Desaparece el texto
   ld   a, FADE_STEP_FRAMES
   ld   [wStateTimer], a
   ld   a, STATE_FADE_IN
   ld   [wGameState], a
   ret

.fadeIn:
   call Game_StepTimer
   ret  nz
   ld   a, [wFadeLevel]
   dec  a
   ld   [wFadeLevel], a
   ret  nz
   ld   a, STATE_PLAYING     ;; Pantalla normal: empieza la fase (las celulas saldran tras ENEMY_SPAWN_FIRST fotogramas)
   ld   [wGameState], a
   ret

;;-----------------------------------------------------------------
;; Game_ApplyFade: Pone las paletas de fondo y sprites segun wFadeLevel (0 normal ... 3 negro)
;;    IMPORTANTE: llamar al principio del VBlank (o con la LCD apagada), si no se ve un corte en la pantalla
;;    Destruye: A, DE, HL
Game_ApplyFade::
   ld   a, [wFadeLevel]
   ld   e, a
   ld   d, 0
   ld   hl, FadePalettes
   add  hl, de
   ld   a, [hl]
   ldh  [rBGP], a
   ldh  [rOBP0], a
   ret

FadePalettes:                ;; %DDCCBBAA (AA = color 0): cada escalon hace cada color un tono mas oscuro
   db   PALETTE_DEFAULT     ;; 0: normal      (0,1,2,3)
   db   %11111001           ;; 1:             (1,2,3,3)
   db   %11111110           ;; 2:             (2,3,3,3)
   db   %11111111           ;; 3: negro       (3,3,3,3)

;;-----------------------------------------------------------------
;; Game_Draw: Escribe los sprites de este fotograma en la OAM en sombra
;;    Pantallas de texto (INTRO y FINISHED): solo el texto. Resto: nave, balas y enemigos.
;;    Destruye: A, BC, DE, HL
Game_Draw::
   ld   a, [wGameState]
   cp   STATE_INTRO
   jr   z, .intro
   cp   STATE_FINISHED
   jr   z, .finished
   call Player_Draw
   call Bullets_Draw
   jp   Enemies_Draw

.intro:                      ;; "FASE N" centrado: 6 caracteres de 8 pixeles
   call Sprites_Clear
   ld   de, wShadowOAM
   ld   hl, StrPhase
   ld   b, (SCREEN_W - 6 * TILE_SIZE) / 2
   ld   c, TEXT_CENTER_Y
   call Text_DrawString      ;; Deja B en la columna del siguiente caracter
   ld   a, [wPhase]
   add  TILE_FONT_DIGIT0
   jp   Text_DrawChar

.finished:                   ;; "FIN" centrado
   call Sprites_Clear
   ld   de, wShadowOAM
   ld   hl, StrEnd
   ld   b, (SCREEN_W - 3 * TILE_SIZE) / 2
   ld   c, TEXT_CENTER_Y
   jp   Text_DrawString

;;-----------------------------------------------------------------
;; Game_PlayerHit: El jugador ha sido golpeado: pierde una vida, se rompe el combo y queda invulnerable; sin vidas, fin de la partida
;;    Destruye: A
Game_PlayerHit::
   call Combo_Reset          ;; Un golpe rompe la cadena de bajas
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
