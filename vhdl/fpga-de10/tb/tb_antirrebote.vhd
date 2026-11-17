-- ============================================================
-- Testbench del antirrebote
-- Con FRECUENCIA_HZ = 1000 y TIEMPO_MS = 10 cada cambio debe
-- mantenerse 10 muestras (10 ciclos de reloj) para llegar a la
-- salida. Se comprueban: rebotes que NO deben pasar, un cambio
-- limpio que SÍ pasa, un glitch corto que se ignora y el reset.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity tb_antirrebote is
end entity;

architecture tb of tb_antirrebote is
    constant PERIODO : time    := 1 us;
    constant MUESTRAS : natural := 10;   -- (1000/1000)*10

    component antirrebote is
        generic (
            FRECUENCIA_HZ : natural := 50_000_000;
            TIEMPO_MS     : natural := 10
        );
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            entrada : in  std_logic;
            salida  : out std_logic
        );
    end component;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '0';
    signal entrada : std_logic := '0';
    signal salida  : std_logic;
begin
    dut : antirrebote
        generic map (
            FRECUENCIA_HZ => 1000,
            TIEMPO_MS     => 10
        )
        port map (
            clk     => clk,
            rst     => rst,
            entrada => entrada,
            salida  => salida
        );

    -- reloj y estímulos: el reloj se genera dentro del proceso para que la
    -- simulación termine cuando acaba el testbench (un generador concurrente
    -- mantendría GHDL en marcha indefinidamente).
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
    begin
        -- ---- 1) estado inicial: salida a 0 ----
        ciclos(2);
        assert salida = '0'
            report "tb_antirrebote: la salida debe arrancar en 0" severity failure;

        -- ---- 2) rebotes: 1,0,1,0... cada 3 ciclos (no llega a 10) ----
        for i in 1 to 6 loop
            entrada <= '1'; ciclos(3);
            entrada <= '0'; ciclos(3);
        end loop;
        assert salida = '0'
            report "tb_antirrebote: los rebotes no deben llegar a la salida"
            severity failure;

        -- ---- 3) cambio limpio a 1 durante MUESTRAS ciclos ----
        entrada <= '1';
        ciclos(MUESTRAS - 1);
        assert salida = '0'
            report "tb_antirrebote: la salida cambia antes de tiempo"
            severity failure;
        ciclos(1);
        assert salida = '1'
            report "tb_antirrebote: la salida no acepta un 1 sostenido"
            severity failure;

        -- ---- 4) glitch corto a 0: la salida debe seguir en 1 ----
        entrada <= '0';
        ciclos(MUESTRAS - 2);
        entrada <= '1';
        ciclos(MUESTRAS * 2);
        assert salida = '1'
            report "tb_antirrebote: un glitch corto no debe cambiar la salida"
            severity failure;

        -- ---- 5) cambio limpio a 0 ----
        entrada <= '0';
        ciclos(MUESTRAS);
        assert salida = '0'
            report "tb_antirrebote: la salida no acepta un 0 sostenido"
            severity failure;

        -- ---- 6) reset con la entrada en 1 ----
        entrada <= '1';
        ciclos(MUESTRAS);
        assert salida = '1'
            report "tb_antirrebote: antes del reset la salida debe ser 1"
            severity failure;
        rst <= '1';
        ciclos(1);
        rst <= '0';
        assert salida = '0'
            report "tb_antirrebote: el reset debe dejar la salida en 0"
            severity failure;

        report "tb_antirrebote: OK" severity note;
        wait;
    end process;
end architecture;
