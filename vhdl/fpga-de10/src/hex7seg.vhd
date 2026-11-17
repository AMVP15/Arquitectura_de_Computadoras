-- ============================================================
-- Decodificador de 4 bits a display de 7 segmentos
--
-- Los displays de la DE10-Standard son de ÁNODO COMÚN: cada
-- segmento se enciende con un '0' lógico y se apaga con un '1'.
-- Por eso la salida es activa a nivel bajo.
--
-- Orden de los bits de `salida` (el mismo del manual de la placa,
-- Tabla 3-9, y el de las asignaciones de pin del .qsf):
--   salida(0) = a
--   salida(1) = b
--   salida(2) = c
--   salida(3) = d
--   salida(4) = e
--   salida(5) = f
--   salida(6) = g
-- (el punto decimal no está conectado en estos displays)
--
--        aaa
--       f   b
--       f   b
--        ggg
--       e   c
--       e   c
--        ddd
--
-- Ejemplo: valor = x"0" -> "1000000" (solo g apagado, se lee 0)
-- ============================================================
library ieee;
use ieee.std_logic_1164.all;

entity hex7seg is
    port (
        valor  : in  std_logic_vector(3 downto 0);
        salida : out std_logic_vector(6 downto 0)
    );
end entity;

architecture comportamental of hex7seg is
begin
    process (valor)
    begin
        --                        gfedcba   (0 = segmento encendido)
        case valor is
            when "0000" => salida <= "1000000";   -- 0
            when "0001" => salida <= "1111001";   -- 1
            when "0010" => salida <= "0100100";   -- 2
            when "0011" => salida <= "0110000";   -- 3
            when "0100" => salida <= "0011001";   -- 4
            when "0101" => salida <= "0010010";   -- 5
            when "0110" => salida <= "0000010";   -- 6
            when "0111" => salida <= "1111000";   -- 7
            when "1000" => salida <= "0000000";   -- 8
            when "1001" => salida <= "0010000";   -- 9
            when "1010" => salida <= "0001000";   -- A
            when "1011" => salida <= "0000011";   -- b
            when "1100" => salida <= "1000110";   -- C
            when "1101" => salida <= "0100001";   -- d
            when "1110" => salida <= "0000110";   -- E
            when others => salida <= "0001110";   -- F
        end case;
    end process;
end architecture;
