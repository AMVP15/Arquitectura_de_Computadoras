-- ============================================================
-- Envoltorio de placa de mapeo-memoria (Terasic DE10-Standard)
--
-- No es parte del diseño lógico: conecta las tres cachés de la
-- unidad y la memoria principal a los periféricos de la placa para
-- poder comparar los mapeos sin simulador. Vive en fpga/ (y no en
-- src/) para que scripts/vhdl-analizar y scripts/vhdl-sim sigan
-- trabajando con los módulos originales de la unidad.
--
-- Controles:
--   SW[9:0]  dirección de byte que se quiere leer
--   KEY0     petición de lectura (un flanco = una lectura)
--   KEY1     cambia de caché: directo -> conjuntos -> asociativa
--   KEY2     invalida la caché seleccionada (borra sus líneas)
--   KEY3     reset general (también recarga la memoria)
--
-- Salidas:
--   LEDR[0]     hit del último acceso
--   LEDR[1]     ready del último acceso
--   LEDR[3:2]   estado de la FSM (0 IDLE, 1 COMPARE, 2 FETCH, 3 DONE)
--   HEX5        caché seleccionada (0 directo, 1 conjuntos, 2 asociativa)
--   HEX4        estado de la FSM
--   HEX3..HEX0  data[15:0] en hexadecimal
--
-- Decisiones de diseño:
--   - Solo la caché seleccionada recibe `req`; las otras dos se quedan
--     en IDLE con mem_req = '0'. Por eso no hace falta el árbitro que
--     usa tb_comparacion_mapeos: nunca hay dos peticiones a la vez.
--   - El cambio de caché se acepta solo si la seleccionada está en IDLE,
--     para no dejar una transferencia a medias.
--   - `mem_data` y `mem_ready` se difunden a las tres cachés; `mem_addr`
--     y `mem_req` salen de la seleccionada.
--   - data tiene 32 bits y solo hay 6 displays: se muestran los 16 bits
--     bajos, que cubren de sobra el patrón de fábrica (palabra i = i*3+7,
--     máximo 772). Los 16 altos se pueden ver en simulación.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_placa is
    port (
        clk  : in  std_logic;                     -- CLOCK_50
        key  : in  std_logic_vector(3 downto 0);  -- KEY[3..0], activo bajo
        sw   : in  std_logic_vector(9 downto 0);  -- SW[9..0]
        ledr : out std_logic_vector(9 downto 0);  -- LEDR[9..0]
        hex0 : out std_logic_vector(6 downto 0);  -- HEX0, activo bajo
        hex1 : out std_logic_vector(6 downto 0);
        hex2 : out std_logic_vector(6 downto 0);
        hex3 : out std_logic_vector(6 downto 0);
        hex4 : out std_logic_vector(6 downto 0);
        hex5 : out std_logic_vector(6 downto 0)
    );
end entity;

architecture estructural of top_placa is
    component cache_directo is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            addr      : in  unsigned(9 downto 0);
            req       : in  std_logic;
            ready     : out std_logic;
            data      : out unsigned(31 downto 0);
            hit       : out std_logic;
            estado    : out unsigned(1 downto 0);
            mem_addr  : out unsigned(9 downto 0);
            mem_req   : out std_logic;
            mem_data  : in  unsigned(31 downto 0);
            mem_ready : in  std_logic
        );
    end component;

    component cache_conjuntos is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            addr      : in  unsigned(9 downto 0);
            req       : in  std_logic;
            ready     : out std_logic;
            data      : out unsigned(31 downto 0);
            hit       : out std_logic;
            estado    : out unsigned(1 downto 0);
            mem_addr  : out unsigned(9 downto 0);
            mem_req   : out std_logic;
            mem_data  : in  unsigned(31 downto 0);
            mem_ready : in  std_logic
        );
    end component;

    component cache_asociativa is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            addr      : in  unsigned(9 downto 0);
            req       : in  std_logic;
            ready     : out std_logic;
            data      : out unsigned(31 downto 0);
            hit       : out std_logic;
            estado    : out unsigned(1 downto 0);
            mem_addr  : out unsigned(9 downto 0);
            mem_req   : out std_logic;
            mem_data  : in  unsigned(31 downto 0);
            mem_ready : in  std_logic
        );
    end component;

    component memoria_principal is
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            addr    : in  unsigned(9 downto 0);
            req     : in  std_logic;
            ready   : out std_logic;
            data    : out unsigned(31 downto 0);
            wr_en   : in  std_logic;
            wr_addr : in  unsigned(9 downto 0);
            wr_data : in  unsigned(31 downto 0)
        );
    end component;

    component pulsador is
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            entrada : in  std_logic;
            pulso   : out std_logic
        );
    end component;

    component hex7seg is
        port (
            valor  : in  std_logic_vector(3 downto 0);
            salida : out std_logic_vector(6 downto 0)
        );
    end component;

    signal rst_global   : std_logic;
    signal req_pulso    : std_logic;
    signal cambio_pulso : std_logic;
    signal limpiar_pulso : std_logic;

    -- caché seleccionada: 0 = directo, 1 = conjuntos, 2 = asociativa
    signal sel : unsigned(1 downto 0) := (others => '0');

    -- reset y petición de cada caché
    signal rst_d, rst_c, rst_a : std_logic;
    signal req_d, req_c, req_a : std_logic;
    signal es_d, es_c, es_a    : std_logic;

    -- respuesta de cada caché (antes del multiplexor)
    signal data_d, data_c, data_a     : unsigned(31 downto 0);
    signal hit_d, hit_c, hit_a        : std_logic;
    signal ready_d, ready_c, ready_a  : std_logic;
    signal estado_d, estado_c, estado_a : unsigned(1 downto 0);

    -- bus de memoria de cada caché
    signal mem_addr_d, mem_addr_c, mem_addr_a : unsigned(9 downto 0);
    signal mem_req_d, mem_req_c, mem_req_a    : std_logic;

    -- bus de memoria compartido
    signal mem_addr  : unsigned(9 downto 0);
    signal mem_req   : std_logic;
    signal mem_data  : unsigned(31 downto 0);
    signal mem_ready : std_logic;

    -- respuesta de la caché seleccionada
    signal data_sel   : unsigned(31 downto 0);
    signal hit_sel    : std_logic;
    signal ready_sel  : std_logic;
    signal estado_sel : unsigned(1 downto 0);

    -- valores de 4 bits para los displays
    signal nibble_sel    : std_logic_vector(3 downto 0);
    signal nibble_estado : std_logic_vector(3 downto 0);
begin
    ------------------------------------------------------------------
    -- Entradas de la placa
    ------------------------------------------------------------------
    -- los pulsadores cierran a masa: se invierten para el reset (activo
    -- a nivel alto) y para el detector de flanco
    rst_global <= not key(3);

    u_req : pulsador
        port map (
            clk     => clk,
            rst     => rst_global,
            entrada => not key(0),
            pulso   => req_pulso
        );

    u_cambio : pulsador
        port map (
            clk     => clk,
            rst     => rst_global,
            entrada => not key(1),
            pulso   => cambio_pulso
        );

    u_limpiar : pulsador
        port map (
            clk     => clk,
            rst     => rst_global,
            entrada => not key(2),
            pulso   => limpiar_pulso
        );

    ------------------------------------------------------------------
    -- Selector de caché
    ------------------------------------------------------------------
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_global = '1' then
                sel <= (others => '0');
            elsif cambio_pulso = '1' and estado_sel = "00" then
                if sel = 2 then
                    sel <= (others => '0');   -- 2 -> 0
                else
                    sel <= sel + 1;
                end if;
            end if;
        end if;
    end process;

    -- ¿qué caché está seleccionada?
    es_d <= '1' when sel = "00" else '0';
    es_c <= '1' when sel = "01" else '0';
    es_a <= '1' when sel = "10" else '0';

    -- KEY2 invalida solo la caché seleccionada; KEY3 resetea todas
    rst_d <= rst_global or (limpiar_pulso and es_d);
    rst_c <= rst_global or (limpiar_pulso and es_c);
    rst_a <= rst_global or (limpiar_pulso and es_a);

    -- solo la seleccionada ve la petición
    req_d <= req_pulso and es_d;
    req_c <= req_pulso and es_c;
    req_a <= req_pulso and es_a;

    ------------------------------------------------------------------
    -- Multiplexor de la caché seleccionada
    ------------------------------------------------------------------
    with sel select data_sel <=
        data_d when "00",
        data_c when "01",
        data_a when others;

    with sel select hit_sel <=
        hit_d when "00",
        hit_c when "01",
        hit_a when others;

    with sel select ready_sel <=
        ready_d when "00",
        ready_c when "01",
        ready_a when others;

    with sel select estado_sel <=
        estado_d when "00",
        estado_c when "01",
        estado_a when others;

    with sel select mem_addr <=
        mem_addr_d when "00",
        mem_addr_c when "01",
        mem_addr_a when others;

    with sel select mem_req <=
        mem_req_d when "00",
        mem_req_c when "01",
        mem_req_a when others;

    ------------------------------------------------------------------
    -- Las tres cachés y la memoria compartida
    ------------------------------------------------------------------
    u_directo : cache_directo
        port map (
            clk       => clk,
            rst       => rst_d,
            addr      => unsigned(sw),
            req       => req_d,
            ready     => ready_d,
            data      => data_d,
            hit       => hit_d,
            estado    => estado_d,
            mem_addr  => mem_addr_d,
            mem_req   => mem_req_d,
            mem_data  => mem_data,
            mem_ready => mem_ready
        );

    u_conjuntos : cache_conjuntos
        port map (
            clk       => clk,
            rst       => rst_c,
            addr      => unsigned(sw),
            req       => req_c,
            ready     => ready_c,
            data      => data_c,
            hit       => hit_c,
            estado    => estado_c,
            mem_addr  => mem_addr_c,
            mem_req   => mem_req_c,
            mem_data  => mem_data,
            mem_ready => mem_ready
        );

    u_asociativa : cache_asociativa
        port map (
            clk       => clk,
            rst       => rst_a,
            addr      => unsigned(sw),
            req       => req_a,
            ready     => ready_a,
            data      => data_a,
            hit       => hit_a,
            estado    => estado_a,
            mem_addr  => mem_addr_a,
            mem_req   => mem_req_a,
            mem_data  => mem_data,
            mem_ready => mem_ready
        );

    u_memoria : memoria_principal
        port map (
            clk     => clk,
            rst     => rst_global,
            addr    => mem_addr,
            req     => mem_req,
            ready   => mem_ready,
            data    => mem_data,
            wr_en   => '0',                    -- escritura solo en testbenches
            wr_addr => (others => '0'),
            wr_data => (others => '0')
        );

    ------------------------------------------------------------------
    -- Salidas de la placa
    ------------------------------------------------------------------
    ledr(0) <= hit_sel;
    ledr(1) <= ready_sel;
    ledr(3 downto 2) <= std_logic_vector(estado_sel);
    ledr(9 downto 4) <= (others => '0');

    nibble_sel    <= "00" & std_logic_vector(sel);
    nibble_estado <= "00" & std_logic_vector(estado_sel);

    u_hex5 : hex7seg port map (valor => nibble_sel,                    salida => hex5);
    u_hex4 : hex7seg port map (valor => nibble_estado,                 salida => hex4);
    u_hex3 : hex7seg port map (valor => std_logic_vector(data_sel(15 downto 12)), salida => hex3);
    u_hex2 : hex7seg port map (valor => std_logic_vector(data_sel(11 downto 8)),  salida => hex2);
    u_hex1 : hex7seg port map (valor => std_logic_vector(data_sel(7 downto 4)),   salida => hex1);
    u_hex0 : hex7seg port map (valor => std_logic_vector(data_sel(3 downto 0)),   salida => hex0);
end architecture;
