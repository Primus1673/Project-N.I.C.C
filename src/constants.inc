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

;;--------------------------------------
;;-- OAM (sprites)
;;    En OAM, la coordenada Y de un sprite lleva un desplazamiento de 16 y la X de 8,
;;    de forma que Y=16, X=8 es la esquina superior izquierda de la pantalla visible.
DEF OAM_Y_OFFSET   EQU 16
DEF OAM_X_OFFSET   EQU 8
DEF OAM_ENTRY_SIZE EQU 4
DEF MAX_SPRITES     EQU 40
DEF OAM_SIZE       EQU OAM_ENTRY_SIZE * MAX_SPRITES

;;--------------------------------------
;;-- Indices de tiles (se cargan en VRAM a partir de $8000)
DEF TILE_BYTES     EQU 16  ;; Un tile de 8x8 a 2 bits por pixel ocupa 16 bytes
DEF TILE_BLANK     EQU 0   ;; Tile vacio (fondo). Es el tile 0: la VRAM se borra al arrancar
DEF TILE_PLAYER    EQU 1   ;; Nave del jugador: primer tile de src/sprites/dron.z80

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
DEF PLAYER_MIN_X   EQU 0
DEF PLAYER_MAX_X   EQU SCREEN_W - TILE_SIZE
DEF PLAYER_MIN_Y   EQU 0                       ;; Si mas adelante el HUD ocupa la fila de arriba: TILE_SIZE
DEF PLAYER_MAX_Y   EQU SCREEN_H - TILE_SIZE
DEF PLAYER_START_X EQU (SCREEN_W - TILE_SIZE) / 2
DEF PLAYER_START_Y EQU (SCREEN_H - TILE_SIZE) / 2

ENDC
