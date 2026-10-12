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

   ;; Todos los sprites a 0: con Y=0 el sprite queda oculto fuera de la pantalla
   ld   hl, wShadowOAM
   ld   bc, OAM_SIZE
   xor  a
   call MemSet
   ret

;;-----------------------------------------------------------------
;; Sprites_LoadTiles: Copia los tiles de src/sprites/dron.z80 a la VRAM, a partir del tile TILE_PLAYER
;;    El tile 0 (TILE_BLANK) no se copia: ya esta vacio porque main.asm borra la VRAM al arrancar.
;;    IMPORTANTE: solo llamar con la LCD apagada o durante el VBlank
;;    Destruye: A, BC, DE, HL
Sprites_LoadTiles::
   ld   de, TileLabel
   ld   hl, _VRAM + TILE_PLAYER * TILE_BYTES
   ld   bc, TileLabel.end - TileLabel
   call MemCopy
   ret

;;-----------------------------------------------------------------
;; Datos de los tiles, exportados desde Game Boy Tile Designer (GBTD).
;; Flujo de trabajo: editar src/sprites/dron.gbr en GBTD -> File > Export to... -> "dron.z80" en src/sprites/ -> make clean && make
;; (make clean es necesario porque el Makefile no sabe que sprites.asm depende de este archivo)
;; El archivo exportado define su propia SECTION "Tiles" y la etiqueta TileLabel, y debe ir al final de este fichero.
INCLUDE "sprites/dron.z80"
TileLabel.end:
