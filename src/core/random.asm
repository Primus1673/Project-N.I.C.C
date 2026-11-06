;;-------------------------------------------------------------------------------------------------------------------------------;;
;; random.asm : Generador de numeros pseudoaleatorios
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Random Variables", WRAM0

wRandomState: db

SECTION "Random", ROM0

;;-----------------------------------------------------------------
;; Random_Init: Da un valor inicial (distinto de 0) al generador
Random_Init::
   ldh  a, [rDIV]
   or   $01
   ld   [wRandomState], a
   ret

;;-----------------------------------------------------------------
;; Random_Next: Devuelve un numero pseudoaleatorio de 0 a 255
Random_Next::
   push bc
   ld   a, [wRandomState]
   ld   b, a
   ldh  a, [rDIV]
   xor  b
   jr   nz, .notZero
   ld   a, $A5
.notZero:
   ld   b, a

   ld   a, b
   rrca
   and  $80
   xor  b
   ld   b, a

   ;; x ^= x >> 5
   ld   a, b
   swap a
   and  $0F
   srl  a
   xor  b
   ld   b, a

   ;; x ^= x << 3
   ld   a, b
   add  a
   add  a
   add  a
   xor  b

   ld   [wRandomState], a
   pop  bc
   ret

;;-----------------------------------------------------------------
;; Random_Range: Devuelve un numero pseudoaleatorio de 0 a B-1, con la misma probabilidad para todos
Random_Range::
.retry:
   call Random_Next
   cp   b
   jr   nc, .retry
   ret
