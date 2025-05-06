--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(7 downto 0); -- operands and opcode
        btnU    :   in std_logic; -- reset
        btnC    :   in std_logic; -- fsm cycle
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is 
  
	-- declare components and signals
	
	signal w_clk       : std_logic;
	signal w_adv       : std_logic;
	signal w_reset     : std_logic;
	signal w_cycle     : std_logic_vector(3 downto 0);
	signal w_A         : std_logic_vector(7 downto 0);
	signal w_B         : std_logic_vector(7 downto 0);
	signal w_flags     : std_logic_vector(3 downto 0);
	signal w_result    : std_logic_vector(7 downto 0);
	signal w_bin       : std_logic_vector(7 downto 0);
	signal w_sign      : std_logic;
	signal w_hund      : std_logic_vector(3 downto 0);
	signal w_tens      : std_logic_vector(3 downto 0); 
	signal w_ones      : std_logic_vector(3 downto 0);
	signal w_data      : std_logic_vector(3 downto 0);
	signal w_sel       : std_logic_vector(3 downto 0);
	signal w_7SD_seg   : std_logic_vector(6 downto 0);
	signal w_seg       : std_logic_vector(6 downto 0);
	signal w_ff1       : std_logic_vector(7 downto 0);
	signal w_ff2       : std_logic_vector(7 downto 0); 
	
	component twos_comp is
    port (
        i_bin: in std_logic_vector(7 downto 0);
        o_sign: out std_logic;
        o_hund: out std_logic_vector(3 downto 0);
        o_tens: out std_logic_vector(3 downto 0);
        o_ones: out std_logic_vector(3 downto 0)
    );
    end component twos_comp;


    component controller_fsm is
    Port ( i_reset : in STD_LOGIC;
           i_adv : in STD_LOGIC;
           o_cycle : out STD_LOGIC_VECTOR (3 downto 0));
    end component controller_fsm;
    
    component TDM4 is
	generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
    Port ( i_clk		: in  STD_LOGIC;
           i_reset		: in  STD_LOGIC; -- asynchronous
           i_D3 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D2 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D1 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D0 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_data		: out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_sel		: out STD_LOGIC_VECTOR (3 downto 0)	-- selected data line (one-cold)
	);
    end component TDM4;
    
    component sevenseg_decoder is
        port (
            i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component sevenseg_decoder;
    
    component clock_divider is
	generic ( constant k_DIV : natural := 2	); -- How many clk cycles until slow clock toggles
											   -- Effectively, you divide the clk double this 
											   -- number (e.g., k_DIV := 2 --> clock divider of 4)
	port ( 	i_clk    : in std_logic;
			i_reset  : in std_logic;		   -- asynchronous
			o_clk    : out std_logic		   -- divided (slow) clock
	);
    end component clock_divider;
    
    component ALU is
    Port ( i_A : in STD_LOGIC_VECTOR (7 downto 0);
           i_B : in STD_LOGIC_VECTOR (7 downto 0);
           i_op : in STD_LOGIC_VECTOR (2 downto 0);
           o_result : out STD_LOGIC_VECTOR (7 downto 0);
           o_flags : out STD_LOGIC_VECTOR (3 downto 0));
    end component ALU;
  
begin
	-- PORT MAPS ----------------------------------------
    clk_inst    : clock_divider
    generic map (k_DIV => 50000)
    port map(
        i_clk   => clk,
        i_reset => btnU,
        o_clk   => w_clk
        );
        
    fsm_inst    : controller_fsm
    port map(
        i_reset => btnU,
        i_adv   => btnC,
        o_cycle => w_cycle
        );
        
    ALU_inst    : ALU
    port map(
        i_A         => w_A,
        i_B         => w_B,
        i_op        => sw(2 downto 0),
        o_result    => w_result,
        o_flags     => w_flags
        );
     
    -----MUX------
    
    twos_inst   : twos_comp
    port map(
        i_bin   => w_bin,
        o_sign  => w_sign,
        o_hund  => w_hund,
        o_tens  => w_tens,
        o_ones  => w_ones
        );
        
    TDM_inst    : TDM4
    generic map(k_WIDTH => 4)
    port map(
        i_clk   => w_clk,
        i_reset => btnU,
        i_D3    => "0000",  ---replace value with something else
        i_D2    => w_hund,
        i_D1    => w_tens,
        i_D0    => w_ones,
        o_data  => w_data,
        o_sel   => w_sel
        );
        
    sevenseg_inst   : sevenseg_decoder
    port map(
        i_hex       => w_data,
        o_seg_n     => w_7SD_seg
        );
        
    
	
	-- CONCURRENT STATEMENTS ----------------------------
	w_A     <= sw(7 downto 0) when w_cycle = "0010" else
	             w_ff1;
	             
	w_B     <= sw(7 downto 0) when w_cycle = "0100" else
	             w_ff2;
	             
	with w_cycle select            
	w_bin     <= w_A       when "0010",
	             w_B       when "0100",
	             w_result    when others;
	             
	w_seg <=   "0111111" when ((w_sign = '1') and (w_sel(3) = '0')) else
	           "1111111" when ((w_sign = '0') and (w_sel(3) = '0')) else
	           w_7SD_seg;
	
    an <=   "1111" when w_cycle = "0001" else
            w_sel;
    
    seg(6 downto 0) <= w_seg;
    led(3 downto 0) <= w_cycle;
    led(3 downto 0) <= w_cycle;
    led(15 downto 12) <= w_flags;
    led(11 downto 4) <= (others => '0');
	-- PROCESSES ----------------------------------------
	
	
end top_basys3_arch;
