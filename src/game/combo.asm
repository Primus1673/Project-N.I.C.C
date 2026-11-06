;;-------------------------------------------------------------------------------------------------------------------------------;;
;; combo.asm : Combo de bajas con multiplicador de puntos
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

SECTION "Combo Variables", WRAM0

wCombo::         db
wMult::          db
wComboTimerLo:   db
wComboTimerHi:   db
wComboShow::     db
wComboBlink:     db

SECTION "Combo", ROM0

;;-----------------------------------------------------------------
;; Combo_Reset: Rompe la cadena: 0 bajas, multiplicador x1, sin cuenta atras
Combo_Reset::
   xor  a
   ld   [wCombo], a
   ld   [wComboTimerLo], a
   ld   [wComboTimerHi], a
   ld   [wComboBlink], a
   inc  a
   ld   [wMult], a
   ld   [wComboShow], a
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Combo_Kill: Se ha matado una celula a tiro
Combo_Kill::
   push bc
   push de
   push hl
   ld   b, a

   ;;-- Una baja mas (satura en 255)
   ld   a, [wCombo]
   inc  a
   jr   nz, .store
   dec  a
.store:
   ld   [wCombo], a

   ld   c, 1
.div:
   sub  COMBO_STEP
   jr   c, .divDone
   inc  c
   jr   .div
.divDone:
   ld   a, c
   cp   COMBO_MAX_MULT + 1
   jr   c, .multOk
   ld   a, COMBO_MAX_MULT
.multOk:
   ld   [wMult], a

   ;;-- Cuenta atras completa y "X" visible
   ld   c, a
   ld   a, LOW(COMBO_FRAMES)
   ld   [wComboTimerLo], a
   ld   a, HIGH(COMBO_FRAMES)
   ld   [wComboTimerHi], a
   ld   a, 1
   ld   [wComboShow], a

   ;;-- Puntos = base * multiplicador (suma repetida)
   xor  a
.mul:
   add  b
   dec  c
   jr   nz, .mul
   call Score_AddTens

   pop  hl
   pop  de
   pop  bc
   ret

;;-----------------------------------------------------------------
;; Combo_Update: Un fotograma de combo: cuenta atras y parpadeo
Combo_Update::
   ld   a, [wCombo]
   and  a
   ret  z

   ;;-- Cuenta atras (16 bits)
   ld   a, [wComboTimerLo]
   ld   l, a
   ld   a, [wComboTimerHi]
   ld   h, a
   dec  hl
   ld   a, h
   ld   [wComboTimerHi], a
   ld   a, l
   ld   [wComboTimerLo], a
   or   h
   jr   z, Combo_Reset

   ld   a, h
   and  a
   jr   nz, .steady
   ld   a, l
   cp   COMBO_WARN_FRAMES
   jr   nc, .steady

   ld   a, [wComboBlink]
   dec  a
   ld   [wComboBlink], a
   ret  nz
   ld   a, [wComboShow]
   xor  1
   ld   [wComboShow], a
   ld   a, 1
   ld   [wHudDirty], a
   ld   a, l
   srl  a
   srl  a
   srl  a
   cp   COMBO_BLINK_MIN
   jr   nc, .reload
   ld   a, COMBO_BLINK_MIN
.reload:
   ld   [wComboBlink], a
   ret

.steady:
   ld   a, 1
   ld   [wComboBlink], a
   ld   a, [wComboShow]
   and  a
   ret  nz
   ld   a, 1
   ld   [wComboShow], a
   ld   [wHudDirty], a
   ret
