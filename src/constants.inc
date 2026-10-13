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

;;--------------------------------------
;;-- Indices de tiles (se cargan en VRAM a partir de $8000)
DEF TILE_BYTES     EQU 16  ;; Un tile de 8x8 a 2 bits por pixel ocupa 16 bytes
DEF TILE_BLANK     EQU 0   ;; Tile vacio (fondo). Es el tile 0: la VRAM se borra al arrancar
DEF TILE_PLAYER    EQU 1   ;; Nave del jugador: primer tile de src/sprites/dron.z80
DEF TILE_BORDER    EQU 2   ;; Borde del marco: primer tile de src/sprites/borde.z80
DEF TILE_BULLET    EQU 3   ;; Bala: primer tile de src/sprites/bala.z80

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
;;-- Disparos
;;    El boton A dispara hacia ARRIBA y hacia ABAJO a la vez; el boton B hacia la IZQUIERDA y la DERECHA a la vez.
;;    Cada boton tiene su propia recarga. Cada bala es un sprite de 8x8 que avanza en linea recta.
DEF MAX_BULLETS    EQU 8   ;; Balas que pueden existir a la vez (cada pulsacion crea 2)
DEF BULLET_SPEED   EQU 1   ;; Pixeles por fotograma
DEF SHOT_COOLDOWN  EQU 60  ;; Fotogramas de recarga por boton (60 fotogramas = 1 segundo)

;;    Cada bala ocupa BULLET_SIZE bytes en RAM: [direccion, X, Y]
DEF BULLET_SIZE    EQU 3
DEF BULLET_NONE    EQU 0   ;; Direccion 0 = hueco libre (bala inexistente)
DEF BULLET_UP      EQU 1
DEF BULLET_DOWN    EQU 2
DEF BULLET_LEFT    EQU 3
DEF BULLET_RIGHT   EQU 4

ENDC
