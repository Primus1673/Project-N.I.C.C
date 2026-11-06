;;-------------------------------------------------------------------------------------------------------------------------------;;
;; game.asm : Estado de la partida: vidas, invulnerabilidad, puntuacion, fin de partida y reinicio
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Game Variables", WRAM0

wGameState::  db
wLives::      db
wInvuln::     db
wScore::      ds SCORE_DIGITS
wHudDirty::   db
wPhase::      db
wPhaseTimerLo: db
wPhaseTimerHi: db
wFadeLevel:   db
wStateTimer:  db
wEndKind::    db
wFlash:       db
wPhaseSec:    db
wSecFrames:   db
wComboHold:   db
wBreak:       db
wResultsView: db

SECTION "Game", ROM0

;;-----------------------------------------------------------------
;; Game_Start: Empieza una partida nueva: fase 1, 3 vidas, 0 puntos
Game_Start::
   call Player_Init
   call Results_Init
   call Energy_Init
   xor  a
   ld   [wEndKind], a
   ld   [wResultsView], a
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
   call MemSet
   ld   a, 1
   ld   [wHudDirty], a
   ld   [wPhase], a
   call Combo_Reset
   ;; sigue en Game_BeginPhase

;;-----------------------------------------------------------------
;; Game_BeginPhase: Prepara la fase wPhase (vacia balas y enemigos y carga su dificultad)
Game_BeginPhase:
   call Bullets_Init
   call Enemies_Init
   call Explo_Init
   call Drops_Init
   call Boss_Init
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
;; Game_ToResults: Pasa a la pantalla de puntuacion final (calcula el bonus y prepara la animacion)
Game_ToResults::
   jp   Game_Update.toResults

;;-----------------------------------------------------------------
;; Phase_ResetClock: El cronometro del HUD vuelve a PHASE_SECONDS (principio de una fase)
Phase_ResetClock:
   ld   a, PHASE_SECONDS
   ld   [wPhaseSec], a
   ld   a, 60
   ld   [wSecFrames], a
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Break_Start: Fin de una fase que no es la ultima
Break_Start:
   ld   a, [wPhase]
   ld   b, a
   inc  a
   ld   [wPhase], a
   cp   BOSS_PHASE
   jr   z, .boss
   ld   a, b
   call Enemies_SetPhase
   ld   a, LOW(PHASE_FRAMES)
   ld   [wPhaseTimerLo], a
   ld   a, HIGH(PHASE_FRAMES)
   ld   [wPhaseTimerHi], a
   call Phase_ResetClock
   jr   .common
.boss:
   call Boss_Begin
.common:
   call Enemies_Wipe
   ld   a, 1
   ld   [wComboHold], a
   ld   [wComboShow], a
   ld   [wHudDirty], a
   ld   a, BREAK_FRAMES
   ld   [wBreak], a
   ld   a, [wPhase]
   cp   BOSS_PHASE
   ret  nz
   xor  a
   ld   [wComboHold], a
   ret

;;-----------------------------------------------------------------
;; Break_Tick: Un fotograma del cambio de fase: cuenta atras y parpadeo de la pantalla
Break_Tick:
   ld   a, [wBreak]
   ld   b, a
   dec  a
   ld   [wBreak], a
   ld   a, b
   cp   BREAK_FLASH_END + 1
   ret  c
   and  %00001111
   ret  nz
   ld   a, BREAK_FLASH_LEN
   ld   [wFlash], a
   ret

;;-----------------------------------------------------------------
;; Game_StepTimer: Avanza el contador de un escalon de fundido
Game_StepTimer:
   ld   a, [wStateTimer]
   dec  a
   jr   nz, .wait
   ld   a, FADE_STEP_FRAMES
   ld   [wStateTimer], a
   xor  a
   ret
.wait:
   ld   [wStateTimer], a
   ret

;;-----------------------------------------------------------------
;; Game_Update: Un fotograma del estado de la partida (ver STATE_* en constants.inc)

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
   jp   Menu_Update

.gameOver:
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

.paused:
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   ret  z
   ld   a, STATE_PLAYING
   ld   [wGameState], a
   ret

.playing:
   ldh  a, [hInputNew]
   bit  BTNB_START, a
   jr   z, .noPause
   ld   a, STATE_PAUSED
   ld   [wGameState], a
   ret
   ;; (la pausa no avanza nada)
.noPause:
   call Energy_Update
   call Player_Update
   call Bullets_Update
   ld   a, [wBreak]
   and  a
   jr   nz, .breakTick
   call Enemies_Update
   ld   a, [wPhase]
   cp   BOSS_PHASE
   call z, Boss_Update
   jr   .afterEnemies
.breakTick:
   call Break_Tick
.afterEnemies:
   call Explo_Update
   call Drops_Update
   ld   a, [wGameState]
   cp   STATE_PLAYING
   ret  nz
   ld   a, [wBossState]
   cp   BOSS_STATE_DONE
   jp   z, .winFade
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
   ld   a, [wBreak]
   and  a
   ret  nz
   ld   a, [wPhase]
   cp   BOSS_PHASE
   ret  z
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
   cp   29
   jr   nz, .secDone
   ld   a, [wPhaseSec]
   cp   TIME_BLINK_SEC + 1
   jr   nc, .secDone
   ld   a, 1
   ld   [wHudDirty], a
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
   jp   Break_Start
.winFade:
   ld   a, END_WIN
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
   jp   z, Victory_Begin
.toResults:
   call Results_Begin
   ld   a, STATE_RESULTS
   ld   [wGameState], a
   ld   a, 1
   ld   [wResultsView], a
   jp   Sprites_Clear

.intro:
   ld   a, [wStateTimer]
   dec  a
   ld   [wStateTimer], a
   ret  nz
   call Sprites_Clear
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
   ld   a, STATE_PLAYING
   ld   [wGameState], a
   ret

;;-----------------------------------------------------------------
;; Game_ApplyFade: Pone las paletas de fondo y sprites segun wFadeLevel (0 normal ... 3 negro)
Game_ApplyFade::
   ld   a, [wResultsView]
   and  a
   jr   nz, .results
   ldh  a, [rLCDC]
   res  3, a
   ldh  [rLCDC], a
   ld   a, [wFadeLevel]
   ld   e, a
   ld   d, 0
   ld   hl, FadePalettes
   add  hl, de
   ld   a, [hl]
   ldh  [rOBP0], a
   ld   b, a
   ld   a, [wFlash]
   and  a
   jr   z, .setBg
   dec  a
   ld   [wFlash], a
   ld   b, PALETTE_FLASH_HI
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
   ldh  a, [rLCDC]
   set  3, a
   ldh  [rLCDC], a
   ld   a, [wGameState]
   cp   STATE_VICTORY
   ld   a, BGP_RESULTS
   jr   nz, .titlePal
   ld   a, [wVicPal]
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
.results1:
   ldh  a, [rLCDC]
   set  3, a
   ldh  [rLCDC], a
   ld   a, [wResStage]
   and  a
   ld   a, BGP_RESULTS
   jr   nz, .resPalette
   ld   a, %11111111
.resPalette:
   ldh  [rBGP], a
   ret

FadePalettes:
   db   PALETTE_DEFAULT
   db   %11111001
   db   %11111110
   db   %11111111

;;-----------------------------------------------------------------
;; Game_Draw: Escribe los sprites de este fotograma en la OAM en sombra
Game_Draw::
   ld   a, [wGameState]
   cp   STATE_INTRO
   jp   z, .intro
   cp   STATE_RESULTS
   jp   z, Sprites_Clear
   cp   STATE_PAUSED
   jr   z, .paused
   cp   STATE_TITLE
   jp   nc, Sprites_Clear
   ld   a, [wBreak]
   and  a
   jr   nz, .breakMsg
   call Player_Draw
   call Bullets_Draw
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   call Shield_Draw
   jp   Enemies_DrawAt

.paused:
   call Player_Draw
   call Bullets_Draw
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   call Shield_Draw
   ld   a, 1
   ld   [wTextDark], a
   ld   hl, StrPaused
   ld   b, (SCREEN_W - 5 * TILE_SIZE) / 2
   ld   c, TEXT_CENTER_Y
   call Text_DrawString
   xor  a
   ld   [wTextDark], a
   jp   Enemies_DrawAt

.breakMsg:
   call Player_Draw
   call Bullets_Draw
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   call Shield_Draw
   ld   a, 1
   ld   [wTextDark], a
   ld   a, [wPhase]
   cp   BOSS_PHASE
   jr   z, .bossMsg
   ld   hl, StrPhase
   ld   b, (SCREEN_W - 6 * TILE_SIZE) / 2
   ld   c, TEXT_CENTER_Y
   call Text_DrawString
   ld   a, [wPhase]
   add  TILE_FONT_DIGIT0
   call Text_DrawChar
   jr   .breakEnd
.bossMsg:
   ld   hl, StrBoss
   ld   b, (SCREEN_W - 4 * TILE_SIZE) / 2
   ld   c, TEXT_CENTER_Y
   call Text_DrawString
.breakEnd:
   xor  a
   ld   [wTextDark], a
   jp   Enemies_DrawAt

.intro:
   call Sprites_Clear
   ld   de, wShadowOAM
   ld   hl, StrPhase
   ld   b, (SCREEN_W - 6 * TILE_SIZE) / 2
   ld   c, TEXT_CENTER_Y
   call Text_DrawString
   ld   a, [wPhase]
   add  TILE_FONT_DIGIT0
   jp   Text_DrawChar

;;-----------------------------------------------------------------
;; Game_PlayerHit: El jugador ha sido golpeado
Game_PlayerHit::
   call Combo_Reset
   ld   a, FLASH_FRAMES
   ld   [wFlash], a
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
   ld   [wStateTimer], a
   ld   a, STATE_GAMEOVER
   ld   [wGameState], a
   ret

;;-----------------------------------------------------------------
;; Score_AddTens: Suma A decenas a la puntuacion (A=5 -> +50 puntos)
Score_AddTens::
   push bc
   push hl
   and  a
   jr   z, .end
   ld   b, a
.again:
   ld   hl, wScore + SCORE_DIGITS - 2
   ld   c, SCORE_DIGITS - 1
.carry:
   inc  [hl]
   ld   a, [hl]
   cp   10
   jr   c, .added
   xor  a
   ld   [hl], a
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
