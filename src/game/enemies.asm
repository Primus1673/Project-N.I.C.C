;;-------------------------------------------------------------------------------------------------------------------------------;;
;; enemies.asm : Enemigos del juego (celulas infectadas)
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Enemies Variables", WRAM0

wEnemies::     ds ENEMY_SIZE * MAX_ENEMIES
wSpawnTimer:   db
wMaxEnemies:   db
wSpawnMin:     db
wSpawnVar:     db
wMoveShift:    db
wBigPercent:   db
wMoveShiftBig: db
wDivPercent:   db
wPlaceDir::    db
wMoveShiftSplit: db
wSplitDir:     db
wSplitX:       db
wSplitY:       db
wZigPercent:   db
wAggrPercent:  db
wSpawnRoll:    db
wAggrAcc:      db
wChDX:         db
wChDY:         db
wChDirX:       db
wChDirY:       db
wWarnTimer::   db
wWarnType:     db
wWarnDir:      db
wWarnX:        db
wWarnY:        db
wWarnHp:       db
wHitShift:    db
wHitMissile:  db
wHitSize:      db
wDrawType:     db
;;    Variables de trabajo
wMoveNow:      db
wSpawnType:    db
wSpawnOff:     db
wDrawRows:     db
wDrawN:        db
wDrawTile:     db
wDrawX0:       db

SECTION "Enemies", ROM0

;;-----------------------------------------------------------------
;; Enemies_Init: Elimina todos los enemigos y programa la primera aparicion
Enemies_Init::
   ld   hl, wEnemies
   ld   bc, ENEMY_SIZE * MAX_ENEMIES
   xor  a
   call MemSet
   ld   a, ENEMY_SPAWN_FIRST
   ld   [wSpawnTimer], a
   xor  a
   ld   [wWarnTimer], a
   ret

;;-----------------------------------------------------------------
;; Tabla de dificultad: una fila por fase
MACRO PhaseRow
   ASSERT \1 <= MAX_ENEMIES
   ASSERT \5 + \7 + \8 + \9 <= 100
   db \1, \2, \3, \4, \5, \6, \7, \8, \9
ENDM
DEF PHASE_ROW_SIZE EQU 9
PhaseTable:
   PhaseRow   3, 100,  60, %00010001,       0, %00010000,   0,   0,   0
   PhaseRow   4,  80,  50, %00100101,       0, %00010000,   0,  40,   0
   PhaseRow   5,  70,  40, %01010101,      35, %00010000,   0,   0,  10
   PhaseRow   5,  45,  30, %01010101,       0, %00010000,  35,   0,   0
   PhaseRow   6,  45,  35, %01101101,      15, %00010001,  12,  12,  15
ASSERT (@ - PhaseTable) == PHASE_ROW_SIZE * PHASE_COUNT

;;-----------------------------------------------------------------
;; Enemies_SetPhase: Carga los parametros de dificultad de una fase
Enemies_SetPhase::
   ld   e, a
   ld   d, 0
   add  a
   add  a
   add  a
   add  e
   ld   e, a
   ld   hl, PhaseTable
   add  hl, de
   ld   a, [hl+]
   ld   [wMaxEnemies], a
   ld   a, [hl+]
   ld   [wSpawnMin], a
   ld   a, [hl+]
   ld   [wSpawnVar], a
   ld   a, [hl+]
   ld   [wMoveShift], a
   ld   a, [hl+]
   ld   [wBigPercent], a
   ld   a, [hl+]
   ld   [wMoveShiftBig], a
   ld   a, [hl+]
   ld   [wAggrPercent], a
   ld   a, [hl+]
   ld   [wZigPercent], a
   ld   a, [hl]
   ld   [wDivPercent], a
   ld   a, SPLIT_PATTERN
   ld   [wMoveShiftSplit], a
   ret

;;-----------------------------------------------------------------
;; Enemies_Wipe: Cambio de fase: todas las celulas explotan a la vez
Enemies_Wipe::
   ld   hl, wEnemies
   ld   d, MAX_ENEMIES
.loop:
   ld   a, [hl]
   and  a
   jr   z, .next
   push hl
   xor  a
   ld   [hl], a
   inc  hl
   inc  hl
   ld   a, [hl+]
   ld   b, a
   ld   a, [hl+]
   ld   c, a
   ld   a, [hl]
   dec  a
   add  a
   add  a
   ld   e, a
   ld   a, b
   add  e
   ld   b, a
   ld   a, c
   add  e
   ld   c, a
   call Explo_Spawn
   pop  hl
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  d
   jr   nz, .loop
   xor  a
   ld   [wWarnTimer], a
   ld   a, ENEMY_SPAWN_FIRST
   ld   [wSpawnTimer], a
   ret

;;-----------------------------------------------------------------
;; Enemies_Count: Cuenta las celulas que hay en pantalla
Enemies_Count:
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
   ld   c, 0
.loop:
   ld   a, [hl]
   and  a
   jr   z, .next
   inc  c
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .loop
   ld   a, c
   ret

;;-----------------------------------------------------------------
;; Enemies_CountType: Cuenta las celulas de un tipo
Enemies_CountType:
   ld   hl, wEnemies
   ld   c, 0
   ld   d, MAX_ENEMIES
.loop:
   ld   a, [hl]
   cp   b
   jr   nz, .next
   inc  c
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  d
   jr   nz, .loop
   ld   a, c
   ret

;;-----------------------------------------------------------------
;; Random_PlayX / Random_PlayY: Devuelven una coordenada al azar dentro de la zona de juego
Random_PlayX:
   ld   a, [wSpawnOff]
   ld   b, a
   ld   a, PLAY_RANGE_X
   sub  b
   ld   b, a
   call Random_Range
   add  PLAY_MIN_X
   ret

Random_PlayY:
   ld   a, [wSpawnOff]
   ld   b, a
   ld   a, PLAY_RANGE_Y
   sub  b
   ld   b, a
   call Random_Range
   add  PLAY_MIN_Y
   ret

;;-----------------------------------------------------------------
;; Enemies_ChooseType: Decide el tipo de la proxima celula con una tirada 0..99
Enemies_ChooseType:
   ld   a, [wWarnTimer]
   and  a
   jp   nz, .normal
   ld   b, 100
   call Random_Range
   ld   [wSpawnRoll], a
   ld   b, a
   ld   a, [wBigPercent]
   cp   b
   jr   z, .notBig
   jr   c, .notBig
   ld   b, ENEMY_BIG
   call Enemies_CountType
   cp   MAX_BIG
   jr   nc, .normal
   ld   a, BIG_OFFSET
   ld   [wSpawnOff], a
   ld   a, ENEMY_BIG
   ret
.notBig:
   ld   a, [wBigPercent]
   ld   b, a
   ld   a, [wSpawnRoll]
   sub  b
   ld   b, a
   ld   a, [wAggrPercent]
   cp   b
   jr   z, .tryZig
   jr   c, .tryZig
   ld   b, ENEMY_AGGR
   call Enemies_CountType
   cp   MAX_AGGR
   jr   nc, .normal
   ld   a, AGGR_OFFSET
   ld   [wSpawnOff], a
   ld   a, ENEMY_AGGR
   ret
.tryZig:
   ld   a, [wAggrPercent]
   ld   c, a
   ld   a, b
   sub  c
   ld   b, a
   ld   a, [wZigPercent]
   cp   b
   jr   z, .tryDiv
   jr   c, .tryDiv
   ld   b, ENEMY_ZIGZAG
   call Enemies_CountType
   cp   MAX_ZIG
   jr   nc, .normal
   xor  a
   ld   [wSpawnOff], a
   ld   a, ENEMY_ZIGZAG
   ret
.tryDiv:
   ld   a, [wZigPercent]
   ld   c, a
   ld   a, b
   sub  c
   ld   b, a
   ld   a, [wDivPercent]
   cp   b
   jr   z, .normal
   jr   c, .normal
   ld   b, ENEMY_DIV
   call Enemies_CountType
   cp   MAX_DIV
   jr   nc, .normal
   ld   a, DIV_OFFSET
   ld   [wSpawnOff], a
   ld   a, ENEMY_DIV
   ret
.normal:
   xor  a
   ld   [wSpawnOff], a
   ld   a, ENEMY_NORMAL
   ret

;;-----------------------------------------------------------------
;; Enemies_Spawn: Crea una celula en un lado y una posicion al azar, si hay algun hueco libre
Enemies_Spawn:
   ld   hl, wEnemies
   ld   d, MAX_ENEMIES
.find:
   ld   a, [hl]
   and  a
   jr   z, .free
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  d
   jr   nz, .find
   ret
.free:
   push hl
   call Enemies_ChooseType
   ld   [wSpawnType], a
   pop  hl
   ld   [hl+], a
   call Random_Next
   and  %00000011
   jr   z, .fromLeft
   dec  a
   jr   z, .fromRight
   dec  a
   jr   z, .fromTop
.fromBottom:
   ld   a, DIR_UP
   ld   [hl+], a
   call Random_PlayX
   ld   [hl+], a
   ld   a, [wSpawnOff]
   ld   b, a
   ld   a, PLAY_MAX_Y
   sub  b
   ld   [hl+], a
   jr   .setHp
.fromLeft:
   ld   a, DIR_RIGHT
   ld   [hl+], a
   ld   a, PLAY_MIN_X
   ld   [hl+], a
   call Random_PlayY
   ld   [hl+], a
   jr   .setHp
.fromRight:
   ld   a, DIR_LEFT
   ld   [hl+], a
   ld   a, [wSpawnOff]
   ld   b, a
   ld   a, PLAY_MAX_X
   sub  b
   ld   [hl+], a
   call Random_PlayY
   ld   [hl+], a
   jr   .setHp
.fromTop:
   ld   a, DIR_DOWN
   ld   [hl+], a
   call Random_PlayX
   ld   [hl+], a
   ld   a, PLAY_MIN_Y
   ld   [hl+], a
.setHp:
   ld   a, [wSpawnType]
   cp   ENEMY_BIG
   ld   a, ENEMY_BIG_HP
   jr   z, .storeHp
   ld   a, [wSpawnType]
   cp   ENEMY_AGGR
   ld   a, ENEMY_AGGR_HP
   jr   z, .storeHp
   ld   a, [wSpawnType]
   cp   ENEMY_DIV
   ld   a, ENEMY_DIV_HP
   jr   z, .storeHp
   ld   a, ENEMY_NORMAL_HP
.storeHp:
   ld   [hl], a
   ld   a, [wSpawnType]
   cp   ENEMY_NORMAL
   ret  z
   cp   ENEMY_ZIGZAG
   jr   nz, .needWarn
   push hl
   dec  hl
   dec  hl
   dec  hl
   call Random_Next
   and  %11111000
   ld   b, a
   ld   a, [hl]
   or   b
   ld   [hl], a
   pop  hl
   ret
.needWarn:
   ld   de, wWarnType + ENEMY_SIZE - 1
   ld   b, ENEMY_SIZE
.stash:
   ld   a, [hl-]
   ld   [de], a
   dec  de
   dec  b
   jr   nz, .stash
   inc  hl
   xor  a
   ld   [hl], a
   ld   a, WARN_FRAMES
   ld   [wWarnTimer], a
   ret

;;-----------------------------------------------------------------
;; Enemies_Place: Crea una celula ya en juego en la posicion dada
Enemies_Place::
   ld   d, a
   ld   hl, wEnemies
   ld   e, MAX_ENEMIES
.find:
   ld   a, [hl]
   and  a
   jr   z, .free
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  e
   jr   nz, .find
   ret
.free:
   ld   a, d
   ld   [hl+], a
   ld   a, [wPlaceDir]
   ld   e, a
   ld   a, d
   cp   ENEMY_ZIGZAG
   jr   nz, .dir
   push hl
   call Random_Next
   pop  hl
   and  %11111000
   or   e
   jr   .storeDir
.dir:
   ld   a, e
.storeDir:
   ld   [hl+], a
   ld   a, b
   ld   [hl+], a
   ld   a, c
   ld   [hl+], a
   ld   a, d
   cp   ENEMY_AGGR
   ld   a, ENEMY_AGGR_HP
   jr   z, .hp
   ld   a, d
   cp   ENEMY_DIV
   ld   a, ENEMY_DIV_HP
   jr   z, .hp
   ld   a, 1
.hp:
   ld   [hl], a
   ret

;;-----------------------------------------------------------------
;; Enemies_Activate: Acaba el aviso: la celula guardada en wWarnType entra de verdad en un hueco libre
Enemies_Activate:
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.find:
   ld   a, [hl]
   and  a
   jr   z, .free
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .find
   ret
.free:
   ld   de, wWarnType
   ld   b, ENEMY_SIZE
.copy:
   ld   a, [de]
   inc  de
   ld   [hl+], a
   dec  b
   jr   nz, .copy
   ret

;;-----------------------------------------------------------------
;; Enemies_Move: Mueve las celulas 1 pixel en su direccion
Enemies_Move:
   ld   a, [wMoveShift]
   rlca
   ld   [wMoveShift], a
   ld   a, 0
   rla
   ld   b, a
   ld   a, [wMoveShiftBig]
   rlca
   ld   [wMoveShiftBig], a
   ld   a, b
   rla
   ld   c, a
   bit  1, c
   jr   z, .noAggr
   ld   a, [wAggrAcc]
   add  AGGR_SPEED_PCT
   cp   100
   jr   c, .keepAcc
   sub  100
   set  2, c
.keepAcc:
   ld   [wAggrAcc], a
.noAggr:
   ld   a, [wMoveShiftSplit]
   rlca
   ld   [wMoveShiftSplit], a
   jr   nc, .noSplit
   set  3, c
.noSplit:
   ld   a, c
   ld   [wMoveNow], a
   and  a
   ret  z

   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.loop:
   ld   a, [hl]
   and  a
   jp   z, .next
   cp   ENEMY_AGGR
   jr   z, .isAggr
   cp   ENEMY_DIV
   jr   z, .isAggr
   cp   ENEMY_SPLIT
   jr   z, .isSplit
   cp   ENEMY_BIG
   ld   a, [wMoveNow]
   jr   z, .isBig
   and  %00000010
   jp   z, .next
   jr   .move
.isAggr:
   ld   a, [wMoveNow]
   and  %00000100
   jp   z, .next
   jr   .move
.isSplit:
   ld   a, [wMoveNow]
   and  %00001000
   jp   z, .next
   jr   .move
.isBig:
   and  %00000001
   jp   z, .next
.move:
   ld   a, [hl]
   cp   ENEMY_AGGR
   jr   nz, .straight
   call Enemy_Chase
   jp   .next
.straight:
   push hl
   inc  hl
   ld   a, [hl+]
   and  %00000111
   ld   d, a
   inc  hl
   inc  hl
   ld   a, [hl]
   dec  hl
   dec  hl
   dec  a
   add  a
   add  a
   add  a
   ld   e, a
   ld   a, d
   cp   DIR_UP
   jr   z, .up
   cp   DIR_DOWN
   jr   z, .down
   cp   DIR_LEFT
   jr   z, .left
.right:
   ld   a, [hl]
   inc  a
   ld   [hl], a
   ld   d, a
   ld   a, PLAY_MAX_X + 1
   sub  e
   ld   e, a
   ld   a, d
   cp   e
   jr   nc, .kill
   jr   .moved
.left:
   ld   a, [hl]
   dec  a
   ld   [hl], a
   cp   PLAY_MIN_X
   jr   c, .kill
   jr   .moved
.down:
   inc  hl
   ld   a, [hl]
   inc  a
   ld   [hl], a
   ld   d, a
   ld   a, PLAY_MAX_Y + 1
   sub  e
   ld   e, a
   ld   a, d
   cp   e
   jr   nc, .kill
   jr   .moved
.up:
   inc  hl
   ld   a, [hl]
   dec  a
   ld   [hl], a
   cp   PLAY_MIN_Y
   jr   c, .kill
.moved:
   pop  hl
   ld   a, [hl]
   cp   ENEMY_ZIGZAG
   call z, Enemy_Zig
   jr   .next
.kill:
   pop  hl
   xor  a
   ld   [hl], a
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jp   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Enemy_Zig: Movimiento ondulado de la celula zigzag
Enemy_Zig:
   push bc
   push hl
   inc  hl
   ld   a, [hl]
   add  8
   ld   [hl+], a
   ld   d, a
   and  %00000111
   cp   DIR_LEFT
   ld   b, PLAY_MIN_X
   ld   c, PLAY_MAX_X
   jr   c, .go
   inc  hl
   ld   b, PLAY_MIN_Y
   ld   c, PLAY_MAX_Y
.go:
   ld   e, ZIG_STEP_PX
.lat:
   ld   a, [hl]
   bit  6, d
   jr   nz, .plus
   cp   b
   jr   z, .done
   dec  a
   jr   .store
.plus:
   cp   c
   jr   nc, .done
   inc  a
.store:
   ld   [hl], a
   dec  e
   jr   nz, .lat
.done:
   pop  hl
   pop  bc
   ret

;;-----------------------------------------------------------------
;; Enemy_Chase: Mueve 1 pixel a una celula agresiva hacia el CENTRO del jugador
Enemy_Chase:
   push hl
   push bc
   inc  hl
   inc  hl
   ld   d, h
   ld   e, l
   inc  hl
   inc  hl
   ld   a, [hl]
   add  a
   add  a
   ld   c, a
   ld   h, d
   ld   l, e
   ld   a, [hl+]
   add  c
   ld   d, a
   ld   a, [hl]
   add  c
   ld   e, a
   dec  hl
   ;; --- Distancia en X ---
   ld   a, [wPlayerX]
   add  TILE_SIZE / 2
   sub  d
   ld   b, DIR_RIGHT
   jr   nc, .px
   cpl
   inc  a
   ld   b, DIR_LEFT
.px:
   ld   [wChDX], a
   ld   a, b
   ld   [wChDirX], a
   ;; --- Distancia en Y ---
   ld   a, [wPlayerY]
   add  TILE_SIZE / 2
   sub  e
   ld   b, DIR_DOWN
   jr   nc, .py
   cpl
   inc  a
   ld   b, DIR_UP
.py:
   ld   [wChDY], a
   ld   a, b
   ld   [wChDirY], a
   ;; --- Eje de movimiento ---
   ld   a, [wChDX]
   ld   b, a
   ld   a, [wChDY]
   cp   b
   jr   c, .moveX
   jr   nz, .moveY
   and  a
   jr   z, .done
.moveX:
   ld   a, [wChDirX]
   cp   DIR_RIGHT
   ld   a, [hl]
   jr   z, .xInc
   dec  a
   jr   .xStore
.xInc:
   inc  a
.xStore:
   ld   [hl], a
   jr   .done
.moveY:
   inc  hl
   ld   a, [wChDirY]
   cp   DIR_DOWN
   ld   a, [hl]
   jr   z, .yInc
   dec  a
   jr   .yStore
.yInc:
   inc  a
.yStore:
   ld   [hl], a
.done:
   pop  bc
   pop  hl
   ret

;;-----------------------------------------------------------------
;; Collide_Box: Comprueba si un sprite de 8x8 choca con una celula
Collide_Box:
   push hl
   push de
   push bc
   ld   a, [de]
   ld   b, a
   inc  de
   ld   a, [de]
   ld   c, a
   push hl
   ld   de, ENEMY_SIZE - 1
   add  hl, de
   ld   a, [hl]
   pop  hl
   add  a
   add  a
   add  a
   add  COLLIDE_EXTRA
   ld   d, a
   inc  hl
   inc  hl
   ld   a, b
   sub  [hl]
   add  COLLIDE_BIAS
   cp   d
   jr   nc, .done
   inc  hl
   ld   a, c
   sub  [hl]
   add  COLLIDE_BIAS
   cp   d
   jr   nc, .done
   scf
.done:
   pop  bc
   pop  de
   pop  hl
   ret

;;-----------------------------------------------------------------
;; Enemies_CheckBullets: Cada bala que toca a una celula desaparece y le quita 1 de vida
Enemies_CheckBullets:
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.enemyLoop:
   ld   a, [hl]
   and  a
   jp   z, .nextEnemy
   push bc
   ld   de, wBullets
   ld   c, MAX_BULLETS
.bulletLoop:
   ld   a, [de]
   and  a
   jp   z, .nextBullet
   inc  de
   call Collide_Box
   dec  de
   jp   nc, .nextBullet
   ;; --- La bala ha tocado a la celula ---
   ld   a, [de]
   and  MISSILE_FLAG
   ld   [wHitMissile], a
   xor  a
   ld   [de], a
   push hl
   REPT ENEMY_SIZE - 1
      inc  hl
   ENDR
   ld   a, [hl]
   ld   [wHitSize], a
   REPT ENEMY_SIZE - 1
      dec  hl
   ENDR
   ld   a, [hl]
   REPT ENEMY_SIZE - 1
      inc  hl
   ENDR
   cp   ENEMY_DIV
   jr   nz, .notDiv
   ld   [hl], 1
.notDiv:
   ld   a, [wHitMissile]
   and  a
   jr   z, .normalHit
   ld   a, [hl]
   cp   MISSILE_DAMAGE + 1
   jr   c, .missileKill
   dec  [hl]
   jr   .normalHit
.missileKill:
   ld   [hl], 1
.normalHit:
   dec  [hl]
   pop  hl
   jr   nz, .survived
   ;; --- Muere ---
   ld   a, [hl]
   cp   ENEMY_BIG
   ld   a, ENEMY_BIG_POINTS
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_AGGR
   ld   a, ENEMY_AGGR_POINTS
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_ZIGZAG
   ld   a, ENEMY_ZIG_POINTS
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_DIV
   ld   a, ENEMY_DIV_POINTS
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_SPLIT
   ld   a, ENEMY_SPLIT_POINTS
   jr   z, .points
   ld   a, ENEMY_NORMAL_POINTS
.points:
   push af
   push bc
   push hl
   inc  hl
   inc  hl
   ld   a, [wHitSize]
   dec  a
   add  a
   add  a
   ld   e, a
   ld   a, [hl+]
   add  e
   ld   b, a
   ld   a, [hl]
   add  e
   ld   c, a
   call Explo_Spawn
   call Drop_Roll
   pop  hl
   pop  bc
   ld   a, [hl]
   cp   ENEMY_DIV
   jr   z, .split
   xor  a
   ld   [hl], a
   jr   .freed
.split:
   call Enemies_Split
.freed:
   pop  af
   call Combo_Kill
   jr   .enemyDone
.survived:
   push hl
   REPT ENEMY_SIZE - 1
      inc  hl
   ENDR
   ld   a, [wHitSize]
   sub  [hl]
   add  a
   add  a
   ld   [wHitShift], a
   pop  hl
   inc  hl
   inc  hl
   ld   a, [wHitShift]
   add  [hl]
   ld   [hl+], a
   ld   a, [wHitShift]
   add  [hl]
   ld   [hl], a
   dec  hl
   dec  hl
   dec  hl
.nextBullet:
   REPT BULLET_SIZE
      inc  de
   ENDR
   dec  c
   jp   nz, .bulletLoop
.enemyDone:
   pop  bc
.nextEnemy:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jp   nz, .enemyLoop
   ret

;;-----------------------------------------------------------------
;; Enemies_Split: La divisora destruida se parte en dos celulas hijas
Enemies_Split:
   push hl
   push bc
   push de
   inc  hl
   ld   a, [hl+]
   and  %00000111
   ld   [wSplitDir], a
   ld   a, [hl+]
   add  TILE_SIZE / 2
   ld   [wSplitX], a
   ld   a, [hl]
   add  TILE_SIZE / 2
   ld   [wSplitY], a
   dec  hl
   dec  hl
   dec  hl
   xor  a
   ld   [hl], a
   ld   a, [wSplitDir]
   cp   DIR_LEFT
   ld   a, DIR_LEFT
   ld   b, DIR_RIGHT
   jr   c, .go
   ld   a, DIR_UP
   ld   b, DIR_DOWN
.go:
   push bc
   call .newChild
   pop  bc
   ld   a, b
   call .newChild
   pop  de
   pop  bc
   pop  hl
   ret
;;    A = direccion de la hija
.newChild:
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.find:
   ld   c, [hl]
   inc  c
   dec  c
   jr   z, .put
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .find
   ret
.put:
   ld   c, a
   ld   a, ENEMY_SPLIT
   ld   [hl+], a
   ld   a, c
   ld   [hl+], a
   ld   a, [wSplitX]
   ld   [hl+], a
   ld   a, [wSplitY]
   ld   [hl+], a
   ld   a, 1
   ld   [hl], a
   ret

;;-----------------------------------------------------------------
;; Enemies_CheckPlayer: Comprueba si una celula toca al jugador
Enemies_CheckPlayer:
   ld   a, [wShield]
   and  a
   jr   nz, Enemies_ShieldHit
   ld   a, [wInvuln]
   and  a
   ret  nz
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.loop:
   ld   a, [hl]
   and  a
   jr   z, .next
   ld   de, wPlayerX
   call Collide_Box
   jr   nc, .next
   xor  a
   ld   [hl], a
   jp   Game_PlayerHit
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Enemies_ShieldHit: Con el escudo activo, las celulas que tocan la nave explotan
Enemies_ShieldHit:
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.loop:
   ld   a, [hl]
   and  a
   jr   z, .next
   ld   de, wPlayerX
   call Collide_Box
   jr   nc, .next
   push hl
   push bc
   ld   a, [hl]
   cp   ENEMY_BIG
   ld   a, ENEMY_BIG_POINTS
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_AGGR
   ld   a, ENEMY_AGGR_POINTS
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_ZIGZAG
   ld   a, ENEMY_ZIG_POINTS
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_DIV
   ld   a, ENEMY_DIV_POINTS
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_SPLIT
   ld   a, ENEMY_SPLIT_POINTS
   jr   z, .points
   ld   a, ENEMY_NORMAL_POINTS
.points:
   push af
   xor  a
   ld   [hl], a
   inc  hl
   inc  hl
   ld   a, [hl+]
   ld   b, a
   ld   a, [hl+]
   ld   c, a
   ld   a, [hl]
   dec  a
   add  a
   add  a
   ld   e, a
   ld   a, b
   add  e
   ld   b, a
   ld   a, c
   add  e
   ld   c, a
   call Explo_Spawn
   pop  af
   call Combo_Kill
   pop  bc
   pop  hl
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Enemies_Update: Un fotograma de enemigos
Enemies_Update::
   ;;--------------------------------------
;; -- Aviso: cuando acaba la cuenta atras, la celula grande/agresiva avisada entra
   ld   a, [wWarnTimer]
   and  a
   jr   z, .noWarn
   dec  a
   ld   [wWarnTimer], a
   call z, Enemies_Activate
.noWarn:
   ;;--------------------------------------
;; -- Aparicion: cuando el temporizador llega a 0 sale una celula y se programa la siguiente
   ld   a, [wPhase]
   cp   BOSS_PHASE
   jr   z, .noSpawn
   ld   a, [wSpawnTimer]
   dec  a
   ld   [wSpawnTimer], a
   jr   nz, .noSpawn
   call Enemies_Count
   ld   b, a
   ld   a, [wMaxEnemies]
   cp   b
   jr   c, .skipSpawn
   jr   z, .skipSpawn
   call Enemies_Spawn
.skipSpawn:
   ld   a, [wSpawnVar]
   ld   b, a
   call Random_Range
   ld   b, a
   ld   a, [wSpawnMin]
   add  b
   ld   [wSpawnTimer], a
.noSpawn:

   call Enemies_Move
   call Enemies_CheckBullets
   call Enemies_CheckPlayer
   ret

;;-----------------------------------------------------------------
;; Put_Sprite: Escribe 1 sprite (paleta OBP0) en la OAM en sombra
ASSERT OAM_SIZE < 256
Put_Sprite::
   push af
   ld   a, e
   cp   OAM_SIZE
   jr   nc, .full
   ld   a, c
   add  OAM_Y_OFFSET
   ld   [de], a
   inc  de
   ld   a, b
   add  OAM_X_OFFSET
   ld   [de], a
   inc  de
   pop  af
   ld   [de], a
   inc  de
   xor  a
   ld   [de], a
   inc  de
   ret
.full:
   pop  af
   ret

;;-----------------------------------------------------------------
;; Enemy_DrawSprites: Escribe los sprites de una celula
Enemy_DrawSprites:
   ld   a, [hl+]
   ld   [wDrawType], a
   inc  hl
   ld   a, [hl+]
   ld   b, a
   ld   a, [hl+]
   ld   c, a
   ld   a, [hl]
   ld   [wDrawRows], a
   ld   [wDrawN], a
   ld   a, [wDrawType]
   cp   ENEMY_AGGR
   ld   a, [wDrawN]
   jr   z, .aggr
   ld   a, [wDrawType]
   cp   ENEMY_ZIGZAG
   ld   a, TILE_ZIGZAG
   jr   z, .tile
   ld   a, [wDrawType]
   cp   ENEMY_DIV
   ld   a, TILE_DIV
   jr   z, .tile
   ld   a, [wDrawType]
   cp   ENEMY_SPLIT
   ld   a, TILE_SPLIT
   jr   z, .tile
   ld   a, [wDrawN]
   cp   2
   ld   a, TILE_ENEMY1
   jr   c, .tile
   ld   a, TILE_BIG2
   jr   z, .tile
   ld   a, TILE_BIG3
   jr   .tile
.aggr:
   cp   2
   ld   a, TILE_AGGR1
   jr   c, .tile
   ld   a, TILE_AGGR2
.tile:
   ld   [wDrawTile], a
   ld   a, b
   ld   [wDrawX0], a
.row:
   ld   a, [wDrawN]
   ld   h, a
   ld   a, [wDrawX0]
   ld   b, a
.col:
   ld   a, [wDrawTile]
   call Put_Sprite
   ld   a, [wDrawTile]
   inc  a
   ld   [wDrawTile], a
   ld   a, b
   add  TILE_SIZE
   ld   b, a
   dec  h
   jr   nz, .col
   ld   a, c
   add  TILE_SIZE
   ld   c, a
   ld   a, [wDrawRows]
   dec  a
   ld   [wDrawRows], a
   jr   nz, .row
   ret

;;-----------------------------------------------------------------
;; Enemies_Draw: Escribe los enemigos en la OAM en sombra
Enemies_Draw::
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   ;; sigue en Enemies_DrawAt

;;-----------------------------------------------------------------
;; Enemies_DrawAt: Como Enemies_Draw, pero empezando en el sprite de la OAM en sombra que indica DE
Enemies_DrawAt::
   ASSERT ENEMY_SIZE == 5
   call Boss_Draw
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.enemy:
   ld   a, [hl]
   and  a
   jr   z, .skip
   push hl
   push bc
   call Enemy_DrawSprites
   pop  bc
   pop  hl
.skip:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .enemy
   jp   Explo_Draw
