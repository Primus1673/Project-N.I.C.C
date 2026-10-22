;;-------------------------------------------------------------------------------------------------------------------------------;;
;; explosions.asm : Explosion al destruir una celula
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; Cuando una bala remata a una celula (que en ese momento es siempre de 1x1), aparece en su sitio una explosion de 1 sprite que
;; dura EXPL_FRAMES fotogramas y pasa por 3 dibujos (src/sprites/explosion.z80). Hay como mucho MAX_EXPLOSIONS a la vez; si no
;; hay hueco libre, la explosion simplemente no sale.
;; Cada explosion: [fotogramas que le quedan (0 = hueco libre), X, Y]. Se dibuja justo despues de los enemigos, en los sprites
;; que sobren (si la OAM esta llena, no se dibuja: los enemigos tienen prioridad).
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Explosions Variables", WRAM0

wExplosions: ds EXPL_SIZE * MAX_EXPLOSIONS
wExploLeft:  db           ;; Explo_Draw: explosiones que faltan por mirar

SECTION "Explosions", ROM0

;;-----------------------------------------------------------------
;; Explo_Init: Quita todas las explosiones
;;    Destruye: A, BC, HL
Explo_Init::
   ld   hl, wExplosions
   ld   bc, EXPL_SIZE * MAX_EXPLOSIONS
   xor  a
   jp   MemSet

;;-----------------------------------------------------------------
;; Explo_Spawn: Crea una explosion en un hueco libre (si lo hay)
;;    Entrada: B = X, C = Y (esquina superior izquierda del sprite)
;;    Conserva todos los registros
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
   jr   .end                 ;; Sin hueco
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
;;    Destruye: A, B, HL
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
;; Explo_Draw: Escribe las explosiones en la OAM en sombra y oculta los sprites que sobren hasta el final de la OAM
;;    Entrada: DE = siguiente sprite libre de la OAM en sombra (lo deja Enemies_Draw)
;;    Destruye: A, BC, DE, HL
Explo_Draw::
   ld   hl, wExplosions
   ld   a, MAX_EXPLOSIONS
   ld   [wExploLeft], a
.loop:
   ld   a, [hl+]             ;; Fotogramas que le quedan
   and  a
   jr   z, .skip
   ld   c, a
   ld   a, EXPL_FRAMES
   sub  c                    ;; Fotogramas que lleva (0 a EXPL_FRAMES-1)
   srl  a
   srl  a                    ;; Cada dibujo dura 4 fotogramas
   add  TILE_EXPL
   push af
   ld   a, [hl+]
   ld   b, a                 ;; B = X
   ld   a, [hl+]
   ld   c, a                 ;; C = Y
   pop  af
   call Put_Sprite           ;; (si la OAM esta llena no escribe nada)
   jr   .next
.skip:
   inc  hl
   inc  hl
.next:
   ld   a, [wExploLeft]
   dec  a
   ld   [wExploLeft], a
   jr   nz, .loop
.hide:                       ;; Oculta los sprites que no se han usado
   ld   a, e
   cp   OAM_SIZE
   ret  nc
   xor  a
   ld   [de], a
   inc  de
   jr   .hide
