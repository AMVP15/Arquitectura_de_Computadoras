# `vhdl/fpga-de10` — base común para la DE10-Standard

Módulos que **no** forman parte del diseño lógico de ninguna unidad, sino que
adaptan los datapaths a la placa **Terasic DE10-Standard** (Cyclone V SoC
`5CSXFC6D6F31C6`). Los usa el envoltorio `top_placa` de cada unidad
(`vhdl/<unidad>/fpga/`).

| Módulo | Qué hace |
|---|---|
| `src/divisor.vhd` | 50 MHz → 1 Hz (o lo que se pida) como **pulso de habilitación**, no como reloj derivado |
| `src/antirrebote.vhd` | estabiliza una entrada durante `TIEMPO_MS` milisegundos |
| `src/pulsador.vhd` | nivel de un botón → **pulso de un ciclo** por pulsación (arranca las FSM con un flanco) |
| `src/hex7seg.vhd` | 4 bits → display de 7 segmentos, **activo a nivel bajo** (ánodo común) |

Los pines **no** se declaran en VHDL: se asignan en el `.qsf` de cada proyecto
Quartus. La tabla de abajo es la referencia que usa ese `.qsf`.

## Simular

```bash
scripts/vhdl-sim fpga-de10 tb_divisor        # o tb_antirrebote / tb_hex7seg
```

`vhdl-analizar` y `vhdl-sim` analizan `vhdl/fpga-de10/src` **antes** que el
diseño de la unidad, así que cualquier unidad puede instanciar estos módulos
sin copiarlos.

## Tabla de pines (DE10-Standard)

Fuente: *DE10-Standard User Manual* (Terasic, 20-mar-2018), Tablas 3-5 a 3-9.
Estándar de E/S: **3.3-V LVCMOS** en todos los pines usados.

### Relojes — Tabla 3-5

| Señal | Pin | Nota |
|---|---|---|
| `CLOCK_50` | `PIN_AF14` | 50 MHz (el que se usa como reloj del sistema) |
| `CLOCK2_50` | `PIN_AA16` | 50 MHz |
| `CLOCK3_50` | `PIN_Y26` | 50 MHz |
| `CLOCK4_50` | `PIN_K14` | 50 MHz |
| `HPS_CLOCK1_25` | `PIN_D25` | 25 MHz |
| `HPS_CLOCK2_25` | `PIN_F25` | 25 MHz |

### Pulsadores — Tabla 3-7 (activos a nivel bajo, con disparador de Schmitt)

| Señal | Pin |
|---|---|
| `KEY[0]` | `PIN_AJ4` |
| `KEY[1]` | `PIN_AK4` |
| `KEY[2]` | `PIN_AA14` |
| `KEY[3]` | `PIN_AA15` |

### Interruptores — Tabla 3-6 (sin antirrebote)

| Señal | Pin | Señal | Pin |
|---|---|---|---|
| `SW[0]` | `PIN_AB30` | `SW[5]` | `PIN_V25` |
| `SW[1]` | `PIN_Y27` | `SW[6]` | `PIN_AC28` |
| `SW[2]` | `PIN_AB28` | `SW[7]` | `PIN_AD30` |
| `SW[3]` | `PIN_AC30` | `SW[8]` | `PIN_AC29` |
| `SW[4]` | `PIN_W25` | `SW[9]` | `PIN_AA30` |

### LEDs rojos — Tabla 3-8

| Señal | Pin | Señal | Pin |
|---|---|---|---|
| `LEDR[0]` | `PIN_AA24` | `LEDR[5]` | `PIN_AF25` |
| `LEDR[1]` | `PIN_AB23` | `LEDR[6]` | `PIN_AE24` |
| `LEDR[2]` | `PIN_AC23` | `LEDR[7]` | `PIN_AF24` |
| `LEDR[3]` | `PIN_AD24` | `LEDR[8]` | `PIN_AB22` |
| `LEDR[4]` | `PIN_AG25` | `LEDR[9]` | `PIN_AC22` |

### Displays de 7 segmentos — Tabla 3-9 (ánodo común: `0` enciende)

| Señal | Pin | Señal | Pin | Señal | Pin |
|---|---|---|---|---|---|
| `HEX0[0]` | `PIN_W17` | `HEX2[0]` | `PIN_AA21` | `HEX4[0]` | `PIN_AD21` |
| `HEX0[1]` | `PIN_V18` | `HEX2[1]` | `PIN_AB17` | `HEX4[1]` | `PIN_AG22` |
| `HEX0[2]` | `PIN_AG17` | `HEX2[2]` | `PIN_AA18` | `HEX4[2]` | `PIN_AE22` |
| `HEX0[3]` | `PIN_AG16` | `HEX2[3]` | `PIN_Y17` | `HEX4[3]` | `PIN_AE23` |
| `HEX0[4]` | `PIN_AH17` | `HEX2[4]` | `PIN_Y18` | `HEX4[4]` | `PIN_AG23` |
| `HEX0[5]` | `PIN_AG18` | `HEX2[5]` | `PIN_AF18` | `HEX4[5]` | `PIN_AF23` |
| `HEX0[6]` | `PIN_AH18` | `HEX2[6]` | `PIN_W16` | `HEX4[6]` | `PIN_AH22` |
| `HEX1[0]` | `PIN_AF16` | `HEX3[0]` | `PIN_Y19` | `HEX5[0]` | `PIN_AF21` |
| `HEX1[1]` | `PIN_V16` | `HEX3[1]` | `PIN_W19` | `HEX5[1]` | `PIN_AG21` |
| `HEX1[2]` | `PIN_AE16` | `HEX3[2]` | `PIN_AD19` | `HEX5[2]` | `PIN_AF20` |
| `HEX1[3]` | `PIN_AD17` | `HEX3[3]` | `PIN_AA20` | `HEX5[3]` | `PIN_AG20` |
| `HEX1[4]` | `PIN_AE18` | `HEX3[4]` | `PIN_AC20` | `HEX5[4]` | `PIN_AE19` |
| `HEX1[5]` | `PIN_AE17` | `HEX3[5]` | `PIN_AA19` | `HEX5[5]` | `PIN_AF19` |
| `HEX1[6]` | `PIN_V17` | `HEX3[6]` | `PIN_AD20` | `HEX5[6]` | `PIN_AB21` |

En los displays, `HEXn[0]` es el segmento `a` y `HEXn[6]` el segmento `g`.

## Notas

- **`KEY` ya está antirrebotado en la placa** (disparador de Schmitt), así que
  `antirrebote` se usa sobre todo con `SW` o con botones externos por GPIO.
- **No se generan relojes por lógica**: `divisor` devuelve un `tick` de un
  ciclo que se usa como habilitación, y todo el diseño sigue a 50 MHz.
- El `rst` del diseño es **activo a nivel alto**; los `KEY` de la placa son
  activos a nivel bajo, así que el `top_placa` hace `rst <= not key(3)`.
- `5CSXFC6D6F31C6N` y `5CSXFC6D6F31C6` son el mismo chip: la `N` es el sufijo
  de la orden de compra (libre de plomo) y Quartus lo muestra sin ella.
