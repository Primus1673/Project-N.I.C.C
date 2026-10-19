;;-------------------------------------------------------------------------------------------------------------------------------;;
;; enemies.asm : Enemigos del juego (celulas infectadas)
;;-------------------------------------------------------------------------------------------------------------------------------;;
;;   Hay dos tipos de celula:
;;     - Normal (ENEMY_NORMAL): 1x1 tile, muere de 1 disparo, 10 puntos.
;;     - Grande (ENEMY_BIG): empieza a 3x3 tiles y necesita 3 disparos; cada impacto la encoge (3x3 -> 2x2 -> 1x1) manteniendo
;;       su centro. Se mueve mas despacio que la normal. 50 puntos. Como mucho MAX_BIG a la vez (por el limite de sprites).
;;   - Aparecen pegadas a la cara INTERIOR del marco, por un lado elegido al azar y en una posicion al azar de ese lado.
;;   - Se mueven en linea recta hasta el lado contrario de la zona de juego, donde desaparecen.
;;   - Hay un conjunto fijo de MAX_ENEMIES enemigos. Cada uno es [tipo, direccion, X, Y, vida]; tipo 0 = hueco libre.
;;     X, Y = esquina superior izquierda de la celula. Su TAMAÑO en tiles es igual a su vida (3, 2 o 1): para la normal es siempre 1.
;;   - La dificultad (maximo en pantalla, ritmo de aparicion, velocidades, probabilidad de celula grande) depende de la fase:
;;     ver PhaseTable.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Enemies Variables", WRAM0

wEnemies::     ds ENEMY_SIZE * MAX_ENEMIES   ;; Tabla de enemigos: [tipo, direccion, X, Y, vida] x MAX_ENEMIES
wSpawnTimer:   db                            ;; Fotogramas que faltan para la proxima aparicion
;;    Parametros de la fase actual (los carga Enemies_SetPhase desde PhaseTable)
wMaxEnemies:   db                            ;; Maximo de celulas en pantalla a la vez
wSpawnMin:     db                            ;; Entre apariciones pasan wSpawnMin + (0..wSpawnVar-1) fotogramas
wSpawnVar:     db
wMoveShift:    db                            ;; Patron de movimiento de la celula normal, rotado cada fotograma (ver Enemies_Move)
wBigPercent:   db                            ;; Probabilidad (0-100) de que una aparicion sea una celula grande
wMoveShiftBig: db                            ;; Patron de movimiento de la celula grande
;;    Variables de trabajo
wMoveNow:      db                            ;; Bit 1: las celulas normales se mueven en este fotograma; bit 0: las grandes
wSpawnType:    db                            ;; Tipo de la celula que se esta creando
wSpawnOff:     db                            ;; 0 (normal) o BIG_OFFSET (grande): lo que se estrecha su zona de aparicion
wDrawRows:     db                            ;; Enemies_Draw: filas de sprites que faltan en la celula actual
wDrawN:        db                            ;; ... tamaño en tiles de la celula actual
wDrawTile:     db                            ;; ... tile del siguiente sprite
wDrawX0:       db                            ;; ... X de la primera columna

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
;; Tabla de dificultad: una fila por fase. Cada fila:
;;    [maximo de celulas a la vez, espera minima entre apariciones, variacion de la espera, patron de movimiento de la celula
;;     normal, % de apariciones que son celula grande, patron de movimiento de la celula grande]
;;    Entre apariciones pasan MIN + (0..VAR-1) fotogramas.
;;    Patron de movimiento: 8 bits, uno por fotograma; la celula avanza 1 pixel en los fotogramas con bit a 1.
;;    Velocidad = (bits a 1) / 8 pixeles por fotograma. Las balas van a 1 px/fotograma: las celulas siempre son mas lentas.
MACRO PhaseRow
   ASSERT \1 <= MAX_ENEMIES
   ASSERT \5 <= 100
   db \1, \2, \3, \4, \5, \6
ENDM
DEF PHASE_ROW_SIZE EQU 6
PhaseTable:
   ;;       max  min  var  normal         %grande  grande
   PhaseRow   3, 100,  60, %00010001,       0, %00010000   ;; Fase 1: normal 2/8 = 15 px/s   (sin grandes)
   PhaseRow   4,  80,  50, %00100101,      20, %00010000   ;; Fase 2: normal 3/8 = 22 px/s   grande 1/8 =  7 px/s
   PhaseRow   5,  60,  40, %01010101,      25, %00010001   ;; Fase 3: normal 4/8 = 30 px/s   grande 2/8 = 15 px/s
   PhaseRow   6,  45,  30, %01101101,      30, %00010001   ;; Fase 4: normal 5/8 = 37 px/s   grande 2/8 = 15 px/s
   PhaseRow   7,  30,  30, %11101110,      35, %00100101   ;; Fase 5: normal 6/8 = 45 px/s   grande 3/8 = 22 px/s
ASSERT (@ - PhaseTable) == PHASE_ROW_SIZE * PHASE_COUNT

;;-----------------------------------------------------------------
;; Enemies_SetPhase: Carga los parametros de dificultad de una fase
;;    Entrada: A = fase (0 = la primera)
;;    Destruye: A, DE, HL
Enemies_SetPhase::
   ld   e, a
   add  a                       ;; 2n
   add  e                       ;; 3n
   add  a                       ;; 6n = n * PHASE_ROW_SIZE
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
   ld   a, [hl+]
   ld   [wMoveShift], a
   ld   a, [hl+]
   ld   [wBigPercent], a
   ld   a, [hl]
   ld   [wMoveShiftBig], a
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
;; Enemies_CountType: Cuenta las celulas de un tipo
;;    Entrada: B = tipo
;;    Salida: A = numero de celulas de ese tipo
;;    Destruye: A, C, D, HL
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
;; Random_PlayX / Random_PlayY: Devuelven una coordenada al azar dentro de la zona de juego. La zona se estrecha wSpawnOff
;;    pixeles (0 para la celula normal, BIG_OFFSET para la grande) para que la celula entera quede dentro del marco.
;;    Salida: A = X (PLAY_MIN_X..PLAY_MAX_X-wSpawnOff) o Y (PLAY_MIN_Y..PLAY_MAX_Y-wSpawnOff)
;;    Destruye: A, B, flags (conservan HL)
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
;; Enemies_ChooseType: Decide si la proxima celula es normal o grande (segun el % de la fase y el maximo de grandes)
;;    Salida: A = tipo; wSpawnOff queda en 0 o BIG_OFFSET
;;    Destruye: A, B, C, D, HL
Enemies_ChooseType:
   ld   a, [wBigPercent]
   and  a
   jr   z, .normal              ;; Esta fase no tiene celulas grandes
   ld   b, ENEMY_BIG
   call Enemies_CountType
   cp   MAX_BIG
   jr   nc, .normal             ;; Ya hay el maximo de grandes
   ld   b, 100
   call Random_Range            ;; A = 0..99
   ld   b, a
   ld   a, [wBigPercent]
   cp   b
   jr   z, .normal              ;; porcentaje == tirada
   jr   c, .normal              ;; porcentaje < tirada
   ld   a, BIG_OFFSET           ;; tirada < porcentaje: grande
   ld   [wSpawnOff], a
   ld   a, ENEMY_BIG
   ret
.normal:
   xor  a
   ld   [wSpawnOff], a
   ld   a, ENEMY_NORMAL
   ret

;;-----------------------------------------------------------------
;; Enemies_Spawn: Crea una celula (normal o grande) en un lado y una posicion al azar, si hay algun hueco libre
;;    Lado 0: sale del izquierdo y va hacia la derecha     Lado 1: sale del derecho y va hacia la izquierda
;;    Lado 2: sale del superior y va hacia abajo           Lado 3: sale del inferior y va hacia arriba
;;    La celula grande (24x24) nace con toda su superficie dentro del marco: por eso las posiciones se estrechan BIG_OFFSET.
;;    Destruye: A, B, C, D, HL
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
   push hl
   call Enemies_ChooseType
   ld   [wSpawnType], a
   pop  hl
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
   ld   a, [wSpawnOff]
   ld   b, a
   ld   a, PLAY_MAX_Y
   sub  b
   ld   [hl+], a                ;; Y = borde inferior de la zona de juego (menos lo que mide la celula)
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
   ld   a, [wSpawnOff]
   ld   b, a
   ld   a, PLAY_MAX_X
   sub  b
   ld   [hl+], a                ;; X = borde derecho de la zona de juego (menos lo que mide la celula)
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
   ld   a, [wSpawnType]
   cp   ENEMY_BIG
   ld   a, ENEMY_NORMAL_HP      ;; (ld no toca los flags)
   jr   nz, .storeHp
   ld   a, ENEMY_BIG_HP
.storeHp:
   ld   [hl], a                 ;; Vida (= tamaño en tiles)
   ret

;;-----------------------------------------------------------------
;; Enemies_Move: Mueve las celulas 1 pixel en su direccion, solo en los fotogramas que tocan segun el patron de su tipo.
;;    Al salir de la zona de juego (llegar al lado contrario con TODA la celula) desaparecen:
;;    hacia la derecha/abajo, cuando su borde de delante toca el marco; hacia la izquierda/arriba, cuando X/Y < minimo.
;;    Destruye: A, BC, DE, HL
Enemies_Move:
   ld   a, [wMoveShift]
   rlca                         ;; El bit 7 pasa al carry y el patron gira (se repite cada 8 fotogramas)
   ld   [wMoveShift], a
   ld   a, 0
   rla                          ;; A = 1 si la celula normal se mueve ahora
   ld   b, a
   ld   a, [wMoveShiftBig]
   rlca
   ld   [wMoveShiftBig], a
   ld   a, b
   rla                          ;; A = (normal << 1) | grande
   ld   [wMoveNow], a
   and  a
   ret  z                       ;; Ninguna se mueve en este fotograma

   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.loop:
   ld   a, [hl]                 ;; Tipo
   and  a
   jp   z, .next                ;; Hueco libre
   cp   ENEMY_NORMAL
   ld   a, [wMoveNow]           ;; (ld no toca los flags: sigue valiendo la comparacion)
   jr   z, .isNormal
   and  %00000001               ;; Grande
   jp   z, .next
   jr   .move
.isNormal:
   and  %00000010
   jp   z, .next
.move:
   push hl                      ;; Guardamos el inicio de este enemigo
   inc  hl
   ld   a, [hl+]                ;; A = direccion (HL pasa a apuntar a X)
   ld   d, a
   inc  hl
   inc  hl                      ;; HL -> vida (= tamaño)
   ld   a, [hl]
   dec  hl
   dec  hl                      ;; HL -> X
   dec  a
   add  a
   add  a
   add  a
   ld   e, a                    ;; E = 8 * (tamaño - 1): cuanto antes llega al marco una celula mas grande
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
   ld   e, a                    ;; Primer X en el que la celula ya pasaria del lado derecho
   ld   a, d
   cp   e
   jr   nc, .kill
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
   ld   d, a
   ld   a, PLAY_MAX_Y + 1
   sub  e
   ld   e, a
   ld   a, d
   cp   e
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
   jp   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Collide_Box: Comprueba si un sprite de 8x8 choca con una celula (de 8, 16 o 24 pixeles segun su vida)
;;    Entrada: HL = inicio de la celula, DE = direccion de la X del sprite (su Y va justo detras)
;;    Salida: Carry = 1 si chocan
;;    Conserva HL, DE y BC. Ver COLLIDE_BIAS / COLLIDE_EXTRA en constants.inc.
Collide_Box:
   push hl
   push de
   push bc
   ld   a, [de]
   ld   b, a                    ;; B = X del sprite
   inc  de
   ld   a, [de]
   ld   c, a                    ;; C = Y del sprite
   push hl
   ld   de, ENEMY_SIZE - 1
   add  hl, de
   ld   a, [hl]                 ;; A = vida = tamaño en tiles
   pop  hl
   add  a
   add  a
   add  a                       ;; 8 * tamaño = lado de la celula en pixeles
   add  COLLIDE_EXTRA
   ld   d, a                    ;; D = rango de choque
   inc  hl
   inc  hl                      ;; HL -> X de la celula
   ld   a, b
   sub  [hl]
   add  COLLIDE_BIAS            ;; (x - ex + BIAS), sin signo: los valores negativos dan numeros altos y no chocan
   cp   d
   jr   nc, .done               ;; Fuera en X (el carry ya esta a 0)
   inc  hl                      ;; HL -> Y de la celula
   ld   a, c
   sub  [hl]
   add  COLLIDE_BIAS
   cp   d
   jr   nc, .done               ;; Fuera en Y
   scf                          ;; Chocan
.done:
   pop  bc                      ;; (pop no modifica los flags)
   pop  de
   pop  hl
   ret

;;-----------------------------------------------------------------
;; Enemies_CheckBullets: Cada bala que toca a una celula desaparece y le quita 1 de vida.
;;    Con vida 0 la celula muere y da puntos (con el multiplicador del combo). Si sobrevive, se encoge: su esquina se
;;    desplaza TILE_SIZE/2 en X e Y, con lo que mantiene el centro (3x3 -> 2x2 -> 1x1).
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
   inc  de                      ;; DE -> X de la bala
   call Collide_Box
   dec  de                      ;; (dec de no toca los flags)
   jr   nc, .nextBullet         ;; No chocan
   ;; --- La bala ha tocado a la celula ---
   xor  a
   ld   [de], a                 ;; La bala desaparece
   push hl
   REPT ENEMY_SIZE - 1
      inc  hl                   ;; HL -> vida de la celula (ultimo byte)
   ENDR
   dec  [hl]                    ;; Le quitamos 1 de vida
   pop  hl                      ;; (pop no modifica los flags: sigue valiendo el resultado de dec)
   jr   nz, .survived           ;; Aun le queda vida
   ;; --- Muere ---
   ld   a, [hl]                 ;; Tipo, para saber los puntos
   cp   ENEMY_BIG
   ld   a, ENEMY_NORMAL_POINTS
   jr   nz, .points
   ld   a, ENEMY_BIG_POINTS
.points:
   push af
   xor  a
   ld   [hl], a                 ;; Tipo 0: el hueco queda libre
   pop  af
   call Combo_Kill              ;; Cuenta la baja en el combo y suma los puntos con el multiplicador (conserva BC, DE y HL)
   jr   .enemyDone              ;; Ya no hay que comprobar mas balas contra esta celula
.survived:                      ;; Se encoge, conservando el centro
   inc  hl
   inc  hl                      ;; HL -> X
   ld   a, [hl]
   add  TILE_SIZE / 2
   ld   [hl+], a
   ld   a, [hl]
   add  TILE_SIZE / 2
   ld   [hl], a
   dec  hl
   dec  hl
   dec  hl                      ;; HL -> inicio de la celula
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
;;    Necesita que wPlayerY este justo detras de wPlayerX en memoria (player.asm).
;;    Destruye: A, B, DE, HL
Enemies_CheckPlayer:
   ld   a, [wInvuln]
   and  a
   ret  nz                      ;; Invulnerable
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.loop:
   ld   a, [hl]                 ;; Tipo
   and  a
   jr   z, .next                ;; Hueco libre
   ld   de, wPlayerX
   call Collide_Box
   jr   nc, .next
   xor  a
   ld   [hl], a                 ;; La celula desaparece
   jp   Game_PlayerHit          ;; Pierde una vida (y vuelve de aqui con su ret)
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Enemies_Update: Un fotograma de enemigos: nuevas apariciones, movimiento y choques con las balas y el jugador
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
;; Put_Sprite: Escribe 1 sprite (paleta OBP0) en la OAM en sombra
;;    Entrada: A = tile, B = X, C = Y (esquina superior izquierda en pantalla), DE = destino en la OAM en sombra
;;    Salida: DE avanza al siguiente sprite. Si la OAM ya esta llena no escribe nada (la OAM en sombra ocupa OAM_SIZE bytes).
;;    Destruye: A
ASSERT OAM_SIZE < 256
Put_Sprite:
   push af
   ld   a, e
   cp   OAM_SIZE                ;; wShadowOAM esta alineada a 256: el byte bajo de DE es el desplazamiento dentro de la OAM
   jr   nc, .full
   ld   a, c
   add  OAM_Y_OFFSET
   ld   [de], a                 ;; Byte 0: Y
   inc  de
   ld   a, b
   add  OAM_X_OFFSET
   ld   [de], a                 ;; Byte 1: X
   inc  de
   pop  af
   ld   [de], a                 ;; Byte 2: tile
   inc  de
   xor  a
   ld   [de], a                 ;; Byte 3: atributos
   inc  de
   ret
.full:
   pop  af
   ret

;;-----------------------------------------------------------------
;; Enemy_DrawSprites: Escribe los sprites de una celula: una cuadricula de N x N (N = su vida = su tamaño en tiles)
;;    con los tiles TILE_ENEMY1 (N=1), TILE_BIG2 (N=2, 4 tiles) o TILE_BIG3 (N=3, 9 tiles), por filas.
;;    Entrada: HL = inicio de la celula, DE = destino en la OAM en sombra (avanza)
;;    Destruye: A, BC, HL
Enemy_DrawSprites:
   inc  hl
   inc  hl                      ;; HL -> X
   ld   a, [hl+]
   ld   b, a                    ;; B = X
   ld   a, [hl+]
   ld   c, a                    ;; C = Y
   ld   a, [hl]                 ;; A = N
   ld   [wDrawRows], a
   ld   [wDrawN], a
   cp   2
   ld   a, TILE_ENEMY1
   jr   c, .tile                ;; N = 1
   ld   a, TILE_BIG2
   jr   z, .tile                ;; N = 2
   ld   a, TILE_BIG3            ;; N = 3
.tile:
   ld   [wDrawTile], a
   ld   a, b
   ld   [wDrawX0], a
.row:
   ld   a, [wDrawN]
   ld   h, a                    ;; H = columnas que faltan en esta fila
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
   ld   c, a                    ;; Siguiente fila
   ld   a, [wDrawRows]
   dec  a
   ld   [wDrawRows], a
   jr   nz, .row
   ret

;;-----------------------------------------------------------------
;; Enemies_Draw: Escribe los enemigos en la OAM en sombra, a partir del sprite SPR_SLOT_ENEMIES, usando solo los sprites que
;;    hacen falta (1, 4 o 9 por celula). Los sprites que sobran hasta el final de la OAM se ocultan (Y=0).
;;    El DMA lo copiara a la OAM real en el proximo VBlank.
;;    Destruye: A, BC, DE, HL
Enemies_Draw::
   ASSERT ENEMY_SIZE == 5       ;; Esta rutina asume la estructura [tipo, direccion, X, Y, vida]
   ld   hl, wEnemies
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   ld   b, MAX_ENEMIES
.enemy:
   ld   a, [hl]                 ;; Tipo
   and  a
   jr   z, .skip                ;; Hueco libre
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
.hideRest:                      ;; Oculta los sprites que no se han usado, hasta el final de la OAM
   ld   a, e
   cp   OAM_SIZE
   ret  nc
   xor  a
   ld   [de], a
   inc  de
   jr   .hideRest
