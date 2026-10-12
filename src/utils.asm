;;-------------------------------------------------------------------------------------------------------------------------------;;
;; utils.asm : Rutinas de utilidad generales (copiar y rellenar memoria)
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Utils", ROM0

;;-----------------------------------------------------------------
;; MemCopy: Copia BC bytes desde DE hasta HL
;;    Entrada: DE = origen, HL = destino, BC = numero de bytes (BC != 0)
;;    Destruye: A, BC, DE, HL
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
;;    Entrada: A = valor, HL = destino, BC = numero de bytes (BC != 0)
;;    Destruye: A, BC, D, HL
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
