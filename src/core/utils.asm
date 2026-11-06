;;-------------------------------------------------------------------------------------------------------------------------------;;
;; utils.asm : Rutinas de utilidad generales (copiar y rellenar memoria)
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Utils", ROM0

;;-----------------------------------------------------------------
;; MemCopy: Copia BC bytes desde DE hasta HL
MemCopy::
   ld   a, [de]
   inc  de
   ld   [hl+], a
   dec  bc
   ld   a, b
   or   c
   jr   nz, MemCopy
   ret

;;-----------------------------------------------------------------
;; MemSet: Rellena BC bytes a partir de HL con el valor A
MemSet::
   ld   d, a
.loop:
   ld   a, d
   ld   [hl+], a
   dec  bc
   ld   a, b
   or   c
   jr   nz, .loop
   ret
