;;-------------------------------------------------------------------------------------------------------------------------------;;
;; input.asm : Lectura del mando (cruceta y botones)
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "HRAM Input", HRAM

hInput::    db
hInputNew:: db

SECTION "Input", ROM0

;;-----------------------------------------------------------------
;; Input_Init: Deja el estado del mando a cero
Input_Init::
   xor  a
   ldh  [hInput], a
   ldh  [hInputNew], a
   ret

;;-----------------------------------------------------------------
;; Input_Read: Lee el mando y actualiza hInput y hInputNew
Input_Read::
   ld   a, P1F_GET_DPAD
   ldh  [rP1], a
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   and  $0F
   swap a
   ld   b, a

   ld   a, P1F_GET_BTN
   ldh  [rP1], a
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   and  $0F
   or   b
   cpl
   ld   b, a

   ;; Deseleccionamos el mando
   ld   a, P1F_GET_NONE
   ldh  [rP1], a

   ;; Recien pulsados = actual AND NOT(anterior)
   ldh  a, [hInput]
   cpl
   and  b
   ldh  [hInputNew], a

   ld   a, b
   ldh  [hInput], a
   ret
