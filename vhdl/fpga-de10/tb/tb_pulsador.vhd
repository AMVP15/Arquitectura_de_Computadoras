-- ============================================================
-- Testbench del detector de flanco de pulsador
-- Comprueba que cada pulsación produce UN solo pulso de un ciclo,
-- que mantener el botón no repite el pulso, que al soltar y volver
-- a pulsar sale otro pulso, y que el reset limpia el estado.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_pulsador is
end entity;

architecture tb of tb_pulsador is
    constant PERIODO : time := 10 ns;

    component pulsador is
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            entrada : in  std_logic;
            pulso   : out std_logic
        );
    end component;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '0';
    signal entrada : std_logic := '0';
    signal pulso   : std_logic;
begin
    dut : pulsador
        port map (
            clk     => clk,
            rst     => rst,
            entrada => entrada,
            pulso   => pulso
        );

    stim : process
        -- avanza n ciclos y devuelve en cuántos de ellos hubo pulso
        -- (se muestrea en la fase baja, justo antes del flanco de subida,
        --  que es donde el pulso combinacional está activo)
        procedure ciclos (n : in natural; pulsos : out natural) is
            variable cuenta : natural := 0;
        begin
            for i in 1 to n loop
                clk <= '0';
                wait for PERIODO / 2;
                if pulso = '1' then
                    cuenta := cuenta + 1;
                end if;
                clk <= '1';
                wait for PERIODO / 2;
            end loop;
            pulsos := cuenta;
        end procedure;

        variable n_pulsos : natural;
    begin
        -- ---- 1) reposo: no hay pulso ----
        ciclos(3, n_pulsos);
        assert n_pulsos = 0
            report "tb_pulsador: en reposo no debe haber pulso" severity failure;

        -- ---- 2) pulsación: exactamente un pulso ----
        entrada <= '1';
        ciclos(1, n_pulsos);
        assert n_pulsos = 1
            report "tb_pulsador: la pulsación debe dar un pulso" severity failure;

        -- ---- 3) mantener pulsado: no repite ----
        ciclos(5, n_pulsos);
        assert n_pulsos = 0
            report "tb_pulsador: mantener pulsado no debe repetir el pulso"
            severity failure;

        -- ---- 4) soltar: tampoco hay pulso ----
        entrada <= '0';
        ciclos(3, n_pulsos);
        assert n_pulsos = 0
            report "tb_pulsador: al soltar no debe haber pulso" severity failure;

        -- ---- 5) segunda pulsación: otro pulso ----
        entrada <= '1';
        ciclos(1, n_pulsos);
        assert n_pulsos = 1
            report "tb_pulsador: la segunda pulsación debe dar otro pulso"
            severity failure;
        ciclos(3, n_pulsos);
        assert n_pulsos = 0
            report "tb_pulsador: el pulso debe durar un solo ciclo"
            severity failure;

        -- ---- 6) el reset limpia el estado ----
        entrada <= '0';
        ciclos(1, n_pulsos);
        rst <= '1';
        ciclos(1, n_pulsos);
        rst <= '0';
        entrada <= '1';
        ciclos(1, n_pulsos);
        assert n_pulsos = 1
            report "tb_pulsador: tras el reset debe volver a detectar el flanco"
            severity failure;

        report "tb_pulsador: OK" severity note;
        wait;
    end process;
end architecture;
