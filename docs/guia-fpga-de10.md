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
  PLANTILLA-README.md           esqueleto del README de uso de cada unidad

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

Tiempo estimado: 1-2 h; de ellas, 5 minutos son de Quartus. El resto es
escribir el envoltorio y su testbench.

### 6.1 Contrato de puertos (léelo antes de escribir VHDL)

El bloque de pines del `.qsf` asigna **nombres concretos** (`clk`, `key[0]`,
`sw[3]`, `ledr[0]`, `hex0[6]`…). Si tu entidad no usa esos nombres, Quartus
ignora esas asignaciones y los periféricos no responden: parece que "no
funciona la placa" cuando el problema es el nombre de un puerto.

Declara siempre estos siete, con estos nombres y anchos, aunque tu unidad no
use todos:

| Puerto | Tipo | Ancho | Pines |
|---|---|---|---|
| `clk` | in `std_logic` | 1 | `AF14` (CLOCK_50, 50 MHz) |
| `key` | in `std_logic_vector(3 downto 0)` | 4 | `AJ4 AK4 AA14 AA15` (activos a nivel bajo) |
| `sw` | in `std_logic_vector(9 downto 0)` | 10 | `AB30 Y27 AB28 AC30 W25 V25 AC28 AD30 AC29 AA30` |
| `ledr` | out `std_logic_vector(9 downto 0)` | 10 | `AA24 AB23 AC23 AD24 AG25 AF25 AE24 AF24 AB22 AC22` |
| `hex0` … `hex5` | out `std_logic_vector(6 downto 0)` | 7 cada uno | ver `vhdl/fpga-de10/README.md`, Tabla 3-9 |

Reglas:

- La entidad se llama **`top_placa`** (es el `TOP_LEVEL_ENTITY` del `.qsf`).
- Un `sw` que no uses no molesta: es una entrada y simplemente no se lee.
- Un `ledr` o un `hex` que no uses **no se borra del puerto**: se apaga
  (`ledr(x) <= '0'`, `hex4 <= (others => '1')`). Si prefieres borrar sus líneas
  del `.qsf`, asumirás el aviso *Ignored assignments*.

### 6.2 Qué copiar (y qué no)

```bash
git switch dev && git pull
git switch -c vhdl/<unidad>/top-placa
mkdir -p vhdl/<unidad>/fpga
cp vhdl/mapeo-memoria/fpga/{top_placa.qpf,top_placa.qsf,top_placa.sdc,README.md} \
   vhdl/<unidad>/fpga/
```

**No** copies la carpeta entera con `cp -r`: arrastrarías `output_files/`,
`db/`, `incremental_db/` y `c5_pin_model_dump.txt`, que son de la compilación de
la otra unidad (git los ignora, pero ocupan y confunden).

`top_placa.vhd` y `tb_top_placa.vhd` **se escriben nuevos**: el envoltorio es de
tu unidad y el testbench debe comprobar *tus* resultados.

### 6.3 Ajustar el `.qsf`

| Asignación | Qué poner |
|---|---|
| `VHDL_FILE` | tus `../src/*.vhd` y los `../../fpga-de10/src/*.vhd` que uses. **Nunca testbenches** |
| `TOP_LEVEL_ENTITY` | `top_placa` (o el nombre que uses, coherente con la entidad) |
| `SDC_FILE` | el nombre real del `.sdc`; si renombras el proyecto, renómbralo también |
| Bloque de pines | no se toca si respetas el contrato de §6.1 |

El `.sdc` solo restringe `CLOCK_50` a 20 ns. Es suficiente mientras no haya
protocolos síncronos en los pines; sin él, TimeQuest analiza como si el reloj
fuera de 1 GHz.

### 6.4 Qué módulo común usar

| Necesitas… | Usa |
|---|---|
| pasos lentos o parpadeo visible | `divisor` (genera un *tick* de habilitación) |
| leer un switch o un botón externo sin rebotes | `antirrebote` |
| que un botón dispare una acción una sola vez | `pulsador` |
| mostrar un valor de 4 bits | `hex7seg` |

**No derives relojes con lógica** (`clk_div <= not clk_div`): usa el tick del
`divisor` como habilitación. Quartus no puede analizar los tiempos de un reloj
generado así y el diseño deja de ser fiable.

### 6.5 Verificar antes del PR

```bash
scripts/vhdl-analizar <unidad>
scripts/vhdl-sim <unidad> tb_top_placa
```

Checklist:

- [ ] Los dos comandos anteriores terminan correctamente.
- [ ] Quartus compila con **0 errores** y genera `output_files/top_placa.sof`.
- [ ] En `Flow Summary` los pines usados son los del contrato y no hay
      *Ignored assignments* sobre puertos que sí existen.
- [ ] `fpga/README.md` sigue la plantilla
      **`vhdl/fpga-de10/PLANTILLA-README.md`**.
- [ ] `git status` no muestra `db/`, `output_files/`, `*.sof` ni `*.qws`.

### 6.6 Commit y PR

```bash
git add vhdl/<unidad>/fpga
git commit -m "vhdl(<unidad>): añadir envoltorio y proyecto Quartus para la DE10-Standard"
git push -u origin vhdl/<unidad>/top-placa
```

Y abre el PR hacia `dev`.

> Un cambio = una rama. No mezcles el `top_placa` de dos unidades ni el
> envoltorio con cambios del reporte.

### 6.7 Qué NO se versiona

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
