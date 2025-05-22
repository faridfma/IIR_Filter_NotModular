library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity Cascaded_ChbyChevII_Fc37K5_Fp100K_Astop60 is
    Port (
        clk                  : in  std_logic := '0';           -- Clock signal
        reset                : in  std_logic := '0';           -- Reset signal
        x_in                 : in  signed (15 downto 0):= (others=>'0');  -- Input signal x[n] (Q0.16 format) 
        iir_out              : out signed (15 downto 0):= (others=>'0');  -- Filtered output
        sample_valid_out     : out std_logic := '0';     -- Sample valid output signal
        busy                : out std_logic := '0'      -- Busy signal
    );
end Cascaded_ChbyChevII_Fc37K5_Fp100K_Astop60;

architecture Behavioral of Cascaded_ChbyChevII_Fc37K5_Fp100K_Astop60 is


    signal x_in_Sig : signed (15 downto 0):= (others=>'0');  -- Input signal x[n] (Q0.16 format)
 
    -- Register declarations for input (x) and output (y) values
    type x_regArray is array(0 to 4) of signed(31 downto 0);  -- Input registers (x); add 8 bits for scaling
    signal BiQuad1_x_reg : x_regArray;
    signal BiQuad2_x_reg : x_regArray; 
    signal BiQuad3_x_reg : x_regArray; 
     
    type y_regArray is array(0 to 4) of signed(31 downto 0);  -- Input registers (y)
    signal BiQuad1_y_reg : y_regArray;
    signal BiQuad2_y_reg : y_regArray;
    signal BiQuad3_y_reg : y_regArray; 

    -- Multiplication signals
   type mul_xArray  is array(0 to 4) of signed(63 downto 0); --16 bits times 8 bits ==>24 bits
   signal BiQuad1_mul_x : mul_xArray; 
   signal BiQuad2_mul_x : mul_xArray; 
   signal BiQuad3_mul_x : mul_xArray; 
   
   type mul_yArray is array(1 to 4) of signed(63 downto 0);  --16 bits times 8 bits ==>24 bits
   signal BiQuad1_mul_y : mul_yArray; 
   signal BiQuad2_mul_y : mul_yArray;
   signal BiQuad3_mul_y : mul_yArray;
   
   -- Sum signals
   type Sum_xArray is array(0 to 5) of signed(63 downto 0);  -- need 27 bits
   signal BiQuad1_Sum_x : Sum_xArray;  
   signal BiQuad2_Sum_x : Sum_xArray;  
   signal BiQuad3_Sum_x : Sum_xArray;  
     
   type Sum_yArray  is array(0 to 4) of signed(63 downto 0);  --need 26 bits
   signal BiQuad1_Sum_y : Sum_yArray; 
   signal BiQuad2_Sum_y : Sum_yArray; 
   signal BiQuad3_Sum_y : Sum_yArray; 
   
   
   -- Scaling factor
  -- constant scaling_factor : real := 65535.0 / 40360.0;


    -- Coefficients (b and a arrays)
    type Biquad1_B_Coefficients_Array is array(0 to 2) of signed(31 downto 0);    -- Biquad1 b Coefficients
    constant Biquad1_B_Coef : Biquad1_B_Coefficients_Array := (
          to_signed(20132, 32),
          to_signed(-10066, 32),
          to_signed(20132, 32)
    );

   type Biquad1_A_Coefficients_Array is array(0 to 2) of signed(31 downto 0);
   constant Biquad1_A_Coef : Biquad1_A_Coefficients_Array := (
        to_signed(16777216, 32),
        to_signed(-26420759, 32),
        to_signed(10460594, 32)
    );

    type Biquad2_B_Coefficients_Array is array(0 to 2) of signed(31 downto 0);
    constant Biquad2_B_Coef : Biquad2_B_Coefficients_Array := (
           to_signed(16777216, 32),
           to_signed(-28390404, 32),
           to_signed(16777216, 32)
    );
    
    type Biquad2_A_Coefficients_Array is array(0 to 2) of signed(31 downto 0);  -- Corrected duplicated declaration
    constant Biquad2_A_Coef : Biquad2_A_Coefficients_Array := (
        to_signed(16777216, 32),
        to_signed(-28497779, 32),
        to_signed(12478893, 32)
    );

    type Biquad3_B_Coefficients_Array is array(0 to 2) of signed(31 downto 0);
    constant Biquad3_B_Coef : Biquad3_B_Coefficients_Array := (
          to_signed(16777216, 32),
          to_signed(-30685528, 32),
          to_signed(16777216, 32)
    );

    type Biquad3_A_Coefficients_Array is array(0 to 2) of signed(31 downto 0);  -- Corrected type name
    constant Biquad3_A_Coef : Biquad3_A_Coefficients_Array := (
        to_signed(16777216, 32),
        to_signed(-31304607, 32),
        to_signed(15258877, 32)
    );

    -- Final output signal
    signal BiQuad1_Output_Shifted    : signed(31 downto 0):= (others=>'0');   
    signal BiQuad1_Output_NotShifted : signed(63 downto 0):= (others=>'0'); 
    
    signal BiQuad2_Output_Shifted    : signed(31 downto 0):= (others=>'0');   
    signal BiQuad2_Output_NotShifted : signed(63 downto 0):= (others=>'0'); 
    
    signal BiQuad3_Output_Shifted    : signed(31 downto 0):= (others=>'0');   
    signal BiQuad3_Output_NotShifted : signed(63 downto 0):= (others=>'0'); 
   

    -- State machine state
    signal state : integer := 0;
    signal sample_valid_in_sig : std_logic:='0'; 

    signal sample_validin_Sig: std_logic := '0'; 
    signal clockcounter : integer range 0 to 64;  

    signal BiQuad1_sample_valid_out  : std_logic := '0';     -- Sample valid output signal
    signal BiQuad2_sample_valid_out  : std_logic := '0';     -- Sample valid output signal
    signal BiQuad3_sample_valid_out  : std_logic := '0';     -- Sample valid output signal
     
    signal BiQuad1_busy  : std_logic := '0';
    signal BiQuad2_busy  : std_logic := '0';
    signal BiQuad3_busy  : std_logic := '0';
    
    COMPONENT  Noisy_Signal_Generation 
    Port (
         clk                  : in  std_logic := '0';           -- Clock signal
         reset                : in  std_logic := '0';           -- Reset signal
         x_out                : Out signed(15 downto 0):= (others=>'0');   
         sample_valid_out     : out std_logic := '0'      -- Sample valid input signal
    );
    END COMPONENT;
    
begin

 SineWaveGen : Noisy_Signal_Generation
     PORT MAP (
		 clk  => clk,                
		 reset => reset,             
		 x_out => x_in_sig,                  
		 sample_valid_out => sample_valid_in_sig
  ); 
  
    -- Process for updating the filter with pipelined calculations
    process(clk, reset)
    variable index: integer:= 0; 
    begin
        if reset = '1' then
            -- Reset input and output registers to 0
            BiQuad1_x_reg <= (others => (others => '0'));
            BiQuad1_y_reg <= (others => (others => '0'));
            BiQuad2_x_reg <= (others => (others => '0'));
            BiQuad2_y_reg <= (others => (others => '0'));
            BiQuad3_x_reg <= (others => (others => '0'));
            BiQuad3_y_reg <= (others => (others => '0'));
            
            BiQuad1_mul_x <= (others => (others => '0'));
            BiQuad1_mul_y <= (others => (others => '0'));
            BiQuad2_mul_x <= (others => (others => '0'));
            BiQuad2_mul_y <= (others => (others => '0'));
            BiQuad3_mul_x <= (others => (others => '0'));
            BiQuad3_mul_y <= (others => (others => '0'));
            
            BiQuad1_Sum_x <= (others => (others => '0'));
            BiQuad1_Sum_y <= (others => (others => '0'));
            BiQuad2_Sum_x <= (others => (others => '0'));
            BiQuad2_Sum_y <= (others => (others => '0'));
            BiQuad3_Sum_x <= (others => (others => '0'));
            BiQuad3_Sum_y <= (others => (others => '0'));
            
            BiQuad1_sample_valid_out <= '0';
            BiQuad2_sample_valid_out <= '0';
            BiQuad3_sample_valid_out <= '0';
             
            BiQuad1_busy <= '0';
            BiQuad2_busy <= '0';
            BiQuad3_busy <= '0';
            
            state <= 0;
            index:=0; 
            
        elsif rising_edge(clk) then
            case state is
               
               
               --FIRST QUAD LOGIC ---------------------------------------
               ----------------------------------------------------------
                -- Initial stage: Load the input values and shift registers
                when 0 =>
                    if sample_valid_in_sig = '1'  then
                       -- Shift input and output registers
                       BiQuad1_x_reg(0) <= resize(x_in_sig,32);   
                       
                       BiQuad1_busy  <= '1';
                       BiQuad1_sample_valid_out <= '0'; 
                        
                       state <= 1;
                    end if;

                -- Stage 1: Multiply input values by coefficients
                when 1 =>
                
                    for i in 0 to 2 loop
                        BiQuad1_mul_x(i) <= BiQuad1_x_reg(i) * Biquad1_B_Coef(i);  
                    end loop;

                    -- Multiply previous output by feedback coefficients
                    for i in 1 to 2 loop
                       BiQuad1_mul_y(i) <= BiQuad1_y_reg(i) * Biquad1_A_Coef(i);  --8 bits * 16 bits  ==> need 24 bits
                    end loop;

                    state <= 2;

                -- Stage 2: Sum the multiplications
                when 2 =>
                    BiQuad1_Sum_x(0) <= resize(BiQuad1_mul_x(0) + BiQuad1_mul_x(1),64);  
                 
                    BiQuad1_Sum_y(0) <= resize(BiQuad1_mul_y(1) + BiQuad1_mul_y(2),64);  

                    state <= 3;
                    
                 when 3 =>
                    BiQuad1_Sum_x(1) <= resize(BiQuad1_Sum_x(0) + BiQuad1_mul_x(2),64);               
                    
                    state <= 4; 
                    
                when 4 =>
              
                    BiQuad1_Output_NotShifted<= BiQuad1_Sum_x(1)- BiQuad1_Sum_y(0);
                   
                     state <= 5;
                     
                -- Stage 4: Reset output and prepare for next sample
                when 5 =>
  
                  BiQuad1_Output_Shifted <= resize(shift_right(BiQuad1_Output_NotShifted,24),32);   --scale down by 2^24
                   
                  state <= 6;
                    
                when 6 => 
                    
                    BiQuad1_y_reg(1)<=  BiQuad1_Output_Shifted;
					BiQuad1_y_reg(2) <= BiQuad1_y_reg(1);
                   
                    for i in 1 to 2 loop
                       BiQuad1_x_reg(i) <= BiQuad1_x_reg(i-1);
                    end loop;
                    
                     BiQuad1_sample_valid_out <= '1';
                     
                    state <= 7;
                    
                   when 7 =>   
                    
                    BiQuad1_sample_valid_out <= '0';
                    BiQuad1_busy  <= '0';
                    
                    state <= 8;
         
          ----------------------------------------------------------
            --SECOND BIQUAD LOGIC ---------------------------------------
           ----------------------------------------------------------
                -- Initial stage: Load the input values and shift registers
                when 8 =>
                
                       BiQuad2_x_reg(0) <= resize(BiQuad1_Output_Shifted,32); 
                       
                       BiQuad2_busy  <= '1';
                       BiQuad2_sample_valid_out <= '0'; 
                        
                       state <= 9;

                -- Stage 1: Multiply input values by coefficients
                when 9 =>
                
                    for i in 0 to 2 loop
                        BiQuad2_mul_x(i) <= BiQuad2_x_reg(i) * Biquad2_B_Coef(i);  
                    end loop;

                    -- Multiply previous output by feedback coefficients
                    for i in 1 to 2 loop
                       BiQuad2_mul_y(i) <= BiQuad2_y_reg(i) * Biquad2_A_Coef(i);  --8 bits * 16 bits  ==> need 24 bits
                    end loop;

                    state <= 10;

                -- Stage 2: Sum the multiplications
                when 10 =>
                    BiQuad2_Sum_x(0) <= resize(BiQuad2_mul_x(0) + BiQuad2_mul_x(1),64);  
                 
                    BiQuad2_Sum_y(0) <= resize(BiQuad2_mul_y(1) + BiQuad2_mul_y(2),64);  

                    state <= 11;
                    
                 when 11 =>
                    BiQuad2_Sum_x(1) <= resize(BiQuad2_Sum_x(0) + BiQuad2_mul_x(2),64);               
                                                                 
                    
                    state <= 12; 
                    
                when 12 =>
              
                    BiQuad2_Output_NotShifted<= BiQuad2_Sum_x(1)- BiQuad2_Sum_y(0);
                   
                     state <= 13;
                     
                -- Stage 4: Reset output and prepare for next sample
                when 13 =>
  
                  BiQuad2_Output_Shifted <= resize(shift_right(BiQuad2_Output_NotShifted,24),32);   --scale down by 2^24
                   
                  state <= 14;
                        
                when 14 => 
                    
                    BiQuad2_y_reg(1)<=  BiQuad2_Output_Shifted;
					BiQuad2_y_reg(2) <= BiQuad2_y_reg(1);
                   
                    for i in 1 to 2 loop
                       BiQuad2_x_reg(i) <= BiQuad2_x_reg(i-1);
                    end loop;
                    
                     BiQuad2_sample_valid_out <= '1';
                     
                    state <= 15;
                    
                when 15 =>   
                    
                    BiQuad2_sample_valid_out <= '0';
                    BiQuad2_busy  <= '0';
                    
                    state <= 16;
         
                  ----------------------------------------------------------
            -- THIRD  BIQUAD LOGIC ---------------------------------------
           ----------------------------------------------------------
                -- Initial stage: Load the input values and shift registers
                when 16 =>
                
                       BiQuad3_x_reg(0) <= resize(BiQuad2_Output_Shifted,32); 
                       
                       BiQuad3_busy  <= '1';
                       BiQuad3_sample_valid_out <= '0'; 
                        
                       state <= 17;

                -- Stage 1: Multiply input values by coefficients
                when 17 =>
                
                    for i in 0 to 2 loop
                        BiQuad3_mul_x(i) <= BiQuad3_x_reg(i) * Biquad3_B_Coef(i);  
                    end loop;

                    -- Multiply previous output by feedback coefficients
                    for i in 1 to 2 loop
                       BiQuad3_mul_y(i) <= BiQuad3_y_reg(i) * Biquad3_A_Coef(i);  --8 bits * 16 bits  ==> need 24 bits
                    end loop;

                    state <= 18;

                -- Stage 2: Sum the multiplications
                when 18 =>
                    BiQuad3_Sum_x(0) <= resize(BiQuad3_mul_x(0) + BiQuad3_mul_x(1),64);  
                 
                    BiQuad3_Sum_y(0) <= resize(BiQuad3_mul_y(1) + BiQuad3_mul_y(2),64);  

                    state <= 19;
                    
                 when 19 =>
                    BiQuad3_Sum_x(1) <= resize(BiQuad3_Sum_x(0) + BiQuad3_mul_x(2),64);               
                                                                 
                    
                    state <= 20; 
                    
                when 20 =>
              
                    BiQuad3_Output_NotShifted<= BiQuad3_Sum_x(1)- BiQuad3_Sum_y(0);
                   
                     state <= 21;
                     
                -- Stage 4: Reset output and prepare for next sample
                when 21 =>
  
                  BiQuad3_Output_Shifted <= resize(shift_right(BiQuad3_Output_NotShifted,24),32);   --scale down by 2^24
                   
                  state <= 22;
                        
                when 22 => 
                    
                    BiQuad3_y_reg(1)<=  BiQuad3_Output_Shifted;
					BiQuad3_y_reg(2) <= BiQuad3_y_reg(1);
                   
                    for i in 1 to 2 loop
                       BiQuad3_x_reg(i) <= BiQuad3_x_reg(i-1);
                    end loop;
                    
                     BiQuad3_sample_valid_out <= '1';
                     
                    state <= 23;
                    
                when 23 =>   
                    
                    BiQuad3_sample_valid_out <= '0';
                    BiQuad3_busy  <= '0';
                    
                    state <= 0; 
 
                when others =>
                    state <= 0;
            end case;
        end if;
    end process;


   -- Assign the output signal y[n] (output in Q0.16 format)
  --iir_out <= BiQuad3_Output_Shifted;
  
  
    iir_out <= BiQuad3_Output_Shifted(15 downto 0) when (BiQuad3_Output_Shifted >= -32768) AND (BiQuad3_Output_Shifted <= 32767) else
             to_signed(-32768,16) when (BiQuad3_Output_Shifted < -32768) else
             to_signed(32767,16) when (BiQuad3_Output_Shifted < 32767);

end Behavioral;
