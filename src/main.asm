;;----------LICENSE NOTICE-------------------------------------------------------------------------------------------------------;;
;;  This file is part of GBTelera: A Gameboy Development Framework                                                               ;;
;;  Copyright (C) 2024 ronaldo / Cheesetea / ByteRealms (@FranGallegoBR)                                                         ;;
;;                                                                                                                               ;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    ;;
;; files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy,    ;;
;; modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the         ;;
;; Softwareis furnished to do so, subject to the following conditions:                                                           ;;
;;                                                                                                                               ;;
;; The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.;;
;;                                                                                                                               ;;
;; THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          ;;
;; WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         ;;
;; COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   ;;
;; ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         ;;
;;-------------------------------------------------------------------------------------------------------------------------------;;

;;-------------------------------------------------------------------------------------------------------------------------------;;
;; main.asm : Punto de entrada, inicializacion y bucle principal del juego
;;
;; FASE 1: la nave del jugador aparece en pantalla y se mueve con la cruceta, dentro de un marco.
;; FASE 2: disparos (A: arriba y abajo, B: izquierda y derecha).
;; FASE 3: enemigos (celulas infectadas de tipo 1).
;; FASE 4: vidas, invulnerabilidad, puntuacion y HUD; fin de partida y reinicio con START.
;; FASE 5: la partida se divide en fases (niveles) de 1 minuto con dificultad creciente y pantalla de "FASE N" entre ellas.
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

DEF STACK_TOP EQU $E000      ;; La pila crece hacia abajo desde el final de la WRAM ($DFFF)

SECTION "Entry point", ROM0[$150]

main::
   di                        ;; Sin interrupciones mientras inicializamos
   ld   sp, STACK_TOP

   ;;--------------------------------------
   ;;-- Apagar la LCD (solo se puede apagar durante el VBlank)
.waitVBlank:
   ldh  a, [rLY]
   cp   SCREEN_H
   jr   c, .waitVBlank
   xor  a
   ldh  [rLCDC], a           ;; LCD apagada: ya podemos escribir libremente en VRAM

   ;;--------------------------------------
   ;;-- Preparar la VRAM
   ;;   La BIOS deja basura (el logo de Nintendo) en los tiles y en el mapa de fondo: lo borramos todo.
   ld   hl, _VRAM            ;; $8000-$97FF: datos de tiles
   ld   bc, $1800
   xor  a
   call MemSet

   ld   hl, _SCRN0           ;; $9800-$9BFF: mapa de fondo 0 (todo al tile 0, que esta vacio)
   ld   bc, $0400
   ld   a, TILE_BLANK
   call MemSet

   call Border_Draw          ;; Dibuja el marco de la pantalla sobre el mapa limpio

   xor  a
   ldh  [rSCX], a            ;; Sin scroll
   ldh  [rSCY], a

   call Sprites_LoadTiles

   ;;--------------------------------------
   ;;-- Paletas
   ld   a, PALETTE_DEFAULT
   ldh  [rBGP], a
   ldh  [rOBP0], a
   xor  a
   ldh  [rOBP1], a           ;; OBP1 (la usa el texto): todo blanco, para escribir en blanco sobre la pantalla negra

   ;;--------------------------------------
   ;;-- Inicializar los modulos del juego
   call Sprites_Init
   call Input_Init
   call Random_Init
   call Game_Start           ;; Partida nueva: jugador, vidas, puntuacion y pantalla de "FASE 1"
   call Hud_Update           ;; Dibuja el HUD ahora (LCD apagada: se puede escribir en VRAM)
   call Game_ApplyFade       ;; Paletas de arranque (la partida empieza con la pantalla en negro)
   call Game_Draw            ;; Para que el primer DMA ya lleve los sprites en su sitio

   ;;--------------------------------------
   ;;-- Encender la LCD y activar la interrupcion de VBlank
   ld   a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_OBJ8 | LCDCF_BG8000 | LCDCF_BG9800
   ldh  [rLCDC], a

   xor  a
   ldh  [rIF], a             ;; Descartamos interrupciones pendientes
   ld   a, IEF_VBLANK
   ldh  [rIE], a
   ei

   ;;--------------------------------------
   ;;-- Bucle principal: una vuelta por fotograma
.mainLoop:
   call WaitVBlank           ;; Dormimos hasta que empiece el VBlank
   call hOAMDMA              ;; Lo primero en el VBlank: copiar los sprites a la OAM real
   call Hud_Update           ;; Y, aun en el VBlank, redibujar el HUD si ha cambiado algo
   call Game_ApplyFade       ;; Y la paleta (los cambios de paleta tambien se hacen en el VBlank, si no se ve un corte)
   call Input_Read           ;; Leer el mando
   call Game_Update          ;; Estado de la partida: fases, jugador, balas, enemigos, choques y vidas
   call Game_Draw            ;; Escribir todos los sprites en la OAM en sombra
   jr   .mainLoop
