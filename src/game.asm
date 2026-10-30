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
wFlash:       db                ;; Fotogramas que le quedan al destello de pantalla (golpe al jugador o cambio de fase)
wPhaseSec:    db                ;; Segundos que quedan de la fase (el cronometro del HUD)
wSecFrames:   db                ;; Fotogramas que faltan para el siguiente segundo
wComboHold:   db                ;; 1 = el combo esta congelado hasta que la fase nueva tenga la primera celula (o su aviso)
wBreak:       db                ;; Cambio de fase en pantalla de juego: fotogramas que quedan del mensaje (0 = no hay cambio de fase)
wResultsView: db                ;; 1 = se muestra la pantalla de puntuacion (mapa de fondo 1 y paleta invertida)

SECTION "Game", ROM0

;;-----------------------------------------------------------------
;; Game_Start: Empieza una partida nueva (tambien sirve para reiniciar tras perder): fase 1, 3 vidas, 0 puntos
;;    Destruye: A, BC, DE, HL
Game_Start::
   call Player_Init
   call Results_Init
   call Energy_Init          ;; Barra de energia vacia, sin misiles
   xor  a
   ld   [wEndKind], a        ;; La partida sigue
   ld   [wResultsView], a    ;; Se vuelve al mapa de fondo del juego
   ld   [wFlash], a
   ld   [wBreak], a
   ld   [wComboHold], a
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
   call Explo_Init
   call Drops_Init
   ld   a, [wPhase]
   dec  a
   call Enemies_SetPhase
   ld   a, LOW(PHASE_FRAMES)
   ld   [wPhaseTimerLo], a
   ld   a, HIGH(PHASE_FRAMES)
   ld   [wPhaseTimerHi], a
   call Phase_ResetClock
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
;; Game_ToResults: Pasa a la pantalla de puntuacion final (calcula el bonus y prepara la animacion). Lo usa la pantalla de victoria
Game_ToResults::
   jp   Game_Update.toResults

;;-----------------------------------------------------------------
;; Phase_ResetClock: El cronometro del HUD vuelve a PHASE_SECONDS (principio de una fase)
;;    Destruye: A
Phase_ResetClock:
   ld   a, PHASE_SECONDS
   ld   [wPhaseSec], a
   ld   a, 60
   ld   [wSecFrames], a
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Break_Start: Fin de una fase que no es la ultima: sin cortar la partida, las celulas explotan, dejan de salir y durante
;;    BREAK_FRAMES fotogramas la pantalla parpadea y muestra "FASE N" (Game_Draw). El jugador sigue moviendose y disparando
;;    (sin celulas no puede ser golpeado). Aqui ya se pasa a la fase siguiente: dificultad y temporizador listos para cuando acabe.
;;    Destruye: A, BC, DE, HL
Break_Start:
   ld   a, [wPhase]
   ld   b, a
   inc  a
   ld   [wPhase], a
   ld   a, b                 ;; Enemies_SetPhase: 0 = la primera fase, es decir, la fase anterior a la nueva
   call Enemies_SetPhase
   ld   a, LOW(PHASE_FRAMES)
   ld   [wPhaseTimerLo], a
   ld   a, HIGH(PHASE_FRAMES)
   ld   [wPhaseTimerHi], a
   call Phase_ResetClock
   call Enemies_Wipe
   ld   a, 1
   ld   [wComboHold], a      ;; El combo no corre mientras no haya celulas en la fase nueva
   ld   [wComboShow], a      ;; ... y el "X<n>" se queda visible (no congelado en la mitad oculta del parpadeo)
   ld   [wHudDirty], a
   ld   a, BREAK_FRAMES
   ld   [wBreak], a
   ret

;;-----------------------------------------------------------------
;; Break_Tick: Un fotograma del cambio de fase: cuenta atras y parpadeo de la pantalla (uno cada 16 fotogramas al principio)
;;    Destruye: A, B
Break_Tick:
   ld   a, [wBreak]
   ld   b, a
   dec  a
   ld   [wBreak], a
   ld   a, b
   cp   BREAK_FLASH_END + 1
   ret  c                    ;; Ya no hay mas parpadeos
   and  %00001111
   ret  nz
   ld   a, BREAK_FLASH_LEN
   ld   [wFlash], a
   ret

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
;;    Empezar partida: INTRO ("FASE 1" sobre negro) -> FADE_IN -> JUGANDO.
;;    Fin de una fase (no la ultima): sigue JUGANDO, sin cortes, con wBreak > 0 (Break_Start): las celulas explotan, no salen mas, la
;;    pantalla parpadea y se ve "FASE N" unos segundos mientras el jugador sigue moviendose y disparando.
;;    Sin vidas: GAMEOVER (congelado) -> FADE_OUT -> RESULTS. Tras la ultima fase: FADE_OUT -> RESULTS.

;;    START durante la partida la pone en PAUSA (STATE_PAUSED): todo se congela y vuelve con otro START.
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
   cp   STATE_PAUSED
   jr   z, .paused
   cp   STATE_RESULTS
   jp   z, Results_Update
   jp   Menu_Update          ;; STATE_TITLE, STATE_SCORES y STATE_NAME (title.asm)

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
   jp   .startFade

.paused:                     ;; Todo congelado: solo se espera START
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   ret  z
   ld   a, STATE_PLAYING     ;; La partida sigue exactamente donde estaba
   ld   [wGameState], a
   ret

.playing:
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   jr   z, .noPause
   ld   a, STATE_PAUSED      ;; START: pausa (el juego sigue a la vista, congelado)
   ld   [wGameState], a
   ret
   ;; (la pausa no avanza nada)
.noPause:
   call Energy_Update        ;; SELECT activa los misiles; la barra se vacia con ellos
   call Player_Update
   call Bullets_Update
   ld   a, [wBreak]
   and  a
   jr   nz, .breakTick
   call Enemies_Update       ;; Incluye los choques con el jugador (Game_PlayerHit)
   jr   .afterEnemies
.breakTick:                  ;; Cambio de fase: no hay celulas ni salen nuevas; el jugador sigue jugando
   call Break_Tick
.afterEnemies:
   call Explo_Update
   call Drops_Update
   ld   a, [wGameState]
   cp   STATE_PLAYING
   ret  nz                   ;; Ha perdido la ultima vida en este fotograma
   ;; Cuenta atras y parpadeo del combo: congelados durante el mensaje de cambio de fase y hasta que la fase nueva tiene
   ;; su primera celula (o su aviso), para que la espera sin enemigos no rompa la cadena
   ld   a, [wBreak]
   and  a
   jr   nz, .comboFrozen
   ld   a, [wComboHold]
   and  a
   jr   z, .comboRun
   ld   a, [wWarnTimer]
   and  a
   jr   nz, .comboRelease
   call Enemies_Count
   and  a
   jr   z, .comboFrozen
.comboRelease:
   xor  a
   ld   [wComboHold], a
.comboRun:
   call Combo_Update
.comboFrozen:
   ld   a, [wInvuln]
   and  a
   jr   z, .noInvuln
   dec  a
   ld   [wInvuln], a
.noInvuln:
   ;; Temporizador de la fase (16 bits); parado durante el mensaje de cambio de fase
   ld   a, [wBreak]
   and  a
   ret  nz
   ;; Cronometro del HUD: un segundo cada 60 fotogramas; avisa al HUD al cambiar de segundo y, con poco tiempo, cada medio segundo
   ld   hl, wSecFrames
   dec  [hl]
   jr   nz, .secMid
   ld   [hl], 60
   ld   a, [wPhaseSec]
   and  a
   jr   z, .secDirty
   dec  a
   ld   [wPhaseSec], a
.secDirty:
   ld   a, 1
   ld   [wHudDirty], a
   jr   .secDone
.secMid:
   ld   a, [hl]
   cp   29                   ;; (el HUD se dibuja en el VBlank siguiente, ya con 29 o menos: mitad oculta)
   jr   nz, .secDone
   ld   a, [wPhaseSec]
   cp   TIME_BLINK_SEC + 1
   jr   nc, .secDone
   ld   a, 1
   ld   [wHudDirty], a       ;; Empieza la mitad oculta del parpadeo
.secDone:
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
   jp   nz, Break_Start      ;; Cambio de fase sin cortes: parpadeo y mensaje sobre la partida
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
   cp   END_WIN
   jp   z, Victory_Begin     ;; Ganada: antes de la puntuacion sale la pantalla de victoria (title.asm)
.toResults:                  ;; (el fundido a negro solo se usa al acabar la partida, ganada o perdida)
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
   ldh  [rOBP0], a           ;; Los sprites siempre con la paleta normal
   ld   b, a
   ld   a, [wFlash]
   and  a
   jr   z, .setBg
   dec  a
   ld   [wFlash], a
   ld   b, PALETTE_FLASH_HI  ;; Destello tras un golpe: fondo blanco los primeros fotogramas y luego claro
   cp   FLASH_FRAMES / 2
   jr   nc, .setBg
   ld   b, PALETTE_FLASH_LO
.setBg:
   ld   a, b
   ldh  [rBGP], a
   ret
.results:
   cp   2
   jr   nz, .results1
   ldh  a, [rLCDC]           ;; Titulo (wResultsView = 2): mapa 1 y paleta invertida desde el primer fotograma
   set  3, a
   ldh  [rLCDC], a
   ld   a, [wGameState]
   cp   STATE_VICTORY
   ld   a, BGP_RESULTS       ;; (ld no toca los flags)
   jr   nz, .titlePal
   ld   a, [wVicPal]         ;; Pantalla de victoria: destellos (0 invertida, 1 normal, 2 negro mientras se dibuja)
   ld   e, a
   ld   d, 0
   ld   hl, .vicPalettes
   add  hl, de
   ld   a, [hl]
.titlePal:
   ldh  [rBGP], a
   ret

.vicPalettes:
   db   BGP_RESULTS, PALETTE_DEFAULT, %11111111
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
   cp   STATE_PAUSED
   jr   z, .paused
   cp   STATE_TITLE
   jp   nc, Sprites_Clear    ;; El titulo, las puntuaciones, los controles y el nombre tambien (estados >= STATE_TITLE)
   ld   a, [wBreak]
   and  a
   jr   nz, .breakMsg
   call Player_Draw
   call Bullets_Draw
   jp   Enemies_Draw

.paused:                     ;; El juego congelado a la vista, con "PAUSA" en negro encima
   call Player_Draw
   call Bullets_Draw
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   ld   a, 1
   ld   [wTextDark], a
   ld   hl, StrPaused
   ld   b, (SCREEN_W - 5 * TILE_SIZE) / 2
   ld   c, TEXT_CENTER_Y
   call Text_DrawString      ;; Antes que los enemigos: si no caben todos, el texto no se pierde
   xor  a
   ld   [wTextDark], a
   jp   Enemies_DrawAt

.breakMsg:                   ;; Cambio de fase: el juego sigue a la vista con "FASE N" en negro encima
   call Player_Draw
   call Bullets_Draw
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   ld   a, 1
   ld   [wTextDark], a
   ld   hl, StrPhase
   ld   b, (SCREEN_W - 6 * TILE_SIZE) / 2
   ld   c, TEXT_CENTER_Y
   call Text_DrawString
   ld   a, [wPhase]
   add  TILE_FONT_DIGIT0
   call Text_DrawChar
   xor  a
   ld   [wTextDark], a
   jp   Enemies_DrawAt       ;; (ya no hay celulas: dibuja las explosiones, gotas y oculta el resto)

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
   ld   a, FLASH_FRAMES
   ld   [wFlash], a          ;; Destello de pantalla
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
