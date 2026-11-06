;;-------------------------------------------------------------------------------------------------------------------------------;;
;; music.asm : Musica de fondo
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"
INCLUDE "music/song_lengths.inc"

EXPORT hUGE_init, hUGE_dosound

SECTION "Music Variables", WRAM0

wMusicCur:    db
wMusicMuted:  db
wMusicTimer:  dw
wMusicEnded:  db

SECTION "Music", ROM0

;;-----------------------------------------------------------------
;; Music_Init: Enciende el sonido (todos los canales, en estereo, volumen maximo) y deja el silencio
Music_Init::
   ld   a, $80
   ldh  [rAUDENA], a
   ld   a, $FF
   ldh  [rAUDTERM], a
   ld   a, $77
   ldh  [rAUDVOL], a
   ld   a, MUSIC_NONE
   ld   [wMusicCur], a
   xor  a
   ld   [wMusicMuted], a
   ret

;;-----------------------------------------------------------------
;; Music_Frame: Elige la cancion que toca segun el estado del juego
Music_Frame::
   ld   a, [wGameState]
   cp   STATE_PAUSED
   jp   z, .pause
   ld   b, a
   ld   a, [wMusicMuted]
   and  a
   jr   z, .select
   xor  a
   ld   [wMusicMuted], a
   ld   a, $FF
   ldh  [rAUDTERM], a
.select:
   ld   a, b
   cp   STATE_VICTORY
   ld   c, MUSIC_VICTORY
   jr   z, .want
   cp   STATE_GAMEOVER
   jr   z, .silence
   cp   STATE_TITLE
   ld   c, MUSIC_TITLE
   jr   z, .want
   cp   STATE_SCORES
   jr   z, .want
   cp   STATE_NAME
   jr   z, .want
   cp   STATE_RESULTS
   jr   z, .want
   ld   a, [wEndKind]
   cp   END_LOSE
   jr   z, .silence
   cp   END_WIN
   jr   z, .play
   ld   c, MUSIC_GAME
   ld   a, [wPhase]
   cp   BOSS_PHASE
   jr   nz, .want
   ld   c, MUSIC_BOSS
.want:
   ld   a, [wMusicCur]
   cp   c
   call nz, Music_Start
.play:
   ld   a, [wMusicCur]
   cp   MUSIC_NONE
   ret  z
   cp   MUSIC_VICTORY
   jp   nz, hUGE_dosound
   ld   a, [wMusicEnded]
   and  a
   ret  nz
   ld   hl, wMusicTimer
   ld   a, [hl+]
   ld   h, [hl]
   ld   l, a
   ld   de, MUSIC_VICTORY_FRAMES
   ld   a, h
   cp   d
   jr   c, .stillPlaying
   ld   a, l
   cp   e
   jr   c, .stillPlaying
   ld   a, 1
   ld   [wMusicEnded], a
   xor  a
   ldh  [rAUDENA], a
   ld   a, $80
   ldh  [rAUDENA], a
   ld   a, $FF
   ldh  [rAUDTERM], a
   ld   a, $77
   ldh  [rAUDVOL], a
   ret
.stillPlaying:
   inc  hl
   ld   a, l
   ld   [wMusicTimer], a
   ld   a, h
   ld   [wMusicTimer + 1], a
   jp   hUGE_dosound

.silence:
   ld   c, MUSIC_NONE
   jr   .want

.pause:
   ld   a, 1
   ld   [wMusicMuted], a
   xor  a
   ldh  [rAUDTERM], a
   ret

;;-----------------------------------------------------------------
;; Music_Start: Empieza la cancion C (o el silencio si es MUSIC_NONE)
Music_Start:
   ld   a, c
   ld   [wMusicCur], a
   xor  a
   ld   [wMusicEnded], a
   ld   [wMusicTimer], a
   ld   [wMusicTimer + 1], a
   ldh  [rAUDENA], a
   ld   a, $80
   ldh  [rAUDENA], a
   ld   a, $FF
   ldh  [rAUDTERM], a
   ld   a, $77
   ldh  [rAUDVOL], a
   ld   a, c
   cp   MUSIC_NONE
   ret  z
   add  a, a
   ld   e, a
   ld   d, 0
   ld   hl, SongTable
   add  hl, de
   ld   a, [hl+]
   ld   h, [hl]
   ld   l, a
   jp   hUGE_init

;;-----------------------------------------------------------------
;; SongTable: descriptor de cancion de cada MUSIC_*
SongTable:
   dw   song_title            ;; MUSIC_TITLE
   dw   song_game             ;; MUSIC_GAME
   dw   song_boss             ;; MUSIC_BOSS
   dw   song_victory          ;; MUSIC_VICTORY
