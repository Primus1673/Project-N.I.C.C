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
wEndKind::    db                ;; END_NONE, END_WIN (todas las fases superadas) o END_LOSE (sin vidas)
wResultsView: db                ;; 1 = se muestra la pantalla de puntuacion (mapa de fondo 1 y paleta invertida)

SECTION "Game", ROM0

;;-----------------------------------------------------------------
;; Game_Start: Empieza una partida nueva (tambien sirve para reiniciar tras perder): fase 1, 3 vidas, 0 puntos
;;    Destruye: A, BC, DE, HL
Game_Start::
   call Player_Init
   call Results_Init
   xor  a
   ld   [wEndKind], a        ;; La partida sigue
   ld   [wResultsView], a    ;; Se vuelve al mapa de fondo del juego
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
;;    JUGANDO -> (fin de fase) FADE_OUT -> INTRO ("FASE N") -> FADE_IN -> JUGANDO ...
;;    Sin vidas: GAMEOVER (congelado) -> FADE_OUT -> RESULTS. Tras la ultima fase: FADE_OUT -> RESULTS.
;;    En RESULTS se cuenta la puntuacion final (results.asm) y START empieza una partida nueva.
;;    Destruye: A, BC, DE, HL
Game_Update::
   ld   a, [wGameState]
   cp   STATE_PLAYING
   jr   z, .playing
   cp   STATE_FADE_OUT
   jp   z, .fadeOut
   cp   STATE_INTRO
   jp   z, .intro
   cp   STATE_FADE_IN
   jp   z, .fadeIn
   cp   STATE_GAMEOVER
   jr   z, .gameOver
   cp   STATE_TITLE
   jp   z, Title_Update
   jp   Results_Update       ;; STATE_RESULTS

.gameOver:                   ;; Todo congelado un momento (START lo salta) y luego fundido a la pantalla de puntuacion
   ld   a, [wStateTimer]
   dec  a
   ld   [wStateTimer], a
   jr   z, .endFade
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   ret  z
.endFade:
   ld   a, END_LOSE
   ld   [wEndKind], a
   jr   .startFade

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
   ld   a, [wPhase]
   cp   PHASE_COUNT
   jr   nz, .startFade
   ld   a, END_WIN           ;; Era la ultima: despues del negro viene la pantalla de puntuacion
   ld   [wEndKind], a
.startFade:
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
   ld   a, [wEndKind]
   and  a
   jr   nz, .toResults       ;; Fin de la partida (ganada o perdida)
   ld   a, [wPhase]
   inc  a
   ld   [wPhase], a
   jp   Game_BeginPhase      ;; Siguiente fase: pantalla negra con su texto
.toResults:
   call Results_Begin        ;; Calcula bonus y prepara la animacion
   ld   a, STATE_RESULTS
   ld   [wGameState], a
   ld   a, 1
   ld   [wResultsView], a    ;; Game_ApplyFade cambia al mapa de la puntuacion en el proximo VBlank
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
;;    Con la pantalla de puntuacion (wResultsView = 1): mapa de fondo 1 y paleta invertida.
;;    IMPORTANTE: llamar al principio del VBlank (o con la LCD apagada), si no se ve un corte en la pantalla
;;    Destruye: A, DE, HL
Game_ApplyFade::
   ld   a, [wResultsView]
   and  a
   jr   nz, .results
   ldh  a, [rLCDC]
   res  3, a                 ;; Bit 3 de LCDC = 0: el fondo usa el mapa 0 ($9800), el del juego
   ldh  [rLCDC], a
   ld   a, [wFadeLevel]
   ld   e, a
   ld   d, 0
   ld   hl, FadePalettes
   add  hl, de
   ld   a, [hl]
   ldh  [rBGP], a
   ldh  [rOBP0], a
   ret
.results:
   cp   2
   jr   nz, .results1
   ldh  a, [rLCDC]           ;; Titulo (wResultsView = 2): mapa 1 y paleta invertida desde el primer fotograma
   set  3, a
   ldh  [rLCDC], a
   ld   a, BGP_RESULTS
   ldh  [rBGP], a
   ret
.results1:                   ;; Pantalla de puntuacion: mapa 1 ($9C00) y paleta invertida (tile 0 negro, letras blancas)
   ldh  a, [rLCDC]
   set  3, a                 ;; Bit 3 de LCDC = 1: el fondo usa el mapa 1
   ldh  [rLCDC], a
   ld   a, [wResStage]
   and  a
   ld   a, BGP_RESULTS       ;; (ld no toca los flags)
   jr   nz, .resPalette
   ld   a, %11111111         ;; Etapa 0: aun se estan borrando las filas del mapa (pueden tener texto viejo): pantalla negra
.resPalette:
   ldh  [rBGP], a
   ret

FadePalettes:                ;; %DDCCBBAA (AA = color 0): cada escalon hace cada color un tono mas oscuro
   db   PALETTE_DEFAULT     ;; 0: normal      (0,1,2,3)
   db   %11111001           ;; 1:             (1,2,3,3)
   db   %11111110           ;; 2:             (2,3,3,3)
   db   %11111111           ;; 3: negro       (3,3,3,3)

;;-----------------------------------------------------------------
;; Game_Draw: Escribe los sprites de este fotograma en la OAM en sombra
;;    INTRO: solo el texto "FASE N". RESULTS: ningun sprite (la puntuacion va en el fondo). Resto: nave, balas y enemigos.
;;    Destruye: A, BC, DE, HL
Game_Draw::
   ld   a, [wGameState]
   cp   STATE_INTRO
   jr   z, .intro
   cp   STATE_RESULTS
   jp   z, Sprites_Clear     ;; La puntuacion se dibuja en el fondo: ningun sprite
   cp   STATE_TITLE
   jp   z, Sprites_Clear     ;; El titulo tambien
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
   ld   a, GAMEOVER_FRAMES
   ld   [wStateTimer], a     ;; Juego congelado un momento antes del fundido a la puntuacion
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
