-- ============================================================
-- Testbench del envoltorio de placa de mapeo-memoria
--
-- Verifica el cableado del top_placa sin placa:
--   - un primer acceso falla (miss) y el segundo al mismo bloque acierta
--   - KEY1 cambia de caché y KEY2 invalida la seleccionada
--   - el selector vuelve a 0 después de 2 (2 -> 0)
--   - los displays muestran la caché, el estado y data[15:0]
--
-- Datos de la memoria de fábrica: palabra i = i*3 + 7.
--   addr 0  -> palabra 0  = 7    (0x07)
--   addr 1  -> palabra 0  = 7    (mismo bloque que 0)
--   addr 64 -> palabra 16 = 55   (0x37)
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_placa is
end entity;

architecture tb of tb_top_placa is
    constant PERIODO : time := 10 ns;

    -- patrones de hex7seg (activo a nivel bajo) que se esperan
    constant D0 : std_logic_vector(6 downto 0) := "1000000";
    constant D1 : std_logic_vector(6 downto 0) := "1111001";
    constant D2 : std_logic_vector(6 downto 0) := "0100100";
    constant D3 : std_logic_vector(6 downto 0) := "0110000";
    constant D7 : std_logic_vector(6 downto 0) := "1111000";
    constant DA : std_logic_vector(6 downto 0) := "0001000";

    component top_placa is
        port (
            clk  : in  std_logic;
            key  : in  std_logic_vector(3 downto 0);
            sw   : in  std_logic_vector(9 downto 0);
            ledr : out std_logic_vector(9 downto 0);
            hex0 : out std_logic_vector(6 downto 0);
            hex1 : out std_logic_vector(6 downto 0);
            hex2 : out std_logic_vector(6 downto 0);
            hex3 : out std_logic_vector(6 downto 0);
            hex4 : out std_logic_vector(6 downto 0);
            hex5 : out std_logic_vector(6 downto 0)
        );
    end component;

    signal clk  : std_logic := '0';
    signal key  : std_logic_vector(3 downto 0) := "1111";  -- todo suelto
    signal sw   : std_logic_vector(9 downto 0) := (others => '0');
    signal ledr : std_logic_vector(9 downto 0);
    signal hex0, hex1, hex2 : std_logic_vector(6 downto 0);
    signal hex3, hex4, hex5 : std_logic_vector(6 downto 0);
begin
    dut : top_placa
        port map (
            clk  => clk,
            key  => key,
            sw   => sw,
            ledr => ledr,
            hex0 => hex0,
            hex1 => hex1,
            hex2 => hex2,
            hex3 => hex3,
            hex4 => hex4,
            hex5 => hex5
        );

    stim : process
        procedure ciclos (n : in natural) is
        begin
            for i in 1 to n loop
                clk <= '0';
                wait for PERIODO / 2;
                clk <= '1';
                wait for PERIODO / 2;
            end loop;
        end procedure;

        -- pulsa una tecla (activas a nivel bajo) y deja terminar la FSM
        procedure pulsar (tecla : in natural) is
        begin
            key(tecla) <= '0';
            ciclos(2);
            key(tecla) <= '1';
            ciclos(12);
        end procedure;

        -- selecciona la dirección y lanza una lectura
        procedure acceder (dir : in unsigned(9 downto 0)) is
        begin
            sw <= std_logic_vector(dir);
            wait for PERIODO;
            pulsar(0);
        end procedure;

        -- comprueba los 4 displays de datos contra un valor de 16 bits
        procedure comprobar_data (
            valor : in std_logic_vector(15 downto 0);
            msg   : in string
        ) is
            type tabla_t is array (0 to 15) of std_logic_vector(6 downto 0);
            constant PATRON : tabla_t := (
                D0, D1, D2, D3, "0011001", "0010010", "0000010", D7,
                "0000000", "0010000", "0001000", "0000011", "1000110",
                "0100001", "0000110", "0001110");
        begin
            assert hex3 = PATRON(to_integer(unsigned(valor(15 downto 12))))
                report "tb_top_placa: " & msg & " (nibble 3)" severity failure;
            assert hex2 = PATRON(to_integer(unsigned(valor(11 downto 8))))
                report "tb_top_placa: " & msg & " (nibble 2)" severity failure;
            assert hex1 = PATRON(to_integer(unsigned(valor(7 downto 4))))
                report "tb_top_placa: " & msg & " (nibble 1)" severity failure;
            assert hex0 = PATRON(to_integer(unsigned(valor(3 downto 0))))
                report "tb_top_placa: " & msg & " (nibble 0)" severity failure;
        end procedure;
    begin
        -- ---- 1) reset con KEY3 ----
        key <= "0111";
        ciclos(3);
        assert ledr(0) = '0' and ledr(1) = '0'
            report "tb_top_placa: tras el reset hit y ready deben ser 0"
            severity failure;
        assert hex5 = D0
            report "tb_top_placa: tras el reset debe estar la caché directa"
            severity failure;
        assert hex4 = D0
            report "tb_top_placa: tras el reset la FSM debe estar en IDLE"
            severity failure;
        key <= "1111";
        ciclos(1);

        -- ---- 2) directo: primer acceso = fallo, dato de memoria ----
        acceder(to_unsigned(0, 10));
        assert ledr(0) = '0'
            report "tb_top_placa: el primer acceso debe fallar" severity failure;
        comprobar_data(x"0007", "el fallo debe traer la palabra 0 = 7");

        -- ---- 3) directo: el mismo bloque acierta ----
        acceder(to_unsigned(1, 10));
        assert ledr(0) = '1'
            report "tb_top_placa: el segundo acceso al mismo bloque debe acertar"
            severity failure;
        comprobar_data(x"0007", "el acierto debe devolver la palabra 0");

        -- ---- 4) directo: conflicto (mismo índice, otra etiqueta) ----
        acceder(to_unsigned(64, 10));
        assert ledr(0) = '0'
            report "tb_top_placa: addr 64 compite con la línea 0 en directo"
            severity failure;
        comprobar_data(x"0037", "addr 64 debe traer la palabra 16 = 55");

        -- el bloque 0 ya no está: vuelve a fallar
        acceder(to_unsigned(0, 10));
        assert ledr(0) = '0'
            report "tb_top_placa: tras el conflicto el bloque 0 debe fallar"
            severity failure;

        -- ---- 5) cambio a asociativa por conjuntos (KEY1) ----
        pulsar(1);
        assert hex5 = D1
            report "tb_top_placa: KEY1 debe seleccionar la caché por conjuntos"
            severity failure;

        -- la caché por conjuntos está recién estrenada: fallo y luego acierto
        acceder(to_unsigned(0, 10));
        assert ledr(0) = '0'
            report "tb_top_placa: la caché por conjuntos arranca vacía"
            severity failure;
        comprobar_data(x"0007", "el fallo debe traer la palabra 0 = 7");

        acceder(to_unsigned(0, 10));
        assert ledr(0) = '1'
            report "tb_top_placa: la segunda lectura debe acertar" severity failure;

        -- ---- 6) KEY2 invalida la caché seleccionada ----
        pulsar(2);
        acceder(to_unsigned(0, 10));
        assert ledr(0) = '0'
            report "tb_top_placa: KEY2 debe invalidar las líneas de la caché"
            severity failure;

        -- ---- 7) cambio a asociativa total (KEY1) ----
        pulsar(1);
        assert hex5 = D2
            report "tb_top_placa: KEY1 debe seleccionar la caché asociativa"
            severity failure;
        acceder(to_unsigned(0, 10));
        assert ledr(0) = '0'
            report "tb_top_placa: la asociativa arranca vacía" severity failure;
        acceder(to_unsigned(0, 10));
        assert ledr(0) = '1'
            report "tb_top_placa: la asociativa debe acertar la segunda vez"
            severity failure;
        -- data de la asociativa: palabra 0 = 7, y nibble alto 0
        assert hex1 = D0 and hex0 = D7
            report "tb_top_placa: la asociativa debe devolver la palabra 0"
            severity failure;

        -- ---- 8) el selector vuelve a 0 después de 2 ----
        pulsar(1);
        assert hex5 = D0
            report "tb_top_placa: el selector debe volver a la caché directa"
            severity failure;

        -- ---- 9) el estado de la FSM vuelve a IDLE y ready se apaga ----
        assert hex4 = D0 and ledr(1) = '0'
            report "tb_top_placa: al terminar la FSM estado=IDLE y ready=0"
            severity failure;

        report "tb_top_placa: OK" severity note;
        wait;
    end process;
end architecture;
