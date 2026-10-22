;;-------------------------------------------------------------------------------------------------------------------------------;;
;; save.asm : Tabla de puntuaciones, guardada en la RAM del cartucho (SRAM, con bateria)
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; El cartucho declara MBC1 + RAM + BATERIA y 8 KB de RAM (header.asm), asi que lo que se escribe en $A000 sobrevive al apagar
;; la consola (en BGB se guarda en el archivo game.sav).
;; La tabla tiene SCORE_SLOTS entradas ordenadas de mayor a menor puntuacion. Cada una: [letra1, letra2, letra3, 5 cifras]
;; (letras 0-25 = A-Z; cifras 0-9, la mas significativa primero, como wScore). Una puntuacion 0 es un hueco vacio.
;; Formato en la SRAM:  [$4E, $54, tabla (64 bytes), control]   control = ((suma de todos los bytes anteriores) XOR $A5)
;; Si la marca o el control no cuadran (cartucho nuevo, RAM con basura o sin bateria), la tabla empieza vacia.
;; La SRAM solo se activa mientras se lee o se escribe, para que no se corrompa al apagar.
;; Las puntuaciones son el TOTAL de la pantalla de resultados (puntos + bonus de fases y corazones).
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

DEF SAVE_MAGIC0  EQU $4E
DEF SAVE_MAGIC1  EQU $54
DEF SAVE_XOR     EQU $A5
DEF SAVE_SUM0    EQU (SAVE_MAGIC0 + SAVE_MAGIC1) & $FF   ;; Valor inicial de la suma de control
DEF SAVE_SRAM_ON EQU $0A    ;; Escribir $0A en $0000-$1FFF activa la RAM del cartucho; cualquier otro valor la desactiva
DEF SAVE_TABLE_BYTES EQU SCORE_SLOTS * SCORE_ENTRY_SIZE

SECTION "Save Variables", WRAM0

wScores::     ds SAVE_TABLE_BYTES   ;; La tabla (copia en RAM de la que hay en la SRAM)
wFinalScore:: ds SCORE_DIGITS       ;; Total de la partida que acaba de terminar (puntos + bonus)
wNewPos::     db                    ;; Puesto de esa partida en la tabla (0 = primero); SCORE_SLOTS = no ha entrado

SECTION "Save", ROM0

;;-----------------------------------------------------------------
;; Save_Load: Lee la tabla de la SRAM a wScores (o la deja vacia si no es valida). Llamar al arrancar.
;;    Destruye: A, BC, DE, HL
Save_Load::
   ld   a, SAVE_SRAM_ON
   ld   [$0000], a
   ld   hl, _SRAM
   ld   a, [hl+]
   cp   SAVE_MAGIC0
   jr   nz, .invalid
   ld   a, [hl+]
   cp   SAVE_MAGIC1
   jr   nz, .invalid
   ld   b, SAVE_TABLE_BYTES
   ld   c, SAVE_SUM0
.sum:
   ld   a, [hl+]
   add  c
   ld   c, a
   dec  b
   jr   nz, .sum
   ld   a, [hl]              ;; Byte de control guardado
   ld   b, a
   ld   a, c
   xor  SAVE_XOR
   cp   b
   jr   nz, .invalid
   ld   hl, _SRAM + 2
   ld   de, wScores
   ld   b, SAVE_TABLE_BYTES
.copy:
   ld   a, [hl+]
   ld   [de], a
   inc  de
   dec  b
   jr   nz, .copy
   jr   .end
.invalid:
   ld   hl, wScores
   ld   bc, SAVE_TABLE_BYTES
   xor  a
   call MemSet
.end:
   xor  a
   ld   [$0000], a           ;; SRAM desactivada
   ret

;;-----------------------------------------------------------------
;; Save_Store: Escribe wScores en la SRAM
;;    Destruye: A, BC, DE, HL
Save_Store::
   ld   a, SAVE_SRAM_ON
   ld   [$0000], a
   ld   hl, _SRAM
   ld   a, SAVE_MAGIC0
   ld   [hl+], a
   ld   a, SAVE_MAGIC1
   ld   [hl+], a
   ld   de, wScores
   ld   b, SAVE_TABLE_BYTES
   ld   c, SAVE_SUM0
.copy:
   ld   a, [de]
   inc  de
   ld   [hl+], a
   add  c
   ld   c, a
   dec  b
   jr   nz, .copy
   ld   a, c
   xor  SAVE_XOR
   ld   [hl], a              ;; Byte de control
   xor  a
   ld   [$0000], a           ;; SRAM desactivada
   ret

;;-----------------------------------------------------------------
;; Save_Cmp5: Compara dos listas de 5 cifras
;;    Entrada: HL = lista A, DE = lista B
;;    Salida: Z = iguales; si no, NC = A mayor que B, C = A menor que B
;;    Destruye: A, B, HL, DE
Save_Cmp5:
   ld   b, SCORE_DIGITS
.loop:
   ld   a, [de]
   ld   c, a
   ld   a, [hl+]
   cp   c
   ret  nz
   inc  de
   dec  b
   jr   nz, .loop
   xor  a                    ;; Iguales: Z = 1
   ret

;;-----------------------------------------------------------------
;; Save_Update: Busca el puesto de wFinalScore en la tabla (un empate queda por debajo). Si entra: wNewPos = puesto, las
;;    entradas de debajo bajan un puesto, se escribe la nueva (nombre AAA) y se guarda en la SRAM. Si no, wNewPos = SCORE_SLOTS.
;;    Llamar al empezar la pantalla de resultados, con wFinalScore ya calculado.
;;    Destruye: A, BC, DE, HL
Save_Update::
   ld   a, SCORE_SLOTS
   ld   [wNewPos], a
   ld   c, 0                 ;; C = entrada que se mira
   ld   de, wScores + 3      ;; DE = cifras de esa entrada
.entry:
   push bc
   push de
   ld   hl, wFinalScore
   call Save_Cmp5
   pop  de
   pop  bc
   jr   z, .next             ;; Igual: queda por debajo
   jr   nc, .found           ;; Mayor: entra aqui
.next:
   ld   a, e
   add  SCORE_ENTRY_SIZE
   ld   e, a
   ld   a, d
   adc  0
   ld   d, a
   inc  c
   ld   a, c
   cp   SCORE_SLOTS
   jr   nz, .entry
   ret                       ;; No entra
.found:
   ld   a, c
   ld   [wNewPos], a
   ld   a, SCORE_SLOTS - 1
   sub  c                    ;; Entradas que hay que bajar: de la C a la penultima
   jr   z, .write
   add  a
   add  a
   add  a                    ;; * 8 bytes
   ld   b, a
   ld   hl, wScores + (SCORE_SLOTS - 1) * SCORE_ENTRY_SIZE - 1   ;; Ultimo byte de la penultima entrada
   ld   de, wScores + SCORE_SLOTS * SCORE_ENTRY_SIZE - 1         ;; Ultimo byte de la ultima
.move:                       ;; Copia hacia atras (los bloques se solapan)
   ld   a, [hl-]
   ld   [de], a
   dec  de
   dec  b
   jr   nz, .move
.write:
   ld   a, c
   add  a
   add  a
   add  a
   ld   e, a
   ld   d, 0
   ld   hl, wScores
   add  hl, de               ;; HL = la nueva entrada
   xor  a
   ld   [hl+], a             ;; Nombre AAA (se cambia despues en la pantalla de nombre)
   ld   [hl+], a
   ld   [hl+], a
   ld   de, wFinalScore
   ld   b, SCORE_DIGITS
.digits:
   ld   a, [de]
   inc  de
   ld   [hl+], a
   dec  b
   jr   nz, .digits
   jp   Save_Store
