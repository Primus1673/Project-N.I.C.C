;;-------------------------------------------------------------------------------------------------------------------------------;;
;; text.asm : Texto en pantalla, dibujado con sprites (fuente de src/sprites/font.z80: digitos 0-9 y letras A-Z)
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "core/constants.inc"

;;--------------------------------------
;; -- Mapa de caracteres: en los "db" de abajo
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

SECTION "Text Variables", WRAM0

wTextDark:: db

SECTION "Text", ROM0

;;--------------------------------------
;; -- Cadenas (terminan en TEXT_END; el espacio es el tile 0, que no se dibuja)
StrPhase:: db "FASE ", TEXT_END
StrBoss::  db "JEFE", TEXT_END
StrPaused:: db "PAUSA", TEXT_END
StrWin::     db "VICTORIA", TEXT_END
StrLose::    db "GAME OVER", TEXT_END
StrPoints::  db "PUNTOS", TEXT_END
StrPhases::  db "FASES", TEXT_END
StrHearts::  db "BATERIAS", TEXT_END
StrTotal::   db "TOTAL", TEXT_END
StrPress::   db "PULSA START", TEXT_END
StrInfection:: db "INFECCION", TEXT_END
StrEradicated:: db "ERRADICADA", TEXT_END
StrRecord::  db "RECORD", TEXT_END
StrNewRecord:: db "NUEVO RECORD", TEXT_END
StrPlace::   db "PUESTO", TEXT_END
StrName::    db "NOMBRE", TEXT_END
StrPlay::    db "JUGAR", TEXT_END
StrScores::  db "PUNTUACIONES", TEXT_END

;;-----------------------------------------------------------------
;; Text_DrawChar: Escribe 1 caracter como sprite en la OAM en sombra
Text_DrawChar::
   push af
   ld   a, c
   add  OAM_Y_OFFSET
   ld   [de], a
   inc  de
   ld   a, b
   add  OAM_X_OFFSET
   ld   [de], a
   inc  de
   pop  af
   ld   [de], a
   inc  de
   ld   a, [wTextDark]
   and  a
   ld   a, TEXT_ATTR
   jr   z, .attr
   xor  a
.attr:
   ld   [de], a
   inc  de
   ret

;;-----------------------------------------------------------------
;; Text_DrawString: Escribe una cadena, un sprite por caracter (los espacios solo avanzan)
Text_DrawString::
.loop:
   ld   a, [hl+]
   cp   TEXT_END
   ret  z
   and  a
   jr   z, .skip
   call Text_DrawChar
.skip:
   ld   a, b
   add  TILE_SIZE
   ld   b, a
   jr   .loop
