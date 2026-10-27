;;-------------------------------------------------------------------------------------------------------------------------------;;
;; bullets.asm : Disparos del jugador
;;-------------------------------------------------------------------------------------------------------------------------------;;
;;   - Boton A: dispara una bala hacia ARRIBA y otra hacia ABAJO a la vez.
;;   - Boton B: dispara una bala hacia la IZQUIERDA y otra hacia la DERECHA a la vez.
;;   - Cada boton tiene su propia recarga de SHOT_COOLDOWN fotogramas (1 segundo). Si se mantiene pulsado, dispara
;;     de nuevo en cuanto termina la recarga. (Para obligar a soltar y volver a pulsar, ver la nota en Bullets_Update.)
;;   - Las balas avanzan en linea recta y desaparecen al llegar al marco de la pantalla.
;;   - Con el modo misiles activo (energy.asm), A y B disparan MISILES en vez de balas: van guardados en la misma tabla, con el
;;     bit 7 (MISSILE_FLAG) de la direccion a 1. Un misil va a MISSILE_SPEED px/fotograma hacia la celula mas cercana (Missile_Step)
;;     y mata de un golpe a cualquier celula. Su direccion (bits 0-2) es hacia donde apunta, para dibujarlo girado.
;;   - Hay un conjunto fijo de MAX_BULLETS balas. Cada una es [direccion, X, Y]; direccion 0 = hueco libre.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Bullets Variables", WRAM0

wBullets::   ds BULLET_SIZE * MAX_BULLETS    ;; Tabla de balas: [direccion, X, Y] x MAX_BULLETS
wCooldownA:: db                              ;; Fotogramas que faltan para poder disparar con A
wCooldownB:: db                              ;; Fotogramas que faltan para poder disparar con B
wShotFlag:   db                              ;; 0 (balas) o MISSILE_FLAG (modo misiles): se suma a la direccion de lo que se dispara
wShotCd:     db                              ;; Recarga de los botones en el modo actual
wDrawDirB:   db                              ;; Bullets_Draw: direccion de la bala actual
wMsX:        db                              ;; Missile_Step: centro del misil...
wMsY:        db
wBestD:      db                              ;; ... distancia a la celula mas cercana encontrada hasta ahora
wFound:      db                              ;; ... 1 si hay alguna celula a la que perseguir
wTgtX:       db                              ;; ... centro de esa celula
wTgtY:       db
wMdx:        db                              ;; ... distancia (valor absoluto) y sentido hasta ella, por cada eje
wMdy:        db
wMdirX:      db
wMdirY:      db
wClaimed:    ds MAX_ENEMIES                  ;; Por hueco de celula: 1 si algun misil de este fotograma ya la persigue
wPass:       db                              ;; 0: se saltan las celulas ya reclamadas; 1: se admiten todas
wBestIdx:    db                              ;; Hueco de la celula elegida

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
   ld   a, [wShotFlag]
   or   c
   ld   [hl+], a                ;; Direccion (con el bit 7 si es un misil)
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
   ;;-- Modo de disparo: balas normales o misiles
   ld   a, [wMissileMode]
   and  a
   jr   z, .bulletMode
   ld   a, MISSILE_FLAG
   ld   [wShotFlag], a
   ld   a, MISSILE_COOLDOWN
   ld   [wShotCd], a
   jr   .modeSet
.bulletMode:
   xor  a
   ld   [wShotFlag], a
   ld   a, SHOT_COOLDOWN
   ld   [wShotCd], a
.modeSet:

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
   ld   a, [wShotCd]
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
   ld   a, [wShotCd]
   ld   [wCooldownB], a
   ld   c, BULLET_LEFT
   call Bullets_Spawn
   ld   c, BULLET_RIGHT
   call Bullets_Spawn
.noShotB:

   ;;--------------------------------------
   ;;-- Mover todas las balas existentes. Si una saldria de la zona de juego (tocaria el marco), desaparece.
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
   ld   a, [hl]                 ;; Direccion
   and  a
   jr   z, .next                ;; Hueco libre: nada que mover
   bit  7, a
   jr   nz, .missile            ;; Es un misil
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
   jr   .next
.missile:
   call Missile_Step            ;; (conserva HL y B)
.next:
   REPT BULLET_SIZE
      inc  hl                   ;; Siguiente bala
   ENDR
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Missile_Step: Mueve un misil MISSILE_SPEED pixeles hacia la celula mas cercana. Si no hay ninguna, sigue recto y desaparece
;;    al tocar el marco. Los misiles no pueden pasarse de su objetivo: el ultimo paso es de la distancia que falta.
;;    "Mas cerca" = distancia octogonal desde el centro del misil al de la celula: mayor + menor/2.
;;    Entrada: HL = inicio del misil [direccion, X, Y]     Conserva HL y B     Destruye: A, C, DE
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
   ld   a, [hl]                 ;; Tipo
   and  a
   jr   z, .nextEnemy
   ld   a, [wPass]
   and  a
   jr   nz, .consider           ;; 2a pasada: vale cualquier celula
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
   jr   nz, .nextEnemy          ;; Otro misil ya va a por esta
.consider:
   push hl
   inc  hl
   inc  hl                      ;; HL -> X
   ld   a, [hl+]
   ld   d, a                    ;; D = X
   ld   a, [hl+]
   ld   e, a                    ;; E = Y
   ld   a, [hl]                 ;; tamaño en tiles
   add  a
   add  a                       ;; 4 * tamaño = mitad del lado
   ld   c, a
   ld   a, d
   add  c
   ld   d, a                    ;; D = centro X de la celula
   ld   a, e
   add  c
   ld   e, a                    ;; E = centro Y de la celula
   ld   a, [wMsX]
   ld   c, a
   ld   a, d
   sub  c
   jr   nc, .dxAbs
   cpl
   inc  a
.dxAbs:
   ld   c, a                    ;; C = |dx|
   ld   a, [wMsY]
   ld   h, a
   ld   a, e
   sub  h
   jr   nc, .dyAbs
   cpl
   inc  a
.dyAbs:
   ld   h, a                    ;; H = |dy|
   ld   a, c
   cp   h
   jr   c, .yFar
   ld   a, h                    ;; |dx| >= |dy|: distancia = |dx| + |dy| / 2
   srl  a
   add  c
   jr   .gotDist
.yFar:
   ld   a, c                    ;; |dy| > |dx|: distancia = |dy| + |dx| / 2
   srl  a
   add  h
.gotDist:
   ld   l, a                    ;; L = distancia a esta celula
   ld   a, [wBestD]
   cp   l
   jr   c, .notBetter           ;; la mejor hasta ahora es mas cercana
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
   jr   nz, .claim              ;; Ya se probo con todas: no hay ninguna
   inc  a
   ld   [wPass], a
   jp   .search                 ;; Todas estaban reclamadas: se repite admitiendo las reclamadas
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
   ;; --- Hacia la celula elegida: se avanza por el eje en el que esta mas lejos ---
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
   jr   c, .stepX               ;; |dy| < |dx|
   jr   nz, .stepY              ;; |dy| > |dx|
   and  a
   jp   z, .done                ;; Ya esta encima
.stepX:
   ld   a, [wMdx]
   cp   MISSILE_SPEED
   jr   c, .xs
   ld   a, MISSILE_SPEED        ;; Paso = lo que falte si es menos que la velocidad
.xs:
   ld   c, a                    ;; C = paso
   ld   a, [wMdirX]
   or   MISSILE_FLAG
   ld   [hl+], a                ;; Direccion/rumbo
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
   inc  hl                      ;; HL -> Y
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
   ;; --- Sin celulas: sigue recto (a MISSILE_SPEED) hasta el marco ---
.straight:
   ld   a, [hl]
   and  %00000111               ;; Rumbo
   cp   DIR_UP
   jr   z, .sUp
   cp   DIR_DOWN
   jr   z, .sDown
   cp   DIR_LEFT
   jr   z, .sLeft
   inc  hl                      ;; Derecha: HL -> X
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
   inc  hl                      ;; HL -> Y
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
   ld   [hl], a                 ;; Fuera de la zona: el misil desaparece
   ret
.done:
   pop  bc
   pop  hl
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
   ld   [wDrawDirB], a
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
   ld   a, [wDrawDirB]
   bit  7, a
   jr   z, .plain
   and  %00000111               ;; Misil: tile segun hacia donde apunta (arriba/abajo: vertical; izquierda/derecha: horizontal)
   cp   DIR_LEFT
   jr   nc, .horizontal
   ld   a, TILE_MISSILE_V
   ld   [de], a                 ;; Byte 2: tile
   inc  de
   ld   a, [wDrawDirB]
   and  %00000111
   cp   DIR_DOWN
   ld   a, OAM_YFLIP            ;; Hacia abajo: tile vertical invertido
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
   ld   a, OAM_XFLIP            ;; Hacia la izquierda: tile horizontal invertido
   jr   z, .attr
   xor  a
   jr   .attr
.plain:
   ld   a, TILE_BULLET
   ld   [de], a                 ;; Byte 2: tile
   inc  de
   xor  a
.attr:
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
