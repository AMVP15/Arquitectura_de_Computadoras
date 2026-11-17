-- ============================================================
-- Testbench del decodificador hex7seg
-- Recorre los 16 valores y comprueba el patrón completo de los
-- segmentos, incluido el sentido activo-bajo (los displays de la
-- DE10-Standard son de ánodo común: '0' enciende).
-- Comprueba además que el 0 y el 8 son casos extremos: el 0 tiene
-- un único segmento (g) apagado y el 8 no tiene ninguno apagado.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_hex7seg is
end entity;

architecture tb of tb_hex7seg is
    component hex7seg is
        port (
            valor  : in  std_logic_vector(3 downto 0);
            salida : out std_logic_vector(6 downto 0)
        );
    end component;

    signal valor  : std_logic_vector(3 downto 0) := (others => '0');
    signal salida : std_logic_vector(6 downto 0);

    -- patrones esperados, índice = valor (0..15), activo a nivel bajo
    type tabla_t is array (0 to 15) of std_logic_vector(6 downto 0);
    constant ESPERADO : tabla_t := (
        "1000000",   -- 0
        "1111001",   -- 1
        "0100100",   -- 2
        "0110000",   -- 3
        "0011001",   -- 4
        "0010010",   -- 5
        "0000010",   -- 6
        "1111000",   -- 7
        "0000000",   -- 8
        "0010000",   -- 9
        "0001000",   -- A
        "0000011",   -- b
        "1000110",   -- C
        "0100001",   -- d
        "0000110",   -- E
        "0001110"    -- F
    );
begin
    dut : hex7seg
        port map (
            valor  => valor,
            salida => salida
        );

    stim : process
    begin
        -- ---- 1) los 16 valores ----
        for v in 0 to 15 loop
            valor <= std_logic_vector(to_unsigned(v, 4));
            wait for 10 ns;
            assert salida = ESPERADO(v)
                report "tb_hex7seg: patrón incorrecto para el valor " & integer'image(v)
                severity failure;
        end loop;

        -- ---- 2) comprobaciones de sentido activo-bajo ----
        valor <= x"0";
        wait for 10 ns;
        assert salida(6) = '1' and salida(5 downto 0) = "000000"
            report "tb_hex7seg: el 0 debe apagar solo g (activo a nivel bajo)"
            severity failure;

        valor <= x"8";
        wait for 10 ns;
        assert salida = "0000000"
            report "tb_hex7seg: el 8 debe encender los 7 segmentos"
            severity failure;

        -- el segmento a (bit 0) está encendido con el 8 y con el 0
        valor <= x"0";
        wait for 10 ns;
        assert salida(0) = '0'
            report "tb_hex7seg: el segmento a debe estar encendido en el 0"
            severity failure;

        report "tb_hex7seg: OK" severity note;
        wait;
    end process;
end architecture;
