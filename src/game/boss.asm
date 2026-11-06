;;-------------------------------------------------------------------------------------------------------------------------------;;
;; boss.asm : El jefe final, "Virus Madre" (fase BOSS_PHASE, tras las PHASE_COUNT fases con tiempo)
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Boss Variables", WRAM0

wBossState::  db
wBossHp::     db
wBossX::      db
wBossYb::     db
wBossDir:     db
wBossTick:    db
wBossFlash::  db
wBossTimer:   db
wBossStage:   db
wBossSpawnT:  db
wBossBox:     ds ENEMY_SIZE

SECTION "Boss", ROM0

;;-----------------------------------------------------------------
;; Boss_Init: No hay jefe (al empezar una fase)
Boss_Init::
   xor  a
   ld   [wBossState], a
   ld   [wBossFlash], a
   ld   [wBossHp], a
   ret

;;-----------------------------------------------------------------
;; Boss_Begin: Empieza la fase del jefe: lleno de vida y oculto justo encima de la pantalla
Boss_Begin::
   ld   a, BOSS_STATE_ENTER
   ld   [wBossState], a
   ld   a, BOSS_HP
   ld   [wBossHp], a
   ld   a, BOSS_START_X
   ld   [wBossX], a
   ld   a, BOSS_YB_START
   ld   [wBossYb], a
   ld   a, 1
   ld   [wBossDir], a
   ld   [wBossStage], a
   xor  a
   ld   [wBossTick], a
   ld   [wBossFlash], a
   ld   a, %01010101
   ld   [wMoveShift], a
   ld   a, SPLIT_PATTERN
   ld   [wMoveShiftSplit], a
   ld   a, 1
   ld   [wBossBox], a
   ld   a, BOSS_TILES
   ld   [wBossBox + ENEMY_SIZE - 1], a
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Boss_Update: Un fotograma del jefe (solo en la fase del jefe, despues de Enemies_Update)
Boss_Update::
   ld   a, [wBossState]
   cp   BOSS_STATE_ENTER
   jr   z, .enter
   cp   BOSS_STATE_FIGHT
   jr   z, .fight
   cp   BOSS_STATE_DYING
   jp   z, .dying
   ret

.enter:
   ld   a, [wBossTick]
   inc  a
   ld   [wBossTick], a
   and  %00000001
   ret  nz
   ld   a, [wBossYb]
   inc  a
   ld   [wBossYb], a
   cp   BOSS_YB_FIGHT
   ret  nz
   ld   a, BOSS_STATE_FIGHT
   ld   [wBossState], a
   xor  a
   ld   [wBossTick], a
   ld   a, BOSS_FIRST_SPAWN
   ld   [wBossSpawnT], a
   ret

.fight:
   ld   a, [wBossStage]
   cp   3
   ld   b, BOSS_MOVE_FRAMES
   jr   nz, .speed
   ld   b, BOSS_MOVE_FAST
.speed:
   ld   a, [wBossTick]
   inc  a
   ld   [wBossTick], a
   cp   b
   jr   c, .moved
   xor  a
   ld   [wBossTick], a
   ld   a, [wBossX]
   ld   b, a
   ld   a, [wBossDir]
   and  a
   ld   a, b
   jr   z, .left
   inc  a
   cp   BOSS_MAX_X
   jr   c, .store
   ld   a, BOSS_MAX_X
   ld   [wBossX], a
   xor  a
   ld   [wBossDir], a
   jr   .moved
.left:
   dec  a
   cp   BOSS_MIN_X
   jr   nc, .store
   ld   a, BOSS_MIN_X
   ld   [wBossX], a
   ld   a, 1
   ld   [wBossDir], a
   jr   .moved
.store:
   ld   [wBossX], a
.moved:
   ;;-- La celula falsa sigue al jefe
   ld   a, [wBossX]
   ld   [wBossBox + 2], a
   ld   a, [wBossYb]
   sub  BOSS_YBIAS
   ld   [wBossBox + 3], a
   ;;-- Parpadeo del impacto
   ld   a, [wBossFlash]
   and  a
   jr   z, .noFlash
   dec  a
   ld   [wBossFlash], a
.noFlash:
   call Boss_CheckBullets
   ld   a, [wBossState]
   cp   BOSS_STATE_FIGHT
   ret  nz
   call Boss_UpdateStage
   call Boss_Spawner
   jp   Boss_CheckPlayer

.dying:
   ld   a, [wBossTimer]
   dec  a
   ld   [wBossTimer], a
   ld   [wBossFlash], a
   jr   z, .done
   cp   BOSS_BURST_AT
   jr   z, .burst
   and  %00000111
   ret  nz
   call Boss_RandomExplosion
   jp   Boss_RandomExplosion
.burst:
   ld   a, FLASH_FRAMES * 2
   ld   [wFlash], a
   ld   b, 5
.burstLoop:
   push bc
   call Boss_RandomExplosion
   pop  bc
   dec  b
   jr   nz, .burstLoop
   ret
.done:
   ld   a, BOSS_STATE_DONE
   ld   [wBossState], a
   ret

;;-----------------------------------------------------------------
;; Boss_UpdateStage: Calcula la etapa del jefe segun su vida
Boss_UpdateStage:
   ld   b, 1
   ld   a, [wBossHp]
   cp   BOSS_STAGE2_HP + 1
   jr   nc, .got
   inc  b
   cp   BOSS_STAGE3_HP + 1
   jr   nc, .got
   inc  b
.got:
   ld   a, [wBossStage]
   cp   b
   ret  z
   ld   a, b
   ld   [wBossStage], a
   ld   a, FLASH_FRAMES * 2
   ld   [wFlash], a
   ld   a, BOSS_STAGE_PAUSE
   ld   [wBossSpawnT], a
   jp   Enemies_Wipe

;;-----------------------------------------------------------------
;; Boss_Spawner: Cuenta atras para soltar celulas desde el cuerpo del jefe
Boss_Spawner:
   ld   a, [wBossSpawnT]
   dec  a
   ld   [wBossSpawnT], a
   ret  nz
   call Boss_SpawnOne
   ld   a, [wBossStage]
   cp   3
   jr   c, .next
   call Boss_SpawnOne
   call Random_Next
   bit  0, a
   call nz, Boss_SpawnOne
   ld   a, BOSS_SPAWN_S3
   jr   .setTimer
.next:
   ld   a, [wBossStage]
   cp   2
   ld   a, BOSS_SPAWN_S1
   jr   nz, .setTimer
   ld   a, BOSS_SPAWN_S2
.setTimer:
   push af
   ld   b, BOSS_SPAWN_VAR
   call Random_Range
   ld   b, a
   pop  af
   add  b
   ld   [wBossSpawnT], a
   ret

;;-----------------------------------------------------------------
;; Boss_SpawnOne: Suelta una celula por debajo del cuerpo del jefe
Boss_SpawnOne:
   call Enemies_Count
   ld   b, a
   ld   a, [wBossStage]
   cp   1
   ld   a, BOSS_CELLS_S1
   jr   z, .cap
   ld   a, BOSS_CELLS_MAX
.cap:
   cp   b
   ret  c
   ret  z
   ld   b, 100
   call Random_Range
   ld   c, a
   ld   a, [wBossStage]
   cp   1
   ld   a, c
   jr   nz, .later
   cp   60
   jr   c, .zig
   jr   .normal
.later:
   cp   25
   jr   c, .normal
   cp   50
   jr   c, .zig
   cp   75
   jr   c, .aggr
   ld   b, ENEMY_DIV
   call Enemies_CountType
   cp   MAX_DIV
   jr   nc, .normal
   ld   a, ENEMY_DIV
   ld   d, ENEMY_DIV_HP
   jr   .place
.aggr:
   ld   b, ENEMY_AGGR
   call Enemies_CountType
   cp   MAX_AGGR
   jr   nc, .normal
   ld   a, ENEMY_AGGR
   ld   d, ENEMY_AGGR_HP
   jr   .place
.zig:
   ld   b, ENEMY_ZIGZAG
   call Enemies_CountType
   cp   MAX_ZIG
   jr   nc, .normal
   ld   a, ENEMY_ZIGZAG
   ld   d, 1
   jr   .place
.normal:
   ld   a, ENEMY_NORMAL
   ld   d, 1
.place:
   push af
   ld   a, d
   add  a
   add  a
   add  a
   ld   e, a
   ld   a, DIR_DOWN
   ld   [wPlaceDir], a
   ld   a, [wPlayerX]
   add  TILE_SIZE / 2
   ld   b, a
   ld   a, [wBossX]
   cp   b
   jr   z, .notLeft
   jr   c, .notLeft
   ld   a, DIR_LEFT
   ld   [wPlaceDir], a
   ld   a, [wBossX]
   sub  e
   add  4
   ld   b, a
   jr   .sideY
.notLeft:
   ld   a, [wBossX]
   add  BOSS_PIX
   cp   b
   jr   nc, .below
   ld   a, DIR_RIGHT
   ld   [wPlaceDir], a
   ld   a, [wBossX]
   add  BOSS_PIX - 4
   ld   b, a
.sideY:
   ld   a, e
   srl  a
   ld   d, a
   ld   a, [wPlayerY]
   add  TILE_SIZE / 2
   sub  d
   ld   d, a
   ld   a, [wBossYb]
   sub  BOSS_YBIAS
   ld   c, a
   ld   a, d
   cp   c
   jr   nc, .minOk
   ld   d, c
.minOk:
   ld   a, c
   add  BOSS_PIX
   sub  e
   cp   d
   jr   nc, .maxOk
   ld   d, a
.maxOk:
   ld   c, d
   pop  af
   jp   Enemies_Place
.below:
   ld   a, BOSS_PIX + 1
   sub  e
   ld   b, a
   call Random_Range
   ld   b, a
   ld   a, [wBossX]
   add  b
   ld   b, a
   ld   a, [wBossYb]
   sub  BOSS_YBIAS
   add  BOSS_PIX + 4
   sub  e
   ld   c, a
   pop  af
   jp   Enemies_Place

;;-----------------------------------------------------------------
;; Boss_RandomExplosion: Una explosion en un punto al azar del cuerpo del jefe
Boss_RandomExplosion:
   ld   b, BOSS_PIX - TILE_SIZE + 1
   call Random_Range
   ld   c, a
   ld   a, [wBossX]
   add  c
   push af
   ld   b, BOSS_PIX - TILE_SIZE + 1
   call Random_Range
   ld   c, a
   ld   a, [wBossYb]
   sub  BOSS_YBIAS
   add  c
   ld   c, a
   pop  af
   ld   b, a
   jp   Explo_Spawn

;;-----------------------------------------------------------------
;; Boss_CheckBullets: Cada bala que toca al jefe desaparece y le quita vida
Boss_CheckBullets:
   ld   hl, wBossBox
   ld   de, wBullets
   ld   c, MAX_BULLETS
.loop:
   ld   a, [de]
   and  a
   jr   z, .next
   inc  de
   call Collide_Box
   dec  de
   jr   nc, .next
   ld   a, [de]
   and  MISSILE_FLAG
   ld   b, 1
   jr   z, .damage
   ld   b, MISSILE_DAMAGE
.damage:
   xor  a
   ld   [de], a
   ld   a, [wBossHp]
   sub  b
   jr   nc, .alive
   xor  a
.alive:
   ld   [wBossHp], a
   ld   b, a
   ld   a, BOSS_FLASH_FRAMES
   ld   [wBossFlash], a
   ld   a, 1
   ld   [wHudDirty], a
   ld   a, BOSS_HIT_POINTS
   call Combo_Kill
   ld   a, b
   and  a
   jr   z, Boss_Die
.next:
   REPT BULLET_SIZE
      inc  de
   ENDR
   dec  c
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Boss_Die: El jefe se queda sin vida: explotan todas las celulas que queden
Boss_Die:
   ld   a, BOSS_STATE_DYING
   ld   [wBossState], a
   ld   a, BOSS_DYING_FRAMES
   ld   [wBossTimer], a
   ld   a, 255
   ld   [wInvuln], a
   call Enemies_Wipe
   ld   a, BOSS_KILL_POINTS
   call Combo_Kill
   ret

;;-----------------------------------------------------------------
;; Boss_CheckPlayer: Si el jefe toca al jugador, este pierde una vida (salvo con escudo o invulnerable)
Boss_CheckPlayer:
   ld   a, [wShield]
   and  a
   ret  nz
   ld   a, [wInvuln]
   and  a
   ret  nz
   ld   hl, wBossBox
   ld   de, wPlayerX
   call Collide_Box
   ret  nc
   jp   Game_PlayerHit

;;-----------------------------------------------------------------
;; Boss_Draw: Escribe los 16 sprites del jefe (por filas)
Boss_Draw::
   ld   a, [wBossState]
   and  a
   ret  z
   cp   BOSS_STATE_DYING
   jr   nz, .notDying
   ld   a, [wBossTimer]
   cp   BOSS_BURST_AT
   ret  c
.notDying:
   ld   a, [wBossFlash]
   bit  1, a
   ret  nz
   ld   h, 0
   ld   l, TILE_BOSS
.row:
   ld   a, [wBossYb]
   add  h
   cp   PLAY_MIN_Y + BOSS_YBIAS
   jr   c, .skipRow
   sub  BOSS_YBIAS
   ld   c, a
   ld   a, [wBossX]
   ld   b, a
   REPT BOSS_TILES
      ld   a, l
      call Put_Sprite
      inc  l
      ld   a, b
      add  TILE_SIZE
      ld   b, a
   ENDR
   jr   .nextRow
.skipRow:
   ld   a, l
   add  BOSS_TILES
   ld   l, a
.nextRow:
   ld   a, h
   add  TILE_SIZE
   ld   h, a
   cp   BOSS_PIX
   jr   nz, .row
   ret
