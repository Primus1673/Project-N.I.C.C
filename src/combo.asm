;;-------------------------------------------------------------------------------------------------------------------------------;;
;; combo.asm : Combo de bajas con multiplicador de puntos
;;-------------------------------------------------------------------------------------------------------------------------------;;
;;   - Cada baja a tiro suma 1 a la cadena (wCombo) y reinicia la cuenta atras de COMBO_FRAMES (7 s).
;;   - Multiplicador = 1 + wCombo / COMBO_STEP, con tope COMBO_MAX_MULT: x1 (0-2 bajas), x2 (3-5), x3 (6-8), x4 (9-11), x5 (12+).
;;   - La cadena se rompe (Combo_Reset) si se acaba la cuenta atras o si el jugador recibe un golpe.
;;   - La cuenta atras solo avanza en Combo_Update, que se llama unicamente mientras se juega: en las pantallas de
;;     "FASE N" (y en los fundidos) el tiempo del combo queda detenido, y la cadena se mantiene al cambiar de fase: el combo
;;     tambien se congela durante el mensaje de cambio de fase y hasta la primera celula de la fase nueva (game.asm, wComboHold).
;;   - En el HUD se ve "X<multiplicador>" (a partir de x2). Cuando quedan menos de COMBO_WARN_FRAMES fotogramas parpadea,
;;     con un semiperiodo proporcional al tiempo que queda (T/8, minimo COMBO_BLINK_MIN): cada vez mas rapido hasta 0.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Combo Variables", WRAM0

wCombo::         db     ;; Bajas seguidas de la cadena actual (satura en 255)
wMult::          db     ;; Multiplicador actual (1 a COMBO_MAX_MULT)
wComboTimerLo:   db     ;; Fotogramas que quedan para que se rompa la cadena (16 bits)
wComboTimerHi:   db
wComboShow::     db     ;; 1 = el "X3" se ve en el HUD, 0 = fase oculta del parpadeo
wComboBlink:     db     ;; Cuenta atras hasta el proximo cambio de fase del parpadeo

SECTION "Combo", ROM0

;;-----------------------------------------------------------------
;; Combo_Reset: Rompe la cadena: 0 bajas, multiplicador x1, sin cuenta atras
;;    Destruye: A
Combo_Reset::
   xor  a
   ld   [wCombo], a
   ld   [wComboTimerLo], a
   ld   [wComboTimerHi], a
   ld   [wComboBlink], a
   inc  a                    ;; A = 1
   ld   [wMult], a
   ld   [wComboShow], a
   ld   [wHudDirty], a       ;; Hay que redibujar el HUD (para borrar el "X3")
   ret

;;-----------------------------------------------------------------
;; Combo_Kill: Se ha matado una celula a tiro: suma la baja a la cadena y los puntos con el multiplicador resultante
;;    Entrada: A = puntos base de la celula, en DECENAS (1 = 10 puntos)
;;    Conserva BC, DE y HL
Combo_Kill::
   push bc
   push de
   push hl
   ld   b, a                 ;; B = puntos base (decenas)

   ;;-- Una baja mas (satura en 255)
   ld   a, [wCombo]
   inc  a
   jr   nz, .store
   dec  a                    ;; Habia 255: se queda en 255
.store:
   ld   [wCombo], a

   ;;-- Multiplicador = 1 + bajas / COMBO_STEP, con tope
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
   ld   c, a                 ;; C = multiplicador
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
   call Score_AddTens        ;; (tambien marca el HUD para redibujar)

   pop  hl
   pop  de
   pop  bc
   ret

;;-----------------------------------------------------------------
;; Combo_Update: Un fotograma de combo: cuenta atras y parpadeo. LLAMAR SOLO MIENTRAS SE JUEGA (STATE_PLAYING).
;;    Destruye: A, HL
Combo_Update::
   ld   a, [wCombo]
   and  a
   ret  z                    ;; No hay cadena

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
   jr   z, Combo_Reset       ;; Se acabo el tiempo: la cadena se rompe

   ;;-- Parpadeo: solo en el ultimo tramo (menos de COMBO_WARN_FRAMES fotogramas)
   ld   a, h
   and  a
   jr   nz, .steady          ;; Quedan 256 o mas
   ld   a, l
   cp   COMBO_WARN_FRAMES
   jr   nc, .steady

   ld   a, [wComboBlink]
   dec  a
   ld   [wComboBlink], a
   ret  nz                   ;; Aun no toca cambiar de fase
   ld   a, [wComboShow]
   xor  1                    ;; Alterna visible / oculto
   ld   [wComboShow], a
   ld   a, 1
   ld   [wHudDirty], a
   ;; Semiperiodo siguiente = T / 8 (minimo COMBO_BLINK_MIN): cuanto menos tiempo queda, mas rapido parpadea
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

.steady:                     ;; Tiempo de sobra: el "X3" fijo y visible; el contador queda listo para disparar el primer cambio
   ld   a, 1
   ld   [wComboBlink], a
   ld   a, [wComboShow]
   and  a
   ret  nz
   ld   a, 1
   ld   [wComboShow], a
   ld   [wHudDirty], a
   ret
