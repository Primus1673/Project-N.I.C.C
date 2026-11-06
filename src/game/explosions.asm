;;-------------------------------------------------------------------------------------------------------------------------------;;
;; explosions.asm : Explosion al destruir una celula
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Explosions Variables", WRAM0

wExplosions: ds EXPL_SIZE * MAX_EXPLOSIONS
wExploLeft:  db

SECTION "Explosions", ROM0

;;-----------------------------------------------------------------
;; Explo_Init: Quita todas las explosiones
Explo_Init::
   ld   hl, wExplosions
   ld   bc, EXPL_SIZE * MAX_EXPLOSIONS
   xor  a
   jp   MemSet

;;-----------------------------------------------------------------
;; Explo_Spawn: Crea una explosion en un hueco libre (si lo hay)
Explo_Spawn::
   push af
   push de
   push hl
   ld   hl, wExplosions
   ld   d, MAX_EXPLOSIONS
.find:
   ld   a, [hl]
   and  a
   jr   z, .free
   inc  hl
   inc  hl
   inc  hl
   dec  d
   jr   nz, .find
   jr   .end
.free:
   ld   a, EXPL_FRAMES
   ld   [hl+], a
   ld   a, b
   ld   [hl+], a
   ld   a, c
   ld   [hl], a
.end:
   pop  hl
   pop  de
   pop  af
   ret

;;-----------------------------------------------------------------
;; Explo_Update: Un fotograma: a cada explosion le queda uno menos
Explo_Update::
   ld   hl, wExplosions
   ld   b, MAX_EXPLOSIONS
.loop:
   ld   a, [hl]
   and  a
   jr   z, .next
   dec  [hl]
.next:
   inc  hl
   inc  hl
   inc  hl
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Explo_Draw: Escribe las explosiones en la OAM en sombra
Explo_Draw::
   call Warn_Draw
   call Drops_Draw
   ld   hl, wExplosions
   ld   a, MAX_EXPLOSIONS
   ld   [wExploLeft], a
.loop:
   ld   a, [hl+]
   and  a
   jr   z, .skip
   ld   c, a
   ld   a, EXPL_FRAMES
   sub  c
   srl  a
   srl  a
   add  TILE_EXPL
   push af
   ld   a, [hl+]
   ld   b, a
   ld   a, [hl+]
   ld   c, a
   pop  af
   call Put_Sprite
   jr   .next
.skip:
   inc  hl
   inc  hl
.next:
   ld   a, [wExploLeft]
   dec  a
   ld   [wExploLeft], a
   jr   nz, .loop
.hide:
   ld   a, e
   cp   OAM_SIZE
   ret  nc
   xor  a
   ld   [de], a
   inc  de
   jr   .hide

;;-----------------------------------------------------------------
;; Warn_Draw: Dibuja la flecha del aviso de entrada
Warn_Draw:
   ld   a, [wWarnTimer]
   and  a
   ret  z
   bit  WARN_BLINK_BIT, a
   ret  z
   ld   a, [wWarnHp]
   dec  a
   add  a
   add  a
   add  a
   srl  a
   ld   l, a
   ld   a, [wWarnDir]
   ld   h, a
   ld   a, [wWarnX]
   ld   b, a
   ld   a, [wWarnY]
   ld   c, a
   ld   a, h
   cp   DIR_RIGHT
   jr   z, .fromLeft
   cp   DIR_LEFT
   jr   z, .fromRight
   ld   a, b
   add  l
   ld   b, a
   ld   c, PLAY_MIN_Y
   ld   a, h
   cp   DIR_DOWN
   jr   z, .draw
   ld   c, PLAY_MAX_Y
   jr   .draw
.fromLeft:
   ld   a, c
   add  l
   ld   c, a
   ld   b, PLAY_MIN_X
   jr   .draw
.fromRight:
   ld   a, c
   add  l
   ld   c, a
   ld   b, PLAY_MAX_X
.draw:
   ld   a, h
   dec  a
   add  TILE_WARN
   jp   Put_Sprite
