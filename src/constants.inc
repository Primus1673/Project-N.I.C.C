;;-------------------------------------------------------------------------------------------------------------------------------;;
;; constants.inc : Constantes comunes del juego (se incluye desde cada .asm con INCLUDE "constants.inc")
;;-------------------------------------------------------------------------------------------------------------------------------;;

IF !DEF(CONSTANTS_INC)
DEF CONSTANTS_INC EQU 1

INCLUDE "hardware.inc"
rev_Check_hardware_inc 4.0

;;--------------------------------------
;;-- Pantalla (en pixeles)
DEF TILE_SIZE      EQU 8
DEF SCREEN_W       EQU 160
DEF SCREEN_H       EQU 144

DEF SCREEN_TILES_W EQU SCREEN_W / TILE_SIZE    ;; 20 tiles visibles de ancho
DEF SCREEN_TILES_H EQU SCREEN_H / TILE_SIZE    ;; 18 tiles visibles de alto
DEF MAP_STRIDE     EQU 32                      ;; El mapa de fondo tiene 32 tiles por fila (solo se ven 20)

;;--------------------------------------
;;-- Marco de la pantalla (se dibuja con tiles del FONDO, no con sprites: 72 sprites no caben,
;;   la GB admite 40 en total y solo 10 por linea)
DEF BORDER_SIZE    EQU TILE_SIZE               ;; Grosor del marco: 1 tile (8 pixeles)

;;    Zona de juego: valores minimo y maximo de la esquina superior izquierda de un sprite de 8x8 para
;;    que quede dentro del marco, sin pisarlo. La usan el jugador y las balas.
DEF PLAY_MIN_X     EQU BORDER_SIZE
DEF PLAY_MAX_X     EQU SCREEN_W - BORDER_SIZE - TILE_SIZE
DEF PLAY_MIN_Y     EQU BORDER_SIZE
DEF PLAY_MAX_Y     EQU SCREEN_H - BORDER_SIZE - TILE_SIZE
DEF PLAY_RANGE_X   EQU PLAY_MAX_X - PLAY_MIN_X + 1   ;; Cuantos valores distintos puede tomar X (137)
DEF PLAY_RANGE_Y   EQU PLAY_MAX_Y - PLAY_MIN_Y + 1   ;; Cuantos valores distintos puede tomar Y (121)

;;--------------------------------------
;;-- OAM (sprites)
;;    En OAM, la coordenada Y de un sprite lleva un desplazamiento de 16 y la X de 8,
;;    de forma que Y=16, X=8 es la esquina superior izquierda de la pantalla visible.
DEF OAM_Y_OFFSET   EQU 16
DEF OAM_X_OFFSET   EQU 8
DEF OAM_ENTRY_SIZE EQU 4
DEF MAX_SPRITES     EQU 40
DEF OAM_SIZE       EQU OAM_ENTRY_SIZE * MAX_SPRITES

;;    Reparto de los sprites (un sprite con numero menor se dibuja ENCIMA de uno con numero mayor)
DEF SPR_SLOT_PLAYER  EQU 0                          ;; 1 sprite: la nave
DEF SPR_SLOT_BULLETS EQU 1                          ;; MAX_BULLETS sprites: las balas
;;    (el sprite SPR_SLOT_ENEMIES, con los enemigos, se define mas abajo en la seccion de enemigos)

;;--------------------------------------
;;-- Indices de tiles (se cargan en VRAM a partir de $8000)
DEF TILE_BYTES     EQU 16  ;; Un tile de 8x8 a 2 bits por pixel ocupa 16 bytes
DEF TILE_BLANK     EQU 0   ;; Tile vacio (fondo). Es el tile 0: la VRAM se borra al arrancar
DEF TILE_PLAYER    EQU 1   ;; Nave del jugador: primer tile de src/sprites/dron.z80
DEF TILE_BORDER    EQU 2   ;; Borde del marco: primer tile de src/sprites/borde.z80
DEF TILE_BULLET    EQU 3   ;; Bala: primer tile de src/sprites/bala.z80
DEF TILE_ENEMY1    EQU 4   ;; Celula infectada (tipo 1): primer tile de src/sprites/celula.z80
DEF TILE_HUD       EQU 5   ;; Tiles del HUD: primer tile de src/sprites/hud.z80 (13 tiles: digitos 0-9, corazon lleno, corazon vacio y X)
DEF TILE_DIGIT0    EQU TILE_HUD          ;; Tile del digito 0 (el digito N es TILE_DIGIT0 + N)
DEF TILE_HEART_FULL  EQU TILE_HUD + 10   ;; Corazon lleno (vida que se conserva)
DEF TILE_HEART_EMPTY EQU TILE_HUD + 11   ;; Corazon vacio (vida perdida)
DEF TILE_HUD_X     EQU TILE_HUD + 12     ;; Letra X del multiplicador de combo ("X3")
DEF TILE_FONT      EQU 18  ;; Fuente de texto para SPRITES: primer tile de src/sprites/font.z80 (36 tiles, hasta el 53)
DEF TILE_BIG3      EQU 54  ;; Celula grande a 3x3: 9 tiles seguidos (por filas) de src/sprites/celula_grande.z80
DEF TILE_BIG2      EQU 63  ;; Celula grande a 2x2: 4 tiles seguidos (por filas), a continuacion de los 9 anteriores

DEF TILE_FONT_DIGIT0 EQU TILE_FONT        ;; Digito N = TILE_FONT_DIGIT0 + N
DEF TILE_FONT_A    EQU TILE_FONT + 10     ;; Letra A (la B es la siguiente...)

;;--------------------------------------
;;-- Paleta (4 tonos: %DDCCBBAA con AA=color 0 ... DD=color 3; 0=blanco ... 3=negro)
DEF PALETTE_DEFAULT EQU %11100100

;;--------------------------------------
;;-- Botones. Formato de hInput: nibble alto = cruceta, nibble bajo = botones. 1 = pulsado
DEF BTNB_A         EQU 0
DEF BTNB_B         EQU 1
DEF BTNB_SELECT    EQU 2
DEF BTNB_START     EQU 3
DEF BTNB_RIGHT     EQU 4
DEF BTNB_LEFT      EQU 5
DEF BTNB_UP        EQU 6
DEF BTNB_DOWN      EQU 7

;;--------------------------------------
;;-- Jugador
;;    Posicion = esquina superior izquierda del sprite en pantalla (0..159, 0..143).
;;    Los limites son los valores MINIMO y MAXIMO que puede tomar esa esquina.
DEF PLAYER_SPEED   EQU 1                       ;; Pixeles por fotograma (60 fps)
DEF PLAYER_MIN_X   EQU PLAY_MIN_X              ;; El jugador no puede pisar el marco: queda
DEF PLAYER_MAX_X   EQU PLAY_MAX_X              ;; justo pegado a el por dentro
DEF PLAYER_MIN_Y   EQU PLAY_MIN_Y
DEF PLAYER_MAX_Y   EQU PLAY_MAX_Y
DEF PLAYER_START_X EQU (SCREEN_W - TILE_SIZE) / 2
DEF PLAYER_START_Y EQU (SCREEN_H - TILE_SIZE) / 2


;;--------------------------------------
;;-- Direcciones de movimiento (las usan balas y enemigos)
DEF DIR_NONE       EQU 0
DEF DIR_UP         EQU 1
DEF DIR_DOWN       EQU 2
DEF DIR_LEFT       EQU 3
DEF DIR_RIGHT      EQU 4

;;--------------------------------------
;;-- Disparos
;;    El boton A dispara hacia ARRIBA y hacia ABAJO a la vez; el boton B hacia la IZQUIERDA y la DERECHA a la vez.
;;    Cada boton tiene su propia recarga. Cada bala es un sprite de 8x8 que avanza en linea recta.
DEF MAX_BULLETS    EQU 8   ;; Balas que pueden existir a la vez (cada pulsacion crea 2)
DEF BULLET_SPEED   EQU 1   ;; Pixeles por fotograma
DEF SHOT_COOLDOWN  EQU 60  ;; Fotogramas de recarga por boton (60 fotogramas = 1 segundo)

;;    Cada bala ocupa BULLET_SIZE bytes en RAM: [direccion, X, Y]
DEF BULLET_SIZE    EQU 3
DEF BULLET_NONE    EQU DIR_NONE    ;; Direccion 0 = hueco libre (bala inexistente)
DEF BULLET_UP      EQU DIR_UP
DEF BULLET_DOWN    EQU DIR_DOWN
DEF BULLET_LEFT    EQU DIR_LEFT
DEF BULLET_RIGHT   EQU DIR_RIGHT


;;--------------------------------------
;;-- Enemigos (celulas infectadas)
;;    Cada enemigo ocupa ENEMY_SIZE bytes en RAM: [tipo, direccion, X, Y, vida]. Tipo 0 = hueco libre.
DEF MAX_ENEMIES    EQU 8   ;; Enemigos que pueden existir a la vez
DEF SPR_SLOT_ENEMIES EQU SPR_SLOT_BULLETS + MAX_BULLETS ;; Sprites de OAM de los enemigos (de momento 1 sprite cada uno)
DEF ENEMY_SIZE     EQU 5
DEF ENEMY_NONE     EQU 0   ;; Tipo 0 = hueco libre
DEF ENEMY_NORMAL   EQU 1   ;; Celula infectada (tipo 1): 1x1 tile, 1 disparo
DEF ENEMY_NORMAL_HP     EQU 1
DEF ENEMY_BIG      EQU 2   ;; Celula grande (tipo 2): 3 disparos; cada impacto la encoge (3x3 -> 2x2 -> 1x1) hasta destruirla
DEF ENEMY_BIG_HP        EQU 3   ;; La vida de una celula es tambien su TAMAÑO en tiles (3, 2 o 1): ver Enemies_Draw
DEF MAX_BIG        EQU 2   ;; Celulas grandes a la vez (ver el limite de sprites mas abajo)
DEF BIG_OFFSET     EQU (ENEMY_BIG_HP - 1) * TILE_SIZE   ;; Lo que se estrecha su zona de aparicion: 16 pixeles

;;    Limite de sprites: la OAM admite 40. Nave (1) + balas (MAX_BULLETS) + enemigos. Una celula grande a 3x3 gasta 9 sprites.
ASSERT MAX_BIG * 9 + (MAX_ENEMIES - MAX_BIG) <= MAX_SPRITES - SPR_SLOT_ENEMIES

DEF ENEMY_SPAWN_FIRST   EQU 60          ;; Fotogramas desde que empieza una fase hasta la primera aparicion
;;    La velocidad, el maximo de celulas en pantalla y el ritmo de aparicion dependen de la fase: ver PhaseTable en enemies.asm

;;    Colision: dos sprites chocan si la distancia en X y en Y es MENOR que COLLISION_DIST (en pixeles).
;;    Con 6 la caja de colision es de 6x6 dentro del tile de 8x8 (un poco permisiva, queda mas justo al jugar).
DEF COLLISION_DIST EQU 6
;;    Para celulas de varios tiles (el tamaño en pixeles es 8 * vida): la caja de la celula se alarga por la derecha/abajo.
;;    Un sprite de 8x8 en (x,y) choca con una celula en (ex,ey) de tamaño S si  -BIAS <= x-ex < S + EXTRA  (igual en Y):
;;    para S=8 es el mismo rango de antes (-5 a 5). Se comprueba como (x-ex+BIAS) < 8*vida + EXTRA, sin signo.
DEF COLLIDE_BIAS   EQU COLLISION_DIST - 1
DEF COLLIDE_EXTRA  EQU 2 * COLLISION_DIST - 9

;;--------------------------------------
;;-- Vidas, puntos y estado de la partida
DEF PLAYER_LIVES   EQU 3     ;; Vidas al empezar
DEF INVULN_FRAMES  EQU 120   ;; Invulnerabilidad tras un golpe: 120 fotogramas = 2 segundos
DEF BLINK_MASK     EQU %00000100  ;; Parpadeo: la nave se oculta mientras este bit del contador de invulnerabilidad vale 1
                                  ;; (4 fotogramas visible, 4 oculta)
DEF STATE_PLAYING  EQU 0     ;; Jugando
DEF STATE_GAMEOVER EQU 1     ;; Sin vidas: todo congelado GAMEOVER_FRAMES fotogramas (START lo salta) y luego fundido a la puntuacion
DEF STATE_FADE_OUT EQU 2     ;; Fin de fase: la pantalla se oscurece hasta el negro
DEF STATE_INTRO    EQU 3     ;; Pantalla negra con el texto "FASE N"
DEF STATE_FADE_IN  EQU 4     ;; La pantalla vuelve a aclararse y empieza la fase
DEF STATE_RESULTS  EQU 5     ;; Pantalla de puntuacion final (tras la ultima fase o tras perder). START reinicia
DEF SCORE_DIGITS   EQU 5     ;; Puntuacion de 5 cifras decimales (maximo 99999, se satura)
DEF ENEMY_NORMAL_POINTS EQU 1 ;; Puntos de la celula tipo 1, EN DECENAS (1 = 10 puntos)
DEF ENEMY_BIG_POINTS    EQU 5 ;; Puntos de la celula grande, en decenas (50 puntos)

;;--------------------------------------
;;-- HUD: ocupa la fila superior del marco (fila 0 del mapa de fondo)
DEF HUD_HEARTS_COL EQU 1                                  ;; Columna del primer corazon (ocupan 3 columnas)
DEF HUD_SCORE_COL  EQU SCREEN_TILES_W - 1 - SCORE_DIGITS  ;; Columna de la primera cifra (la ultima queda junto al marco derecho)
DEF HUD_COMBO_COL  EQU 9                                  ;; Columna de la "X" del multiplicador (la cifra va en la siguiente)

;;--------------------------------------
;;-- Combo: bajas seguidas con multiplicador de puntos
;;    Cada baja a tiro suma 1 a la cadena y reinicia la cuenta atras de COMBO_FRAMES. La cadena se rompe al acabarse la
;;    cuenta atras o al recibir un golpe. Multiplicador = 1 + (bajas / COMBO_STEP), con tope COMBO_MAX_MULT.
;;    La cuenta atras solo avanza mientras se juega (se detiene en las pantallas de "FASE N" y de fin).
DEF COMBO_FRAMES      EQU 420  ;; 7 segundos
DEF COMBO_STEP        EQU 3    ;; Bajas seguidas para subir un escalon del multiplicador (x2 con 3, x3 con 6...)
DEF COMBO_MAX_MULT    EQU 5    ;; Tope del multiplicador (ver el calculo del maximo de puntos en la conversacion: no desborda 99999)
DEF COMBO_WARN_FRAMES EQU 180  ;; Cuando quedan menos de estos fotogramas (3 s), el "X3" parpadea, cada vez mas rapido
DEF COMBO_BLINK_MIN   EQU 2    ;; Semiperiodo minimo del parpadeo (fotogramas)

;;--------------------------------------
;;-- Fases (niveles). La partida dura PHASE_COUNT fases de PHASE_FRAMES fotogramas cada una
DEF PHASE_COUNT    EQU 5
DEF PHASE_FRAMES   EQU 3600  ;; 60 fotogramas/s * 60 s = 1 minuto por fase (la Game Boy real va a 59,7 fps: 60,3 s)
DEF INTRO_FRAMES   EQU 120   ;; Tiempo que se muestra el texto "FASE N" (2 s)
DEF FADE_STEP_FRAMES EQU 6   ;; Cada escalon del oscurecimiento/aclarado dura 6 fotogramas (3 escalones = 18 fotogramas)
DEF FADE_BLACK     EQU 3     ;; Nivel de oscurecimiento maximo (0 = normal ... 3 = negro)

;;--------------------------------------
;;-- Texto con sprites (fuente de src/sprites/font.z80), blanco sobre el fondo negro de las pantallas de texto
DEF TEXT_END       EQU $FF   ;; Fin de cadena
DEF TEXT_ATTR      EQU %00010000  ;; Atributos de los sprites de texto: paleta OBP1 (que main.asm deja en blanco)
DEF TEXT_CENTER_Y  EQU (SCREEN_H - TILE_SIZE) / 2

;;--------------------------------------
;;-- Fin de partida y pantalla de puntuacion
DEF GAMEOVER_FRAMES EQU 90   ;; Tras perder la ultima vida, el juego queda congelado 1,5 s antes del fundido
DEF END_NONE       EQU 0     ;; wEndKind: la partida sigue
DEF END_WIN        EQU 1     ;; ... se han superado todas las fases
DEF END_LOSE       EQU 2     ;; ... se han perdido todas las vidas

;;    Bonus finales (en MILES de puntos, para sumarlos a la puntuacion de 5 cifras). Se suman al total, que satura en 99999.
DEF BONUS_PHASE_K  EQU 1     ;; Por cada fase superada: 1 mil = 1000 puntos
DEF BONUS_HEART_K  EQU 10    ;; Por cada corazon que queda: 10 mil = 10000 puntos
ASSERT PHASE_COUNT * BONUS_PHASE_K + PLAYER_LIVES * BONUS_HEART_K <= 99   ;; (limite de la rutina de bonus)

;;    La pantalla de puntuacion se dibuja en el mapa de fondo 1 ($9C00), con tiles de la fuente (src/sprites/font.z80), y se
;;    muestra cambiando el bit de seleccion de mapa de LCDC. Paleta invertida: el tile 0 se ve negro y las letras blancas.
DEF BGP_RESULTS    EQU %00011011
DEF RES_ROW_TITLE  EQU 3     ;; Fila (0-17) de cada linea
DEF RES_ROW_POINTS EQU 6
DEF RES_ROW_PHASES EQU 8
DEF RES_ROW_HEARTS EQU 10
DEF RES_ROW_TOTAL  EQU 13
DEF RES_ROW_PRESS  EQU 16
DEF RES_LABEL_COL  EQU 2     ;; Columna donde empieza cada etiqueta
DEF RES_VALUE_COL  EQU 13    ;; Columna de la primera cifra de cada valor (5 cifras: columnas 13 a 17)
DEF RES_WAIT       EQU 30    ;; Fotogramas entre una linea y la siguiente (0,5 s)

ENDC
