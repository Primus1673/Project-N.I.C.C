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
   call Warn_Draw
   call Drops_Draw
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

;;-----------------------------------------------------------------
;; Warn_Draw: Dibuja la flecha del aviso de entrada (si hay una celula avisada y toca verse): pegada al marco por dentro, en el punto por el
;;    que va a entrar y apuntando hacia dentro (sobre el fondo claro se ve mejor que sobre el marco). Se dibuja antes que las explosiones.
;;    Entrada: DE = siguiente sprite libre     Salida: DE avanza     Destruye: A, BC, HL
Warn_Draw:
   ld   a, [wWarnTimer]
   and  a
   ret  z                       ;; Ninguna avisada
   bit  WARN_BLINK_BIT, a
   ret  z                       ;; Parte oculta del parpadeo
   ld   a, [wWarnHp]
   dec  a
   add  a
   add  a
   add  a
   srl  a                       ;; 4 * (tamaño - 1): desplazamiento hasta el centro de la celula (menos medio sprite)
   ld   l, a                    ;; L = desplazamiento
   ld   a, [wWarnDir]
   ld   h, a                    ;; H = direccion de entrada
   ld   a, [wWarnX]
   ld   b, a
   ld   a, [wWarnY]
   ld   c, a
   ld   a, h
   cp   DIR_RIGHT
   jr   z, .fromLeft
   cp   DIR_LEFT
   jr   z, .fromRight
   ;; Entra por arriba o por abajo: la flecha va en X = centro de la celula
   ld   a, b
   add  l
   ld   b, a
   ld   c, PLAY_MIN_Y           ;; Borde superior de la zona de juego
   ld   a, h
   cp   DIR_DOWN
   jr   z, .draw
   ld   c, PLAY_MAX_Y           ;; Borde inferior
   jr   .draw
.fromLeft:
   ld   a, c
   add  l
   ld   c, a
   ld   b, PLAY_MIN_X           ;; Borde izquierdo
   jr   .draw
.fromRight:
   ld   a, c
   add  l
   ld   c, a
   ld   b, PLAY_MAX_X           ;; Borde derecho
.draw:
   ld   a, h
   dec  a
   add  TILE_WARN               ;; DIR_UP=1, DOWN=2, LEFT=3, RIGHT=4 -> tiles en ese orden
   jp   Put_Sprite
