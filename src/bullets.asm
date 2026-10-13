;;-------------------------------------------------------------------------------------------------------------------------------;;
;; bullets.asm : Disparos del jugador
;;-------------------------------------------------------------------------------------------------------------------------------;;
;;   - Boton A: dispara una bala hacia ARRIBA y otra hacia ABAJO a la vez.
;;   - Boton B: dispara una bala hacia la IZQUIERDA y otra hacia la DERECHA a la vez.
;;   - Cada boton tiene su propia recarga de SHOT_COOLDOWN fotogramas (1 segundo). Si se mantiene pulsado, dispara
;;     de nuevo en cuanto termina la recarga. (Para obligar a soltar y volver a pulsar, ver la nota en Bullets_Update.)
;;   - Las balas avanzan en linea recta y desaparecen al llegar al marco de la pantalla.
;;   - Hay un conjunto fijo de MAX_BULLETS balas. Cada una es [direccion, X, Y]; direccion 0 = hueco libre.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Bullets Variables", WRAM0

wBullets::   ds BULLET_SIZE * MAX_BULLETS    ;; Tabla de balas: [direccion, X, Y] x MAX_BULLETS
wCooldownA:: db                              ;; Fotogramas que faltan para poder disparar con A
wCooldownB:: db                              ;; Fotogramas que faltan para poder disparar con B

SECTION "Bullets", ROM0

;;-----------------------------------------------------------------
;; Bullets_Init: Elimina todas las balas y reinicia las recargas
;;    Destruye: A, BC, HL
Bullets_Init::
   ld   hl, wBullets
   ld   bc, BULLET_SIZE * MAX_BULLETS
   xor  a
   call MemSet
   xor  a
   ld   [wCooldownA], a
   ld   [wCooldownB], a
   ret

;;-----------------------------------------------------------------
;; Bullets_Spawn: Crea una bala en la posicion del jugador, si hay algun hueco libre
;;    Entrada: C = direccion (BULLET_UP, BULLET_DOWN, BULLET_LEFT o BULLET_RIGHT)
;;    Destruye: A, D, HL (conserva B y C)
Bullets_Spawn:
   ld   hl, wBullets
   ld   d, MAX_BULLETS
.find:
   ld   a, [hl]                 ;; Direccion de esta bala
   and  a
   jr   z, .free                ;; 0 = hueco libre
   REPT BULLET_SIZE
      inc  hl                   ;; Pasamos a la siguiente bala
   ENDR
   dec  d
   jr   nz, .find
   ret                          ;; No quedan huecos: este disparo se pierde
.free:
   ld   a, c
   ld   [hl+], a                ;; Direccion
   ld   a, [wPlayerX]
   ld   [hl+], a                ;; X inicial = la del jugador
   ld   a, [wPlayerY]
   ld   [hl], a                 ;; Y inicial = la del jugador
   ret

;;-----------------------------------------------------------------
;; Bullets_Update: Gestiona los disparos (recargas, nuevas balas) y mueve las balas existentes
;;    Destruye: A, B, C, D, HL
Bullets_Update::
   ;;--------------------------------------
   ;;-- Recargas: cada fotograma bajan en 1 hasta llegar a 0
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
   ;;-- Boton A: arriba + abajo
   ;;   Nota: se usa hInput (boton MANTENIDO). Para exigir una pulsacion nueva por disparo,
   ;;   cambiar aqui "hInput" por "hInputNew".
   ldh  a, [hInput]
   ld   b, a
   bit  BTNB_A, b
   jr   z, .noShotA
   ld   a, [wCooldownA]
   and  a
   jr   nz, .noShotA            ;; Aun recargando
   ld   a, SHOT_COOLDOWN
   ld   [wCooldownA], a
   ld   c, BULLET_UP
   call Bullets_Spawn
   ld   c, BULLET_DOWN
   call Bullets_Spawn
.noShotA:

   ;;--------------------------------------
   ;;-- Boton B: izquierda + derecha
   bit  BTNB_B, b
   jr   z, .noShotB
   ld   a, [wCooldownB]
   and  a
   jr   nz, .noShotB
   ld   a, SHOT_COOLDOWN
   ld   [wCooldownB], a
   ld   c, BULLET_LEFT
   call Bullets_Spawn
   ld   c, BULLET_RIGHT
   call Bullets_Spawn
.noShotB:

   ;;--------------------------------------
   ;;-- Mover todas las balas existentes. Si una saldria de la zona de juego (tocaria el marco), desaparece.
   ld   hl, wBullets
   ld   b, MAX_BULLETS
.loop:
   ld   a, [hl]                 ;; Direccion
   and  a
   jr   z, .next                ;; Hueco libre: nada que mover
   push hl                      ;; Guardamos el inicio de esta bala
   cp   BULLET_UP
   jr   z, .up
   cp   BULLET_DOWN
   jr   z, .down
   cp   BULLET_LEFT
   jr   z, .left
.right:
   inc  hl                      ;; HL -> X
   ld   a, [hl]
   add  BULLET_SPEED
   cp   PLAY_MAX_X + 1
   jr   nc, .kill               ;; Se pasa del limite derecho
   ld   [hl], a
   jr   .moved
.left:
   inc  hl                      ;; HL -> X
   ld   a, [hl]
   sub  BULLET_SPEED
   jr   c, .kill                ;; Habria dado la vuelta por debajo de 0
   cp   PLAY_MIN_X
   jr   c, .kill                ;; Se pasa del limite izquierdo
   ld   [hl], a
   jr   .moved
.down:
   inc  hl
   inc  hl                      ;; HL -> Y
   ld   a, [hl]
   add  BULLET_SPEED
   cp   PLAY_MAX_Y + 1
   jr   nc, .kill               ;; Se pasa del limite inferior
   ld   [hl], a
   jr   .moved
.up:
   inc  hl
   inc  hl                      ;; HL -> Y
   ld   a, [hl]
   sub  BULLET_SPEED
   jr   c, .kill                ;; Habria dado la vuelta por debajo de 0
   cp   PLAY_MIN_Y
   jr   c, .kill                ;; Se pasa del limite superior
   ld   [hl], a
.moved:
   pop  hl                      ;; Recuperamos el inicio de la bala
   jr   .next
.kill:
   pop  hl
   xor  a
   ld   [hl], a                 ;; Direccion 0: el hueco queda libre
.next:
   REPT BULLET_SIZE
      inc  hl                   ;; Siguiente bala
   ENDR
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Bullets_Draw: Escribe las balas en la OAM en sombra, desde el sprite SPR_SLOT_BULLETS.
;;    Los huecos libres se ocultan (Y=0). El DMA lo copiara a la OAM real en el proximo VBlank.
;;    Destruye: A, B, C, DE, HL
Bullets_Draw::
   ASSERT BULLET_SIZE == 3      ;; Esta rutina asume la estructura [direccion, X, Y]
   ld   hl, wBullets
   ld   de, wShadowOAM + SPR_SLOT_BULLETS * OAM_ENTRY_SIZE
   ld   b, MAX_BULLETS
.loop:
   ld   a, [hl+]                ;; Direccion (HL pasa a apuntar a X)
   and  a
   jr   z, .hide
   ld   a, [hl+]                ;; X
   ld   c, a
   ld   a, [hl+]                ;; Y (HL pasa a la siguiente bala)
   add  OAM_Y_OFFSET
   ld   [de], a                 ;; Byte 0: Y
   inc  de
   ld   a, c
   add  OAM_X_OFFSET
   ld   [de], a                 ;; Byte 1: X
   inc  de
   ld   a, TILE_BULLET
   ld   [de], a                 ;; Byte 2: tile
   inc  de
   xor  a
   ld   [de], a                 ;; Byte 3: atributos
   inc  de
   jr   .next
.hide:
   inc  hl
   inc  hl                      ;; Saltamos X e Y de la bala libre
   xor  a
   ld   [de], a                 ;; Y = 0: sprite oculto
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
