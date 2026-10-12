;;-------------------------------------------------------------------------------------------------------------------------------;;
;; interrupts.asm : Interrupcion de VBlank y espera al siguiente fotograma
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "HRAM Interrupts", HRAM

hVBlankFlag:: db     ;; La interrupcion de VBlank lo pone a 1 en cada fotograma

;;-----------------------------------------------------------------
;; Vector de la interrupcion de VBlank ($0040). Solo hay 8 bytes de espacio, asi que saltamos a la rutina.
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
;;    Requiere interrupciones activadas (ei) y IE con VBlank habilitado
;;    Destruye: A
WaitVBlank::
.wait:
   halt
   nop                       ;; Tras un halt conviene un nop (evita el "halt bug")
   ldh  a, [hVBlankFlag]
   and  a
   jr   z, .wait             ;; Si nos desperto otra cosa, seguimos esperando
   xor  a
   ldh  [hVBlankFlag], a
   ret
