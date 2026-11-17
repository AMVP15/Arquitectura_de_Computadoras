-- ============================================================
-- Testbench del divisor de frecuencia
-- Comprueba que `tick` dura un solo ciclo y que aparece cada
-- CICLOS ciclos de reloj, y que el reset reinicia la cuenta.
-- Se instancia con frecuencias pequeñas (10 Hz -> 2 Hz, CICLOS=5)
-- para no simular 50 millones de ciclos.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_divisor is
end entity;

architecture tb of tb_divisor is
    constant PERIODO : time    := 10 ns;
    constant CICLOS : natural := 5;      -- 10 Hz / 2 Hz

    component divisor is
        generic (
            FRECUENCIA_ENTRADA_HZ : natural := 50_000_000;
            FRECUENCIA_SALIDA_HZ  : natural := 1
        );
        port (
            clk  : in  std_logic;
            rst  : in  std_logic;
            tick : out std_logic
        );
    end component;

    signal clk  : std_logic := '0';
    signal rst  : std_logic := '0';
    signal tick : std_logic;
begin
    dut : divisor
        generic map (
            FRECUENCIA_ENTRADA_HZ => 10,
            FRECUENCIA_SALIDA_HZ  => 2
        )
        port map (
            clk  => clk,
            rst  => rst,
            tick => tick
        );

    stim : process
        -- cuenta cuántos ticks han salido en la ventana de prueba
        variable ticks : natural := 0;
    begin
        -- ---- 1) patrón periódico: tick solo en el último ciclo ----
        for n in 1 to 3 * CICLOS loop
            clk <= '0';
            wait for PERIODO / 2;

            -- tras n-1 flancos, el contador vale (n-1) mod CICLOS
            if ((n - 1) mod CICLOS) = CICLOS - 1 then
                assert tick = '1'
                    report "tb_divisor: falta el tick del ciclo " & integer'image(n)
                    severity failure;
                ticks := ticks + 1;
            else
                assert tick = '0'
                    report "tb_divisor: tick prematuro en el ciclo " & integer'image(n)
                    severity failure;
            end if;

            clk <= '1';
            wait for PERIODO / 2;
        end loop;

        assert ticks = 3
            report "tb_divisor: se esperaban 3 ticks en 15 ciclos"
            severity failure;

        -- ---- 2) el reset reinicia el contador ----
        -- se deja el contador a mitad de periodo, se resetea y se
        -- comprueba que el siguiente tick vuelve a tardar CICLOS ciclos
        clk <= '0'; wait for PERIODO / 2;
        rst <= '1';
        clk <= '1'; wait for PERIODO / 2;
        rst <= '0';

        for n in 1 to CICLOS loop
            clk <= '0';
            wait for PERIODO / 2;

            if n = CICLOS then
                assert tick = '1'
                    report "tb_divisor: tras el reset el tick debe llegar en el ciclo CICLOS"
                    severity failure;
            else
                assert tick = '0'
                    report "tb_divisor: tras el reset hay un tick prematuro"
                    severity failure;
            end if;

            clk <= '1';
            wait for PERIODO / 2;
        end loop;

        report "tb_divisor: OK" severity note;
        wait;
    end process;
end architecture;
