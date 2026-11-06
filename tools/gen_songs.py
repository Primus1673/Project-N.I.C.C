#!/usr/bin/env python3
"""Compone las 4 canciones del juego (Project N.I.C.C.) y genera src/music/songs.asm (formato hUGEDriver / RGBDS)
y docs/musica_hUGETracker.md (las mismas canciones en forma de tabla, para recrearlas a mano en hUGETracker).
Uso (desde la raiz del proyecto):  python3 tools/gen_songs.py
Cancion = velocidad + 4 canales (CH1 cuadrada, CH2 cuadrada, CH3 onda, CH4 ruido) + orden de patrones.
Cada patron tiene 64 filas (4 compases de 16 filas = semicorcheas)."""
import os, sys

NAMES = ['C_', 'C#', 'D_', 'D#', 'E_', 'F_', 'F#', 'G_', 'G#', 'A_', 'A#', 'B_']
SEMI = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

def nidx(name):
    """'A#4' / 'A4' / 'C_5' -> indice de nota hUGE (C_3 = 0)."""
    n = name.replace('_', '')
    s = SEMI[n[0]]
    rest = n[1:]
    if rest.startswith('#'):
        s += 1; rest = rest[1:]
    return (int(rest) - 3) * 12 + s

def nname(i):
    assert 0 <= i < 72, i
    return f"{NAMES[i % 12]}{3 + i // 12}"

# acordes: semitonos sobre la raiz
MAJ = [0, 4, 7, 12]
MIN = [0, 3, 7, 12]

def bass_bar(root, rhythm):
    """rhythm: 16 caracteres: r raiz, o octava, f quinta, . nada"""
    r = nidx(root)
    m = {'r': r, 'o': r + 12, 'f': r + 7}
    return [nname(m[c]) if c in m else None for c in rhythm]

def arp_bar(root, chord, pat):
    """pat: 16 caracteres 0-3 (nota del acorde) o ."""
    r = nidx(root)
    return [nname(r + chord[int(c)]) if c != '.' else None for c in pat]

def lead_bar(s):
    return [None if t == '.' else nname(nidx(t)) for t in s.split()]

def drum_bar(s):
    return [{'k': 'KICK', 's': 'SNARE', 'h': 'HAT'}.get(c) for c in s]

# notas de ruido (indice alto = agudo): bombo, caja, charles
NOISE = {'KICK': 'G_3', 'SNARE': 'C_5', 'HAT': 'E_6'}

def pat(bars, inst, noise=False):
    rows = []
    for b in bars:
        assert len(b) == 16, b
        for t in b:
            if t is None:
                rows.append(None)
            else:
                if noise:
                    rows.append((NOISE[t], {'KICK': 1, 'SNARE': 2, 'HAT': 3}[t]))
                else:
                    rows.append((t, inst))
    assert len(rows) == 64
    return rows

EMPTY = [None] * 64

# instrumentos compartidos: (sweep, NR11, NR12) cuadradas; (len, nivel, onda) onda; (NR42) ruido
DUTY = {1: (8, 0x80, 0xF6, 'LEAD 50% decae lento'),
        2: (8, 0x40, 0xB2, 'PLUCK 25% corto'),
        3: (8, 0x00, 0xD3, 'STAB 12.5% (jefe)'),
        4: (8, 0x80, 0xC4, 'LEAD2 50% medio')}
WAVE = {1: (0, 32, 0, 'BAJO onda 100%'), 2: (0, 64, 0, 'BAJO suave 50%')}
NOIS = {1: (0xF2, 'BOMBO'), 2: (0xD1, 'CAJA'), 3: (0x81, 'CHARLES')}

songs = {}

# ---------------- TITULO: La menor, misterioso (velocidad 7, ~128 bpm) ----------------
def song_title():
    chA = [('A_4', MIN), ('F_4', MAJ), ('C_4', MAJ), ('G_4', MAJ)]
    chB = [('A_4', MIN), ('F_4', MAJ), ('D_4', MIN), ('E_4', MAJ)]
    bsA = [('A_3', 'r.....r.o.r.....'), ('F_3', 'r.....r.o.r.....'), ('C_3', 'r.....r.o.r.....'), ('G_3', 'r.....r.o.r.....')]
    bsB = [('A_3', 'r.....r.o.r.....'), ('F_3', 'r.....r.o.r.....'), ('D_3', 'r.....r.o.r.....'), ('E_3', 'r...r.f.r.o.f...')]
    arpP = '0120210301202103'
    leadA = ['E5 . . . C5 . . . D5 . E5 . . . . .',
             'F5 . . . A5 . . . G5 . F5 . . . . .',
             'E5 . . . G5 . . . C6 . . . B5 . . .',
             'D5 . . . G5 . . . B5 . A5 . G5 . . .']
    leadB = ['A5 . . . E5 . . . C6 . . . A5 . . .',
             'A5 . G5 . F5 . . . A5 . . . . . . .',
             'D6 . . . C6 . . . A5 . . . F5 . . .',
             'E5 . G#5 . B5 . . . E6 . . . . . . .']
    P = {}
    P['ch1'] = {'LA': pat([lead_bar(x) for x in leadA], 1), 'LB': pat([lead_bar(x) for x in leadB], 1), 'XX': EMPTY}
    P['ch2'] = {'AA': pat([arp_bar(r, c, arpP) for r, c in chA], 2), 'AB': pat([arp_bar(r, c, arpP) for r, c in chB], 2)}
    P['ch3'] = {'BA': pat([bass_bar(r, p) for r, p in bsA], 1), 'BB': pat([bass_bar(r, p) for r, p in bsB], 1), 'XX': EMPTY}
    dl = [drum_bar('k.......k.......'), drum_bar('k.......k...h...')] * 2
    P['ch4'] = {'DL': pat(dl, 0, True), 'XX': EMPTY}
    order = [('XX', 'AA', 'XX', 'XX'), ('XX', 'AB', 'BA', 'XX'), ('LA', 'AA', 'BA', 'DL'),
             ('LB', 'AB', 'BB', 'DL'), ('LA', 'AA', 'BA', 'DL'), ('LB', 'AB', 'BB', 'DL')]
    return dict(speed=7, P=P, order=order)

# ---------------- JUEGO: Re menor, ritmico (velocidad 5, ~180 bpm) ----------------
def song_game():
    chA = [('D_4', MIN), ('A#3', MAJ), ('C_4', MAJ), ('D_4', MIN)]
    chB = [('D_4', MIN), ('G_3', MIN), ('A_3', MAJ), ('A_3', MAJ)]
    bsA = [('D_3', 'r.r.r.r.o.r.r.o.'), ('A#3', 'r.r.r.r.o.r.r.o.'), ('C_3', 'r.r.r.r.o.r.r.o.'), ('D_3', 'r.r.r.r.o.r.r.o.')]
    bsB = [('D_3', 'r.r.r.r.o.r.r.o.'), ('G_3', 'r.r.r.r.o.r.r.o.'), ('A_3', 'r.r.r.r.o.r.r.o.'), ('A_3', 'r.r.f.f.o.f.r.o.')]
    arpP = '0102010201020123'
    leadA = ['D5 . F5 . A5 . . . G5 . F5 . D5 . . .',
             'D5 . F5 . A#5 . . . A5 . F5 . D5 . . .',
             'E5 . G5 . C6 . . . B5 . G5 . E5 . . .',
             'F5 . A5 . D6 . . . C6 . A5 . F5 . . .']
    leadB = ['A5 . . A5 . . A5 . F5 . . F5 . . D5 .',
             'G5 . . G5 . . G5 . A#5 . . A5 . . G5 .',
             'A5 . . A5 . C#6 . . E6 . . . D6 . C#6 .',
             'D6 . . . A5 . . . E5 . . . A5 . . .']
    P = {}
    P['ch1'] = {'LA': pat([lead_bar(x) for x in leadA], 4), 'LB': pat([lead_bar(x) for x in leadB], 1), 'XX': EMPTY}
    P['ch2'] = {'AA': pat([arp_bar(r, c, arpP) for r, c in chA], 2), 'AB': pat([arp_bar(r, c, arpP) for r, c in chB], 2)}
    P['ch3'] = {'BA': pat([bass_bar(r, p) for r, p in bsA], 1), 'BB': pat([bass_bar(r, p) for r, p in bsB], 1)}
    d = [drum_bar('k.h.s.h.k.k.s.h.')] * 3 + [drum_bar('k.h.s.h.k.k.s.sh')]
    P['ch4'] = {'DA': pat(d, 0, True), 'XX': EMPTY}
    order = [('XX', 'AA', 'BA', 'DA'), ('LA', 'AA', 'BA', 'DA'), ('LB', 'AB', 'BB', 'DA'),
             ('LA', 'AA', 'BA', 'DA'), ('LB', 'AB', 'BB', 'DA')]
    return dict(speed=5, P=P, order=order)

# ---------------- JEFE: Mi frigio, amenazante (velocidad 5) ----------------
def song_boss():
    chA = [('E_4', MIN), ('F_4', MAJ), ('E_4', MIN), ('B_3', MAJ)]
    bs = [('E_3', 'rrr.rr.rrr.rr.rr'), ('F_3', 'rrr.rr.rrr.rr.rr'), ('E_3', 'rrr.rr.rrr.rr.rr'), ('B_3', 'rrr.rr.rrr.rr.ro')]
    arpP = '0120120120120120'
    leadA = ['E5 . . E5 . . F5 . . E5 . . B4 . . .',
             'F5 . . F5 . . G5 . . F5 . . C5 . . .',
             'E5 . . E5 . . B5 . . A#5 . . E5 . . .',
             'B5 . . A#5 . . A5 . . G#5 . . B5 . . .']
    leadB = ['E6 . . . B5 . . . E6 . . . F6 . . .',
             'C6 . . . A5 . . . F5 . . . A5 . . .',
             'E6 . . . D#6 . . . E6 . . . B5 . . .',
             'F6 . E6 . D#6 . D6 . C#6 . C6 . B5 . . .']
    # compases con 16 tokens exactos
    leadB[3] = 'F6 . E6 . D#6 . D6 . C#6 . C6 . B5 . . .'
    P = {}
    P['ch1'] = {'LA': pat([lead_bar(x) for x in leadA], 3), 'LB': pat([lead_bar(x) for x in leadB], 1), 'XX': EMPTY}
    P['ch2'] = {'AA': pat([arp_bar(r, MIN if c == MIN else MAJ, arpP) for r, c in chA], 2)}
    P['ch3'] = {'BA': pat([bass_bar(r, p) for r, p in bs], 1)}
    dA = [drum_bar('k..hk.hsk..hk.hs')] * 3 + [drum_bar('k..hk.hsk.hsksks')]
    dB = [drum_bar('k.hhs.hhk.hhs.sh')] * 4
    P['ch4'] = {'DA': pat(dA, 0, True), 'DB': pat(dB, 0, True), 'XX': EMPTY}
    order = [('XX', 'AA', 'BA', 'DA'), ('LA', 'AA', 'BA', 'DA'), ('LB', 'AA', 'BA', 'DB'), ('LA', 'AA', 'BA', 'DA')]
    return dict(speed=5, P=P, order=order)

# ---------------- VICTORIA: Do mayor, fanfarria (velocidad 5) ----------------
def song_victory():
    ch = [('C_4', MAJ), ('F_4', MAJ), ('G_4', MAJ), ('C_4', MAJ)]
    bs = [('C_3', 'r...r...o...r...'), ('F_3', 'r...r...o...r...'), ('G_3', 'r...r...o...r...'), ('C_3', 'r...............')]
    arpP = '0123210301232103'
    lead = ['G4 . . . C5 . . . E5 . . . G5 . . .',
            'A5 . . . . . G5 . F5 . . . A5 . . .',
            'G5 . . . D5 . . . B4 . D5 . G5 . . .',
            'C6 . . . . . . . . . . . . . . .']
    P = {}
    P['ch1'] = {'LA': pat([lead_bar(x) for x in lead], 1)}
    P['ch2'] = {'AA': pat([arp_bar(r, c, arpP) for r, c in ch], 2)}
    P['ch3'] = {'BA': pat([bass_bar(r, p) for r, p in bs], 1)}
    P['ch3']['BA'][52] = 'CUT'   # efecto E (corte de nota): el bajo se apaga antes del final y la cancion muere sola
    d = [drum_bar('k...s...k...s...')] * 3 + [drum_bar('k...............')]
    P['ch4'] = {'DA': pat(d, 0, True)}
    order = [('LA', 'AA', 'BA', 'DA')]
    return dict(speed=5, P=P, order=order)

songs = {'song_title': song_title(), 'song_game': song_game(), 'song_boss': song_boss(), 'song_victory': song_victory()}

def dn(cell):
    if cell == 'CUT':
        return ' dn ___,0,$E01'
    if cell is None:
        return ' dn ___,0,$000'
    n, i = cell
    return f' dn {n},{i},$000'

def emit(name, s):
    L = []
    pre = name[5:] + '_'
    chn = ['ch1', 'ch2', 'ch3', 'ch4']
    L += [f'{name}::', f'db {s["speed"]}', f'dw {pre}order_cnt', f'dw {pre}o1, {pre}o2, {pre}o3, {pre}o4',
          f'dw {pre}duty, {pre}wave, {pre}noise', f'dw {pre}routines', f'dw {pre}waves', '']
    L += [f'{pre}order_cnt: db {len(s["order"]) * 2}']
    for ci, c in enumerate(chn):
        L.append(f'{pre}o{ci + 1}: dw ' + ','.join(f'{pre}{c}_{st[ci]}' for st in s['order']))
    L.append('')
    for c in chn:
        for pn, rows in s['P'][c].items():
            if not any(st[chn.index(c)] == pn for st in s['order']):
                continue
            L.append(f'{pre}{c}_{pn}:')
            L += [dn(r) for r in rows]
    L += ['', f'{pre}duty:']
    for k in sorted(DUTY):
        sw, l, e, _ = DUTY[k]
        L += [f'db {sw}', f'db ${l:02X}', f'db ${e:02X}', 'dw 0', 'db 128']
    L += ['', f'{pre}wave:']
    for k in sorted(WAVE):
        ln, lv, w, _ = WAVE[k]
        L += [f'db {ln}', f'db {lv}', f'db {w}', 'dw 0', 'db 128']
    L += ['', f'{pre}noise:']
    for k in sorted(NOIS):
        L += [f'db ${NOIS[k][0]:02X}', 'dw 0', 'db 0', 'ds 2']
    L += ['', f'{pre}routines:', f'{pre}r0: ret', 'dw ' + ','.join([f'{pre}r0'] * 16), '',
          f'{pre}waves:', 'db 0,17,34,51,68,85,102,119,136,153,170,187,204,221,238,255', '']
    return L

out = ['; songs.asm - GENERADO por tools/gen_songs.py (no editar a mano). Musica original, compuesta con IA (Claude).',
       'include "include/hUGE.inc"', '', 'SECTION "Songs", ROMX', '']
for n, s in songs.items():
    out += emit(n, s)
os.makedirs('src/music', exist_ok=True)
v = songs['song_victory']
open('src/music/song_lengths.inc', 'w').write(
    '; GENERADO por tools/gen_songs.py: duracion de la victoria (suena una sola vez): filas * ticks por fila * pasos\n'
    f'DEF MUSIC_VICTORY_FRAMES EQU {64 * v["speed"] * len(v["order"])}\n')
open('src/music/songs.asm', 'w').write('\n'.join(out) + '\n')

# ---- documento para hUGETracker ----
def tk(r):
    if r == 'CUT': return 'CUT'
    if not r: return '...'
    return f"{r[0].replace('_', '-')}:{r[1]}"
D = ['# Música original del juego y cómo recrearla en hUGETracker', '',
     'Las 4 canciones (título, partida, jefe y victoria) están compuestas con IA (Claude) y generadas por `tools/gen_songs.py`',
     'en formato hUGEDriver. Este documento las describe como las verías en hUGETracker para que puedas recrearlas o retocarlas.', '',
     '## Instrumentos (iguales en las 4 canciones)', '',
     'Duty (CH1 y CH2): nº / duty / volumen inicial y decaimiento (NR12)', '']
for k in sorted(DUTY):
    sw, l, e, nm = DUTY[k]
    D.append(f'- {k}: {nm}. Duty {["12.5%","25%","50%","75%"][l >> 6]}, volumen {e >> 4}, decae (dirección bajar), periodo {e & 7}, sin sweep, longitud desactivada')
D += ['', 'Wave (CH3): onda en diente de sierra suave (16 valores 0,17,34,...,255 = rampa)', '']
for k in sorted(WAVE):
    D.append(f'- {k}: {WAVE[k][3]}, volumen {["mudo","100%","50%","25%"][WAVE[k][1] >> 5]}')
D += ['', 'Noise (CH4): ancho 15 bits, sin longitud', '']
for k in sorted(NOIS):
    D.append(f'- {k}: {NOIS[k][1]}, volumen {NOIS[k][0] >> 4}, periodo de decaimiento {NOIS[k][0] & 7}')
D += ['', 'Batería (CH4): bombo = nota G-3 con instrumento 1, caja = C-5 con instrumento 2, charles = E-6 con instrumento 3.', '',
      '## Cómo recrear una canción en hUGETracker', '',
      '1. File → New. En *Song settings* pon el **ticks per row** que indica cada canción (los patrones tienen 64 filas).',
      '2. Define los instrumentos de arriba en las pestañas Duty/Wave/Noise (mismos números).',
      '3. En la lista de órdenes (Order list) crea tantos pasos como indica cada canción; cada paso asigna un patrón a CH1..CH4.',
      '4. Escribe cada patrón fila a fila: la notación `NOTA:instrumento` (p. ej. `E-5:1`) significa nota e instrumento; `...` es celda vacía.',
      '   Cada línea de abajo es un compás de 16 filas; un patrón son 4 líneas seguidas. No se usan efectos.',
      '5. Para meterla en el juego: File → Export → RGBDS .asm, y sustituir la canción en `src/music/` y su entrada en `SongTable` de `src/music.asm`.', '']
for n, sg in songs.items():
    D += [f'## {n}  (ticks por fila = {sg["speed"]}; {len(sg["order"])} pasos)', '', 'Orden (paso: CH1 / CH2 / CH3 / CH4; XX = patrón vacío):', '']
    for i, st in enumerate(sg['order']):
        D.append(f'- {i}: ' + ' / '.join(st))
    D.append('')
    for ci, c in enumerate(['ch1', 'ch2', 'ch3', 'ch4']):
        for pn, rows in sg['P'][c].items():
            if pn == 'XX' or not any(st[ci] == pn for st in sg['order']):
                continue
            D.append(f'### {n} · {c.upper()} · patrón {pn}')
            D.append('```')
            for b in range(4):
                D.append(' '.join(tk(r).ljust(5) for r in rows[b * 16:(b + 1) * 16]).rstrip())
            D.append('```')
            D.append('')
os.makedirs('docs', exist_ok=True)
open('docs/musica_hUGETracker.md', 'w').write('\n'.join(D) + '\n')
print('ok', {k: len(v['order']) for k, v in songs.items()})
