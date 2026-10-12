;;-------------------------------------------------------------------------------------------------------------------------------;;
;; input.asm : Lectura del mando (cruceta y botones)
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "HRAM Input", HRAM

hInput::    db       ;; Botones pulsados ahora        (bit a 1 = pulsado, ver BTNB_* en constants.inc)
hInputNew:: db       ;; Botones recien pulsados en este fotograma (para disparos, menus, etc.)

SECTION "Input", ROM0

;;-----------------------------------------------------------------
;; Input_Init: Deja el estado del mando a cero
;;    Destruye: A
Input_Init::
   xor  a
   ldh  [hInput], a
   ldh  [hInputNew], a
   ret

;;-----------------------------------------------------------------
;; Input_Read: Lee el mando y actualiza hInput y hInputNew
;;    Formato: nibble alto = cruceta (Abajo, Arriba, Izq, Der), nibble bajo = (Start, Select, B, A)
;;    Destruye: A, B, C
Input_Read::
   ;; Leemos la cruceta (la linea P14 a 0 selecciona la cruceta)
   ld   a, P1F_GET_DPAD
   ldh  [rP1], a
   ldh  a, [rP1]             ;; Varias lecturas: las lineas del mando tardan en estabilizarse
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   and  $0F
   swap a                    ;; La cruceta pasa al nibble alto
   ld   b, a

   ;; Leemos los botones (la linea P15 a 0 selecciona los botones)
   ld   a, P1F_GET_BTN
   ldh  [rP1], a
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   ldh  a, [rP1]
   and  $0F
   or   b                    ;; A = cruceta | botones (en el hardware, 0 = pulsado)
   cpl                       ;; Invertimos: ahora 1 = pulsado
   ld   b, a                 ;; B = estado actual

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
