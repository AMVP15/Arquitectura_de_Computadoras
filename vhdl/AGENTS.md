# AGENTS.md — Código VHDL

Convención para el código VHDL de las 4 unidades:
`datapath-1`, `datapath-2`, `datapath-3`, `mapeo-memoria`. Además,
`vhdl/fpga-de10/` guarda la base común de la placa DE10-Standard.

## Estructura de cada unidad

```
vhdl/<unidad>/
  src/        una entidad por fichero (el diseño)
  tb/         un testbench por módulo
  fpga/       envoltorio de placa + proyecto Quartus (.qpf/.qsf/.sdc)
  salidas/    .vcd generados (NO se versionan, ya ignorados)
  .ghdl/      workdir temporal de GHDL (NO se versiona)
```

`fpga/` es opcional: solo existe cuando la unidad se porta a la DE10-Standard.
El diseño y los testbenches de `src/` y `tb/` **no** dependen de la placa.

Todo `fpga/` lleva su `README.md` con **cómo se usa la placa**: qué hace cada
switch y botón, qué significa cada LED y display, el guion de demostración paso
a paso y los errores de interacción típicos. Se escribe para alguien que se
pone delante de la placa por primera vez. Modelo:
`vhdl/mapeo-memoria/fpga/README.md`.

`vhdl/fpga-de10/` no es una unidad: es la base común de la placa (`divisor`,
`antirrebote`, `pulsador`, `hex7seg` + su tabla de pines). `scripts/vhdl-analizar`
y `scripts/vhdl-sim` la compilan antes que `src/` y `fpga/` de la unidad.

## Simular: usa siempre los scripts del repo

No recomiendes ni ejecutes `ghdl` a mano; deriva a los wrappers:

```bash
scripts/vhdl-analizar datapath-1            # solo analizar/compilar src/ + tb/
scripts/vhdl-sim datapath-1 tb_alu          # analizar + elaborar + ejecutar
scripts/vhdl-wave vhdl/datapath-1/salidas/tb_alu.vcd   # ver ondas en GTKWave
```

`vhdl-sim` genera `vhdl/<unidad>/salidas/<tb>.vcd`. Si algo falla por
herramienta faltante → `bash scripts/instalar.sh`.

## Reglas de código

- **Estándar VHDL-2008** (`--std=08`, ya fijado en los scripts).
- **Portabilidad GHDL 4.1 (Ubuntu/WSL) y GHDL 6.0 (Arch)**: VHDL-2008
  conservador. Evita construcciones muy recientes o poco soportadas.
- **Un fichero = una entidad** (`sumador.vhd` contiene `entity sumador`).
- Nombres: `snake_case` para señales y puertos, `CONSTANTES` en mayúsculas,
  tipos en `CamelCase`. Comentarios y cadenas en español.
- Siempre `library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;`
  (usa `numeric_std`, **no** `std_logic_arith`/`std_logic_unsigned`).
- Cabecera breve en cada fichero: qué hace el módulo.

## Testbenches (obligatorios)

- Todo módulo nuevo en `src/` necesita su testbench en `tb/`, con
  autochequeo: `assert ... severity failure` si algo falla y un
  `report "... OK"` al pasar.
- Nombre: `tb_<modulo>.vhd` → entidad `tb_<modulo>`.
- El testbench debe **fallar** ante un resultado incorrecto (no solo imprimir).
- Antes de dar por terminado un módulo, debe pasar:
  `scripts/vhdl-sim <unidad> tb_<modulo>`.

## Simulación y placa

El GHDL del equipo es backend **mcode**: **solo simulación**. Para sintetizar y
programar la **DE10-Standard** (Cyclone V `5CSXFC6D6F31C6`) se usa **Quartus
Prime Lite por interfaz gráfica**; guía completa en `docs/guia-fpga-de10.md`.
No se trabaja el flujo libre (yosys/nextpnr): no lo instales ni lo propongas.

Un módulo de placa nuevo va en `vhdl/fpga-de10/src/` si es reutilizable
(`divisor`, `pulsador`, `hex7seg`…) y en `vhdl/<unidad>/fpga/` si es el
envoltorio de esa unidad. Todo lo que se sintetiza debe tener antes su
testbench y pasar `scripts/vhdl-sim`.

## Git: una rama por cada feature

Cada módulo, testbench o refactor nuevo es una feature: **abre su rama antes
de escribir el primer fichero**, aunque el usuario no lo pida explícitamente:

```bash
git switch dev && git pull
git switch -c vhdl/<unidad>/<feat>     # ej.: vhdl/datapath-1/tb-alu
```

Al terminar (testbench pasando), PR de esa rama → `dev`. **Una feature = una
rama**: no acumules dos features distintas en la misma rama. Detalle completo
del flujo en `docs/guia-git.md`.

## Artefactos

Nunca hagas `commit` de: `*.cf`, `*.o`, `*.ali`, `work-obj*`, `*.vcd`,
`*.ghw`, `.ghdl/`, `salidas/`. Todo eso ya está en `.gitignore`.
De Quartus, nunca se versionan `db/`, `incremental_db/`, `output_files/`,
`*.sof`, `*.rbf`, `*.qws` ni los informes (`*.rpt`, `*.summary`).
Las **capturas** que van en los reportes son PNG exportados de GTKWave, y se
guardan en `reportes/<unidad>/figuras/`.
