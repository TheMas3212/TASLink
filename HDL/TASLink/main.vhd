library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main is
    Port ( CLK : in std_logic;
           RX : in std_logic;
           TX : out std_logic;
           btn : in  STD_LOGIC_VECTOR (3 downto 0);
           p1_latch : in  STD_LOGIC;
           p1_clock : in  STD_LOGIC;
           p1_d0 : out STD_LOGIC;
           p1_d1 : out STD_LOGIC;
           p1_io : in STD_LOGIC;
           p2_latch : in std_logic;
           p2_clock : in std_logic;
           p2_d0 : out std_logic;
           p2_d1 : out std_logic;
           p2_io : in std_logic;
           p1_d0_oe : out std_logic;
           p2_d0_oe : out std_logic;
           p1_d1_oe : out std_logic;
           p2_d1_oe : out std_logic;
           debug : out STD_LOGIC_VECTOR (3 downto 0);
           l: out STD_LOGIC_VECTOR(3 downto 0));
end main;

architecture Behavioral of main is
  component shift_register is
    Port ( latch : in  STD_LOGIC;
           clock : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (7 downto 0);
           dout : out  STD_LOGIC;
           sin : in STD_LOGIC;
           clk : in std_logic);
  end component;
  
  component filter is
    Port ( signal_in : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           signal_out : out  STD_LOGIC);
  end component;
  
  component toggle is
    Port ( signal_in : in  STD_LOGIC;
           signal_out : out  STD_LOGIC);
  end component;
  
  component UART is
    Port ( rx_data_out : out STD_LOGIC_VECTOR (7 downto 0);
           rx_data_was_recieved : in STD_LOGIC;
           rx_byte_waiting : out STD_LOGIC;
           clk : in  STD_LOGIC;

           rx_in : in STD_LOGIC;
           tx_data_in : in STD_LOGIC_VECTOR (7 downto 0);
           tx_buffer_full : out STD_LOGIC;
           tx_write : in STD_LOGIC;
           tx_out : out STD_LOGIC);
  end component;
  
  component controller is
    Port ( console_clock : in  STD_LOGIC;
           console_latch : in  STD_LOGIC;
           console_io : in  STD_LOGIC;
           console_d0 : out  STD_LOGIC;
           console_d1 : out  STD_LOGIC;
           console_d0_oe : out  STD_LOGIC;
           console_d1_oe : out  STD_LOGIC;
           data : in  STD_LOGIC_VECTOR (31 downto 0);
           overread_value : in  STD_LOGIC;
           size : in  STD_LOGIC_VECTOR (1 downto 0);
           connected : in  STD_LOGIC;
           clk : STD_LOGIC);
  end component;
  
  component snes_multitap is
    Port ( console_clock : in  STD_LOGIC;
           console_latch : in  STD_LOGIC;
           console_io : in  STD_LOGIC;
           console_d0 : out  STD_LOGIC;
           console_d1 : out  STD_LOGIC;
           console_d0_oe : out  STD_LOGIC;
           console_d1_oe : out  STD_LOGIC;
           
           clk : in  STD_LOGIC;
           sw : in  STD_LOGIC;
           
           port1_latch : out  STD_LOGIC;
           port1_clock : out  STD_LOGIC;
           port1_io : out  STD_LOGIC;
           port1_d0 : in  STD_LOGIC;
           port1_d1 : in  STD_LOGIC;
           port1_d0_oe : in  STD_LOGIC;
           port1_d1_oe : in  STD_LOGIC;
           
           port2_latch : out  STD_LOGIC;
           port2_clock : out  STD_LOGIC;
           port2_io : out  STD_LOGIC;
           port2_d0 : in  STD_LOGIC;
           port2_d1 : in  STD_LOGIC;
           port2_d0_oe : in  STD_LOGIC;
           port2_d1_oe : in  STD_LOGIC;
           
           port3_latch : out  STD_LOGIC;
           port3_clock : out  STD_LOGIC;
           port3_io : out  STD_LOGIC;
           port3_d0 : in  STD_LOGIC;
           port3_d1 : in  STD_LOGIC;
           port3_d0_oe : in  STD_LOGIC;
           port3_d1_oe : in  STD_LOGIC;
           
           port4_latch : out  STD_LOGIC;
           port4_clock : out  STD_LOGIC;
           port4_io : out  STD_LOGIC;
           port4_d0 : in  STD_LOGIC;
           port4_d1 : in  STD_LOGIC;
           port4_d0_oe : in  STD_LOGIC;
           port4_d1_oe : in  STD_LOGIC);
  end component;

  -- Filtered signals coming from the console
  signal p1_clock_f : std_logic;
  signal p1_latch_f : std_logic;
  signal p1_io_f : std_logic;
  signal p2_clock_f : std_logic;
  signal p2_latch_f : std_logic;
  signal p2_io_f : std_logic;
  
  -- Toggle signals, useful for monitoring when the FPGA detects a rising edge
  signal p1_clock_toggle : std_logic;
  signal p1_latch_toggle : std_logic;
  signal p1_clock_f_toggle : std_logic;
  signal p1_latch_f_toggle : std_logic;
  signal p2_clock_toggle : std_logic;
  signal p2_latch_toggle : std_logic;
  signal p2_clock_f_toggle : std_logic;
  signal p2_latch_f_toggle : std_logic;
  
  signal data_from_uart : STD_LOGIC_VECTOR (7 downto 0);
  signal uart_data_recieved : STD_LOGIC := '0';
  signal uart_byte_waiting : STD_LOGIC := '0';
  
  signal data_to_uart : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
  signal uart_buffer_full : STD_LOGIC;
  signal uart_write : STD_LOGIC := '0';
  
  signal serial_receive_mode : std_logic_vector (2 downto 0) := (others => '0');
  signal uart_buffer_ptr : integer range 0 to 16 := 0;
  
  type BUTTON_DATA_buffer is array(0 to 31) of std_logic_vector(31 downto 0);
  type BUTTON_DATA_buffer_array is array(1 to 8) of BUTTON_DATA_buffer;
  signal button_queue : BUTTON_DATA_buffer_array;
    
  signal buffer_tail : integer range 0 to 31 := 0;
  signal buffer_head : integer range 0 to 31 := 0;
  
  signal prev_latch : std_logic := '0';
  
  signal frame_timer_active : std_logic := '0';
  signal frame_timer : integer range 0 to 160000 := 0;
  
  signal windowed_mode : std_logic := '0';
  
  signal uart_data_temp : std_logic_vector(7 downto 0);
  
  signal controller_size : std_logic_vector(1 downto 0) := "00";
  
  type logic_array is array (natural range <>) of std_logic;
  signal controller_clock : logic_array(8 downto 1);
  signal controller_latch : logic_array(8 downto 1);
  signal controller_io : logic_array(8 downto 1);
  signal controller_d0 : logic_array(8 downto 1);
  signal controller_d1 : logic_array(8 downto 1);
  signal controller_d0_oe : logic_array(8 downto 1);
  signal controller_d1_oe : logic_array(8 downto 1);
  signal controller_overread_value : logic_array(8 downto 1);
  signal controller_connected : logic_array(8 downto 1);
  
  type vector32 is array (natural range <>) of std_logic_vector(31 downto 0);
  signal controller_data : vector32(8 downto 1);


  signal multitap1_d0 : std_logic;
  signal multitap1_d1 : std_logic;
  signal multitap1_d0_oe : std_logic;
  signal multitap1_d1_oe : std_logic;
                                                                                  
  signal multitap1_port1_latch : std_logic;
  signal multitap1_port1_clock : std_logic;
  signal multitap1_port1_io : std_logic;
  signal multitap1_port1_d0 : std_logic;
  signal multitap1_port1_d1 : std_logic;
  signal multitap1_port1_d0_oe : std_logic;
  signal multitap1_port1_d1_oe : std_logic;
                                        
  signal multitap1_port2_latch : std_logic;
  signal multitap1_port2_clock : std_logic;
  signal multitap1_port2_io : std_logic;
  signal multitap1_port2_d0 : std_logic;
  signal multitap1_port2_d1 : std_logic;
  signal multitap1_port2_d0_oe : std_logic;
  signal multitap1_port2_d1_oe : std_logic;
                                        
  signal multitap1_port3_latch : std_logic;
  signal multitap1_port3_clock : std_logic;
  signal multitap1_port3_io : std_logic;
  signal multitap1_port3_d0 : std_logic;
  signal multitap1_port3_d1 : std_logic;
  signal multitap1_port3_d0_oe : std_logic;
  signal multitap1_port3_d1_oe : std_logic;
                                         
  signal multitap1_port4_latch : std_logic;
  signal multitap1_port4_clock : std_logic;
  signal multitap1_port4_io : std_logic;
  signal multitap1_port4_d0 : std_logic;
  signal multitap1_port4_d1 : std_logic;
  signal multitap1_port4_d0_oe : std_logic;
  signal multitap1_port4_d1_oe : std_logic;
  
  signal use_multitap1 : std_logic := '0';
  
  signal multitap2_d0 : std_logic;
  signal multitap2_d1 : std_logic;
  signal multitap2_d0_oe : std_logic;
  signal multitap2_d1_oe : std_logic;
                                                                                  
  signal multitap2_port1_latch : std_logic;
  signal multitap2_port1_clock : std_logic;
  signal multitap2_port1_io : std_logic;
  signal multitap2_port1_d0 : std_logic;
  signal multitap2_port1_d1 : std_logic;
  signal multitap2_port1_d0_oe : std_logic;
  signal multitap2_port1_d1_oe : std_logic;
                                        
  signal multitap2_port2_latch : std_logic;
  signal multitap2_port2_clock : std_logic;
  signal multitap2_port2_io : std_logic;
  signal multitap2_port2_d0 : std_logic;
  signal multitap2_port2_d1 : std_logic;
  signal multitap2_port2_d0_oe : std_logic;
  signal multitap2_port2_d1_oe : std_logic;
                                        
  signal multitap2_port3_latch : std_logic;
  signal multitap2_port3_clock : std_logic;
  signal multitap2_port3_io : std_logic;
  signal multitap2_port3_d0 : std_logic;
  signal multitap2_port3_d1 : std_logic;
  signal multitap2_port3_d0_oe : std_logic;
  signal multitap2_port3_d1_oe : std_logic;
                                         
  signal multitap2_port4_latch : std_logic;
  signal multitap2_port4_clock : std_logic;
  signal multitap2_port4_io : std_logic;
  signal multitap2_port4_d0 : std_logic;
  signal multitap2_port4_d1 : std_logic;
  signal multitap2_port4_d0_oe : std_logic;
  signal multitap2_port4_d1_oe : std_logic;
  
  signal use_multitap2 : std_logic := '0';

  
  signal address_to_use : integer range 0 to 63;
begin

  p1_latch_filter: filter port map (signal_in => p1_latch,
                                    clk => CLK,
                                    signal_out => p1_latch_f);
                                 
  p1_clock_filter: filter port map (signal_in => p1_clock,
                                    clk => CLK,
                                    signal_out => p1_clock_f);
  
  p1_io_filter: filter port map (signal_in => p1_io,
                                 clk => CLK,
                                 signal_out => p1_io_f);
                                 
  p2_latch_filter: filter port map (signal_in => p2_latch,
                                    clk => CLK,
                                    signal_out => p2_latch_f);
                                 
  p2_clock_filter: filter port map (signal_in => p2_clock,
                                    clk => CLK,
                                    signal_out => p2_clock_f);

  p2_io_filter: filter port map (signal_in => p2_io,
                                 clk => CLK,
                                 signal_out => p2_io_f);

                                    
  p1latch_toggle: toggle port map (signal_in => p1_latch,
                                   signal_out => p1_latch_toggle);
                                 
  p1latch_f_toggle: toggle port map (signal_in => p1_latch_f,
                                     signal_out => p1_latch_f_toggle);
  
  p1clk_toggle: toggle port map (signal_in => p1_clock,
                                 signal_out => p1_clock_toggle);
  
  p1clock_f_toggle: toggle port map (signal_in => p1_clock_f,
                                     signal_out => p1_clock_f_toggle);

  p2latch_toggle: toggle port map (signal_in => p2_latch,
                                   signal_out => p2_latch_toggle);
                                 
  p2latch_f_toggle: toggle port map (signal_in => p2_latch_f,
                                     signal_out => p2_latch_f_toggle);
  
  p2clk_toggle: toggle port map (signal_in => p2_clock,
                                 signal_out => p2_clock_toggle);
  
  p2clock_f_toggle: toggle port map (signal_in => p2_clock_f,
                                     signal_out => p2_clock_f_toggle);
                                     
  uart1: UART port map (rx_data_out => data_from_uart,
                        rx_data_was_recieved => uart_data_recieved,
                        rx_byte_waiting => uart_byte_waiting,
                        clk => CLK,
                        rx_in => RX,
                        tx_data_in => data_to_uart,
                        tx_buffer_full => uart_buffer_full,
                        tx_write => uart_write,
                        tx_out => TX);
 
  GENERATE_CONTROLLERS:
  for I in 1 to 8 generate
    controllers: controller port map (console_clock => controller_clock(I),
                                     console_latch => controller_latch(I),
                                     console_io => controller_io(I),
                                     console_d0 => controller_d0(I),
                                     console_d1 => controller_d1(I),
                                     console_d0_oe => controller_d0_oe(I),
                                     console_d1_oe => controller_d1_oe(I),
                                     data => controller_data(I),
                                     overread_value => controller_overread_value(I),
                                     size => controller_size,
                                     connected => controller_connected(I),
                                     clk => clk);
  end generate GENERATE_CONTROLLERS;
  
  multitap1: snes_multitap port map ( console_clock => p1_clock_f,
                                      console_latch => p1_latch_f,
                                      console_io => p1_io_f,
                                      console_d0 => multitap1_d0,
                                      console_d1 => multitap1_d1,
                                      console_d0_oe => multitap1_d0_oe,
                                      console_d1_oe => multitap1_d1_oe,
                                       
                                      clk => clk,
                                      sw => '1',
                                       
                                      port1_latch => multitap1_port1_latch,
                                      port1_clock => multitap1_port1_clock,
                                      port1_io => multitap1_port1_io,
                                      port1_d0 => multitap1_port1_d0,
                                      port1_d1 => multitap1_port1_d1,
                                      port1_d0_oe => multitap1_port1_d0_oe,
                                      port1_d1_oe => multitap1_port1_d1_oe,
                                      
                                      port2_latch => multitap1_port2_latch,
                                      port2_clock => multitap1_port2_clock,
                                      port2_io => multitap1_port2_io,
                                      port2_d0 => multitap1_port2_d0,
                                      port2_d1 => multitap1_port2_d1,
                                      port2_d0_oe => multitap1_port2_d0_oe,
                                      port2_d1_oe => multitap1_port2_d1_oe,
                                      
                                      port3_latch => multitap1_port3_latch,
                                      port3_clock => multitap1_port3_clock,
                                      port3_io => multitap1_port3_io,
                                      port3_d0 => multitap1_port3_d0,
                                      port3_d1 => multitap1_port3_d1,
                                      port3_d0_oe => multitap1_port3_d0_oe,
                                      port3_d1_oe => multitap1_port3_d1_oe,
                                       
                                      port4_latch => multitap1_port4_latch,
                                      port4_clock => multitap1_port4_clock,
                                      port4_io => multitap1_port4_io,
                                      port4_d0 => multitap1_port4_d0,
                                      port4_d1 => multitap1_port4_d1,
                                      port4_d0_oe => multitap1_port4_d0_oe,
                                      port4_d1_oe => multitap1_port4_d1_oe); 

  multitap2: snes_multitap port map ( console_clock => p2_clock_f,
                                      console_latch => p2_latch_f,
                                      console_io => p2_io_f,
                                      console_d0 => multitap2_d0,
                                      console_d1 => multitap2_d1,
                                      console_d0_oe => multitap2_d0_oe,
                                      console_d1_oe => multitap2_d1_oe,
                                       
                                      clk => clk,
                                      sw => '1',
                                       
                                      port1_latch => multitap2_port1_latch,
                                      port1_clock => multitap2_port1_clock,
                                      port1_io => multitap2_port1_io,
                                      port1_d0 => multitap2_port1_d0,
                                      port1_d1 => multitap2_port1_d1,
                                      port1_d0_oe => multitap2_port1_d0_oe,
                                      port1_d1_oe => multitap2_port1_d1_oe,
                                      
                                      port2_latch => multitap2_port2_latch,
                                      port2_clock => multitap2_port2_clock,
                                      port2_io => multitap2_port2_io,
                                      port2_d0 => multitap2_port2_d0,
                                      port2_d1 => multitap2_port2_d1,
                                      port2_d0_oe => multitap2_port2_d0_oe,
                                      port2_d1_oe => multitap2_port2_d1_oe,
                                      
                                      port3_latch => multitap2_port3_latch,
                                      port3_clock => multitap2_port3_clock,
                                      port3_io => multitap2_port3_io,
                                      port3_d0 => multitap2_port3_d0,
                                      port3_d1 => multitap2_port3_d1,
                                      port3_d0_oe => multitap2_port3_d0_oe,
                                      port3_d1_oe => multitap2_port3_d1_oe,
                                       
                                      port4_latch => multitap2_port4_latch,
                                      port4_clock => multitap2_port4_clock,
                                      port4_io => multitap2_port4_io,
                                      port4_d0 => multitap2_port4_d0,
                                      port4_d1 => multitap2_port4_d1,
                                      port4_d0_oe => multitap2_port4_d0_oe,
                                      port4_d1_oe => multitap2_port4_d1_oe); 

                                    
uart_recieve_btye: process(CLK)
	begin
		if (rising_edge(CLK)) then
			if (uart_byte_waiting = '1' and uart_data_recieved = '0') then
        case uart_buffer_ptr is
          when 0 =>
            case data_from_uart is
              when x"66" => -- 'f'
                
                uart_buffer_ptr <= 1;
                serial_receive_mode <= "000";
              
              when x"63" => -- 'c'
                buffer_head <= buffer_tail;
                
                uart_buffer_ptr <= 0;  
              
              when x"77" => -- 'w'
                windowed_mode <= '1';
                
              when x"6C" => -- 'l'
                windowed_mode <= '0';
              
              when x"6E" => -- 'n'
                controller_size <= "00";
                uart_buffer_ptr <= 1;
                serial_receive_mode <= "001";
              
              when x"73" => -- 's'
                controller_size <= "01";
                uart_buffer_ptr <= 1;
                serial_receive_mode <= "010";
              
              when others =>
              
            end case;
            
          when 1 =>
            case serial_receive_mode is
              when "000" =>
                if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
                  button_queue(1)(buffer_head) <= "111111111111111111111111" & data_from_uart;
                end if;
                
                uart_buffer_ptr <= 2;
              
              when "001" =>
                case data_from_uart is
                  when x"30" => -- '0'
                    controller_connected(1) <= '0';
                    controller_connected(2) <= '0';
                    controller_connected(3) <= '0';
                    controller_connected(4) <= '0';
                    controller_connected(5) <= '0';
                    controller_connected(6) <= '0';
                    controller_connected(7) <= '0';
                    controller_connected(8) <= '0';
                    
                    use_multitap1 <= '0';
                    use_multitap2 <= '0';
                  
                  when x"31" => -- '1'
                    controller_connected(1) <= '1';
                    controller_connected(2) <= '0';
                    controller_connected(3) <= '0';
                    controller_connected(4) <= '0';
                    controller_connected(5) <= '0';
                    controller_connected(6) <= '0';
                    controller_connected(7) <= '0';
                    controller_connected(8) <= '0';
                    
                    use_multitap1 <= '0';
                    use_multitap2 <= '0';

                  when x"32" => -- '2'
                    controller_connected(1) <= '1';
                    controller_connected(2) <= '1';
                    controller_connected(3) <= '0';
                    controller_connected(4) <= '0';
                    controller_connected(5) <= '0';
                    controller_connected(6) <= '0';
                    controller_connected(7) <= '0';
                    controller_connected(8) <= '0';
                    
                    use_multitap1 <= '0';
                    use_multitap2 <= '0';
                  
                  when others =>
                  
                end case;
                
                uart_buffer_ptr <= 0;

              when "010" =>
                case data_from_uart is
                  when x"30" => -- '0'
                    controller_connected(1) <= '0';
                    controller_connected(2) <= '0';
                    controller_connected(3) <= '0';
                    controller_connected(4) <= '0';
                    controller_connected(5) <= '0';
                    controller_connected(6) <= '0';
                    controller_connected(7) <= '0';
                    controller_connected(8) <= '0';
                    
                    use_multitap1 <= '0';
                    use_multitap2 <= '0';
                  
                  when x"31" => -- '1'
                    controller_connected(1) <= '1';
                    controller_connected(2) <= '0';
                    controller_connected(3) <= '0';
                    controller_connected(4) <= '0';
                    controller_connected(5) <= '0';
                    controller_connected(6) <= '0';
                    controller_connected(7) <= '0';
                    controller_connected(8) <= '0';
                    
                    use_multitap1 <= '0';
                    use_multitap2 <= '0';

                  when x"32" => -- '2'
                    controller_connected(1) <= '1';
                    controller_connected(2) <= '1';
                    controller_connected(3) <= '0';
                    controller_connected(4) <= '0';
                    controller_connected(5) <= '0';
                    controller_connected(6) <= '0';
                    controller_connected(7) <= '0';
                    controller_connected(8) <= '0';
                    
                    use_multitap1 <= '0';
                    use_multitap2 <= '0';
                    
                  when x"38" => -- '8'
                    controller_connected(1) <= '1';
                    controller_connected(2) <= '1';
                    controller_connected(3) <= '1';
                    controller_connected(4) <= '1';
                    controller_connected(5) <= '1';
                    controller_connected(6) <= '1';
                    controller_connected(7) <= '1';
                    controller_connected(8) <= '1';
                    
                    use_multitap1 <= '1';
                    use_multitap2 <= '1';
                  
                  when others =>
                  
                end case;
                
                uart_buffer_ptr <= 0;
              
              when others =>
                uart_buffer_ptr <= 0;
                
            end case;
            
          when 2 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              if (controller_size = "00") then
                -- add it to the next spot
                button_queue(2)(buffer_head) <= "111111111111111111111111" & data_from_uart;
                -- move
                if (buffer_head = 31) then
                  buffer_head <= 0;
                else
                  buffer_head <= buffer_head + 1;
                end if;
                uart_buffer_ptr <= 0;
                
              elsif (controller_size = "01") then
                button_queue(1)(buffer_head) <= "1111111111111111" & data_from_uart & button_queue(1)(buffer_head)(7 downto 0);
                uart_buffer_ptr <= 3;
              else
                uart_buffer_ptr <= 0;
              end if;
            end if;
            
          when 3 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(2)(buffer_head) <= "111111111111111111111111" & data_from_uart;
            end if;  
            uart_buffer_ptr <= 4;
          
          when 4 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(2)(buffer_head) <= "1111111111111111" & data_from_uart & button_queue(2)(buffer_head)(7 downto 0);
            end if;  
            uart_buffer_ptr <= 5;

          when 5 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(3)(buffer_head) <= "111111111111111111111111" & data_from_uart;
            end if;  
            uart_buffer_ptr <= 6;
          
          when 6 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(3)(buffer_head) <= "1111111111111111" & data_from_uart & button_queue(3)(buffer_head)(7 downto 0);
            end if;  
            uart_buffer_ptr <= 7;
          
          when 7 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(4)(buffer_head) <= "111111111111111111111111" & data_from_uart;
            end if;  
            uart_buffer_ptr <= 8;
          
          when 8 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(4)(buffer_head) <= "1111111111111111" & data_from_uart & button_queue(4)(buffer_head)(7 downto 0);
            end if;  
            uart_buffer_ptr <= 9;

          when 9 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(5)(buffer_head) <= "111111111111111111111111" & data_from_uart;
            end if;  
            uart_buffer_ptr <= 10;
          
          when 10 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(5)(buffer_head) <= "1111111111111111" & data_from_uart & button_queue(5)(buffer_head)(7 downto 0);
            end if;  
            uart_buffer_ptr <= 11;
          
          when 11 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(6)(buffer_head) <= "111111111111111111111111" & data_from_uart;
            end if;  
            uart_buffer_ptr <= 12;
          
          when 12 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(6)(buffer_head) <= "1111111111111111" & data_from_uart & button_queue(6)(buffer_head)(7 downto 0);
            end if;  
            uart_buffer_ptr <= 13;

          when 13 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(7)(buffer_head) <= "111111111111111111111111" & data_from_uart;
            end if;  
            uart_buffer_ptr <= 14;
          
          when 14 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(7)(buffer_head) <= "1111111111111111" & data_from_uart & button_queue(7)(buffer_head)(7 downto 0);
            end if;  
            uart_buffer_ptr <= 15;
          
          when 15 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(8)(buffer_head) <= "111111111111111111111111" & data_from_uart;
            end if;  
            uart_buffer_ptr <= 16;
          
          when 16 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              button_queue(8)(buffer_head) <= "1111111111111111" & data_from_uart & button_queue(8)(buffer_head)(7 downto 0);
              
              -- move
              if (buffer_head = 31) then
                buffer_head <= 0;
              else
                buffer_head <= buffer_head + 1;
              end if;
              uart_buffer_ptr <= 0;              
            end if;  
            uart_buffer_ptr <= 0;
          
          when others =>
        end case;
      	uart_data_recieved <= '1';
			else
				uart_data_recieved <= '0';
			end if;
    end if;
	end process;
  
  process (clk) is
  begin
    if (rising_edge(clk)) then
      uart_write <= '0';
      
      if (windowed_mode = '1' and frame_timer_active = '1') then
        if (frame_timer = 96000) then
          frame_timer <= 0;
          frame_timer_active <= '0';
        
          -- move tail pointer if possible
          if (buffer_tail /= buffer_head) then
            if (buffer_tail = 31) then
              buffer_tail <= 0;
            else
              buffer_tail <= buffer_tail + 1;
            end if;
          end if;
          
          -- Send feedback that a frame was consumed
          if (uart_buffer_full = '0') then
            uart_write <= '1';
            data_to_uart <= x"66";
          end if;
          
        else
          frame_timer <= frame_timer + 1;
        end if;
      end if;

      if (p1_latch_f /= prev_latch) then
        if (p1_latch_f = '1') then
          if (windowed_mode = '1') then
            frame_timer <= 0;
            frame_timer_active <= '1';
          else
            -- move tail pointer if possible
            if (buffer_tail /= buffer_head) then
              if (buffer_tail = 31) then
                buffer_tail <= 0;
              else
                buffer_tail <= buffer_tail + 1;
              end if;
            end if;
            
            -- Send feedback that a frame was consumed
            if (uart_buffer_full = '0') then
              uart_write <= '1';
              data_to_uart <= x"66";
            end if;
          end if;
        end if;
        prev_latch <= p1_latch_f;
      end if;
    end if;
  end process;
  
  address_to_use <= buffer_tail when buffer_head /= buffer_tail else
                    31 when buffer_tail = 0 else
                    buffer_tail - 1;

  controller_data(1) <= button_queue(1)(address_to_use);

  controller_data(2) <= button_queue(2)(address_to_use);
  
  controller_data(3) <= button_queue(3)(address_to_use);

  controller_data(4) <= button_queue(4)(address_to_use);
                      
  controller_data(5) <= button_queue(5)(address_to_use);

  controller_data(6) <= button_queue(6)(address_to_use);
                      
  controller_data(7) <= button_queue(7)(address_to_use);

  controller_data(8) <= button_queue(8)(address_to_use);

  p1_d0 <= multitap1_d0 when use_multitap1 = '1' else
           controller_d0(1);
  p1_d1 <= multitap1_d1 when use_multitap1 = '1' else
           controller_d1(1);
  p2_d0 <= multitap2_d0 when use_multitap2 = '1' else
           controller_d0(2);
  p2_d1 <= multitap2_d1 when use_multitap2 = '1' else
           controller_d1(2);
  
  p1_d0_oe <= multitap1_d0_oe when use_multitap1 = '1' else
              controller_d0_oe(1);
  p1_d1_oe <= multitap1_d1_oe when use_multitap1 = '1' else
              controller_d1_oe(1);
  p2_d0_oe <= multitap2_d0_oe when use_multitap2 = '1' else
              controller_d0_oe(2);
  p2_d1_oe <= multitap2_d1_oe when use_multitap2 = '1' else
              controller_d1_oe(2);
  
  controller_clock(1) <= multitap1_port1_clock when use_multitap1 = '1' else
                         p1_clock_f;
  controller_clock(2) <= multitap1_port2_clock when use_multitap1 = '1' else
                         p2_clock_f;
  controller_clock(3) <= multitap1_port3_clock when use_multitap1 = '1' else
                         p2_clock_f;
  controller_clock(4) <= multitap1_port4_clock when use_multitap1 = '1' else
                         p2_clock_f;
  controller_clock(5) <= multitap2_port1_clock when use_multitap2 = '1' else
                         p2_clock_f;
  controller_clock(6) <= multitap2_port2_clock when use_multitap2 = '1' else
                         p2_clock_f;
  controller_clock(7) <= multitap2_port3_clock when use_multitap2 = '1' else
                         p2_clock_f;
  controller_clock(8) <= multitap2_port4_clock when use_multitap2 = '1' else
                         p2_clock_f;
  
  controller_latch(1) <= multitap1_port1_latch when use_multitap1 = '1' else
                         p1_latch_f;
  controller_latch(2) <= multitap1_port2_latch when use_multitap1 = '1' else
                         p2_latch_f;
  controller_latch(3) <= multitap1_port3_latch when use_multitap1 = '1' else
                         p2_latch_f;
  controller_latch(4) <= multitap1_port4_latch when use_multitap1 = '1' else
                         p2_latch_f;
  controller_latch(5) <= multitap2_port1_latch when use_multitap2 = '1' else
                         p1_latch_f;
  controller_latch(6) <= multitap2_port2_latch when use_multitap2 = '1' else
                         p2_latch_f;
  controller_latch(7) <= multitap2_port3_latch when use_multitap2 = '1' else
                         p2_latch_f;
  controller_latch(8) <= multitap2_port4_latch when use_multitap2 = '1' else
                         p2_latch_f;
  
  controller_io(1) <= '1';
  controller_io(2) <= '1';
  controller_io(3) <= '1';
  controller_io(4) <= '1';
  controller_io(5) <= '1';
  controller_io(6) <= '1';
  controller_io(7) <= '1';
  controller_io(8) <= '1';
  
  controller_overread_value(1) <= '1';
  controller_overread_value(2) <= '1';
  controller_overread_value(3) <= '1';
  controller_overread_value(4) <= '1';
  controller_overread_value(5) <= '1';
  controller_overread_value(6) <= '1';
  controller_overread_value(7) <= '1';
  controller_overread_value(8) <= '1';
  
  multitap1_port1_d0 <= controller_d0(1);
  multitap1_port2_d0 <= controller_d0(2);
  multitap1_port3_d0 <= controller_d0(3);
  multitap1_port4_d0 <= controller_d0(4);
  
  multitap1_port1_d1 <= controller_d1(1);
  multitap1_port2_d1 <= controller_d1(2);
  multitap1_port3_d1 <= controller_d1(3);
  multitap1_port4_d1 <= controller_d1(4);
  
  multitap1_port1_d0_oe <= controller_d0_oe(1);
  multitap1_port2_d0_oe <= controller_d0_oe(2);
  multitap1_port3_d0_oe <= controller_d0_oe(3);
  multitap1_port4_d0_oe <= controller_d0_oe(4);

  multitap1_port1_d1_oe <= controller_d1_oe(1);
  multitap1_port2_d1_oe <= controller_d1_oe(2);
  multitap1_port3_d1_oe <= controller_d1_oe(3);
  multitap1_port4_d1_oe <= controller_d1_oe(4);
  
  
  multitap2_port1_d0 <= controller_d0(5);
  multitap2_port2_d0 <= controller_d0(6);
  multitap2_port3_d0 <= controller_d0(7);
  multitap2_port4_d0 <= controller_d0(8);
  
  multitap2_port1_d1 <= controller_d1(5);
  multitap2_port2_d1 <= controller_d1(6);
  multitap2_port3_d1 <= controller_d1(7);
  multitap2_port4_d1 <= controller_d1(8);
  
  multitap2_port1_d0_oe <= controller_d0_oe(5);
  multitap2_port2_d0_oe <= controller_d0_oe(6);
  multitap2_port3_d0_oe <= controller_d0_oe(7);
  multitap2_port4_d0_oe <= controller_d0_oe(8);

  multitap2_port1_d1_oe <= controller_d1_oe(5);
  multitap2_port2_d1_oe <= controller_d1_oe(6);
  multitap2_port3_d1_oe <= controller_d1_oe(7);
  multitap2_port4_d1_oe <= controller_d1_oe(8);

  l <= std_logic_vector(to_unsigned(buffer_tail, 4));
    
  debug(0) <= p1_latch_toggle;
  debug(1) <= p2_latch_f;
  debug(2) <= p1_clock_toggle;
  debug(3) <= p2_clock_f;

end Behavioral;

