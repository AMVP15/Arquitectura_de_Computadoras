-- ============================================================
-- Antirrebote (debounce) de una señal de entrada
--
-- La entrada solo se da por buena cuando se mantiene igual a la
-- salida actual durante TIEMPO_MS milisegundos consecutivos. Los
-- rebotes más cortos reinician el contador y no llegan a la salida.
--
-- Uso en la DE10-Standard:
--   FRECUENCIA_HZ = 50_000_000, TIEMPO_MS = 10  ->  500 000 muestras
-- Los pulsadores KEY0..KEY3 ya llevan un disparador de Schmitt en
-- la placa (el manual los documenta como «debounced»), así que este
-- módulo se usa sobre todo con los interruptores SW y con botones
-- externos conectados a un puerto GPIO.
--
-- Requisito: FRECUENCIA_HZ debe ser múltiplo de 1000.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity antirrebote is
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
end entity;

architecture comportamental of antirrebote is
    -- nº de muestras consecutivas que debe durar el cambio
    constant MUESTRAS : natural := (FRECUENCIA_HZ / 1000) * TIEMPO_MS;

    signal contador : natural range 0 to MUESTRAS - 1 := 0;
    signal estable  : std_logic := '0';
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                contador <= 0;
                estable  <= '0';
            elsif entrada = estable then
                contador <= 0;              -- coincide: no hay cambio que medir
            elsif contador = MUESTRAS - 1 then
                contador <= 0;
                estable  <= entrada;        -- cambio sostenido: se acepta
            else
                contador <= contador + 1;
            end if;
        end if;
    end process;

    salida <= estable;
end architecture;
