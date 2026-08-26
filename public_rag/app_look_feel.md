# Look & feel — Cara o Cruz

Guía de estilo aplicada a la app. Es la fuente de verdad para paleta,
tipografía, materiales e interacción — cualquier cambio visual debería
actualizar este archivo en el mismo commit.

Origen: propuesta generada con `ui-ux-pro-max` (paletas P1/P2, material E1/E2,
tipografía T1/T2, historial L1/L2), revisada y recortada por el usuario el
2026-08-26. Selección aplicada: **P1+P2 condicionados por cara, E2, T1, H2,
H4, L2**. `H1`, `H3`, `E1`, `L1`, `P2` en su variante índigo original y `T2`
quedaron fuera (T2 documentado abajo para una futura implementación).

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
| **CRUZ** | Plata Azulada (P2) | `#8FA3C2` | `#C7D2E0` | moneda `cruz.png`, borde/glow del `_GlassLabel`, punto + borde del chip de historial cuando `record.result == 'cruz'` |

Nota de diseño: la propuesta original llamaba a P2 "Índigo Nocturno"
(`#7B7BEA`/`#38C9BB`, más púrpura/teal). El usuario pidió explícitamente que
CRUZ se sienta **azul, plateado, metálico** — P2 se ajustó a un tono acero
más neutro (`#8FA3C2`) en vez del índigo saturado original. Si se retoma la
variante índigo en el futuro, tratarla como `P2b`, no como reemplazo de esta.

`glassTint` (`accent` @ 18% alpha) y `glassBorder` (`accent` @ 45% alpha) se
derivan del `accent` en tiempo de uso — no se guardan como constantes
aparte.

Fondo de la app: **sin cambios**, sigue siendo `AppTheme.darkBackground`
(`#1C1C1E`). El acento nunca reemplaza el fondo de sistema.

### Assets de la moneda

`generate_placeholders.dart` escribe los PNG placeholder (no usa el paquete
`image`, ver Gotchas en `CLAUDE.md`) y mantiene **sus propios literales RGB**
porque corre con `dart run` fuera del SDK de Flutter y no puede importar
`CoinPalette`. Si se cambia un hex acá, hay que replicarlo a mano en ese
script y correr `dart run generate_placeholders.dart` para regenerar los 14
PNG:

- `cara.png` → `#D6AD60`
- `cruz.png` → `#8FA3C2`
- `flip_sequence/frame_00,01,02,11` (lado cara) → degradé cálido hacia `#D6AD60`
- `flip_sequence/frame_06,07,08` (lado cruz) → degradé frío hacia `#8FA3C2`
- `flip_sequence/frame_03,04,05,09,10` (canto) → neutros sin tinte (el canto de una moneda no tiene cara)

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
