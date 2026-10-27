;;-------------------------------------------------------------------------------------------------------------------------------;;
;; energy.asm : Energia celular: gotas que sueltan las celulas, barra de energia y modo misiles
;;-------------------------------------------------------------------------------------------------------------------------------;;
;;   - Al morir una celula, con probabilidad DROP_PERCENT suelta una gota (Drop_Roll). La gota cae despacio hacia abajo y
;;     desaparece al llegar al marco inferior. Si el jugador la toca, la barra sube ENERGY_PER_DROP pixeles (maximo ENERGY_MAX).
;;   - Con la barra llena, SELECT activa el modo misiles (wMissileMode = 1): bullets.asm dispara misiles guiados en vez de balas.
;;     Mientras dura, la barra baja 1 pixel cada ENERGY_DRAIN_FRAMES fotogramas; al llegar a 0 el modo se desactiva.
;;     (Se pueden seguir recogiendo gotas con el modo activo: alargan el tiempo.)
;;   - La barra se dibuja en el HUD (hud.asm). Con la barra llena y sin activar, parpadea para avisar de que SELECT esta listo.
;;   - Solo avanza mientras se juega (Game_Update); la pausa y las pantallas de fase la congelan.
;;   - Cada gota: [activa (0 = hueco libre), X, Y], esquina superior izquierda del sprite.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Energy Variables", WRAM0

wEnergy::      db                  ;; Energia: 0 a ENERGY_MAX (pixeles de la barra)
wMissileMode:: db                  ;; 1 = modo misiles activo
wEnergyDrain:  db                  ;; Fotogramas que faltan para bajar 1 pixel la barra
wEnergyBlink:: db                  ;; Contador del parpadeo de "barra llena" (el bit 4 decide si se ve)
wDropTick:     db                  ;; Cuenta fotogramas para que las gotas caigan despacio
wDropLeft:     db                  ;; Drops_Draw: gotas que faltan por mirar
wDrops:        ds DROP_SIZE * MAX_DROPS

SECTION "Energy", ROM0

;;-----------------------------------------------------------------
;; Energy_Init: Barra vacia y modo misiles desactivado (al empezar una partida)
;;    Destruye: A, BC, HL
Energy_Init::
   xor  a
   ld   [wEnergy], a
   ld   [wMissileMode], a
   ld   [wEnergyDrain], a
   ld   [wEnergyBlink], a
   ld   [wDropTick], a
   ;; sigue en Drops_Init

;;-----------------------------------------------------------------
;; Drops_Init: Quita todas las gotas (al empezar cada fase)
;;    Destruye: A, BC, HL
Drops_Init::
   ld   hl, wDrops
   ld   bc, DROP_SIZE * MAX_DROPS
   xor  a
   jp   MemSet

;;-----------------------------------------------------------------
;; Energy_Add: Suma ENERGY_PER_DROP a la barra (con tope)
;;    Destruye: A
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
;; Energy_Update: Un fotograma: SELECT activa el modo misiles si la barra esta llena; con el modo activo la barra se vacia
;;    Destruye: A
Energy_Update::
   ldh  a, [hInputNew]
   bit  BTNB_SELECT, a
   jr   z, .noSelect
   ld   a, [wMissileMode]
   and  a
   jr   nz, .noSelect           ;; Ya esta activo
   ld   a, [wEnergy]
   cp   ENERGY_MAX
   jr   nz, .noSelect           ;; La barra no esta llena
   ld   a, 1
   ld   [wMissileMode], a
   ld   [wHudDirty], a
   ld   a, ENERGY_DRAIN_FRAMES
   ld   [wEnergyDrain], a
.noSelect:
   ld   a, [wMissileMode]
   and  a
   jr   z, .idle
   ld   a, [wEnergyDrain]       ;; Modo activo: la barra baja 1 pixel cada ENERGY_DRAIN_FRAMES
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
   ld   [wMissileMode], a       ;; Barra vacia: se acabaron los misiles
   ret
.idle:
   ld   a, [wEnergy]
   cp   ENERGY_MAX
   ret  nz
   ld   a, [wEnergyBlink]       ;; Barra llena sin activar: parpadea (cambia cada 16 fotogramas)
   inc  a
   ld   [wEnergyBlink], a
   and  %00001111
   ret  nz
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Drop_Spawn: Crea una gota en un hueco libre (si lo hay)
;;    Entrada: B = X, C = Y     Conserva todos los registros
Drop_Spawn:
   push af
   push de
   push hl
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
   jr   .end                    ;; Sin hueco
.free:
   ld   a, 1
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
;;    Entrada: B = X, C = Y (esquina superior izquierda de un sprite de 8x8 centrado en la celula)
;;    Conserva todos los registros
Drop_Roll::
   push af
   push bc
   push de
   push hl
   push bc
   ld   b, 100
   call Random_Range            ;; A = 0..99 (conserva C, DE y HL)
   pop  bc
   cp   DROP_PERCENT
   jr   nc, .none
   call Drop_Spawn
.none:
   pop  hl
   pop  de
   pop  bc
   pop  af
   ret

;;-----------------------------------------------------------------
;; Drops_Update: Un fotograma: las gotas caen y se recogen al tocar al jugador
;;    Destruye: A, BC, DE, HL
Drops_Update::
   ld   a, [wDropTick]
   inc  a
   cp   DROP_SLOW
   jr   c, .store
   xor  a
.store:
   ld   [wDropTick], a
   ld   c, a                    ;; C = 0 cuando toca mover las gotas
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
   inc  hl                      ;; HL -> Y
   ld   a, [hl]
   inc  a
   ld   [hl-], a
   dec  hl                      ;; HL -> activa
   cp   PLAY_MAX_Y + 1
   jr   c, .noMove
   xor  a
   ld   [hl], a                 ;; Ha llegado al marco inferior: desaparece
   jr   .next
.noMove:
   ;; --- Choque con el jugador: |dx| y |dy| <= DROP_REACH ---
   inc  hl                      ;; HL -> X
   ld   a, [wPlayerX]
   sub  [hl]
   add  DROP_REACH
   cp   2 * DROP_REACH + 1
   jr   nc, .miss
   inc  hl                      ;; HL -> Y
   ld   a, [wPlayerY]
   sub  [hl]
   add  DROP_REACH
   cp   2 * DROP_REACH + 1
   dec  hl
   jr   nc, .miss
   dec  hl                      ;; HL -> activa
   xor  a
   ld   [hl], a                 ;; Recogida
   push bc
   push hl
   call Energy_Add
   pop  hl
   pop  bc
   jr   .next
.miss:
   dec  hl                      ;; HL -> activa
.next:
   inc  hl
   inc  hl
   inc  hl
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Drops_Draw: Escribe las gotas en la OAM en sombra
;;    Entrada: DE = siguiente sprite libre     Salida: DE avanza     Destruye: A, BC, HL
Drops_Draw::
   ld   hl, wDrops
   ld   a, MAX_DROPS
   ld   [wDropLeft], a
.loop:
   ld   a, [hl+]
   and  a
   jr   z, .skip
   ld   a, [hl+]
   ld   b, a
   ld   a, [hl+]
   ld   c, a
   ld   a, TILE_DROP
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
