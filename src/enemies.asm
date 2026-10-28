;;-------------------------------------------------------------------------------------------------------------------------------;;
;; enemies.asm : Enemigos del juego (celulas infectadas)
;;-------------------------------------------------------------------------------------------------------------------------------;;
;;   Hay tres tipos de celula:
;;     - Normal (ENEMY_NORMAL): 1x1 tile, muere de 1 disparo, 10 puntos.
;;     - Grande (ENEMY_BIG): empieza a 3x3 tiles y necesita 3 disparos; cada impacto la encoge (3x3 -> 2x2 -> 1x1) manteniendo
;;       su centro. Se mueve mas despacio que la normal. 50 puntos. Como mucho MAX_BIG a la vez (por el limite de sprites).
;;     - Agresiva (ENEMY_AGGR): empieza a 2x2 y necesita 2 disparos (el primero la encoge a 1x1, con dibujo propio). No va en
;;       linea recta: persigue al jugador en tiempo real (fila y columna) hasta chocar con el o ser destruida. Va a el AGGR_SPEED_PCT % de la
;;       velocidad de la celula normal de la fase. 30 puntos. Como mucho MAX_AGGR a la vez.
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
wAggrPercent:  db                            ;; Probabilidad (0-100) de que una aparicion sea una celula agresiva
wSpawnRoll:    db                            ;; Tirada (0-99) con la que se elige el tipo de la proxima celula
wAggrAcc:      db                            ;; Acumulador (0-99) que reparte los pasos de la agresiva: se mueve el AGGR_SPEED_PCT % de los pasos de la normal
wChDX:         db                            ;; Persecucion: distancia en X hasta el jugador (valor absoluto)
wChDY:         db                            ;; ... distancia en Y
wChDirX:       db                            ;; ... DIR_LEFT o DIR_RIGHT
wChDirY:       db                            ;; ... DIR_UP o DIR_DOWN
wWarnTimer::   db                            ;; Fotogramas que faltan para que entre la celula avisada (0 = no hay ninguna avisada)
wWarnType:     db                            ;; La celula avisada, ya preparada: [tipo, direccion, X, Y, vida] (como en wEnemies)
wWarnDir:      db
wWarnX:        db
wWarnY:        db
wWarnHp:       db
wHitMissile:  db                            ;; Enemies_CheckBullets: $80 si el impacto es de un misil
wHitSize:      db                            ;; ... tamaño en tiles de la celula antes del impacto
wDrawType:     db                            ;; Enemies_Draw: tipo de la celula actual
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
   xor  a
   ld   [wWarnTimer], a         ;; Sin celula avisada
   ret

;;-----------------------------------------------------------------
;; Tabla de dificultad: una fila por fase. Cada fila:
;;    [maximo de celulas a la vez, espera minima entre apariciones, variacion de la espera, patron de movimiento de la celula
;;     normal, % de apariciones que son celula grande, patron de movimiento de la celula grande, % que son celula agresiva]
;;    El resto de apariciones son celulas normales.
;;    Entre apariciones pasan MIN + (0..VAR-1) fotogramas.
;;    Patron de movimiento: 8 bits, uno por fotograma; la celula avanza 1 pixel en los fotogramas con bit a 1.
;;    Velocidad = (bits a 1) / 8 pixeles por fotograma. Las balas van a 1 px/fotograma: las celulas siempre son mas lentas.
MACRO PhaseRow
   ASSERT \1 <= MAX_ENEMIES
   ASSERT \5 + \7 <= 100
   db \1, \2, \3, \4, \5, \6, \7
ENDM
DEF PHASE_ROW_SIZE EQU 7
PhaseTable:
   ;;       max  min  var  normal         %grande  grande      %agresiva
   PhaseRow   3, 100,  60, %00010001,       0, %00010000,   0   ;; Fase 1: normal 2/8 = 15 px/s   (sin grandes ni agresivas)
   PhaseRow   4,  80,  50, %00100101,      20, %00010000,   0   ;; Fase 2: normal 3/8 = 22 px/s   grande 1/8 =  7 px/s
   PhaseRow   5,  60,  40, %01010101,      25, %00010001,  15   ;; Fase 3: normal 4/8 = 30 px/s   grande 2/8 = 15 px/s
   PhaseRow   6,  45,  30, %01101101,      30, %00010001,  20   ;; Fase 4: normal 5/8 = 37 px/s   grande 2/8 = 15 px/s
   PhaseRow   7,  30,  30, %11101110,      35, %00100101,  25   ;; Fase 5: normal 6/8 = 45 px/s   grande 3/8 = 22 px/s
ASSERT (@ - PhaseTable) == PHASE_ROW_SIZE * PHASE_COUNT

;;-----------------------------------------------------------------
;; Enemies_SetPhase: Carga los parametros de dificultad de una fase
;;    Entrada: A = fase (0 = la primera)
;;    Destruye: A, DE, HL
Enemies_SetPhase::
   ld   e, a
   ld   d, 0
   add  a
   add  a
   add  a                       ;; 8n
   sub  e                       ;; 7n = n * PHASE_ROW_SIZE (la fase maxima es 4: cabe en 8 bits)
   ld   e, a
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
   ld   a, [hl+]
   ld   [wMoveShiftBig], a
   ld   a, [hl]
   ld   [wAggrPercent], a
   ret

;;-----------------------------------------------------------------
;; Enemies_Wipe: Cambio de fase: todas las celulas explotan a la vez (sin puntos ni gotas) y desaparecen, se cancela el aviso
;;    de entrada pendiente y la proxima aparicion se programa como al empezar una fase
;;    Destruye: A, BC, DE, HL
Enemies_Wipe::
   ld   hl, wEnemies
   ld   d, MAX_ENEMIES
.loop:
   ld   a, [hl]                 ;; Tipo
   and  a
   jr   z, .next
   push hl
   xor  a
   ld   [hl], a                 ;; El hueco queda libre
   inc  hl
   inc  hl                      ;; HL -> X
   ld   a, [hl+]
   ld   b, a                    ;; B = X
   ld   a, [hl+]
   ld   c, a                    ;; C = Y
   ld   a, [hl]                 ;; tamaño en tiles
   dec  a
   add  a
   add  a                       ;; 4 * (tamaño - 1): hasta el centro de la celula
   ld   e, a
   ld   a, b
   add  e
   ld   b, a
   ld   a, c
   add  e
   ld   c, a
   call Explo_Spawn
   pop  hl
.next:
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  d
   jr   nz, .loop
   xor  a
   ld   [wWarnTimer], a         ;; Sin celula avisada
   ld   a, ENEMY_SPAWN_FIRST
   ld   [wSpawnTimer], a
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
;; Enemies_ChooseType: Decide el tipo de la proxima celula con una tirada 0..99: [0, %grande) grande, despues [%agresiva)
;;    agresiva, y el resto normal. Si ya hay el maximo de ese tipo, sale una normal.
;;    Salida: A = tipo; wSpawnOff queda en 0, BIG_OFFSET o AGGR_OFFSET
;;    Destruye: A, B, C, D, HL
Enemies_ChooseType:
   ld   a, [wWarnTimer]
   and  a
   jr   nz, .normal             ;; Ya hay una celula grande/agresiva avisada: esta sale normal
   ld   b, 100
   call Random_Range            ;; A = 0..99
   ld   [wSpawnRoll], a
   ld   b, a
   ld   a, [wBigPercent]
   cp   b
   jr   z, .notBig              ;; porcentaje == tirada
   jr   c, .notBig              ;; porcentaje < tirada
   ld   b, ENEMY_BIG            ;; tirada < porcentaje: grande, si hay sitio
   call Enemies_CountType
   cp   MAX_BIG
   jr   nc, .normal
   ld   a, BIG_OFFSET
   ld   [wSpawnOff], a
   ld   a, ENEMY_BIG
   ret
.notBig:
   ld   a, [wBigPercent]
   ld   b, a
   ld   a, [wSpawnRoll]
   sub  b                       ;; tirada - %grande
   ld   b, a
   ld   a, [wAggrPercent]
   cp   b
   jr   z, .normal
   jr   c, .normal              ;; %agresiva <= (tirada - %grande): normal
   ld   b, ENEMY_AGGR
   call Enemies_CountType
   cp   MAX_AGGR
   jr   nc, .normal
   ld   a, AGGR_OFFSET
   ld   [wSpawnOff], a
   ld   a, ENEMY_AGGR
   ret
.normal:
   xor  a
   ld   [wSpawnOff], a
   ld   a, ENEMY_NORMAL
   ret

;;-----------------------------------------------------------------
;; Enemies_Spawn: Crea una celula (normal, grande o agresiva) en un lado y una posicion al azar, si hay algun hueco libre
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
   ld   a, ENEMY_BIG_HP         ;; (ld no toca los flags)
   jr   z, .storeHp
   ld   a, [wSpawnType]
   cp   ENEMY_AGGR
   ld   a, ENEMY_AGGR_HP
   jr   z, .storeHp
   ld   a, ENEMY_NORMAL_HP
.storeHp:
   ld   [hl], a                 ;; Vida (= tamaño en tiles)
   ;; Las celulas grandes y agresivas no entran de golpe: antes parpadea una flecha en el marco (ver Enemies_Activate)
   ld   a, [wSpawnType]
   cp   ENEMY_NORMAL
   ret  z
   ld   de, wWarnType + ENEMY_SIZE - 1
   ld   b, ENEMY_SIZE
.stash:                         ;; Copia la celula (de atras adelante) a wWarnType y libera su hueco
   ld   a, [hl-]
   ld   [de], a
   dec  de
   dec  b
   jr   nz, .stash
   inc  hl                      ;; HL -> inicio del hueco
   xor  a
   ld   [hl], a                 ;; Hueco libre otra vez
   ld   a, WARN_FRAMES
   ld   [wWarnTimer], a
   ret

;;-----------------------------------------------------------------
;; Enemies_Activate: Acaba el aviso: la celula guardada en wWarnType entra de verdad en un hueco libre (si no hay, se pierde)
;;    Destruye: A, BC, DE, HL
Enemies_Activate:
   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.find:
   ld   a, [hl]
   and  a
   jr   z, .free
   REPT ENEMY_SIZE
      inc  hl
   ENDR
   dec  b
   jr   nz, .find
   ret
.free:
   ld   de, wWarnType
   ld   b, ENEMY_SIZE
.copy:
   ld   a, [de]
   inc  de
   ld   [hl+], a
   dec  b
   jr   nz, .copy
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
   ld   c, a
   bit  1, c
   jr   z, .noAggr              ;; La normal no se mueve ahora: la agresiva tampoco
   ld   a, [wAggrAcc]
   add  AGGR_SPEED_PCT          ;; Cada paso de la normal suma AGGR_SPEED_PCT; al llegar a 100 la agresiva da un paso
   cp   100
   jr   c, .keepAcc
   sub  100
   set  2, c                    ;; Bit 2: las agresivas se mueven en este fotograma
.keepAcc:
   ld   [wAggrAcc], a
.noAggr:
   ld   a, c
   ld   [wMoveNow], a
   and  a
   ret  z                       ;; Ninguna se mueve en este fotograma

   ld   hl, wEnemies
   ld   b, MAX_ENEMIES
.loop:
   ld   a, [hl]                 ;; Tipo
   and  a
   jp   z, .next                ;; Hueco libre
   cp   ENEMY_AGGR
   jr   z, .isAggr
   cp   ENEMY_BIG
   ld   a, [wMoveNow]           ;; (ld no toca los flags: sigue valiendo la comparacion)
   jr   z, .isBig
   and  %00000010               ;; Normal
   jp   z, .next
   jr   .move
.isAggr:
   ld   a, [wMoveNow]
   and  %00000100
   jp   z, .next
   jr   .move
.isBig:
   and  %00000001
   jp   z, .next
.move:
   ld   a, [hl]
   cp   ENEMY_AGGR
   jr   nz, .straight
   call Enemy_Chase             ;; La agresiva no va en linea recta: persigue al jugador
   jp   .next
.straight:
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
;; Enemy_Chase: Mueve 1 pixel a una celula agresiva hacia el CENTRO del jugador, por el eje en el que mas lejos esta (en empate,
;;    el X). Asi rastrea su fila y su columna en tiempo real y avanza al mismo ritmo que una celula normal. Si ya esta
;;    centrada sobre el jugador no se mueve.
;;    Entrada: HL = inicio de la celula     Conserva HL y BC. Destruye: A, DE
Enemy_Chase:
   push hl
   push bc
   inc  hl
   inc  hl                      ;; HL -> X
   ld   d, h
   ld   e, l                    ;; DE -> X
   inc  hl
   inc  hl                      ;; HL -> vida (= tamaño en tiles)
   ld   a, [hl]
   add  a
   add  a                       ;; 4 * tamaño = mitad de su lado en pixeles
   ld   c, a
   ld   h, d
   ld   l, e                    ;; HL -> X
   ld   a, [hl+]                ;; A = X; HL -> Y
   add  c
   ld   d, a                    ;; D = centro X de la celula
   ld   a, [hl]
   add  c
   ld   e, a                    ;; E = centro Y de la celula
   dec  hl                      ;; HL -> X
   ;; --- Distancia en X ---
   ld   a, [wPlayerX]
   add  TILE_SIZE / 2           ;; centro X del jugador
   sub  d
   ld   b, DIR_RIGHT
   jr   nc, .px
   cpl
   inc  a                       ;; valor absoluto
   ld   b, DIR_LEFT
.px:
   ld   [wChDX], a
   ld   a, b
   ld   [wChDirX], a
   ;; --- Distancia en Y ---
   ld   a, [wPlayerY]
   add  TILE_SIZE / 2
   sub  e
   ld   b, DIR_DOWN
   jr   nc, .py
   cpl
   inc  a
   ld   b, DIR_UP
.py:
   ld   [wChDY], a
   ld   a, b
   ld   [wChDirY], a
   ;; --- Eje de movimiento ---
   ld   a, [wChDX]
   ld   b, a
   ld   a, [wChDY]
   cp   b
   jr   c, .moveX               ;; dy < dx
   jr   nz, .moveY              ;; dy > dx
   and  a
   jr   z, .done                ;; dx = dy = 0: ya esta encima
.moveX:
   ld   a, [wChDirX]
   cp   DIR_RIGHT
   ld   a, [hl]
   jr   z, .xInc
   dec  a
   jr   .xStore
.xInc:
   inc  a
.xStore:
   ld   [hl], a
   jr   .done
.moveY:
   inc  hl                      ;; HL -> Y
   ld   a, [wChDirY]
   cp   DIR_DOWN
   ld   a, [hl]
   jr   z, .yInc
   dec  a
   jr   .yStore
.yInc:
   inc  a
.yStore:
   ld   [hl], a
.done:
   pop  bc
   pop  hl
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
   ld   a, [de]
   and  MISSILE_FLAG
   ld   [wHitMissile], a        ;; $80 si era un misil (mata de un golpe a cualquier celula)
   xor  a
   ld   [de], a                 ;; La bala desaparece
   push hl
   REPT ENEMY_SIZE - 1
      inc  hl                   ;; HL -> vida de la celula (ultimo byte)
   ENDR
   ld   a, [hl]
   ld   [wHitSize], a           ;; Tamaño antes del impacto
   ld   a, [wHitMissile]
   and  a
   jr   z, .normalHit
   ld   [hl], 1                 ;; Misil: la vida baja a 1 y el impacto la deja en 0
.normalHit:
   dec  [hl]                    ;; Le quitamos 1 de vida
   pop  hl                      ;; (pop no modifica los flags: sigue valiendo el resultado de dec)
   jr   nz, .survived           ;; Aun le queda vida
   ;; --- Muere ---
   ld   a, [hl]                 ;; Tipo, para saber los puntos
   cp   ENEMY_BIG
   ld   a, ENEMY_BIG_POINTS     ;; (ld no toca los flags)
   jr   z, .points
   ld   a, [hl]
   cp   ENEMY_AGGR
   ld   a, ENEMY_AGGR_POINTS
   jr   z, .points
   ld   a, ENEMY_NORMAL_POINTS
.points:
   push af
   push bc
   push hl
   inc  hl
   inc  hl                      ;; HL -> X
   ld   a, [wHitSize]
   dec  a
   add  a
   add  a
   ld   e, a                    ;; E = 4 * (tamaño - 1): del extremo de la celula a su centro (con un misil puede morir una grande)
   ld   a, [hl+]
   add  e
   ld   b, a                    ;; B = X del sprite centrado en la celula
   ld   a, [hl]
   add  e
   ld   c, a
   call Explo_Spawn
   call Drop_Roll               ;; Con probabilidad DROP_PERCENT suelta una gota de energia
   pop  hl
   pop  bc
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
   ;;-- Aviso: cuando acaba la cuenta atras, la celula grande/agresiva avisada entra
   ld   a, [wWarnTimer]
   and  a
   jr   z, .noWarn
   dec  a
   ld   [wWarnTimer], a
   call z, Enemies_Activate
.noWarn:
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
Put_Sprite::
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
   ld   a, [hl+]
   ld   [wDrawType], a          ;; (HL -> direccion)
   inc  hl                      ;; HL -> X
   ld   a, [hl+]
   ld   b, a                    ;; B = X
   ld   a, [hl+]
   ld   c, a                    ;; C = Y
   ld   a, [hl]                 ;; A = N
   ld   [wDrawRows], a
   ld   [wDrawN], a
   ld   a, [wDrawType]
   cp   ENEMY_AGGR
   ld   a, [wDrawN]
   jr   z, .aggr
   cp   2
   ld   a, TILE_ENEMY1
   jr   c, .tile                ;; N = 1
   ld   a, TILE_BIG2
   jr   z, .tile                ;; N = 2
   ld   a, TILE_BIG3            ;; N = 3
   jr   .tile
.aggr:
   cp   2
   ld   a, TILE_AGGR1           ;; N = 1 (ya herida)
   jr   c, .tile
   ld   a, TILE_AGGR2           ;; N = 2
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
;;    hacen falta (1, 4 o 9 por celula). Despues Explo_Draw dibuja las explosiones y oculta los sprites que sobran (Y=0).
;;    El DMA lo copiara a la OAM real en el proximo VBlank.
;;    Destruye: A, BC, DE, HL
Enemies_Draw::
   ld   de, wShadowOAM + SPR_SLOT_ENEMIES * OAM_ENTRY_SIZE
   ;; sigue en Enemies_DrawAt

;;-----------------------------------------------------------------
;; Enemies_DrawAt: Como Enemies_Draw, pero empezando en el sprite de la OAM en sombra que indica DE (lo usa la pausa,
;;    que escribe antes su texto)
;;    Entrada: DE = primer sprite libre
Enemies_DrawAt::
   ASSERT ENEMY_SIZE == 5       ;; Esta rutina asume la estructura [tipo, direccion, X, Y, vida]
   ld   hl, wEnemies
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
   jp   Explo_Draw              ;; Dibuja las explosiones a continuacion y oculta los sprites que sobren
