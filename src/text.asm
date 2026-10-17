;;-------------------------------------------------------------------------------------------------------------------------------;;
;; text.asm : Texto en pantalla, dibujado con sprites (fuente de src/sprites/font.z80: digitos 0-9 y letras A-Z)
;;-------------------------------------------------------------------------------------------------------------------------------;;
;; Cada caracter es un sprite de 8x8 con la paleta OBP1 (blanca): se usa sobre pantallas de fondo negro.
;; Con 40 sprites en total y 10 por linea, el texto debe ser corto (maximo 10 caracteres por linea).
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

;;--------------------------------------
;;-- Mapa de caracteres: en los "db" de abajo, cada letra/digito se convierte en el indice de su tile de la fuente
NEWCHARMAP texto
SETCHARMAP texto
CHARMAP " ", TILE_BLANK
DEF _n = 0
REPT 10
   CHARMAP STRSUB("0123456789", _n + 1, 1), TILE_FONT_DIGIT0 + _n
   DEF _n += 1
ENDR
DEF _n = 0
REPT 26
   CHARMAP STRSUB("ABCDEFGHIJKLMNOPQRSTUVWXYZ", _n + 1, 1), TILE_FONT_A + _n
   DEF _n += 1
ENDR

SECTION "Text", ROM0

;;--------------------------------------
;;-- Cadenas (terminan en TEXT_END; el espacio es el tile 0, que no se dibuja)
StrPhase:: db "FASE ", TEXT_END
StrWin::     db "VICTORIA", TEXT_END      ;; Pantalla de puntuacion (se dibujan en el fondo, ver results.asm)
StrLose::    db "GAME OVER", TEXT_END
StrPoints::  db "PUNTOS", TEXT_END
StrPhases::  db "FASES", TEXT_END
StrHearts::  db "CORAZONES", TEXT_END
StrTotal::   db "TOTAL", TEXT_END
StrPress::   db "PULSA START", TEXT_END

;;-----------------------------------------------------------------
;; Text_DrawChar: Escribe 1 caracter como sprite en la OAM en sombra
;;    Entrada: A = tile del caracter, B = X en pantalla, C = Y en pantalla (esquina superior izquierda),
;;             DE = direccion de la OAM en sombra donde escribir
;;    Salida: DE avanza al siguiente sprite. B y C no cambian.
;;    Destruye: A
Text_DrawChar::
   push af
   ld   a, c
   add  OAM_Y_OFFSET
   ld   [de], a              ;; Byte 0: Y
   inc  de
   ld   a, b
   add  OAM_X_OFFSET
   ld   [de], a              ;; Byte 1: X
   inc  de
   pop  af
   ld   [de], a              ;; Byte 2: tile
   inc  de
   ld   a, TEXT_ATTR
   ld   [de], a              ;; Byte 3: atributos (paleta OBP1)
   inc  de
   ret

;;-----------------------------------------------------------------
;; Text_DrawString: Escribe una cadena, un sprite por caracter (los espacios solo avanzan)
;;    Entrada: HL = cadena (acabada en TEXT_END), B = X del primer caracter, C = Y, DE = destino en la OAM en sombra
;;    Salida: B = X donde iria el siguiente caracter, DE avanza
;;    Destruye: A, HL
Text_DrawString::
.loop:
   ld   a, [hl+]
   cp   TEXT_END
   ret  z
   and  a
   jr   z, .skip             ;; Espacio: no gasta sprite
   call Text_DrawChar
.skip:
   ld   a, b
   add  TILE_SIZE
   ld   b, a
   jr   .loop
