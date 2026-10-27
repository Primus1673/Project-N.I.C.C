;;-------------------------------------------------------------------------------------------------------------------------------;;
;; sprites.asm : OAM en sombra (shadow OAM), transferencia por DMA y datos de los tiles
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; El juego NO escribe directamente en la OAM real ($FE00). Escribe en una copia en RAM (wShadowOAM) y,
;; una vez por fotograma al empezar el VBlank, se copia entera a la OAM mediante DMA (rutina en HRAM).
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

;;-----------------------------------------------------------------
;; Copia de la OAM en RAM. Debe estar alineada a 256 bytes: el DMA solo recibe el byte alto de la direccion.
SECTION "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM:: ds OAM_SIZE

SECTION "Sprites", ROM0

;;-----------------------------------------------------------------
;; Rutina de DMA. Durante la transferencia la CPU solo puede acceder a HRAM, asi que la rutina
;; se guarda en ROM y se copia a HRAM al arrancar (Sprites_InitDMA). Se ejecuta con "call hOAMDMA".
OAMDMA_Source:
LOAD "HRAM OAM DMA", HRAM
hOAMDMA::
   ld   a, HIGH(wShadowOAM)
   ldh  [rDMA], a
   ld   a, 40                ;; El DMA tarda 160 ciclos de maquina; 40 vueltas de (dec + jr) = 160
.wait:
   dec  a
   jr   nz, .wait
   ret
.end:
ENDL

;;-----------------------------------------------------------------
;; Sprites_Init: Copia la rutina de DMA a HRAM y deja la OAM en sombra vacia (sprites fuera de pantalla)
;;    Destruye: A, BC, DE, HL
Sprites_Init::
   ;; Copiamos la rutina de DMA de ROM a HRAM
   ld   de, OAMDMA_Source
   ld   hl, hOAMDMA
   ld   bc, hOAMDMA.end - hOAMDMA
   call MemCopy

   ;; (sigue en Sprites_Clear)

;;-----------------------------------------------------------------
;; Sprites_Clear: Deja la OAM en sombra vacia (todos los sprites ocultos: con Y=0 quedan fuera de la pantalla)
;;    Destruye: A, BC, D, HL
Sprites_Clear::
   ld   hl, wShadowOAM
   ld   bc, OAM_SIZE
   xor  a
   jp   MemSet

;;-----------------------------------------------------------------
;; Sprites_LoadTiles: Copia todos los tiles del juego a la VRAM (sprites y fondo comparten los tiles de $8000):
;;    - src/sprites/dron.z80  -> a partir del tile TILE_PLAYER (nave)
;;    - src/sprites/borde.z80 -> a partir del tile TILE_BORDER (marco de la pantalla)
;;    - src/sprites/bala.z80  -> a partir del tile TILE_BULLET (balas)
;;    - src/sprites/celula.z80 -> a partir del tile TILE_ENEMY1 (celula infectada)
;;    - src/sprites/hud.z80   -> a partir del tile TILE_HUD (digitos 0-9, corazon lleno, corazon vacio y X del combo)
;;    - src/sprites/font.z80  -> a partir del tile TILE_FONT (fuente para texto con sprites: digitos 0-9 y letras A-Z)
;;    - src/sprites/celula_grande.z80 -> a partir del tile TILE_BIG3 (celula grande: 9 tiles a 3x3 y 4 tiles a 2x2)
;;    - src/sprites/celula_agresiva.z80 -> a partir del tile TILE_AGGR2 (celula agresiva: 4 tiles a 2x2 y 1 tile a 1x1)
;;    - src/sprites/titulo.z80 -> a partir del tile TILE_TITLE (letras grandes de la pantalla de titulo)
;;    - src/sprites/explosion.z80 -> a partir del tile TILE_EXPL (3 dibujos de la explosion de una celula)
;;    - src/sprites/aviso.z80 -> a partir del tile TILE_WARN (4 flechas del aviso de entrada de las celulas)
;;    - src/sprites/energia.z80 -> a partir del tile TILE_MISSILE_V (misiles, gota y barra de energia: 12 tiles)
;;    - src/sprites/virus.z80 -> a partir del tile TILE_VIRUS (virus grande del fondo del titulo: 36 tiles a 6x6)
;;    El tile 0 (TILE_BLANK) no se copia: ya esta vacio porque main.asm borra la VRAM al arrancar.
;;    IMPORTANTE: solo llamar con la LCD apagada o durante el VBlank
;;    Destruye: A, BC, DE, HL
Sprites_LoadTiles::
   ld   de, TileLabel
   ld   hl, _VRAM + TILE_PLAYER * TILE_BYTES
   ld   bc, TileLabel.end - TileLabel
   call MemCopy

   ld   de, BorderTiles
   ld   hl, _VRAM + TILE_BORDER * TILE_BYTES
   ld   bc, BorderTiles.end - BorderTiles
   call MemCopy

   ld   de, BulletTiles
   ld   hl, _VRAM + TILE_BULLET * TILE_BYTES
   ld   bc, BulletTiles.end - BulletTiles
   call MemCopy

   ld   de, CellTiles
   ld   hl, _VRAM + TILE_ENEMY1 * TILE_BYTES
   ld   bc, CellTiles.end - CellTiles
   call MemCopy

   ld   de, HudTiles
   ld   hl, _VRAM + TILE_HUD * TILE_BYTES
   ld   bc, HudTiles.end - HudTiles
   call MemCopy

   ld   de, FontTiles
   ld   hl, _VRAM + TILE_FONT * TILE_BYTES
   ld   bc, FontTiles.end - FontTiles
   call MemCopy

   ld   de, BigCellTiles
   ld   hl, _VRAM + TILE_BIG3 * TILE_BYTES
   ld   bc, BigCellTiles.end - BigCellTiles
   call MemCopy

   ld   de, AggrCellTiles
   ld   hl, _VRAM + TILE_AGGR2 * TILE_BYTES
   ld   bc, AggrCellTiles.end - AggrCellTiles
   call MemCopy

   ld   de, TitleTiles
   ld   hl, _VRAM + TILE_TITLE * TILE_BYTES
   ld   bc, TitleTiles.end - TitleTiles
   call MemCopy

   ld   de, ExplosionTiles
   ld   hl, _VRAM + TILE_EXPL * TILE_BYTES
   ld   bc, ExplosionTiles.end - ExplosionTiles
   call MemCopy

   ld   de, WarnTiles
   ld   hl, _VRAM + TILE_WARN * TILE_BYTES
   ld   bc, WarnTiles.end - WarnTiles
   call MemCopy

   ld   de, EnergyTiles
   ld   hl, _VRAM + TILE_MISSILE_V * TILE_BYTES
   ld   bc, EnergyTiles.end - EnergyTiles
   call MemCopy

   ld   de, VirusTiles
   ld   hl, _VRAM + TILE_VIRUS * TILE_BYTES
   ld   bc, VirusTiles.end - VirusTiles
   call MemCopy
   ret

;;-----------------------------------------------------------------
;; Datos de los tiles, exportados desde Game Boy Tile Designer (GBTD).
;; Flujo de trabajo: editar el .gbr en GBTD -> File > Export to... -> el .z80 en src/sprites/ -> make clean && make
;; (make clean es necesario porque el Makefile no sabe que sprites.asm depende de estos archivos)
;; Cada archivo exportado define su propia SECTION y su etiqueta, y debe ir con su etiqueta ".end" justo detras.
;; Las SECTION y las etiquetas de cada archivo deben tener nombres distintos (se configuran al exportar en GBTD).
INCLUDE "sprites/dron.z80"
TileLabel.end:

INCLUDE "sprites/borde.z80"
BorderTiles.end:

INCLUDE "sprites/bala.z80"
BulletTiles.end:

INCLUDE "sprites/celula.z80"
CellTiles.end:

INCLUDE "sprites/hud.z80"
HudTiles.end:

INCLUDE "sprites/font.z80"
FontTiles.end:

INCLUDE "sprites/celula_grande.z80"
BigCellTiles.end:

INCLUDE "sprites/celula_agresiva.z80"
AggrCellTiles.end:

INCLUDE "sprites/titulo.z80"
TitleTiles.end:

INCLUDE "sprites/explosion.z80"
ExplosionTiles.end:

INCLUDE "sprites/aviso.z80"
WarnTiles.end:

INCLUDE "sprites/energia.z80"
EnergyTiles.end:

INCLUDE "sprites/virus.z80"
VirusTiles.end:
