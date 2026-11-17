# `vhdl/mapeo-memoria/fpga` — la unidad en la DE10-Standard

Envoltorio de placa de **mapeo-memoria**: pone las tres cachés de la unidad
(`cache_directo`, `cache_conjuntos`, `cache_asociativa`) y la
`memoria_principal` en la FPGA para poder comparar los mapeos **sin simulador**.

No sustituye al diseño: `src/` y `tb/` quedan intactos y siguen validándose con
`scripts/vhdl-sim`. Lo único que hace este directorio es cablear los módulos a
los periféricos de la placa.

```
fpga/
  top_placa.vhd        envoltorio (selector de caché + memoria + displays)
  tb_top_placa.vhd     autochequeo del envoltorio (simulación)
  top_placa.qpf        proyecto Quartus (doble clic para abrir)
  top_placa.qsf        dispositivo, fuentes y los 67 pines
  top_placa.sdc        restricciones de tiempo (CLOCK_50 = 20 ns)
  output_files/        .sof generado (ignorado por git)
```

Qué hay dentro de la FPGA:

```
 SW[9:0] ─────────────► dirección de byte
 KEY0..KEY2 ─► pulsador ─► req / cambio de caché / invalidar
 KEY3 ─────────────────► reset

              ┌────────────────────┐
   sel ──────►│ reparto de req     │  solo la caché seleccionada
              └──┬───────┬──────┬──┘
                 ▼       ▼      ▼
          cache_directo  cache_conjuntos  cache_asociativa
                 └───────┬────────┴──────────┘
                  mux ──► memoria_principal (256 × 32 bits, i*3+7)
                  mux ──► LEDR / HEX
```

---

# Guía de uso — día de la prueba

La placa no tiene teclado ni pantalla: la conversación son **10 interruptores,
4 botones, 10 LEDs y 6 displays**. Todo lo demás es automático.

## 1. Qué es cada pin

| Pin | Tipo | Para qué sirve |
|---|---|---|
| `SW[9:0]` | entrada | escribes la **dirección** en binario (0-1023) |
| `KEY0` | entrada | "consulta esta dirección": un clic = una lectura |
| `KEY1` | entrada | cambia de caché: directa → conjuntos → asociativa |
| `KEY2` | entrada | invalida (borra las líneas de) la caché activa |
| `KEY3` | entrada | reset general (recarga la memoria con su patrón) |
| `LEDR[0]` | salida | **hit**: encendido = acierto, apagado = fallo |
| `LEDR[1]` | salida | `ready`; dura 1 ciclo (80 ns): **no se ve**, ignóralo |
| `LEDR[3:2]` | salida | estado de la FSM; también dura nanosegundos: no se ve |
| `HEX5` | salida | caché activa: `0` directa, `1` conjuntos, `2` asociativa |
| `HEX4` | salida | estado de la FSM en hexadecimal (en reposo, `0`) |
| `HEX3..HEX0` | salida | **el dato leído**, en hexadecimal |

Los `KEY` están activos a nivel bajo (pulsar = 0), pero lo resuelve el
envoltorio: tú solo pulsas.

## 2. El bucle de interacción

Siempre es el mismo, se repita la vez que se repita:

```
 ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
 │ 1. Pon la       │   │ 2. Pulsa KEY0   │   │ 3. Mira LEDR0   │   │ 4. Repite con   │
 │    dirección en │──►│    y suelta     │──►│    y HEX3..HEX0 │──►│    otra SW o    │
 │    SW9..SW0     │   │                 │   │                 │   │    cambia KEY1  │
 └─────────────────┘   └─────────────────┘   └─────────────────┘   └─────────────────┘
        ↑                                                                   │
        └───────────────────────────────────────────────────────────────────┘
```

> La dirección se captura **en el instante en que pulsas `KEY0`**. Si mueves
> los switches después, el resultado anterior se queda hasta la próxima
> pulsación. No hay refresco automático.

## 3. Escribir la dirección con los switches

Cada switch vale un peso binario; los que uses, en **ON** (arriba), los demás
abajo:

| Switch | `SW0` | `SW1` | `SW2` | `SW3` | `SW4` | `SW5` | `SW6` | `SW7` | `SW8` | `SW9` |
|---|---|---|---|---|---|---|---|---|---|---|
| Vale | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 | 256 | 512 |

Direcciones que se usan en la demo (dato = palabra *i* = `i*3+7`, con
*i* = dirección/4):

| Dirección | Binario `SW9..SW0` | Switches en ON | Dato esperado |
|---|---|---|---|
| `0` | `0000000000` | ninguno | `0007` |
| `1` | `0000000001` | `SW0` | `0007` |
| `4` | `0000000100` | `SW2` | `000A` |
| `16` | `0000010000` | `SW4` | `0013` |
| `64` | `0001000000` | `SW6` | `0037` |
| `128` | `0010000000` | `SW7` | `0067` |
| `192` | `0011000000` | `SW6` + `SW7` | `0097` |
| `256` | `0100000000` | `SW8` | `00C7` |

Las direcciones 0 y 1 devuelven lo mismo porque la caché guarda **palabras de
4 bytes**: los dos bits bajos de la dirección no cambian la palabra.

## 4. Guion paso a paso

| Paso | Tú haces | La placa muestra | Qué significa |
|---|---|---|---|
| 1 | Enciendes y pulsas `KEY3` | `HEX5`=`0`, `HEX4`=`0`, `LEDR0` apagado | todo reiniciado, caché directa |
| 2 | `SW` todos abajo (dir 0) y `KEY0` | `LEDR0` **apagado**, `HEX3..0`=`0007` | **fallo**: línea inválida, dato traído de memoria |
| 3 | `SW0` en ON (dir 1) y `KEY0` | `LEDR0` **encendido**, `0007` | **acierto**: 0 y 1 son la misma palabra |
| 4 | `SW6` en ON (dir 64) y `KEY0` | `LEDR0` **apagado**, `0037` | **fallo**: en directa choca con la línea de la dir 0 |
| 5 | Dir 0 otra vez y `KEY0` | `LEDR0` **apagado** | **fallo**: la dir 0 fue desalojada por la 64 |
| 6 | `KEY1` | `HEX5`=`1` | pasa a la caché por conjuntos (vacía) |
| 7 | Dir 0, `KEY0`; dir 64, `KEY0`; dir 0, `KEY0` | fallo, fallo, **`LEDR0` encendido** | **la demo**: en conjuntos 0 y 64 conviven (2 vías) |
| 8 | `KEY2` y luego `KEY0` con dir 0 | `LEDR0` **apagado** | invalidar borró las líneas |
| 9 | `KEY1` (`HEX5`=`2`), dir 0 ×2 | fallo y después **acierto** | asociativa total (16 líneas) |
| 10 | `KEY1` | `HEX5`=`0` | el selector vuelve a directa (2 → 0) |

**El resultado que importa es `LEDR0`**: se queda encendido o apagado después de
cada pulsación, no parpadea.

Si se prueba `0 → 64 → 128 → 0`, la caché por conjuntos también falla: tres
etiquetas ya no caben en 2 vías. Es el matiz que suele preguntar el profesor.

## 5. Cómo leer los displays

Con la dirección 64:

```
 HEX5   HEX4   HEX3   HEX2   HEX1   HEX0
  0      0      0      0      3      7
  │      │      └──────┴──────┴──────┘
  │      │            dato = 0x0037 = 55 = 16*3 + 7
  │      └── estado de la FSM (00 = reposo)
  └── caché seleccionada (0 = directa)
```

`data` tiene 32 bits y la placa solo 6 displays de 4 bits, así que se muestran
los **16 bits bajos**. Alcanzan de sobra para el patrón de fábrica (máximo 772);
los 16 altos solo se ven en simulación.

## 6. Lo que no se ve (y por qué)

| Señal | Por qué no se ve |
|---|---|
| `LEDR[1]` (`ready`) | dura un ciclo a 50 MHz (20 ns) |
| `LEDR[3:2]` (estado) | la FSM tarda 3-8 ciclos por acceso (60-160 ns) |
| `HEX4` cambiando | vuelve a `0` en reposo; en la práctica siempre se lee `0` |
| el orden de los estados | solo se ve en GTKWave (`scripts/vhdl-wave`) |

`LEDR[0]` sí se ve porque `hit` queda **latcheado** hasta la siguiente petición.

## 7. Errores de interacción típicos

| Lo que haces | Por qué "no funciona" |
|---|---|
| Mueves `SW` y esperas que el display cambie solo | hay que pulsar `KEY0`; los switches no disparan nada |
| Mantienes `KEY0` pulsado esperando más lecturas | es detector de flanco: una pulsación = una consulta |
| Pulsas `KEY1` a la vez que `KEY0` | el cambio de caché solo se acepta con la FSM en reposo (IDLE) |
| Miras `LEDR1` o `LEDR3:2` | duran ~20 ns: invisibles al ojo |
| Buscas la dirección en algún display | no está cableada a la salida: apúntala en papel |
| Cambias de caché y esperas que se borren las otras | cambiar de caché **no** borra: solo `KEY2` invalida, y solo la activa |

---

## Recursos y tiempos (Quartus 25.1 Lite, `5CSXFC6D6F31C6`)

Compilación de referencia del 17-nov-2026, sin errores:

| Métrica | Valor |
|---|---|
| ALMs | 822 / 41 910 (2 %) |
| Registros | 989 |
| Pines | 67 / 499 (13 %) |
| Bloques de memoria | 0 / 5 662 720 bits (0 %) |
| DSP | 0 / 112 |
| Fmax (Slow 1100 mV 85 °C, setup) | ≈ 62 MHz (slack **+3.987 ns** con reloj de 20 ns) |

La memoria no consume bloques M10K porque Quartus no infiere RAM con lectura
asíncrona (`Info (276014): Found 4 instances of uninferred RAM logic`): las
tablas se implementan en registros y lógica, y como `wr_en` está atado a `'0'`
la memoria principal queda como ROM con el patrón de fábrica. De ahí los 989
registros en lugar de los ~8 000 que saldrían si se infirieran RAM.

El `.sdc` es imprescindible: sin él TimeQuest no conoce el periodo y analiza
como si el reloj fuera de 1 GHz, con *slack* negativo artificial.

## Simular el envoltorio

```bash
scripts/vhdl-sim mapeo-memoria tb_top_placa
scripts/vhdl-wave vhdl/mapeo-memoria/salidas/tb_top_placa.vcd
```

El testbench comprueba, sin placa: fallo → acierto en el mismo bloque, conflicto
en mapeo directo, cambio de caché con `KEY1`, invalidación con `KEY2`, el
retorno del selector 2 → 0 y los cuatro displays de datos.

## Decisiones de diseño

- **Solo la caché seleccionada recibe `req`**; las otras dos se quedan en IDLE
  con `mem_req = '0'`. Por eso no hace falta el árbitro que usa
  `tb_comparacion_mapeos`: nunca hay dos peticiones simultáneas.
- **El cambio de caché solo se acepta en IDLE**, para no cortar una
  transferencia a medias.
- **Cambiar de caché no borra las otras**: al volver a una caché anterior sus
  líneas siguen cargadas (solo `KEY2` invalida, y solo la seleccionada).
- `mem_data` y `mem_ready` se difunden a las tres cachés; `mem_addr` y `mem_req`
  salen de la seleccionada.
- `KEY0..KEY2` pasan por `pulsador` (de `vhdl/fpga-de10`) para convertir la
  pulsación en un pulso de un ciclo, que es lo que espera `req` en las FSM.

## Compilar y programar (todo con la GUI)

1. **Abrir**: doble clic en `top_placa.qpf` (o `File → Open Project`).
2. **Revisar pines** (opcional): `Assignments → Pin Planner`. Ya están los 67.
3. **Compilar**: `Processing → Start Compilation` (`Ctrl+L`), 1-3 minutos.
4. **Comprobar**: `Compilation Report → Flow Summary` (ALMs, registros, pines)
   y `Fitter → Resource Section`. Solo los **Error** son problema; los Warning
   de pines sin usar son normales.
5. **Programar**: `Tools → Programmer` →
   - `Hardware Setup…` → debe aparecer **USB-Blaster II**,
   - `Add File…` → `output_files/top_placa.sof`,
   - marcar **Program/Configure** y `Start`.

> El `.sof` se carga en la SRAM de la FPGA: **se pierde al apagar**. Para que
> arranque solo habría que generar un `.rbf` y grabarlo en la tarjeta SD, que no
> es parte de esta entrega.
>
> Si el Programmer no ve el cable, falta la regla udev del USB-Blaster:
> ver `docs/guia-fpga-de10.md` §5.

## Antes de ir al laboratorio

- [ ] Llevar `output_files/top_placa.sof` (6,4 MB) en un pendrive o correo.
- [ ] Llevar esta guía impresa o en el móvil (los pasos 1-10 de §4).
- [ ] Llevar el repo (o al menos `fpga/` y `vhdl/fpga-de10/src/`) por si hay
      que recompilar en el PC del laboratorio.
- [ ] Cable micro-USB: el del **USB-Blaster II** (no el UART).
