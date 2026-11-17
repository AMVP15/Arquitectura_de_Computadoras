<!--
Plantilla del README de placa de una unidad.

Uso:
  1. Copia este fichero a vhdl/<unidad>/fpga/README.md
  2. Sustituye todo lo que está entre <...> y borra los comentarios como este.
  3. No borres las secciones: son las mínimas que exige vhdl/AGENTS.md.

Modelo ya relleno: vhdl/mapeo-memoria/fpga/README.md
-->

# `<unidad>` en la DE10-Standard

<Una o dos frases: qué pone esta unidad en la placa y qué se puede demostrar
con ella sin simulador.>

```
fpga/
  top_placa.vhd        <qué hace el envoltorio>
  tb_top_placa.vhd     <qué comprueba el testbench>
  top_placa.qpf        proyecto Quartus (doble clic para abrir)
  top_placa.qsf        dispositivo, fuentes y pines
  top_placa.sdc        restricciones de tiempo (CLOCK_50 = 20 ns)
  output_files/        .sof generado (ignorado por git)
```

## Controles

<Qué hace el usuario con cada periférico. Una fila por elemento que se use.>

| Elemento | Función |
|---|---|
| `SW[<x>:0]` | <qué se escribe con los switches> |
| `KEY0` | <qué dispara> |
| `KEY1` | <...> |
| `KEY3` | reset |

## Qué se ve

<Dónde se lee el resultado y qué significa cada cosa.>

| Salida | Significado |
|---|---|
| `LEDR[0]` | <...> |
| `HEX3..HEX0` | <...> |

## Flujo de uso

<El bucle de interacción: qué se pone, qué botón se pulsa y dónde se lee el
resultado. Vale un diagrama ASCII o una lista numerada.>

```
  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
  │ 1. <...>     │──►│ 2. <...>     │──►│ 3. <...>     │
  └──────────────┘   └──────────────┘   └──────────────┘
```

## Guion de demostración

<Pasos concretos con valores reales, para que otra persona pueda repetirlos sin
pensar. Incluye qué debe aparecer en cada paso.>

| Paso | Acción | Resultado esperado |
|---|---|---|
| 1 | <...> | <...> |
| 2 | <...> | <...> |

## Cómo leer las salidas

<Desglose de los displays y LEDs: qué campo ocupa cada uno y con un ejemplo
real. Si algo se muestra truncado (por ejemplo solo los 16 bits bajos), dilo.>

## Lo que no se ve

<Señales que duran ciclos de reloj y no se aprecian a simple vista (`ready`,
estados intermedios…), y dónde mirarlas si hace falta (GTKWave).>

## Errores típicos

<Los fallos de interacción que desconciertan: mover switches sin pulsar,
mantener el botón, mirar una señal invisible, etc.>

| Lo que haces | Por qué "no funciona" |
|---|---|
| <...> | <...> |

## Compilar y programar

1. **Abrir**: doble clic en `top_placa.qpf`.
2. **Compilar**: `Processing → Start Compilation` (`Ctrl+L`).
3. **Programar**: `Tools → Programmer` →
   `Hardware Setup…` (USB-Blaster II), `Add File…` →
   `output_files/top_placa.sof`, marcar **Program/Configure** y `Start`.

<Notas propias de la unidad: si hay que pulsar reset primero, si algo tarda, si
hay que cambiar de modo…>

## Antes de ir al laboratorio

- [ ] Llevar `output_files/top_placa.sof` en un pendrive o correo.
- [ ] Llevar esta guía impresa o en el móvil.
- [ ] Llevar el repo (o al menos `fpga/` y `vhdl/fpga-de10/src/`).
- [ ] Cable micro-USB: el del **USB-Blaster II** (no el UART).
