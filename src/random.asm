;;-------------------------------------------------------------------------------------------------------------------------------;;
;; random.asm : Generador de numeros pseudoaleatorios
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; Usa un "xorshift" de 8 bits (x ^= x<<7; x ^= x>>5; x ^= x<<3), que recorre los 255 valores posibles antes de repetirse.
;; En cada llamada se mezcla ademas el registro DIV (un contador hardware que no para de avanzar), asi que la secuencia
;; no es la misma en cada partida: depende de CUANDO se pide cada numero.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Random Variables", WRAM0

wRandomState: db     ;; Estado del generador (nunca debe valer 0)

SECTION "Random", ROM0

;;-----------------------------------------------------------------
;; Random_Init: Da un valor inicial (distinto de 0) al generador
;;    Destruye: A
Random_Init::
   ldh  a, [rDIV]
   or   $01                  ;; Garantiza que no sea 0
   ld   [wRandomState], a
   ret

;;-----------------------------------------------------------------
;; Random_Next: Devuelve un numero pseudoaleatorio de 0 a 255
;;    Salida: A = numero
;;    Destruye: A y los flags (conserva BC, DE y HL)
Random_Next::
   push bc
   ld   a, [wRandomState]
   ld   b, a
   ldh  a, [rDIV]
   xor  b                    ;; Mezcla con DIV
   jr   nz, .notZero
   ld   a, $A5               ;; Si saliera 0 el generador se quedaria atascado: usamos otro valor
.notZero:
   ld   b, a

   ;; x ^= x << 7   (x<<7 solo conserva el bit 0, colocado en el bit 7)
   ld   a, b
   rrca
   and  $80
   xor  b
   ld   b, a

   ;; x ^= x >> 5
   ld   a, b
   swap a
   and  $0F                  ;; A = x >> 4
   srl  a                    ;; A = x >> 5
   xor  b
   ld   b, a

   ;; x ^= x << 3
   ld   a, b
   add  a
   add  a
   add  a                    ;; A = x << 3 (se pierden los bits que se salen)
   xor  b

   ld   [wRandomState], a
   pop  bc
   ret

;;-----------------------------------------------------------------
;; Random_Range: Devuelve un numero pseudoaleatorio de 0 a B-1, con la misma probabilidad para todos
;;    Entrada: B = cuantos valores distintos (1 a 255)
;;    Salida: A = numero (0 a B-1)
;;    Destruye: A, flags (conserva C, DE y HL; B se conserva)
Random_Range::
.retry:
   call Random_Next
   cp   b
   jr   nc, .retry           ;; Si A >= B lo descartamos y probamos otra vez (asi no hay sesgo)
   ret
