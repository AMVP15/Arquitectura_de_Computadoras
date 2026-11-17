# Guía FPGA — DE10-Standard con Quartus Prime Lite

Esta guía explica cómo pasar una unidad del repo de la **simulación** a la
**placa Terasic DE10-Standard** (Cyclone V SoC `5CSXFC6D6F31C6`), usando
**Quartus Prime Lite** por interfaz gráfica. Está pensada para que cualquier
integrante replique el flujo en su unidad sin adivinar nada.

> El flujo del curso sigue siendo **GHDL para simular** (`scripts/vhdl-sim`).
> Quartus se usa **solo** para sintetizar y programar la placa. Las dos cosas
> conviven: el diseño vive en `src/`, los testbenches en `tb/` y el envoltorio
> de placa en `fpga/`.

---

## 1. Qué hace falta

| Pieza | Versión | Notas |
|---|---|---|
| Quartus Prime **Lite** | 25.1 | El instalador pide cuenta gratuita de Altera |
| Paquete **Cyclone V device support** | 25.1 | Es el único device package necesario (`cyclonev-25.1std.0.1129.qdz`) |
| USB-Blaster II | — | Ya viene en la placa; cable micro-USB a la FPGA |
| Regla udev | — | Sin ella el Programmer no ve el cable |

No hacen falta **Questa/ModelSim**, **Nios II EDS**, **RISC-Free**, **SoC EDS**
ni **Platform Designer**: son ~11 GB que no se usan en este flujo. En el
instalador se desmarcan.

El dispositivo aparece como `5CSXFC6D6F31C6`; la `N` del pedido
(`5CSXFC6D6F31C6N`) es el sufijo de «libre de plomo», no otro chip.

---

## 2. Estructura en el repositorio

```
vhdl/fpga-de10/                 base común de la placa (no es una unidad)
  src/divisor.vhd               50 MHz -> tick de habilitación (sin relojes derivados)
  src/antirrebote.vhd           estabiliza SW o botones externos
  src/pulsador.vhd              pulsación -> pulso de un ciclo
  src/hex7seg.vhd               4 bits -> display, activo a nivel bajo
  README.md                     tabla de pines del manual de Terasic

vhdl/<unidad>/fpga/             envoltorio y proyecto Quartus de esa unidad
  top_placa.vhd                 conecta el diseño a los periféricos
  tb_top_placa.vhd              autochequeo del envoltorio
  top_placa.qpf                 proyecto Quartus (doble clic)
  top_placa.qsf                 dispositivo, fuentes y pines
  output_files/                 .sof generado (ignorado por git)
  README.md                     controles y guion de demostración
```

**Por qué `fpga/` y no `src/`**: `scripts/vhdl-analizar` y `scripts/vhdl-sim`
comparten `fpga-de10/src` y `fpga/` automáticamente, así que el diseño original
y sus testbenches no se tocan ni ganan dependencias de placa.

---

## 3. Pines

La tabla completa (relojes, `SW`, `KEY`, `LEDR`, `HEX0..HEX5`) está en
**`vhdl/fpga-de10/README.md`**, copiada del *DE10-Standard User Manual*
(Terasic, 20-mar-2018), Tablas 3-5 a 3-9. No hay que picarlos a mano: cada
`.qsf` del repo ya los trae asignados.

Dos detalles que se olvidan:

- Los displays son de **ánodo común**: `0` enciende. Por eso `hex7seg` saca
  la salida activa a nivel bajo.
- Los pulsadores `KEY` son **activos a nivel bajo** y ya llevan disparador de
  Schmitt en la placa. El `rst` de los diseños es activo a nivel alto, así que
  el envoltorio hace `rst <= not key(3)`.

---

## 4. Flujo completo, todo con clic

### 4.1 Abrir el proyecto

Doble clic en `vhdl/<unidad>/fpga/top_placa.qpf`, o
`File → Open Project…`.

### 4.2 Revisar (solo la primera vez)

`Assignments → Pin Planner`. La lista ya está rellena. Si un pin choca con algo
de la placa, se cambia ahí y Quartus lo guarda en el `.qsf`.

### 4.3 Compilar

`Processing → Start Compilation` (o `Ctrl+L`). Tarda 1-3 minutos.

### 4.4 Leer el informe

`Compilation Report`:

| Sección | Qué mirar |
|---|---|
| `Flow Summary` | ALMs, registros, pines, bloques de memoria |
| `Fitter → Resource Section` | que no haya pines sin asignar ni ignorados |
| `TimeQuest → Slow 1200mV 85C → Fmax` | frecuencia máxima del diseño |

Solo los **Error** impiden generar el `.sof`. Los *Warning* habituales
(`unused pins`, `stuck at GND`, `no clock uncertainty`) son normales en un
envoltorio de prácticas.

### 4.5 Programar

`Tools → Programmer`:

1. `Hardware Setup…` → debe aparecer **USB-Blaster II**.
2. `Add File…` → `output_files/top_placa.sof`.
3. Marcar **Program/Configure**.
4. `Start`.

El `.sof` se carga en la **SRAM** de la FPGA: funciona hasta que se apaga. Para
que arranque sola habría que generar un `.rbf` y ponerlo en la tarjeta SD; eso
queda fuera de esta guía.

---

## 5. Permisos del USB-Blaster (una sola vez)

Si `Hardware Setup…` no lista el cable:

```bash
sudo tee /etc/udev/rules.d/51-usbblaster.rules >/dev/null <<'EOF'
# Altera USB-Blaster (09fb:6001) y USB-Blaster II (09fb:6810)
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Comprobación: con la placa conectada, `lsusb` debe mostrar `09fb:6810`.
Si aparece pero Quartus no lo ve, desconecta y vuelve a conectar el cable.

### Lanzadores de escritorio

El instalador **no crea accesos directos**. Si usas rofi o un menú, crea
`~/.local/share/applications/quartus.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Quartus Prime 25.1
Exec=/home/<usuario>/altera_lite/25.1std/quartus/bin/quartus %f
Icon=/home/<usuario>/altera_lite/25.1std/quartus/adm/quartusii.png
Terminal=false
Categories=Development;Electronics;IDE;
StartupWMName=quartus
```

Y para el PATH, en `~/.zshrc`:

```zsh
if [[ -d "$HOME/altera_lite/25.1std/quartus/bin" ]]; then
  export PATH="$HOME/altera_lite/25.1std/quartus/bin:$PATH"
fi
```

---

## 6. Replicar el flujo en otra unidad (receta)

1. **Crea la rama**: `git switch dev && git pull`,
   `git switch -c vhdl/<unidad>/top-placa`.
2. **Copia la carpeta `fpga/`** de una unidad ya hecha:
   ```bash
   cp -r vhdl/mapeo-memoria/fpga vhdl/<unidad>/fpga
   ```
3. **Sustituye `top_placa.vhd` y `tb_top_placa.vhd`** por el envoltorio de tu
   unidad. Lo mínimo es: componentes de tus módulos, mapa de `KEY`/`SW` a las
   entradas, `LEDR`/`HEX` a las salidas y `hex7seg` para los displays.
4. **Ajusta el `.qsf`**, en este orden:
   - `VHDL_FILE`: quita los `../src/...` de la otra unidad y pon los tuyos,
     más los de `../../fpga-de10/src/` que uses (`pulsador`, `hex7seg`,
     `divisor`, `antirrebote`). **No añadas los testbenches.**
   - `TOP_LEVEL_ENTITY`: el nombre de tu entidad (normalmente `top_placa`).
   - El **bloque de pines no se toca**: es de la placa, no de la unidad.
     Basta con no declarar puertos que no uses.
5. **Verifica en simulación** antes de sintetizar:
   ```bash
   scripts/vhdl-sim <unidad> tb_top_placa
   ```
6. **Compila** en Quartus y programa.
7. **Documenta**: `fpga/README.md` con los controles, cómo se usa la placa, qué
   se ve y un guion de demo (modelo: el de `mapeo-memoria`).
8. **Commit y PR** a `dev`:
   `vhdl(<unidad>): añadir envoltorio y proyecto Quartus para la DE10-Standard`.

> Un cambio = una rama. No mezcles el `top_placa` de dos unidades ni el
> envoltorio con cambios del reporte.

### Qué NO se versiona

`db/`, `incremental_db/`, `output_files/`, `*.sof`, `*.rbf`, `*.qws` y los
informes (`*.rpt`, `*.summary`). Ya están en `.gitignore`; si aparecen en
`git status`, algo se ha añadido mal.

---

## 7. Problemas frecuentes

| Síntoma | Causa / solución |
|---|---|
| `Error: cannot find device 5CSXFC6D6F31C6` | Falta el paquete **Cyclone V device support**; reinstala solo ese componente |
| `Hardware Setup…` vacío | Falta la regla udev del §5, o el cable está en el puerto JTAG equivocado |
| El `.sof` se pierde al apagar | Es lo normal en modo JTAG (SRAM); haría falta `.rbf` en la SD |
| Quartus no abre con rofi | No hay `.desktop`; ver §5 |
| `Warning (13024): Output pins are stuck at VCC or GND` | Un puerto sale constante (por ejemplo un LED reservado); no es un error |
| `Warning: Ignored assignments` | Algún pin del `.qsf` corresponde a un puerto que ya no existe |
| La simulación de `tb_top_placa` no termina | El testbench tiene un reloj concurrente (`clk <= not clk after ...`) que nunca deja vaciar la agenda: genera el reloj **dentro** del proceso |
| `DIVISOR`/`divisor` «already used for a declaration» | VHDL no distingue mayúsculas: renombra la constante (`CICLOS_POR_PERIODO`) |

---

## 8. Cómo se usa la placa una vez programada

Programar no es usar: al terminar la carga el diseño ya está corriendo, y a
partir de ahí la placa solo "habla" por LEDs y displays. El patrón es el mismo
en todas las unidades:

```
  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
  │ 1. Pones las   │   │ 2. Pulsas el   │   │ 3. Lees el     │   │ 4. Repites o   │
  │    entradas    │──►│    botón de    │──►│    resultado   │──►│    cambias de  │
  │    (SW)        │   │    disparo     │   │    (LED/HEX)   │   │    modo        │
  └────────────────┘   └────────────────┘   └────────────────┘   └────────────────┘
```

### 8.1 Reglas que valen para cualquier unidad

| Regla | Por qué |
|---|---|
| Las entradas se capturan **al pulsar**, no al mover el switch | el diseño muestrea en el flanco del botón; mover `SW` no dispara nada |
| Un botón = **un flanco = una operación** | los pulsadores pasan por `pulsador`; mantener pulsado no repite |
| Los resultados que importan suelen estar **latcheados** | el LED/dato sigue visible hasta la siguiente petición |
| Las señales internas (`ready`, `estado`) duran **ciclos**, no segundos | a 50 MHz son invisibles al ojo; se miran en GTKWave |
| Los displays son una "consola" hexadecimal | conviene reservar campos fijos: modo, estado, dato |
| La placa **no muestra la entrada** salvo que se cablee a un display | apunta la dirección o el valor que metes |

### 8.2 Ejemplo completo

En `mapeo-memoria` el guion de 10 pasos, la tabla de direcciones en binario, qué
debe mostrar cada display y los errores típicos están en
**`vhdl/mapeo-memoria/fpga/README.md`** (§4 y §5). Ese README es el modelo a
copiar en cada unidad: controles, qué se ve y guion de demostración.

### 8.3 Checklist para el día de la prueba

- [ ] Llevar el `.sof` ya compilado (`output_files/`, unos 6 MB) además del repo.
- [ ] Llevar la guía de uso de la unidad (README de su `fpga/`) impresa.
- [ ] Cable micro-USB al conector **USB-Blaster II**, no al UART.
- [ ] Encender la placa antes de abrir `Hardware Setup…`.
- [ ] Tras programar: `KEY3` (reset), primera lectura y comprobar que responde.

---

## 9. Por qué no usamos el flujo libre

Se intentó **GHDL + ghdl-yosys-plugin + nextpnr-mistral + openFPGALoader** para
Cyclone V y se descartó:

- `ghdl-yosys-plugin` en `master` usa `twines()`, que no existe en el yosys de
  los repositorios (0.66) → no compila sin actualizar yosys a mano.
- El AUR `yosys-git` exige `_build_patch=false` y arrastra conflictos con el
  paquete `yosys` del sistema; con la base de datos de pacman desfasada falla
  con `404` en dependencias como `python-click`.
- `nextpnr-mistral` no está empaquetado y hay que compilarlo a mano.

Nada de eso hace falta con Quartus, que además trae **Pin Planner** (lo que de
verdad se necesita para una placa con 67 pines) y el Programmer integrado.
