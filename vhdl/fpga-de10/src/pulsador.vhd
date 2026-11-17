-- ============================================================
-- Pulsador: convierte el nivel de un botón en un pulso de UN ciclo
--
-- Cada vez que `entrada` pasa de '0' a '1' se emite un único pulso
-- de un ciclo de reloj, aunque el botón siga pulsado. Es lo que
-- necesitan las máquinas de estados que arrancan con un flanco
-- (por ejemplo, `req` en las cachés de mapeo-memoria).
--
-- Los pulsadores KEY0..KEY3 de la DE10-Standard son activos a nivel
-- bajo (cierran a masa) y ya llevan un disparador de Schmitt en la
-- placa, así que no hace falta antirrebote por software: se conecta
-- la entrada invertida, por ejemplo
--     u_pulsador : pulsador port map (clk => clk, rst => rst,
--                                     entrada => not key(0), pulso => req);
--
-- Este módulo no sustituye a `antirrebote`: si la señal viene de un
-- interruptor (SW) o de un botón externo sin acondicionar, hay que
-- pasar primero por `antirrebote`.
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity pulsador is
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        entrada : in  std_logic;
        pulso   : out std_logic
    );
end entity;

architecture comportamental of pulsador is
    -- valor de la entrada en el ciclo anterior
    signal anterior : std_logic := '0';
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                anterior <= '0';
            else
                anterior <= entrada;
            end if;
        end if;
    end process;

    -- flanco de subida: dura exactamente el ciclo en que cambia
    pulso <= entrada and (not anterior);
end architecture;
