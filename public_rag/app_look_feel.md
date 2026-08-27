# Look & feel — Cara o Cruz

Guía de estilo aplicada a la app. Es la fuente de verdad para paleta,
tipografía, materiales e interacción — cualquier cambio visual debería
actualizar este archivo en el mismo commit.

Origen: propuesta generada con `ui-ux-pro-max` (paletas P1/P2, material E1/E2,
tipografía T1/T2, historial L1/L2), revisada y recortada por el usuario el
2026-08-26. Selección aplicada: **P1+P2 condicionados por cara, E2, T1, H2,
H4, L2**. `H1`, `H3`, `E1`, `L1` y `T2` quedaron fuera (T2 documentado abajo
para una futura implementación).

Pasadas siguientes, mismo día:

1. Se reemplazó el placeholder cuadrado por una moneda circular con
   sombreado metálico y se extendió la paleta condicional al fondo de la
   app — ver "Assets de la moneda" y "Fondo condicional" más abajo.
2. Se corrigió el squish de los frames de giro (era horizontal, pasó a
   vertical) y se agregó `.gitattributes` marcando los PNG como binarios,
   para blindarlos contra corrupción por conversión de saltos de línea de
   git en Windows (`core.autocrlf`) — ver "Assets de la moneda".
3. El acento de CRUZ (P2) volvió al índigo/teal original de la propuesta,
   revirtiendo el acero neutro de una iteración intermedia — ver la nota de
   diseño en "Paleta condicional" más abajo.

## Principio rector

La app se mantiene **Cupertino oscuro** (sin Material, sin fuentes de Google
Fonts): el acento no reemplaza el sistema, lo tiñe. El color y el material
cambian según **qué cara de la moneda está resultando en pantalla** — no hay
un tema global fijo, hay dos identidades que se activan una a la vez.

## Paleta condicional (P1 / P2)

Implementada en `CoinPalette` (`lib/core/theme.dart`), seleccionada vía
`CoinPalette.forResult(FlipResult?)`.

| Cara | Nombre | `accent` | `accentHighlight` | Uso |
|---|---|---|---|---|
| **CARA** | Oro y Grafito (P1) | `#D6AD60` | `#F0D698` | moneda `cara.png`, borde/glow del `_GlassLabel`, punto + borde del chip de historial cuando `record.result == 'cara'` |
| **CRUZ** | Índigo Nocturno (P2) | `#7B7BEA` | `#38C9BB` | moneda `cruz.png`, borde/glow del `_GlassLabel`, punto + borde del chip de historial cuando `record.result == 'cruz'` |

Nota de diseño: P2 pasó por dos versiones el mismo día. La propuesta
original era este índigo/teal saturado; se cambió después a un acero más
neutro (`#8FA3C2`/`#C7D2E0`) porque el usuario pidió que CRUZ se sintiera
"azul, plateado, metálico". Al ver el resultado en pantalla, el usuario
volvió a pedir explícitamente el índigo original (imagen de referencia con
los hex `#0B0B12` `#1C1A30` `#7B7BEA` `#38C9BB`) — **esta es la versión
vigente**. El acero neutro no quedó documentado como alternativa; si hace
falta retomarlo, es `accent: #8FA3C2` / `accentHighlight: #C7D2E0`.

`glassTint` (`accent` @ 18% alpha) y `glassBorder` (`accent` @ 45% alpha) se
derivan del `accent` en tiempo de uso — no se guardan como constantes
aparte.

### Fondo condicional

`CoinPalette` también trae `backgroundTop`/`backgroundBottom`: un degradado
vertical Cupertino oscuro (más claro arriba, más oscuro abajo) que reemplazó
el `AppTheme.darkBackground` (`#1C1C1E`) fijo. Se aplica en `CoinScreen.build`
con un `AnimatedContainer` (500ms, `Curves.easeInOut`) que envuelve el
`SafeArea` — el `CupertinoPageScaffold` pasa a `backgroundColor: transparent`
para dejarlo ver.

| Cara | `backgroundTop` | `backgroundBottom` |
|---|---|---|
| CARA (P1) | `#19191D` | `#101012` |
| CRUZ (P2) | `#1C1A30` | `#0B0B12` |

P1 es casi neutro (un gris carbón con la tibieza justa para no chocar con el
oro); P2 lleva un tinte índigo perceptible — así el fondo de CRUZ se nota
más "propio" que el de CARA, que replica el Cupertino oscuro base. Estos dos
hex no cambiaron entre las dos versiones de P2 (ver nota arriba) — solo se
ajustó `accent`/`accentHighlight`. Sigue el mismo
`CoinPalette.forResult(coinState.lastResult)` que el resto de los acentos:
en `idle` (antes del primer tiro) muestra el fondo P1 por defecto.

### Assets de la moneda

`generate_placeholders.dart` ya no dibuja un cuadrado de color plano: renderiza
a mano (sin el paquete `image`, ver Gotchas en `CLAUDE.md`) un círculo RGBA
sombreado como metal — highlight desplazado arriba-izquierda, degradé hacia
un borde más oscuro, un aro (`rim`) todavía más oscuro cerca del canto, y una
sombra suave debajo — sobre fondo transparente. Mantiene **sus propios
literales RGB** porque corre con `dart run` fuera del SDK de Flutter y no
puede importar `CoinPalette`. Si se cambia un hex de paleta, hay que
replicarlo a mano en `_caraColor`/`_cruzColor` de ese script y correr
`dart run generate_placeholders.dart` para regenerar los 14 PNG.

Los 12 frames del giro (`flip_sequence/frame_00..11.png`) aplican, por
frame `i`, un único ángulo `angle = i * π/6` (30° por frame, 360° en total)
del que salen dos cosas a la vez:

- **Squish vertical** — `squish = |cos(angle)|` (con piso 0.08 para que el
  canto nunca desaparezca del todo) simula la moneda tumbando de punta a
  punta en el aire (no girando plana como un trompo, que sería squish
  horizontal): alto completo en `frame_00` (cara) y `frame_06` (cruz), una
  elipse achatada casi nula en `frame_03`/`frame_09` (de canto).
- **Blend de color** — `colorT = (1 - cos(angle)) / 2` mezcla `_caraColor`
  → `_cruzColor` con el mismo ángulo, y el canto además se oscurece
  (`edgeShade`) porque una moneda de canto está en sombra.

Si se retoca el sombreado (highlight, rim, sombra) o el squish, hacerlo en
`_writeCoin`/`main()` de `generate_placeholders.dart` — es la única fuente
de verdad para el render, no hay assets de arte por fuera de este script.

## Material — vidrio con relieve (E2)

Aplicado en `_GlassLabel` y `_HistoryRow` (`coin_screen.dart`). En vez del
vidrio plano original (blur + color sólido), el contenedor usa:

- `LinearGradient` vertical sutil (blanco 14%→4% en el label, 10%→2% en la
  fila de historial) para simular una superficie curva.
- `border` con el `glassBorder` de la paleta activa (no un gris fijo) — así
  el borde "sabe" si el resultado fue cara o cruz.
- Dos `BoxShadow`: una oscura difusa debajo (profundidad) y una tenue del
  color de acento (`accent` @ 18%, `spreadRadius` negativo) simulando un
  glow del material, no solo una sombra.
- `BackdropFilter` blur subió de 12px a 14px (label) / se mantuvo en 10px
  (historial).

`E1` (vidrio fino, sin gradiente ni glow) queda documentado como alternativa
más discreta si en algún momento el E2 se siente demasiado cargado.

## Tipografía (T1)

Sin fuente custom — Cupertino ya resuelve a San Francisco nativo en iOS; traer
una fuente de Google Fonts sería lo que más rompería el "touch and feel" de
iOS. La mejora es de **escala**, no de familia.

- Resultado (`_GlassLabel`): `fontSize: 40`, `fontWeight: w700`,
  `letterSpacing: -0.5` (antes: 28 / w700 / +4). Se lee como titular, no como
  texto de botón.
- Chips de historial: sin cambios (`fontSize: 11`, `w600`, `letterSpacing: 1`)
  — a esa escala son metadata, no protagonistas.

### T2 — Acento numérico (NO implementado)

Reservado para cuando exista una métrica numérica en pantalla (racha de
tiradas, contador, porcentaje). Todavía no hay ese feature — no crear el
widget hasta que exista el dato real que mostrar.

Cuando se implemente:

- `fontWeight: w800`, `fontVariations`/`fontFeatures: [FontFeature.tabularFigures()]`
  (o `font-variant-numeric: tabular-nums` si el número vive en un widget que
  soporte feature settings) para que los dígitos no salten de ancho al
  cambiar.
- Color: `CoinPalette.forResult(...).accent` de la paleta activa en ese
  momento — igual que el resto de los acentos, no un color fijo nuevo.
- Tamaño de referencia: ~28px, bien por debajo del resultado principal (40px)
  para no competir con el titular.

## Interacción (H2 + H4)

Implementadas en `_CoinScreenState` (`coin_screen.dart`):

- **H2 — haptic al revelar resultado**: `HapticFeedback.selectionClick()` se
  dispara en `_animController.onComplete`, en el mismo instante en que
  aterriza la moneda y antes de llamar a `resolveFlip()`. No tiene efecto en
  web/desktop (Flutter hace no-op ahí); es real en iOS/Android.
- **H4 — rebote al aterrizar**: `AnimationController` + `TweenSequence`
  (`_landingController` / `_landingScale`) que escala la moneda
  `1.0 → 1.1 (easeOut) → 1.0 (elasticOut)` en 380ms, envuelto con
  `Transform.scale` alrededor del `Image.asset`. Es un `AnimationController`
  separado del sequencer de frames de `CoinAnimationController` (que sigue
  usando `Timer.periodic` a propósito — ver `CLAUDE.md` — para poder
  testearse sin árbol de widgets). El rebote es una capa puramente visual
  encima, no reemplaza ni modifica esa lógica.

`H1` (haptic al iniciar el tiro) y `H3` (auditoría del área táctil mínima
44×44pt) quedaron fuera de esta iteración — no están implementados.

## Historial — chips horizontales (L2)

`_HistoryChip` pasó de ser texto suelto en una `Column` a un chip con fondo
propio:

- `Container` con `palette.glassTint` de fondo y `palette.glassBorder` de
  borde (según `record.result`, no según el resultado actual en pantalla —
  cada chip lleva el color de **su propia** tirada).
- Punto de color de 7px (`palette.accent`) arriba de la etiqueta, como
  indicador rápido de cara/cruz sin tener que leer el texto.
- El contenedor exterior (`_HistoryRow`) usa el mismo tratamiento E2 que el
  label de resultado, pero sin tinte de una paleta específica (contiene
  tiradas mixtas).

`L1` (lista agrupada estilo Ajustes.app, una fila por tirada con separador)
queda documentado como alternativa si el historial se muda a una pantalla
propia con más de 5 registros.
