;;-------------------------------------------------------------------------------------------------------------------------------;;
;; boss.asm : El jefe final, "Virus Madre" (fase BOSS_PHASE, tras las PHASE_COUNT fases con tiempo)
;;-------------------------------------------------------------------------------------------------------------------------------;;
;;   - Un virus gigante de 4x4 tiles (32x32 pixeles, 16 sprites). Sale por la parte de arriba (BOSS_STATE_ENTER: no se le puede hacer
;;     daño todavia), se queda en la parte superior moviendose de lado a lado (BOSS_STATE_FIGHT) y tiene BOSS_HP puntos de vida:
;;     una bala quita 1 y un misil MISSILE_DAMAGE. Al recibir un impacto parpadea.
;;   - Tocar al jefe cuesta una vida (con el escudo activo no pasa nada, pero el jefe tampoco sufre daño).
;;   - Sin vida: BOSS_STATE_DYING (parpadea y explota), luego BOSS_STATE_DONE y Game_Update pasa al fundido de la victoria.
;;   - Para usar las rutinas de colision de las celulas (Collide_Box) el jefe tiene una "celula" falsa, wBossBox, de tamaño 4.
;;   - Su vida se ve en el HUD como una barra de 2 tiles, en el hueco del cronometro (hud.asm).
;;   - La coordenada Y se guarda con un sesgo de BOSS_YBIAS (para poder salir desde arriba de la pantalla con numeros sin signo).
;;-------------------------------------------------------------------------------------------------------------------------------;;

INCLUDE "constants.inc"

SECTION "Boss Variables", WRAM0

wBossState::  db                   ;; BOSS_STATE_*
wBossHp::     db                   ;; Vida que le queda (0 a BOSS_HP)
wBossX::      db                   ;; X de su esquina superior izquierda
wBossYb::     db                   ;; Y de su esquina superior izquierda, mas BOSS_YBIAS
wBossDir:     db                   ;; 1 = va hacia la derecha, 0 = hacia la izquierda
wBossTick:    db                   ;; Contador de fotogramas (reparte su velocidad)
wBossFlash::  db                   ;; Fotogramas que le quedan de parpadeo (bit 1 a 1 = oculto)
wBossTimer:   db                   ;; Cuenta atras de su muerte
wBossStage:   db                   ;; Etapa (1 a 3), segun su vida
wBossSpawnT:  db                   ;; Fotogramas que faltan para soltar celulas
wBossBox:     ds ENEMY_SIZE        ;; "Celula" falsa para Collide_Box: [tipo, direccion, X, Y, tamaño]

SECTION "Boss", ROM0

;;-----------------------------------------------------------------
;; Boss_Init: No hay jefe (al empezar una fase)
;;    Destruye: A
Boss_Init::
   xor  a
   ld   [wBossState], a
   ld   [wBossFlash], a
   ld   [wBossHp], a
   ret

;;-----------------------------------------------------------------
;; Boss_Begin: Empieza la fase del jefe: lleno de vida y oculto justo encima de la pantalla (entrara cuando acabe el mensaje)
;;    Destruye: A
Boss_Begin::
   ld   a, BOSS_STATE_ENTER
   ld   [wBossState], a
   ld   a, BOSS_HP
   ld   [wBossHp], a
   ld   a, BOSS_START_X
   ld   [wBossX], a
   ld   a, BOSS_YB_START
   ld   [wBossYb], a
   ld   a, 1
   ld   [wBossDir], a
   ld   [wBossStage], a
   xor  a
   ld   [wBossTick], a
   ld   [wBossFlash], a
   ld   a, %01010101
   ld   [wMoveShift], a         ;; Las celulas que suelta van a 4/8 = 30 px/s
   ld   a, SPLIT_PATTERN
   ld   [wMoveShiftSplit], a
   ld   a, 1
   ld   [wBossBox], a           ;; Tipo distinto de 0
   ld   a, BOSS_TILES
   ld   [wBossBox + ENEMY_SIZE - 1], a
   ld   a, 1
   ld   [wHudDirty], a
   ret

;;-----------------------------------------------------------------
;; Boss_Update: Un fotograma del jefe (solo en la fase del jefe, despues de Enemies_Update)
;;    Destruye: A, BC, DE, HL
Boss_Update::
   ld   a, [wBossState]
   cp   BOSS_STATE_ENTER
   jr   z, .enter
   cp   BOSS_STATE_FIGHT
   jr   z, .fight
   cp   BOSS_STATE_DYING
   jp   z, .dying
   ret

.enter:                         ;; Baja 1 pixel cada 2 fotogramas hasta su sitio
   ld   a, [wBossTick]
   inc  a
   ld   [wBossTick], a
   and  %00000001
   ret  nz
   ld   a, [wBossYb]
   inc  a
   ld   [wBossYb], a
   cp   BOSS_YB_FIGHT
   ret  nz
   ld   a, BOSS_STATE_FIGHT
   ld   [wBossState], a
   xor  a
   ld   [wBossTick], a
   ld   a, BOSS_FIRST_SPAWN
   ld   [wBossSpawnT], a
   ret

.fight:
   ;;-- Movimiento lateral: 1 pixel cada BOSS_MOVE_FRAMES fotogramas, rebotando en los lados de la zona de juego
   ld   a, [wBossStage]
   cp   3
   ld   b, BOSS_MOVE_FRAMES
   jr   nz, .speed
   ld   b, BOSS_MOVE_FAST       ;; Etapa 3: se mueve mas rapido
.speed:
   ld   a, [wBossTick]
   inc  a
   ld   [wBossTick], a
   cp   b
   jr   c, .moved
   xor  a
   ld   [wBossTick], a
   ld   a, [wBossX]
   ld   b, a
   ld   a, [wBossDir]
   and  a
   ld   a, b
   jr   z, .left
   inc  a
   cp   BOSS_MAX_X
   jr   c, .store
   ld   a, BOSS_MAX_X
   ld   [wBossX], a
   xor  a
   ld   [wBossDir], a           ;; Rebota: ahora va a la izquierda
   jr   .moved
.left:
   dec  a
   cp   BOSS_MIN_X
   jr   nc, .store
   ld   a, BOSS_MIN_X
   ld   [wBossX], a
   ld   a, 1
   ld   [wBossDir], a
   jr   .moved
.store:
   ld   [wBossX], a
.moved:
   ;;-- La celula falsa sigue al jefe
   ld   a, [wBossX]
   ld   [wBossBox + 2], a
   ld   a, [wBossYb]
   sub  BOSS_YBIAS
   ld   [wBossBox + 3], a
   ;;-- Parpadeo del impacto
   ld   a, [wBossFlash]
   and  a
   jr   z, .noFlash
   dec  a
   ld   [wBossFlash], a
.noFlash:
   call Boss_CheckBullets
   ld   a, [wBossState]
   cp   BOSS_STATE_FIGHT
   ret  nz                      ;; Ha muerto en este fotograma
   call Boss_UpdateStage
   call Boss_Spawner
   jp   Boss_CheckPlayer

.dying:
   ld   a, [wBossTimer]
   dec  a
   ld   [wBossTimer], a
   ld   [wBossFlash], a         ;; (el parpadeo de Boss_Draw sigue la cuenta atras)
   jr   z, .done
   cp   BOSS_BURST_AT
   jr   z, .burst
   and  %00000111
   ret  nz                      ;; Una tanda de explosiones cada 8 fotogramas
   call Boss_RandomExplosion
   jp   Boss_RandomExplosion
.burst:                         ;; Explosion final: el jefe desaparece y salen explosiones por todo su cuerpo
   ld   a, FLASH_FRAMES * 2
   ld   [wFlash], a
   ld   b, 5
.burstLoop:
   push bc
   call Boss_RandomExplosion
   pop  bc
   dec  b
   jr   nz, .burstLoop
   ret
.done:
   ld   a, BOSS_STATE_DONE
   ld   [wBossState], a
   ret

;;-----------------------------------------------------------------
;; Boss_UpdateStage: Etapa segun la vida: 1 hasta BOSS_STAGE2_HP + 1, 2 hasta BOSS_STAGE3_HP + 1 y 3 despues. Al cambiar de etapa
;;    destella la pantalla, explotan las celulas que haya y el jefe descansa BOSS_STAGE_PAUSE fotogramas.
;;    Destruye: A, B, C, DE, HL
Boss_UpdateStage:
   ld   b, 1
   ld   a, [wBossHp]
   cp   BOSS_STAGE2_HP + 1
   jr   nc, .got
   inc  b
   cp   BOSS_STAGE3_HP + 1
   jr   nc, .got
   inc  b
.got:
   ld   a, [wBossStage]
   cp   b
   ret  z
   ld   a, b
   ld   [wBossStage], a
   ld   a, FLASH_FRAMES * 2
   ld   [wFlash], a
   ld   a, BOSS_STAGE_PAUSE
   ld   [wBossSpawnT], a
   jp   Enemies_Wipe

;;-----------------------------------------------------------------
;; Boss_Spawner: Cuenta atras para soltar celulas desde el cuerpo del jefe: una cada cierto tiempo (mas seguido en cada etapa) y,
;;    en la etapa 3, en rafagas de 2 o 3.
;;    Destruye: A, BC, DE, HL
Boss_Spawner:
   ld   a, [wBossSpawnT]
   dec  a
   ld   [wBossSpawnT], a
   ret  nz
   call Boss_SpawnOne
   ld   a, [wBossStage]
   cp   3
   jr   c, .next
   call Boss_SpawnOne           ;; Etapa 3: rafaga de 2 y, a veces, 3
   call Random_Next
   bit  0, a
   call nz, Boss_SpawnOne
   ld   a, BOSS_SPAWN_S3
   jr   .setTimer
.next:
   ld   a, [wBossStage]
   cp   2
   ld   a, BOSS_SPAWN_S1
   jr   nz, .setTimer
   ld   a, BOSS_SPAWN_S2
.setTimer:
   push af
   ld   b, BOSS_SPAWN_VAR
   call Random_Range
   ld   b, a
   pop  af
   add  b
   ld   [wBossSpawnT], a
   ret

;;-----------------------------------------------------------------
;; Boss_SpawnOne: Suelta una celula por debajo del cuerpo del jefe (si no se ha llegado al maximo de celulas de la etapa).
;;    Etapa 1: zigzag y normales. Etapas 2 y 3: normales, zigzag, agresivas y divisoras a partes iguales (respetando los maximos de
;;    cada tipo: si no caben, sale una normal). Salen hacia abajo o, si el jugador no esta debajo del jefe, hacia su lado.
;;    Destruye: A, BC, DE, HL
Boss_SpawnOne:
   call Enemies_Count
   ld   b, a
   ld   a, [wBossStage]
   cp   1
   ld   a, BOSS_CELLS_S1
   jr   z, .cap
   ld   a, BOSS_CELLS_MAX
.cap:
   cp   b
   ret  c
   ret  z                       ;; Ya hay el maximo
   ld   b, 100
   call Random_Range            ;; A = tirada 0..99
   ld   c, a
   ld   a, [wBossStage]
   cp   1
   ld   a, c
   jr   nz, .later
   cp   60                      ;; Etapa 1: 60 % zigzag, 40 % normal
   jr   c, .zig
   jr   .normal
.later:
   cp   25
   jr   c, .normal
   cp   50
   jr   c, .zig
   cp   75
   jr   c, .aggr
   ld   b, ENEMY_DIV
   call Enemies_CountType
   cp   MAX_DIV
   jr   nc, .normal
   ld   a, ENEMY_DIV
   ld   d, ENEMY_DIV_HP
   jr   .place
.aggr:
   ld   b, ENEMY_AGGR
   call Enemies_CountType
   cp   MAX_AGGR
   jr   nc, .normal
   ld   a, ENEMY_AGGR
   ld   d, ENEMY_AGGR_HP
   jr   .place
.zig:
   ld   b, ENEMY_ZIGZAG
   call Enemies_CountType
   cp   MAX_ZIG
   jr   nc, .normal
   ld   a, ENEMY_ZIGZAG
   ld   d, 1
   jr   .place
.normal:
   ld   a, ENEMY_NORMAL
   ld   d, 1
.place:                         ;; A = tipo, D = tamaño en tiles
   push af
   ld   a, d
   add  a
   add  a
   add  a
   ld   e, a                    ;; E = 8 * tamaño
   ld   a, DIR_DOWN
   ld   [wPlaceDir], a          ;; Por defecto la celula baja
   ;;-- Si el jugador esta a un lado del jefe (su centro fuera de la anchura del jefe), la celula sale por ese lado, a la altura
   ;;   del jugador (sin salirse de la altura del jefe): asi se interpone en sus disparos horizontales
   ld   a, [wPlayerX]
   add  TILE_SIZE / 2
   ld   b, a                    ;; B = centro X del jugador
   ld   a, [wBossX]
   cp   b
   jr   z, .notLeft
   jr   c, .notLeft             ;; El jefe esta a la izquierda del jugador
   ld   a, DIR_LEFT
   ld   [wPlaceDir], a
   ld   a, [wBossX]
   sub  e
   add  4
   ld   b, a                    ;; X: pegada al lado izquierdo del jefe, solapada 4 pixeles con el
   jr   .sideY
.notLeft:
   ld   a, [wBossX]
   add  BOSS_PIX
   cp   b
   jr   nc, .below              ;; El jugador no esta a la derecha del jefe: esta debajo
   ld   a, DIR_RIGHT
   ld   [wPlaceDir], a
   ld   a, [wBossX]
   add  BOSS_PIX - 4
   ld   b, a                    ;; X: pegada al lado derecho del jefe
.sideY:
   ld   a, e
   srl  a
   ld   d, a                    ;; D = mitad del tamaño de la celula
   ld   a, [wPlayerY]
   add  TILE_SIZE / 2
   sub  d
   ld   d, a                    ;; D = Y que centra la celula con la nave
   ld   a, [wBossYb]
   sub  BOSS_YBIAS
   ld   c, a                    ;; C = Y mas alta posible (parte alta del jefe)
   ld   a, d
   cp   c
   jr   nc, .minOk
   ld   d, c
.minOk:
   ld   a, c
   add  BOSS_PIX
   sub  e                       ;; A = Y mas baja posible (parte baja del jefe)
   cp   d
   jr   nc, .maxOk
   ld   d, a
.maxOk:
   ld   c, d
   pop  af
   jp   Enemies_Place
.below:
   ld   a, BOSS_PIX + 1
   sub  e
   ld   b, a                    ;; B = cuantas X distintas caben bajo el jefe
   call Random_Range            ;; (conserva C, DE y HL)
   ld   b, a
   ld   a, [wBossX]
   add  b
   ld   b, a                    ;; B = X
   ld   a, [wBossYb]
   sub  BOSS_YBIAS
   add  BOSS_PIX + 4
   sub  e
   ld   c, a                    ;; C = Y: la celula asoma por la parte de abajo del jefe
   pop  af
   jp   Enemies_Place

;;-----------------------------------------------------------------
;; Boss_RandomExplosion: Una explosion en un punto al azar del cuerpo del jefe
;;    Destruye: A, BC
Boss_RandomExplosion:
   ld   b, BOSS_PIX - TILE_SIZE + 1
   call Random_Range
   ld   c, a
   ld   a, [wBossX]
   add  c
   push af
   ld   b, BOSS_PIX - TILE_SIZE + 1
   call Random_Range
   ld   c, a
   ld   a, [wBossYb]
   sub  BOSS_YBIAS
   add  c
   ld   c, a
   pop  af
   ld   b, a
   jp   Explo_Spawn

;;-----------------------------------------------------------------
;; Boss_CheckBullets: Cada bala (o misil) que toca al jefe desaparece y le quita vida (1 la bala, MISSILE_DAMAGE el misil)
;;    Cada impacto cuenta como una baja mas del combo (Combo_Kill, BOSS_HIT_POINTS decenas).
;;    Destruye: A, BC, DE, HL
Boss_CheckBullets:
   ld   hl, wBossBox
   ld   de, wBullets
   ld   c, MAX_BULLETS
.loop:
   ld   a, [de]                 ;; Direccion de la bala
   and  a
   jr   z, .next                ;; Hueco libre
   inc  de                      ;; DE -> X de la bala
   call Collide_Box
   dec  de
   jr   nc, .next               ;; No chocan
   ld   a, [de]
   and  MISSILE_FLAG
   ld   b, 1                    ;; B = daño
   jr   z, .damage
   ld   b, MISSILE_DAMAGE
.damage:
   xor  a
   ld   [de], a                 ;; La bala desaparece
   ld   a, [wBossHp]
   sub  b
   jr   nc, .alive
   xor  a                       ;; (con menos vida que el daño: se queda en 0)
.alive:
   ld   [wBossHp], a
   ld   b, a                    ;; B = vida que queda
   ld   a, BOSS_FLASH_FRAMES
   ld   [wBossFlash], a
   ld   a, 1
   ld   [wHudDirty], a
   ld   a, BOSS_HIT_POINTS
   call Combo_Kill
   ld   a, b
   and  a
   jr   z, Boss_Die             ;; Sin vida: muere (y ya no se miran mas balas)
.next:
   REPT BULLET_SIZE
      inc  de
   ENDR
   dec  c
   jr   nz, .loop
   ret

;;-----------------------------------------------------------------
;; Boss_Die: El jefe se queda sin vida: explotan todas las celulas que queden, el jugador queda a salvo y empieza la agonia
;;    Destruye: A, BC, DE, HL
Boss_Die:
   ld   a, BOSS_STATE_DYING
   ld   [wBossState], a
   ld   a, BOSS_DYING_FRAMES
   ld   [wBossTimer], a
   ld   a, 255
   ld   [wInvuln], a            ;; Mientras muere no se puede perder ninguna vida
   call Enemies_Wipe
   ld   a, BOSS_KILL_POINTS
   call Combo_Kill
   ret

;;-----------------------------------------------------------------
;; Boss_CheckPlayer: Si el jefe toca al jugador, este pierde una vida (salvo con escudo o invulnerable)
;;    Destruye: A, BC, DE, HL
Boss_CheckPlayer:
   ld   a, [wShield]
   and  a
   ret  nz
   ld   a, [wInvuln]
   and  a
   ret  nz
   ld   hl, wBossBox
   ld   de, wPlayerX
   call Collide_Box
   ret  nc
   jp   Game_PlayerHit

;;-----------------------------------------------------------------
;; Boss_Draw: Escribe los 16 sprites del jefe (por filas). Las filas que aun estan por encima del marco superior no se dibujan:
;;    asi parece que sale desde detras del marco.
;;    Entrada: DE = destino en la OAM en sombra (avanza)
;;    Destruye: A, BC, HL
Boss_Draw::
   ld   a, [wBossState]
   and  a
   ret  z
   cp   BOSS_STATE_DYING
   jr   nz, .notDying
   ld   a, [wBossTimer]
   cp   BOSS_BURST_AT
   ret  c                       ;; Tras la explosion final ya no hay jefe
.notDying:
   ld   a, [wBossFlash]
   bit  1, a
   ret  nz                      ;; Fase oculta del parpadeo
   ld   h, 0                    ;; H = desplazamiento de la fila en pixeles
   ld   l, TILE_BOSS            ;; L = tile
.row:
   ld   a, [wBossYb]
   add  h
   cp   PLAY_MIN_Y + BOSS_YBIAS
   jr   c, .skipRow             ;; Esta fila aun esta por encima del marco
   sub  BOSS_YBIAS
   ld   c, a
   ld   a, [wBossX]
   ld   b, a
   REPT BOSS_TILES
      ld   a, l
      call Put_Sprite
      inc  l
      ld   a, b
      add  TILE_SIZE
      ld   b, a
   ENDR
   jr   .nextRow
.skipRow:
   ld   a, l
   add  BOSS_TILES
   ld   l, a
.nextRow:
   ld   a, h
   add  TILE_SIZE
   ld   h, a
   cp   BOSS_PIX
   jr   nz, .row
   ret
