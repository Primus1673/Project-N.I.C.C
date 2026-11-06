;;-------------------------------------------------------------------------------------------------------------------------------;;
;; interrupts.asm : Interrupcion de VBlank y espera al siguiente fotograma
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "HRAM Interrupts", HRAM

hVBlankFlag:: db

;;-----------------------------------------------------------------
;; Vector de la interrupcion de VBlank ($0040)
SECTION "VBlank Vector", ROM0[$0040]
   jp   VBlankHandler

SECTION "Interrupts", ROM0

;;-----------------------------------------------------------------
;; VBlankHandler: Avisa de que ha empezado el VBlank
VBlankHandler:
   push af
   ld   a, 1
   ldh  [hVBlankFlag], a
   pop  af
   reti

;;-----------------------------------------------------------------
;; WaitVBlank: Duerme la CPU (halt) hasta que empiece el siguiente VBlank
WaitVBlank::
.wait:
   halt
   nop
   ldh  a, [hVBlankFlag]
   and  a
   jr   z, .wait
   xor  a
   ldh  [hVBlankFlag], a
   ret
