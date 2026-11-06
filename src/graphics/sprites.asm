;;-------------------------------------------------------------------------------------------------------------------------------;;
;; sprites.asm : OAM en sombra (shadow OAM), transferencia por DMA y datos de los tiles
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

;;-----------------------------------------------------------------
;; Copia de la OAM en RAM
SECTION "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM:: ds OAM_SIZE

SECTION "Sprites", ROM0

;;-----------------------------------------------------------------
;; Rutina de DMA. Durante la transferencia la CPU solo puede acceder a HRAM
OAMDMA_Source:
LOAD "HRAM OAM DMA", HRAM
hOAMDMA::
   ld   a, HIGH(wShadowOAM)
   ldh  [rDMA], a
   ld   a, 40
.wait:
   dec  a
   jr   nz, .wait
   ret
.end:
ENDL

;;-----------------------------------------------------------------
;; Sprites_Init: Copia la rutina de DMA a HRAM y deja la OAM en sombra vacia
Sprites_Init::
   ;; Copiamos la rutina de DMA de ROM a HRAM
   ld   de, OAMDMA_Source
   ld   hl, hOAMDMA
   ld   bc, hOAMDMA.end - hOAMDMA
   call MemCopy

   ;; (sigue en Sprites_Clear)

;;-----------------------------------------------------------------
;; Sprites_Clear: Deja la OAM en sombra vacia
Sprites_Clear::
   ld   hl, wShadowOAM
   ld   bc, OAM_SIZE
   xor  a
   jp   MemSet

;;-----------------------------------------------------------------
;; Sprites_LoadTiles: Copia todos los tiles del juego a la VRAM
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

   ld   de, BatteryTiles
   ld   hl, _VRAM + TILE_HEART_DROP * TILE_BYTES
   ld   bc, BatteryTiles.end - BatteryTiles
   call MemCopy

   ld   de, ZigTiles
   ld   hl, _VRAM + TILE_ZIGZAG * TILE_BYTES
   ld   bc, ZigTiles.end - ZigTiles
   call MemCopy

   ld   de, DivTiles
   ld   hl, _VRAM + TILE_DIV * TILE_BYTES
   ld   bc, DivTiles.end - DivTiles
   call MemCopy

   ld   de, BossTiles
   ld   hl, _VRAM + TILE_BOSS * TILE_BYTES
   ld   bc, BossTiles.end - BossTiles
   call MemCopy

   ld   de, ShieldTiles
   ld   hl, _VRAM + TILE_SHIELD * TILE_BYTES
   ld   bc, ShieldTiles.end - ShieldTiles
   call MemCopy
   ret

;;-----------------------------------------------------------------
;; Datos de los tiles, exportados desde Game Boy Tile Designer (GBTD)
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

INCLUDE "sprites/bateria.z80"
BatteryTiles.end:

INCLUDE "sprites/escudo.z80"
ShieldTiles.end:

INCLUDE "sprites/celula_zigzag.z80"
ZigTiles.end:

INCLUDE "sprites/celula_divisora.z80"
DivTiles.end:

INCLUDE "sprites/jefe.z80"
BossTiles.end:
