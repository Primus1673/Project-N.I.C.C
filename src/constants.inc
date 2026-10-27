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

DEF TILE_AGGR2     EQU 67  ;; Celula agresiva a 2x2: 4 tiles seguidos (por filas) de src/sprites/celula_agresiva.z80
DEF TILE_AGGR1     EQU 71  ;; Celula agresiva a 1x1 (tras el primer disparo): 5o tile del mismo archivo

DEF TILE_TITLE     EQU 72  ;; Letras grandes del titulo: 38 tiles (P,R,O,J,E,C,T,N,I a 2x2 y el punto a 1x2) de src/sprites/titulo.z80

DEF TILE_EXPL      EQU 112 ;; Explosion: 3 tiles seguidos de src/sprites/explosion.z80

DEF TILE_WARN      EQU 115 ;; Flechas del aviso de entrada: 4 tiles de src/sprites/aviso.z80, en el orden DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT

DEF TILE_MISSILE_V EQU 119 ;; Misil vertical (apunta arriba; con Y invertida, abajo): primer tile de src/sprites/energia.z80
DEF TILE_MISSILE_H EQU 120 ;; Misil horizontal (apunta a la derecha; con X invertida, a la izquierda)
DEF TILE_DROP      EQU 121 ;; Gota de energia
DEF TILE_BAR       EQU 122 ;; Barra de energia del HUD: 9 tiles seguidos, con 0 a 8 pixeles rellenos
DEF TILE_VIRUS     EQU 131 ;; Virus del fondo del titulo: 36 tiles seguidos (por filas) de src/sprites/virus.z80, a 6x6

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
DEF ENEMY_AGGR     EQU 3   ;; Celula agresiva (tipo 3): 2x2, persigue al jugador; 2 disparos (el primero la encoge a 1x1)
DEF ENEMY_AGGR_HP       EQU 2
DEF AGGR_SPEED_PCT EQU 70  ;; Velocidad de la agresiva = este % de la de la celula normal de la fase (1-99)
ASSERT AGGR_SPEED_PCT > 0 && AGGR_SPEED_PCT < 100
DEF MAX_AGGR       EQU 2   ;; Celulas agresivas a la vez
DEF AGGR_OFFSET    EQU (ENEMY_AGGR_HP - 1) * TILE_SIZE   ;; Zona de aparicion estrechada: 8 pixeles

;;    Limite de sprites: la OAM admite 40. Nave (1) + balas (MAX_BULLETS) + enemigos. Una celula grande a 3x3 gasta 9 sprites.
ASSERT MAX_BIG * 9 + MAX_AGGR * 4 + (MAX_ENEMIES - MAX_BIG - MAX_AGGR) <= MAX_SPRITES - SPR_SLOT_ENEMIES

DEF WARN_FRAMES    EQU 48   ;; Aviso antes de que entre una celula grande o agresiva: una flecha parpadea en el marco (0,8 s)
DEF WARN_BLINK_BIT EQU 2    ;; La flecha se ve cuando este bit del contador esta a 1: parpadea cada 4 fotogramas

;;--------------------------------------
;;-- Energia celular, gotas y misiles (energy.asm, bullets.asm)
;;    Algunas celulas sueltan una gota al morir (DROP_PERCENT %). La gota cae y, si el jugador la toca, rellena la barra de
;;    energia (ENERGY_PER_DROP pixeles de ENERGY_MAX). Con la barra llena, SELECT activa el modo misiles: A y B disparan misiles
;;    guiados en vez de balas, y la barra se vacia sola (1 pixel cada ENERGY_DRAIN_FRAMES fotogramas = 8 s en total).
DEF ENERGY_MAX      EQU 40   ;; Barra llena: 5 tiles de 8 pixeles
DEF ENERGY_PER_DROP EQU 5    ;; Cada gota: 1/8 de la barra
DEF ENERGY_DRAIN_FRAMES EQU 12   ;; Con el modo misiles activo, la barra baja 1 pixel cada 12 fotogramas: 40 * 12 = 480 = 8 s
DEF DROP_PERCENT    EQU 20   ;; Probabilidad (0-100) de que una celula suelte una gota al morir
DEF MAX_DROPS       EQU 3    ;; Gotas a la vez (1 sprite cada una)
DEF DROP_SIZE       EQU 3    ;; [activa, X, Y]
DEF DROP_SLOW       EQU 3    ;; La gota baja 1 pixel cada DROP_SLOW fotogramas
DEF DROP_REACH      EQU 6    ;; Distancia maxima (pixeles, por eje) entre la gota y el jugador para recogerla
DEF HUD_BAR_COL     EQU 4    ;; Columna del primer tile de la barra del HUD (ocupa 5)
DEF HUD_BAR_TILES   EQU 5
ASSERT ENERGY_MAX == HUD_BAR_TILES * TILE_SIZE
ASSERT HUD_BAR_COL + HUD_BAR_TILES <= HUD_COMBO_COL
DEF MISSILE_FLAG    EQU $80  ;; En la direccion de una bala: bit 7 = es un misil (los bits 0-2 son hacia donde apunta)
DEF MISSILE_SPEED   EQU 2    ;; Pixeles por fotograma (las balas van a 1)
DEF MISSILE_COOLDOWN EQU 30  ;; Recarga por boton en modo misiles (0,5 s)
DEF OAM_XFLIP       EQU $20
DEF OAM_YFLIP       EQU $40

DEF MAX_EXPLOSIONS EQU 3    ;; Explosiones a la vez (1 sprite cada una)
DEF EXPL_SIZE      EQU 3    ;; [fotogramas que quedan, X, Y]
DEF EXPL_FRAMES    EQU 12   ;; Duracion de una explosion (3 dibujos de 4 fotogramas)
DEF FLASH_FRAMES   EQU 4    ;; Duracion del destello de pantalla al ser golpeado
DEF PALETTE_FLASH_HI EQU %00000000   ;; Destello: todo el fondo blanco...
DEF PALETTE_FLASH_LO EQU %01010100   ;; ...y despues claro, antes de volver a la paleta normal

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
DEF STATE_TITLE    EQU 6     ;; Menu del titulo (JUGAR / PUNTUACIONES / CONTROLES)
DEF STATE_SCORES   EQU 7     ;; Tabla de puntuaciones
DEF STATE_PAUSED   EQU 10    ;; Partida en pausa (START): todo congelado, pantalla negra con "PAUSA"
DEF STATE_NAME     EQU 9     ;; Eleccion del nombre (3 letras) tras entrar en la tabla
DEF STATE_RESULTS  EQU 5     ;; Pantalla de puntuacion final (tras la ultima fase o tras perder). START reinicia
DEF SCORE_DIGITS   EQU 5     ;; Puntuacion de 5 cifras decimales (maximo 99999, se satura)
DEF ENEMY_NORMAL_POINTS EQU 1 ;; Puntos de la celula tipo 1, EN DECENAS (1 = 10 puntos)
DEF ENEMY_BIG_POINTS    EQU 5 ;; Puntos de la celula grande, en decenas (50 puntos)
DEF ENEMY_AGGR_POINTS   EQU 3 ;; Puntos de la celula agresiva, en decenas (30 puntos)

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
DEF RES_ROW_TITLE  EQU 2     ;; Fila (0-17) de cada linea
DEF RES_ROW_POINTS EQU 5
DEF RES_ROW_PHASES EQU 7
DEF RES_ROW_HEARTS EQU 9
DEF RES_ROW_TOTAL  EQU 12
DEF RES_ROW_RECORD EQU 14   ;; Record (entre el TOTAL y PULSA START)
DEF RES_ROW_PRESS  EQU 16
DEF RES_RECORD_COL EQU 4     ;; Columna de "RECORD" (las 5 cifras van 7 columnas mas alla)
DEF RES_LABEL_COL  EQU 2     ;; Columna donde empieza cada etiqueta
DEF RES_VALUE_COL  EQU 13    ;; Columna de la primera cifra de cada valor (5 cifras: columnas 13 a 17)
DEF RES_WAIT       EQU 30    ;; Fotogramas entre una linea y la siguiente (0,5 s)

ENDC

;;--------------------------------------
;;-- Pantalla de titulo, tabla de puntuaciones y eleccion de nombre (title.asm, save.asm). Todo va en el mapa de fondo 1.
DEF TITLE_ROW1     EQU 3     ;; Fila donde empieza "PROJECT" (ocupa 2 filas)
DEF TITLE_ROW2     EQU 6     ;; Fila donde empieza "N.I.C.C" (ocupa 2 filas)
DEF MENU_ROW0      EQU 12    ;; Fila de la primera opcion del menu (una opcion cada 2 filas)
DEF MENU_CURSOR_COL EQU 3    ;; Columna de la flecha que marca la opcion elegida
DEF MENU_TEXT_COL  EQU 5     ;; Columna del texto de las opciones
DEF TILE_ARROW     EQU TILE_TITLE + 38   ;; Flecha ">" (tile de titulo.z80)
DEF TILE_DASH      EQU TILE_TITLE + 39   ;; Guion "-" (tile de titulo.z80)
DEF SCORE_SLOTS    EQU 8     ;; Puntuaciones que guarda la tabla
DEF SCORE_ENTRY_SIZE EQU 8   ;; Cada una: 3 letras del nombre (0 = A ... 25 = Z) + 5 cifras de la puntuacion
DEF NAME_LETTERS   EQU 26
DEF SCORES_ROW_TITLE EQU 1
DEF SCORES_ROW0    EQU 4     ;; Fila de la primera puntuacion (una por fila)
DEF SCORES_ROW_PRESS EQU 15
DEF SCORES_MARK_COL EQU 2    ;; Flecha que marca tu puntuacion
DEF SCORES_POS_COL EQU 4     ;; Numero de puesto
DEF SCORES_NAME_COL EQU 6    ;; Nombre
DEF SCORES_VALUE_COL EQU 11  ;; Primera de las 5 cifras
DEF NAME_ROW_TITLE EQU 5     ;; Pantalla de nombre: fila de "NUEVO RECORD" / "PUESTO n"
DEF NAME_ROW_POINTS EQU 8    ;; ... de los puntos
DEF NAME_ROW       EQU 11    ;; Fila de "NOMBRE" y las 3 letras (columnas NAME_COL, +2, +4)
DEF NAME_COL       EQU 11
DEF NAME_BLINK     EQU 20    ;; Fotogramas que la letra elegida esta visible / oculta
