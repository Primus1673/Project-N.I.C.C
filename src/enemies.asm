;;-------------------------------------------------------------------------------------------------------------------------------;;
;; enemies.asm : Enemigos del juego (celulas infectadas)
;;-------------------------------------------------------------------------------------------------------------------------------;;
;;   - De momento solo existe la celula infectada de tipo 1 (ENEMY_NORMAL): ocupa 1 tile y muere de un disparo.
;;   - Aparece pegada a la cara INTERIOR del marco, por un lado elegido al azar y en una posicion al azar de ese lado.
;;   - Se mueve en linea recta hasta el lado contrario de la zona de juego, donde desaparece.
;;   - Hay un conjunto fijo de MAX_ENEMIES enemigos. Cada uno es [tipo, direccion, X, Y, vida]; tipo 0 = hueco libre.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Enemies Variables", WRAM0

wEnemies::     ds ENEMY_SIZE * MAX_ENEMIES   ;; Tabla de enemigos: [tipo, direccion, X, Y, vida] x MAX_ENEMIES
wSpawnTimer:   db                            ;; Fotogramas que faltan para la proxima aparicion
;;    Parametros de la fase actual (los carga Enemies_SetPhase desde PhaseTable)
wMaxEnemies:   db                            ;; Maximo de celulas en pantalla a la vez
wSpawnMin:     db                            ;; Entre apariciones pasan wSpawnMin + (0..wSpawnVar-1) fotogramas
wSpawnVar:     db
wMoveShift:    db                            ;; Patron de movimiento, rotado cada fotograma (ver Enemies_Move)

SECTION "Enemies", ROM0

;;-----------------------------------------------------------------
;; Enemies_Init: Elimina todos los enemigos y programa la primera aparicion
;;    Destruye: A, BC, HL
Enemies_Init::
   ld   hl, wEnemies
   ld   bc, ENEMY_SIZE * MAX_ENEMIES
   xor  a
   call MemSet
   ld   a, ENEMY_SPAWN_FIRST
   ld   [wSpawnTimer], a
   ret

;;-----------------------------------------------------------------
;; Tabla de dificultad: una fila por fase. Cada fila: [maximo de celulas a la vez, espera minima entre apariciones,
;;    variacion de la espera, patron de movimiento]. Entre apariciones pasan MIN + (0..VAR-1) fotogramas.
;;    Patron de movimiento: 8 bits, uno por fotograma; la celula avanza 1 pixel en los fotogramas con bit a 1.
;;    Velocidad = (bits a 1) / 8 pixeles por fotograma. Las balas van a 1 px/fotograma: la celula siempre es mas lenta.
MACRO PhaseRow
   ASSERT \1 <= MAX_ENEMIES
   db \1, \2, \3, \4
ENDM
DEF PHASE_ROW_SIZE EQU 4
PhaseTable:
   ;;       max  min  var  patron       (velocidad)
   PhaseRow   3, 100,  60, %00010001   ;; Fase 1: 2/8 = 15 px/s
   PhaseRow   4,  80,  50, %00100101   ;; Fase 2: 3/8 = 22 px/s
   PhaseRow   5,  60,  40, %01010101   ;; Fase 3: 4/8 = 30 px/s
   PhaseRow   6,  45,  30, %01101101   ;; Fase 4: 5/8 = 37 px/s
   PhaseRow   7,  30,  30, %11101110   ;; Fase 5: 6/8 = 45 px/s
ASSERT (@ - PhaseTable) == PHASE_ROW_SIZE * PHASE_COUNT

;;-----------------------------------------------------------------
;; Enemies_SetPhase: Carga los parametros de dificultad de una fase
;;    Entrada: A = fase (0 = la primera)
;;    Destruye: A, DE, HL
Enemies_SetPhase::
   add  a
   add  a                       ;; A * PHASE_ROW_SIZE (4)
   ld   e, a
   ld   d, 0
   ld   hl, PhaseTable
   add  hl, de
   ld   a, [hl+]
   ld   [wMaxEnemies], a
   ld   a, [hl+]
   ld   [wSpawnMin], a
   ld   a, [hl+]
   ld   [wSpawnVar], a
   ld   a, [hl]
   ld   [wMoveShift], a
   ret

;;-----------------------------------------------------------------
;; Enemies_Count: Cuenta las celulas que hay en pantalla
;;    Salida: A = numero de celulas
;;    Destruye: A, B, C, HL
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
;; Random_PlayX / Random_PlayY: Devuelven una coordenada al azar dentro de la zona de juego
;;    Salida: A = X (PLAY_MIN_X..PLAY_MAX_X) o Y (PLAY_MIN_Y..PLAY_MAX_Y)
;;    Destruye: A, B, flags (conservan HL)
Random_PlayX:
   ld   b, PLAY_RANGE_X
   call Random_Range
   add  PLAY_MIN_X
   ret

Random_PlayY:
   ld   b, PLAY_RANGE_Y
   call Random_Range
   add  PLAY_MIN_Y
   ret

;;-----------------------------------------------------------------
;; Enemies_Spawn: Crea una celula infectada en un lado y una posicion al azar, si hay algun hueco libre
;;    Lado 0: sale del izquierdo y va hacia la derecha     Lado 1: sale del derecho y va hacia la izquierda
;;    Lado 2: sale del superior y va hacia abajo           Lado 3: sale del inferior y va hacia arriba
;;    Destruye: A, B, D, HL
Enemies_Spawn:
   ld   hl, wEnemies
   ld   d, MAX_ENEMIES
.find:
   ld   a, [hl]                 ;; Tipo de este hueco
   and  a
   jr   z, .free                ;; 0 = hueco libre
   REPT ENEMY_SIZE
      inc  hl                   ;; Pasamos al siguiente enemigo
   ENDR
   dec  d
   jr   nz, .find
   ret                          ;; No quedan huecos: esta aparicion se pierde
.free:
   ld   a, ENEMY_NORMAL
   ld   [hl+], a                ;; Tipo (HL pasa a apuntar a la direccion)
   call Random_Next
   and  %00000011               ;; Lado al azar: 0 a 3
   jr   z, .fromLeft
   dec  a
   jr   z, .fromRight
   dec  a
   jr   z, .fromTop
.fromBottom:
   ld   a, DIR_UP
   ld   [hl+], a                ;; Direccion
   call Random_PlayX
   ld   [hl+], a                ;; X al azar
   ld   a, PLAY_MAX_Y
   ld   [hl+], a                ;; Y = borde inferior de la zona de juego
   jr   .setHp
.fromLeft:
   ld   a, DIR_RIGHT
   ld   [hl+], a
   ld   a, PLAY_MIN_X
   ld   [hl+], a                ;; X = borde izquierdo de la zona de juego
   call Random_PlayY
   ld   [hl+], a                ;; Y al azar
   jr   .setHp
.fromRight:
   ld   a, DIR_LEFT
   ld   [hl+], a
   ld   a, PLAY_MAX_X
   ld   [hl+], a                ;; X = borde derecho de la zona de juego
   call Random_PlayY
   ld   [hl+], a
   jr   .setHp
.fromTop:
   ld   a, DIR_DOWN
   ld   [hl+], a
   call Random_PlayX
   ld   [hl+], a
   ld   a, PLAY_MIN_Y
   ld   [hl+], a                ;; Y = borde superior de la zona de juego
.setHp:
   ld   a, ENEMY_NORMAL_HP
   ld   [hl], a                 ;; Vida
   ret

;;-----------------------------------------------------------------
;; Enemies_Move: Mueve las celulas 1 pixel en su direccion, solo en los fotogramas que toca segun el patron de la fase.
;;    Al salir de la zona de juego (llegar al lado contrario) desaparecen.
;;    Destruye: A, B, HL
Enemies_Move:
   ld   a, [wMoveShift]
   rlca                         ;; El bit 7 pasa al carry y el patron gira (se repite cada 8 fotogramas)
   ld   [wMoveShift], a
   ret  nc                      ;; En este fotograma las celulas no se mueven

   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.loop:
   ld   a, [hl]                 ;; Tipo
   and  a
   jr   z, .next                ;; Hueco libre
   push hl                      ;; Guardamos el inicio de este enemigo
   inc  hl
   ld   a, [hl+]                ;; A = direccion (HL pasa a apuntar a X)
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
   cp   PLAY_MAX_X + 1
   jr   nc, .kill               ;; Ha pasado el lado derecho
   jr   .moved
.left:
   ld   a, [hl]
   dec  a
   ld   [hl], a
   cp   PLAY_MIN_X
   jr   c, .kill                ;; Ha pasado el lado izquierdo
   jr   .moved
.down:
   inc  hl                      ;; HL -> Y
   ld   a, [hl]
   inc  a
   ld   [hl], a
   cp   PLAY_MAX_Y + 1
   jr   nc, .kill               ;; Ha pasado el lado inferior
   jr   .moved
.up:
   inc  hl                      ;; HL -> Y
   ld   a, [hl]
   dec  a
   ld   [hl], a
   cp   PLAY_MIN_Y
   jr   c, .kill                ;; Ha pasado el lado superior
.moved:
   pop  hl
   jr   .next
.kill:
   pop  hl
   xor  a
   ld   [hl], a                 ;; Tipo 0: el hueco queda libre
.next:
   REPT ENEMY_SIZE
      inc  hl                   ;; Siguiente enemigo
   ENDR
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Collide_Check: Comprueba si una bala y un enemigo chocan (distancia en X e Y menor que COLLISION_DIST)
;;    Entrada: HL = inicio del enemigo, DE = inicio de la bala
;;    Salida: Carry = 1 si chocan
;;    Destruye: A, B (conserva HL y DE)
MACRO AbsA                      ;; A = valor absoluto de la resta que acaba de hacerse (A = A - B)
   jr   nc, .abs\@
   cpl
   inc  a
.abs\@:
ENDM

Collide_Check:
   push hl
   push de
   inc  de                      ;; DE -> X de la bala
   inc  hl
   inc  hl                      ;; HL -> X del enemigo
   ld   a, [de]
   ld   b, a
   ld   a, [hl]
   sub  b
   AbsA
   cp   COLLISION_DIST
   jr   nc, .done               ;; Muy lejos en X: no chocan (el carry ya esta a 0)
   inc  de                      ;; DE -> Y de la bala
   inc  hl                      ;; HL -> Y del enemigo
   ld   a, [de]
   ld   b, a
   ld   a, [hl]
   sub  b
   AbsA
   cp   COLLISION_DIST
   jr   nc, .done               ;; Muy lejos en Y: no chocan
   scf                          ;; Chocan
.done:
   pop  de                      ;; (pop no modifica los flags)
   pop  hl
   ret

;;-----------------------------------------------------------------
;; Enemies_CheckBullets: Cada bala que toca a un enemigo desaparece y le quita 1 de vida; con 0 de vida, el enemigo muere
;;    Destruye: A, BC, DE, HL
Enemies_CheckBullets:
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.enemyLoop:
   ld   a, [hl]                 ;; Tipo
   and  a
   jr   z, .nextEnemy           ;; Hueco libre
   push bc                      ;; Guardamos el contador de enemigos
   ld   de, wBullets
   ld   c, MAX_BULLETS
.bulletLoop:
   ld   a, [de]                 ;; Direccion de la bala
   and  a
   jr   z, .nextBullet          ;; Hueco libre
   call Collide_Check
   jr   nc, .nextBullet         ;; No chocan
   ;; --- La bala ha tocado al enemigo ---
   xor  a
   ld   [de], a                 ;; La bala desaparece
   push hl
   REPT ENEMY_SIZE - 1
      inc  hl                   ;; HL -> vida del enemigo (ultimo byte)
   ENDR
   dec  [hl]                    ;; Le quitamos 1 de vida
   pop  hl                      ;; (pop no modifica los flags: sigue valiendo el resultado de dec)
   jr   nz, .nextBullet         ;; Aun le queda vida
   xor  a
   ld   [hl], a                 ;; Sin vida: el enemigo muere (tipo 0)
   ld   a, ENEMY_NORMAL_POINTS
   call Combo_Kill              ;; Cuenta la baja en el combo y suma los puntos con el multiplicador (conserva BC, DE y HL)
   jr   .enemyDone              ;; Ya no hay que comprobar mas balas contra este enemigo
.nextBullet:
   REPT BULLET_SIZE
      inc  de                   ;; Siguiente bala
   ENDR
   dec  c
   jr   nz, .bulletLoop
.enemyDone:
   pop  bc
.nextEnemy:
   REPT ENEMY_SIZE
      inc  hl                   ;; Siguiente enemigo
   ENDR
   dec  b
   jr   nz, .enemyLoop
   ret

;;-----------------------------------------------------------------
;; Enemies_CheckPlayer: Si una celula toca al jugador, la celula desaparece (sin dar puntos) y el jugador pierde una vida.
;;    No hace nada mientras el jugador es invulnerable (las celulas lo atraviesan). Como mucho una vida por fotograma.
;;    Destruye: A, B, C, D, HL
Enemies_CheckPlayer:
   ld   a, [wInvuln]
   and  a
   ret  nz                      ;; Invulnerable
   ld   hl, wEnemies
   ld   d, MAX_ENEMIES
.loop:
   ld   a, [hl]                 ;; Tipo
   and  a
   jr   z, .next                ;; Hueco libre
   push hl
   inc  hl
   inc  hl                      ;; HL -> X del enemigo
   ld   a, [wPlayerX]
   ld   b, a
   ld   a, [hl+]                ;; A = X del enemigo (HL -> Y)
   sub  b
   AbsA
   cp   COLLISION_DIST
   jr   nc, .far                ;; Lejos en X
   ld   a, [wPlayerY]
   ld   b, a
   ld   a, [hl]
   sub  b
   AbsA
   cp   COLLISION_DIST
   jr   nc, .far                ;; Lejos en Y
   pop  hl                      ;; --- Choque ---
   xor  a
   ld   [hl], a                 ;; La celula desaparece
   jp   Game_PlayerHit          ;; Pierde una vida (y vuelve de aqui con su ret)
.far:
   pop  hl
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  d
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Enemies_Update: Un fotograma de enemigos: nuevas apariciones, movimiento y choques con las balas
;;    Destruye: A, BC, DE, HL
Enemies_Update::
   ;;--------------------------------------
   ;;-- Aparicion: cuando el temporizador llega a 0 sale una celula y se programa la siguiente
   ld   a, [wSpawnTimer]
   dec  a
   ld   [wSpawnTimer], a
   jr   nz, .noSpawn
   call Enemies_Count           ;; Solo sale una celula si no se ha alcanzado el maximo de la fase
   ld   b, a
   ld   a, [wMaxEnemies]
   cp   b
   jr   c, .skipSpawn           ;; maximo < numero actual
   jr   z, .skipSpawn           ;; maximo == numero actual
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
;; Enemies_Draw: Escribe los enemigos en la OAM en sombra, desde el sprite SPR_SLOT_ENEMIES.
;;    Los huecos libres se ocultan (Y=0). El DMA lo copiara a la OAM real en el proximo VBlank.
;;    Destruye: A, B, C, DE, HL
Enemies_Draw::
   ASSERT ENEMY_SIZE == 5       ;; Esta rutina asume la estructura [tipo, direccion, X, Y, vida]
   ld   hl, wEnemies
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   ld   b, MAX_ENEMIES
.loop:
   ld   a, [hl+]                ;; Tipo (HL pasa a apuntar a la direccion)
   and  a
   jr   z, .hide
   inc  hl                      ;; Saltamos la direccion: HL -> X
   ld   a, [hl+]                ;; X
   ld   c, a
   ld   a, [hl+]                ;; Y
   add  OAM_Y_OFFSET
   ld   [de], a                 ;; Byte 0: Y
   inc  de
   ld   a, c
   add  OAM_X_OFFSET
   ld   [de], a                 ;; Byte 1: X
   inc  de
   ld   a, TILE_ENEMY1
   ld   [de], a                 ;; Byte 2: tile
   inc  de
   xor  a
   ld   [de], a                 ;; Byte 3: atributos
   inc  de
   inc  hl                      ;; Saltamos la vida: HL -> siguiente enemigo
   jr   .next
.hide:
   REPT ENEMY_SIZE - 1
      inc  hl                   ;; Saltamos el resto del hueco libre
   ENDR
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
