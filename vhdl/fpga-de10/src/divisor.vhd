-- ============================================================
-- Divisor de frecuencia con salida de habilitación (tick)
--
-- Genera un pulso de UN ciclo de reloj cada 1/FRECUENCIA_SALIDA_HZ
-- segundos. No crea un reloj nuevo: produce un «enable» para que el
-- resto del diseño siga trabajando con el reloj de la placa
-- (50 MHz) en lugar de con relojes derivados por lógica, que en
-- FPGA reparten peor y generan avisos en el análisis de tiempos.
--
-- Uso típico en la DE10-Standard:
--   FRECUENCIA_ENTRADA_HZ = 50_000_000 (CLOCK_50)
--   FRECUENCIA_SALIDA_HZ  = 1          (un tick por segundo)
--
-- Requisito: FRECUENCIA_ENTRADA_HZ debe ser múltiplo de
-- FRECUENCIA_SALIDA_HZ; si no lo es, el periodo real es
-- FRECUENCIA_ENTRADA_HZ / floor(división) ciclos.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity divisor is
    generic (
        FRECUENCIA_ENTRADA_HZ : natural := 50_000_000;
        FRECUENCIA_SALIDA_HZ  : natural := 1
    );
    port (
        clk  : in  std_logic;
        rst  : in  std_logic;
        tick : out std_logic
    );
end entity;

architecture comportamental of divisor is
    -- ciclos de reloj que dura un periodo de la salida
    constant CICLOS_POR_PERIODO : natural := FRECUENCIA_ENTRADA_HZ / FRECUENCIA_SALIDA_HZ;

    -- el contador solo necesita contar de 0 a CICLOS_POR_PERIODO-1
    signal contador : natural range 0 to CICLOS_POR_PERIODO - 1 := 0;
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                contador <= 0;
            elsif contador = CICLOS_POR_PERIODO - 1 then
                contador <= 0;              -- se cierra el periodo
            else
                contador <= contador + 1;
            end if;
        end if;
    end process;

    -- combinacional: el pulso dura exactamente el último ciclo del periodo
    tick <= '1' when contador = CICLOS_POR_PERIODO - 1 else '0';
end architecture;
