;;-------------------------------------------------------------------------------------------------------------------------------;;
;; bullets.asm : Disparos del jugador
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Bullets Variables", WRAM0

wBullets::   ds BULLET_SIZE * MAX_BULLETS
wCooldownA:: db
wCooldownB:: db
wShotFlag:   db
wChargeA:    db
wChargeB:    db
wChargeHide:: db
wChargeBlink: db
wDrawDirB:   db
wMsX:        db
wMsY:        db
wBestD:      db
wFound:      db
wTgtX:       db
wTgtY:       db
wMdx:        db
wMdy:        db
wMdirX:      db
wMdirY:      db
wClaimed:    ds MAX_ENEMIES
wPass:       db
wBestIdx:    db

SECTION "Bullets", ROM0

MACRO ShotButton
   ldh  a, [hInput]
   bit  \1, a
   jr   z, .released\@
   ldh  a, [hInputNew]
   bit  \1, a
   jr   z, .holding\@
   xor  a
   ld   [\2], a
   ld   a, [\3]
   and  a
   jr   nz, .holding\@
   ld   a, SHOT_COOLDOWN
   ld   [\3], a
   ld   c, \4
   call Bullets_Spawn
   ld   c, \5
   call Bullets_Spawn
.holding\@:
   ld   a, [\6]
   and  a
   jr   nz, .done\@
   ld   a, [\2]
   and  a
   jr   nz, .have\@
   ld   a, [wEnergy]
   cp   MISSILE_COST
   jr   c, .done\@
.have\@:
   ld   a, [\2]
   cp   CHARGE_FRAMES
   jr   nc, .done\@
   inc  a
   ld   [\2], a
   cp   CHARGE_FRAMES
   jr   nz, .done\@
   ld   a, CHARGE_FLASH
   ld   [wFlash], a
   jr   .done\@
.released\@:
   ld   a, [\2]
   cp   CHARGE_FRAMES
   jr   c, .clear\@
   ld   a, [wEnergy]
   cp   MISSILE_COST
   jr   c, .clear\@
   sub  MISSILE_COST
   ld   [wEnergy], a
   ld   a, 1
   ld   [wHudDirty], a
   ld   a, MISSILE_FLAG
   ld   [wShotFlag], a
   ld   c, \4
   call Bullets_Spawn
   ld   c, \5
   call Bullets_Spawn
   xor  a
   ld   [wShotFlag], a
   ld   a, SHOT_COOLDOWN
   ld   [\3], a
.clear\@:
   xor  a
   ld   [\2], a
.done\@:
ENDM

;;-----------------------------------------------------------------
;; Bullets_Init: Elimina todas las balas y reinicia las recargas
Bullets_Init::
   ld   hl, wBullets
   ld   bc, BULLET_SIZE * MAX_BULLETS
   xor  a
   call MemSet
   xor  a
   ld   [wCooldownA], a
   ld   [wCooldownB], a
   ld   [wChargeA], a
   ld   [wChargeB], a
   ld   [wChargeHide], a
   ld   [wShotFlag], a
   inc  a
   ld   [wChargeBlink], a
   ret

;;-----------------------------------------------------------------
;; Bullets_Spawn: Crea una bala en la posicion del jugador, si hay algun hueco libre
Bullets_Spawn:
   ld   hl, wBullets
   ld   d, MAX_BULLETS
.find:
   ld   a, [hl]
   and  a
   jr   z, .free
   REPT BULLET_SIZE
      inc  hl
   ENDR
   dec  d
   jr   nz, .find
   ret
.free:
   ld   a, [wShotFlag]
   or   c
   ld   [hl+], a
   ld   a, [wPlayerX]
   ld   [hl+], a
   ld   a, [wPlayerY]
   ld   [hl], a
   ret

;;-----------------------------------------------------------------
;; Bullets_Update: Gestiona los disparos (recargas, nuevas balas) y mueve las balas existentes
Bullets_Update::
;;--------------------------------------
;; -- Recargas: cada fotograma bajan en 1 hasta llegar a 0
   ld   a, [wCooldownA]
   and  a
   jr   z, .cooldownAready
   dec  a
   ld   [wCooldownA], a
.cooldownAready:
   ld   a, [wCooldownB]
   and  a
   jr   z, .cooldownBready
   dec  a
   ld   [wCooldownB], a
.cooldownBready:

   ;;--------------------------------------
;; -- Botones A (arriba + abajo) y B (izquierda + derecha)
   ShotButton BTNB_A, wChargeA, wCooldownA, BULLET_UP, BULLET_DOWN, wChargeB
   ShotButton BTNB_B, wChargeB, wCooldownB, BULLET_LEFT, BULLET_RIGHT, wChargeA

   ;;--------------------------------------
;; -- Parpadeo de la nave mientras se carga
   ld   a, [wChargeA]
   ld   c, a
   ld   a, [wChargeB]
   cp   c
   jr   c, .chargeKnown
   ld   c, a
.chargeKnown:
   ld   a, c
   cp   CHARGE_BLINK_START
   jr   c, .noBlink
   cp   CHARGE_FRAMES
   jr   nc, .noBlink
   ld   a, [wChargeBlink]
   dec  a
   ld   [wChargeBlink], a
   jr   nz, .blinkDone
   ld   a, [wChargeHide]
   xor  1
   ld   [wChargeHide], a
   ld   a, CHARGE_FRAMES
   sub  c
   srl  a
   srl  a
   srl  a
   cp   2
   jr   nc, .reload
   ld   a, 2
.reload:
   ld   [wChargeBlink], a
   jr   .blinkDone
.noBlink:
   xor  a
   ld   [wChargeHide], a
   inc  a
   ld   [wChargeBlink], a
.blinkDone:

   ;;--------------------------------------
;; -- Mover todas las balas existentes
   ld   hl, wBullets
   push hl
   push bc
   ld   hl, wClaimed
   ld   b, MAX_ENEMIES
   xor  a
.clrClaim:
   ld   [hl+], a
   dec  b
   jr   nz, .clrClaim
   pop  bc
   pop  hl
   ld   b, MAX_BULLETS
.loop:
   ld   a, [hl]
   and  a
   jr   z, .next
   bit  7, a
   jr   nz, .missile
   push hl
   cp   BULLET_UP
   jr   z, .up
   cp   BULLET_DOWN
   jr   z, .down
   cp   BULLET_LEFT
   jr   z, .left
.right:
   inc  hl
   ld   a, [hl]
   add  BULLET_SPEED
   cp   PLAY_MAX_X + 1
   jr   nc, .kill
   ld   [hl], a
   jr   .moved
.left:
   inc  hl
   ld   a, [hl]
   sub  BULLET_SPEED
   jr   c, .kill
   cp   PLAY_MIN_X
   jr   c, .kill
   ld   [hl], a
   jr   .moved
.down:
   inc  hl
   inc  hl
   ld   a, [hl]
   add  BULLET_SPEED
   cp   PLAY_MAX_Y + 1
   jr   nc, .kill
   ld   [hl], a
   jr   .moved
.up:
   inc  hl
   inc  hl
   ld   a, [hl]
   sub  BULLET_SPEED
   jr   c, .kill
   cp   PLAY_MIN_Y
   jr   c, .kill
   ld   [hl], a
.moved:
   pop  hl
   jr   .next
.kill:
   pop  hl
   xor  a
   ld   [hl], a
   jr   .next
.missile:
   call Missile_Step
.next:
   REPT BULLET_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Missile_Step: Mueve un misil MISSILE_SPEED pixeles hacia la celula mas cercana
Missile_Step:
   push hl
   push bc
   ;; --- Centro del misil ---
   inc  hl
   ld   a, [hl+]
   add  TILE_SIZE / 2
   ld   [wMsX], a
   ld   a, [hl]
   add  TILE_SIZE / 2
   ld   [wMsY], a
   ;; --- Busqueda de la celula mas cercana ---
   xor  a
   ld   [wPass], a
.search:
   ld   a, $FF
   ld   [wBestD], a
   xor  a
   ld   [wFound], a
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.enemy:
   ld   a, [hl]
   and  a
   jr   z, .nextEnemy
   ld   a, [wPass]
   and  a
   jr   nz, .consider
   push hl
   ld   a, MAX_ENEMIES
   sub  b
   ld   e, a
   ld   d, 0
   ld   hl, wClaimed
   add  hl, de
   ld   a, [hl]
   pop  hl
   and  a
   jr   nz, .nextEnemy
.consider:
   push hl
   inc  hl
   inc  hl
   ld   a, [hl+]
   ld   d, a
   ld   a, [hl+]
   ld   e, a
   ld   a, [hl]
   add  a
   add  a
   ld   c, a
   ld   a, d
   add  c
   ld   d, a
   ld   a, e
   add  c
   ld   e, a
   ld   a, [wMsX]
   ld   c, a
   ld   a, d
   sub  c
   jr   nc, .dxAbs
   cpl
   inc  a
.dxAbs:
   ld   c, a
   ld   a, [wMsY]
   ld   h, a
   ld   a, e
   sub  h
   jr   nc, .dyAbs
   cpl
   inc  a
.dyAbs:
   ld   h, a
   ld   a, c
   cp   h
   jr   c, .yFar
   ld   a, h
   srl  a
   add  c
   jr   .gotDist
.yFar:
   ld   a, c
   srl  a
   add  h
.gotDist:
   ld   l, a
   ld   a, [wBestD]
   cp   l
   jr   c, .notBetter
   jr   z, .notBetter
   ld   a, l
   ld   [wBestD], a
   ld   a, d
   ld   [wTgtX], a
   ld   a, e
   ld   [wTgtY], a
   ld   a, 1
   ld   [wFound], a
   ld   a, MAX_ENEMIES
   sub  b
   ld   [wBestIdx], a
.notBetter:
   pop  hl
.nextEnemy:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jp   nz, .enemy
   ld   a, [wFound]
   and  a
   jr   nz, .claim
   ld   a, [wPass]
   and  a
   jr   nz, .claim
   inc  a
   ld   [wPass], a
   jp   .search
.claim:
   ld   a, [wFound]
   and  a
   jr   z, .noClaim
   ld   a, [wBestIdx]
   ld   e, a
   ld   d, 0
   ld   hl, wClaimed
   add  hl, de
   ld   [hl], 1
.noClaim:
   pop  bc
   pop  hl
   push hl
   push bc
   ld   a, [wFound]
   and  a
   jp   z, .straight
   ld   a, [wTgtX]
   ld   c, a
   ld   a, [wMsX]
   ld   b, a
   ld   a, c
   sub  b
   ld   b, DIR_RIGHT
   jr   nc, .px
   cpl
   inc  a
   ld   b, DIR_LEFT
.px:
   ld   [wMdx], a
   ld   a, b
   ld   [wMdirX], a
   ld   a, [wTgtY]
   ld   c, a
   ld   a, [wMsY]
   ld   b, a
   ld   a, c
   sub  b
   ld   b, DIR_DOWN
   jr   nc, .py
   cpl
   inc  a
   ld   b, DIR_UP
.py:
   ld   [wMdy], a
   ld   a, b
   ld   [wMdirY], a
   ld   a, [wMdx]
   ld   b, a
   ld   a, [wMdy]
   cp   b
   jr   c, .stepX
   jr   nz, .stepY
   and  a
   jp   z, .done
.stepX:
   ld   a, [wMdx]
   cp   MISSILE_SPEED
   jr   c, .xs
   ld   a, MISSILE_SPEED
.xs:
   ld   c, a
   ld   a, [wMdirX]
   or   MISSILE_FLAG
   ld   [hl+], a
   ld   a, [wMdirX]
   cp   DIR_RIGHT
   ld   a, [hl]
   jr   z, .xInc
   sub  c
   jr   .xStore
.xInc:
   add  c
.xStore:
   ld   [hl], a
   jp   .done
.stepY:
   ld   a, [wMdy]
   cp   MISSILE_SPEED
   jr   c, .ys
   ld   a, MISSILE_SPEED
.ys:
   ld   c, a
   ld   a, [wMdirY]
   or   MISSILE_FLAG
   ld   [hl+], a
   inc  hl
   ld   a, [wMdirY]
   cp   DIR_DOWN
   ld   a, [hl]
   jr   z, .yInc
   sub  c
   jr   .yStore
.yInc:
   add  c
.yStore:
   ld   [hl], a
   jr   .done
.straight:
   ld   a, [hl]
   and  %00000111
   cp   DIR_UP
   jr   z, .sUp
   cp   DIR_DOWN
   jr   z, .sDown
   cp   DIR_LEFT
   jr   z, .sLeft
   inc  hl
   ld   a, [hl]
   add  MISSILE_SPEED
   cp   PLAY_MAX_X + 1
   jr   nc, .sKill
   ld   [hl], a
   jr   .done
.sLeft:
   inc  hl
   ld   a, [hl]
   sub  MISSILE_SPEED
   jr   c, .sKill
   cp   PLAY_MIN_X
   jr   c, .sKill
   ld   [hl], a
   jr   .done
.sDown:
   inc  hl
   inc  hl
   ld   a, [hl]
   add  MISSILE_SPEED
   cp   PLAY_MAX_Y + 1
   jr   nc, .sKill
   ld   [hl], a
   jr   .done
.sUp:
   inc  hl
   inc  hl
   ld   a, [hl]
   sub  MISSILE_SPEED
   jr   c, .sKill
   cp   PLAY_MIN_Y
   jr   c, .sKill
   ld   [hl], a
   jr   .done
.sKill:
   pop  bc
   pop  hl
   xor  a
   ld   [hl], a
   ret
.done:
   pop  bc
   pop  hl
   ret

;;-----------------------------------------------------------------
;; Bullets_Draw: Escribe las balas en la OAM en sombra, desde el sprite SPR_SLOT_BULLETS
Bullets_Draw::
   ASSERT BULLET_SIZE == 3
   ld   hl, wBullets
   ld   de, wShadowOAM + SPR_SLOT_BULLETS * OAM_ENTRY_SIZE
   ld   b, MAX_BULLETS
.loop:
   ld   a, [hl+]
   and  a
   jr   z, .hide
   ld   [wDrawDirB], a
   ld   a, [hl+]
   ld   c, a
   ld   a, [hl+]
   add  OAM_Y_OFFSET
   ld   [de], a
   inc  de
   ld   a, c
   add  OAM_X_OFFSET
   ld   [de], a
   inc  de
   ld   a, [wDrawDirB]
   bit  7, a
   jr   z, .plain
   and  %00000111
   cp   DIR_LEFT
   jr   nc, .horizontal
   ld   a, TILE_MISSILE_V
   ld   [de], a
   inc  de
   ld   a, [wDrawDirB]
   and  %00000111
   cp   DIR_DOWN
   ld   a, OAM_YFLIP
   jr   z, .attr
   xor  a
   jr   .attr
.horizontal:
   ld   a, TILE_MISSILE_H
   ld   [de], a
   inc  de
   ld   a, [wDrawDirB]
   and  %00000111
   cp   DIR_LEFT
   ld   a, OAM_XFLIP
   jr   z, .attr
   xor  a
   jr   .attr
.plain:
   ld   a, TILE_BULLET
   ld   [de], a
   inc  de
   xor  a
.attr:
   ld   [de], a
   inc  de
   jr   .next
.hide:
   inc  hl
   inc  hl
   xor  a
   ld   [de], a
   inc  de
   ld   [de], a
   inc  de
   ld   [de], a
   inc  de
   ld   [de], a
   inc  de
.next:
   dec  b
   jr   nz, .loop
   ret
