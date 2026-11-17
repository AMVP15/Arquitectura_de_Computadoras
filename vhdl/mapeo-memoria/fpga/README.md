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

## Controles

| Elemento | Función |
|---|---|
| `SW[9:0]` | dirección de byte que se va a leer |
| `KEY0` | petición de lectura (un flanco = una lectura) |
| `KEY1` | cambia de caché: **directo → conjuntos → asociativa → directo** |
| `KEY2` | invalida la caché seleccionada (borra sus líneas) |
| `KEY3` | reset general (también recarga la memoria con su patrón) |

## Qué se ve

| Salida | Significado |
|---|---|
| `LEDR[0]` | `hit` del último acceso (encendido = acierto) |
| `LEDR[1]` | `ready` del último acceso |
| `LEDR[3:2]` | `estado` de la FSM: 0 = IDLE, 1 = COMPARE, 2 = FETCH_MEM, 3 = DONE |
| `HEX5` | caché seleccionada: 0 = directo, 1 = conjuntos, 2 = asociativa |
| `HEX4` | `estado` de la FSM en hexadecimal |
| `HEX3..HEX0` | `data[15:0]` en hexadecimal |

`data` tiene 32 bits y la placa solo tiene 6 displays de 4 bits, así que se
muestran los 16 bits bajos. Alcanzan de sobra para el patrón de fábrica de la
memoria (palabra *i* = `i*3 + 7`, máximo 772); los 16 altos solo se ven en
simulación.

## Guion de demostración (2 minutos)

La memoria arranca con la palabra *i* = `i*3 + 7`, así que:

| Paso | Acción | Resultado esperado |
|---|---|---|
| 1 | `KEY3` y soltar | todo a 0, `HEX5` = 0, `HEX4` = 0 |
| 2 | `SW[9:0]` = 0, pulsar `KEY0` | **fallo**: `LEDR0` apagado, `HEX3..0` = `0007` |
| 3 | `SW` = 1, pulsar `KEY0` | **acierto**: `LEDR0` encendido (mismo bloque), `HEX3..0` = `0007` |
| 4 | `SW` = 64, pulsar `KEY0` | **fallo en directo**: dirección 64 compite por la misma línea, `HEX3..0` = `0037` (palabra 16 = 55) |
| 5 | `SW` = 0, pulsar `KEY0` | **fallo**: el bloque 0 fue desalojado |
| 6 | `KEY1` (pasa a conjuntos), `SW` = 0, `KEY0` ×2 | fallo y después **acierto**: no hubo conflicto |
| 7 | `KEY2` (invalida), `KEY0` | **fallo** otra vez: se borraron las líneas |
| 8 | `KEY1` (pasa a asociativa), `SW` = 0, `KEY0` ×2 | fallo y **acierto** |

El paso 4 frente al 6 es la demostración de la unidad: **la misma dirección que
en mapeo directo provoca un conflicto, en asociativa por conjuntos acierta.**

## Abrir, compilar y programar (todo con la GUI)

1. **Abrir**: doble clic en `top_placa.qpf` (o `File → Open Project`).
2. **Revisar pines** (opcional): `Assignments → Pin Planner`. Ya están los 67.
3. **Compilar**: `Processing → Start Compilation` (`Ctrl+L`), 1-3 minutos.
4. **Comprobar**: `Compilation Report → Flow Summary` (ALMs, registros, pines)
   y `Fitter → Resource Section`. Solo los **Error** son problema; los Warning
   de pines sin usar son normales.5. **Programar**: `Tools → Programmer` →
   - `Hardware Setup…` → debe aparecer **USB-Blaster II**,
   - `Add File…` → `output_files/top_placa.sof`,
   - marcar **Program/Configure** y `Start`.

> El `.sof` se carga en la SRAM de la FPGA: **se pierde al apagar**. Para que
> arranque solo habría que generar un `.rbf` y grabarlo en la tarjeta SD, que no
> es parte de esta entrega.
>
> Si el Programmer no ve el cable, falta la regla udev del USB-Blaster:
> ver `docs/guia-fpga-de10.md`.

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
