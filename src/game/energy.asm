;;-------------------------------------------------------------------------------------------------------------------------------;;
;; energy.asm : Energia celular: gotas que sueltan las celulas, barra de energia y modo misiles
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Energy Variables", WRAM0

wEnergy::      db
wShield:: db
wEnergyDrain:  db
wEnergyBlink:: db
wDropTick:     db
wDropLeft:     db
wDrops:        ds DROP_SIZE * MAX_DROPS

SECTION "Energy", ROM0

;;-----------------------------------------------------------------
;; Energy_Init: Barra vacia y modo misiles desactivado (al empezar una partida)
Energy_Init::
   xor  a
   ld   [wEnergy], a
   ld   [wShield], a
   ld   [wEnergyDrain], a
   ld   [wEnergyBlink], a
   ld   [wDropTick], a
   ;; sigue en Drops_Init

;;-----------------------------------------------------------------
;; Drops_Init: Quita todas las gotas (al empezar cada fase)
Drops_Init::
   ld   hl, wDrops
   ld   bc, DROP_SIZE * MAX_DROPS
   xor  a
   jp   MemSet

;;-----------------------------------------------------------------
;; Energy_Add: Suma ENERGY_PER_DROP a la barra (con tope)
Energy_Add:
   ld   a, [wEnergy]
   add  ENERGY_PER_DROP
   cp   ENERGY_MAX + 1
   jr   c, .store
   ld   a, ENERGY_MAX
.store:
   ld   [wEnergy], a
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Energy_Update: Un fotograma: SELECT activa el modo misiles si la barra esta llena
Energy_Update::
   ldh  a, [hInputNew]
   bit  BTNB_SELECT, a
   jr   z, .noSelect
   ld   a, [wShield]
   and  a
   jr   nz, .noSelect
   ld   a, [wEnergy]
   cp   ENERGY_MAX
   jr   nz, .noSelect
   ld   a, 1
   ld   [wShield], a
   ld   [wHudDirty], a
   ld   a, ENERGY_DRAIN_FRAMES
   ld   [wEnergyDrain], a
.noSelect:
   ld   a, [wShield]
   and  a
   jr   z, .idle
   ld   a, [wEnergy]
   and  a
   jr   nz, .shieldOn
   xor  a
   ld   [wShield], a
   inc  a
   ld   [wHudDirty], a
   ret
.shieldOn:
   ld   hl, wEnergyBlink
   inc  [hl]
   ld   a, [wEnergyDrain]
   dec  a
   ld   [wEnergyDrain], a
   ret  nz
   ld   a, ENERGY_DRAIN_FRAMES
   ld   [wEnergyDrain], a
   ld   a, 1
   ld   [wHudDirty], a
   ld   a, [wEnergy]
   dec  a
   ld   [wEnergy], a
   ret  nz
   xor  a
   ld   [wShield], a
   ret
.idle:
   ld   a, [wEnergy]
   cp   ENERGY_MAX
   ret  nz
   ld   a, [wEnergyBlink]
   inc  a
   ld   [wEnergyBlink], a
   and  %00001111
   ret  nz
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Shield_Draw: Dibuja el anillo del escudo alrededor de la nave (4 sprites de 8x8, centrado en ella)
Shield_Draw::
   ld   a, [wShield]
   and  a
   ret  z
   ld   a, [wEnergy]
   cp   SHIELD_WARN_PX + 1
   jr   nc, .visible
   ld   a, [wEnergyBlink]
   bit  2, a
   ret  z
.visible:
   ld   a, [wPlayerX]
   sub  TILE_SIZE / 2
   ld   b, a
   ld   a, [wPlayerY]
   sub  TILE_SIZE / 2
   ld   c, a
   ld   a, TILE_SHIELD
   call Put_Sprite
   ld   a, b
   add  TILE_SIZE
   ld   b, a
   ld   a, TILE_SHIELD + 1
   call Put_Sprite
   ld   a, c
   add  TILE_SIZE
   ld   c, a
   ld   a, TILE_SHIELD + 3
   call Put_Sprite
   ld   a, b
   sub  TILE_SIZE
   ld   b, a
   ld   a, TILE_SHIELD + 2
   jp   Put_Sprite

;;-----------------------------------------------------------------
;; Life_Add: Recoge una bateria de vida: +1 vida (como mucho PLAYER_LIVES)
Life_Add:
   ld   a, [wLives]
   cp   PLAYER_LIVES
   ret  nc
   inc  a
   ld   [wLives], a
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Drop_Spawn: Crea una gota en un hueco libre (si lo hay)
Drop_Spawn:
   push af
   push de
   push hl
   ld   e, a
   ld   hl, wDrops
   ld   d, MAX_DROPS
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
   ld   a, e
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
;; Drop_Roll: Tira los dados: con probabilidad DROP_PERCENT crea una gota donde ha muerto una celula
Drop_Roll::
   push af
   push bc
   push de
   push hl
   push bc
   ld   b, 100
   call Random_Range
   pop  bc
   cp   DROP_PERCENT
   jr   nc, .noEnergy
   ld   a, DROP_ENERGY
   call Drop_Spawn
   jr   .none
.noEnergy:
   cp   DROP_PERCENT + HEART_PERCENT
   jr   nc, .none
   ld   a, [wLives]
   cp   PLAYER_LIVES
   jr   nc, .none
   ld   a, DROP_HEART
   call Drop_Spawn
.none:
   pop  hl
   pop  de
   pop  bc
   pop  af
   ret

;;-----------------------------------------------------------------
;; Drops_Update: Un fotograma: las gotas caen y se recogen al tocar al jugador
Drops_Update::
   ld   a, [wDropTick]
   inc  a
   cp   DROP_SLOW
   jr   c, .store
   xor  a
.store:
   ld   [wDropTick], a
   ld   c, a
   ld   hl, wDrops
   ld   b, MAX_DROPS
.loop:
   ld   a, [hl]
   and  a
   jr   z, .next
   ld   a, c
   and  a
   jr   nz, .noMove
   inc  hl
   inc  hl
   ld   a, [hl]
   inc  a
   ld   [hl-], a
   dec  hl
   cp   PLAY_MAX_Y + 1
   jr   c, .noMove
   xor  a
   ld   [hl], a
   jr   .next
.noMove:
   inc  hl
   ld   a, [wPlayerX]
   sub  [hl]
   add  DROP_REACH
   cp   2 * DROP_REACH + 1
   jr   nc, .miss
   inc  hl
   ld   a, [wPlayerY]
   sub  [hl]
   add  DROP_REACH
   cp   2 * DROP_REACH + 1
   dec  hl
   jr   nc, .miss
   dec  hl
   ld   a, [hl]
   ld   d, a
   xor  a
   ld   [hl], a
   push bc
   push hl
   ld   a, d
   cp   DROP_HEART
   jr   z, .getHeart
   call Energy_Add
   jr   .collected
.getHeart:
   call Life_Add
.collected:
   pop  hl
   pop  bc
   jr   .next
.miss:
   dec  hl
.next:
   inc  hl
   inc  hl
   inc  hl
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Drops_Draw: Escribe las gotas en la OAM en sombra
Drops_Draw::
   ld   hl, wDrops
   ld   a, MAX_DROPS
   ld   [wDropLeft], a
.loop:
   ld   a, [hl+]
   and  a
   jr   z, .skip
   push af
   ld   a, [hl+]
   ld   b, a
   ld   a, [hl+]
   ld   c, a
   pop  af
   cp   DROP_HEART
   ld   a, TILE_DROP
   jr   nz, .putDrop
   ld   a, TILE_HEART_DROP
.putDrop:
   push hl
   call Put_Sprite
   pop  hl
   jr   .next
.skip:
   inc  hl
   inc  hl
.next:
   ld   a, [wDropLeft]
   dec  a
   ld   [wDropLeft], a
   jr   nz, .loop
   ret
