library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;				--increment decrement shit

entity Clock is
	port(CLOCK_50 : in std_logic;
	
		  --KEYS and SW to control functions
		  
		  KEY : in std_logic_vector(3 downto 0);
		  
		  -- KEY(0) to increment current selection
        -- KEY(1) to decrement current selection
        -- KEY(3) to select hours, minutes or seconds
        -- Keys are all active low
		  
		  SW	: in std_logic_vector(3 downto 0);
		  
		  --SW(0) to enable adjust mode
		  --SW(1) to switch between 12h-24h 
		  
		  --Time Displays
        HEX0 : out std_logic_vector(6 downto 0); -- M		Used in AM/PM format
        HEX1 : out std_logic_vector(6 downto 0); -- A/P 	Used in AM/PM format
        HEX2 : out std_logic_vector(6 downto 0); -- S
        HEX3 : out std_logic_vector(6 downto 0); -- S
        HEX4 : out std_logic_vector(6 downto 0); -- M
        HEX5 : out std_logic_vector(6 downto 0); -- M
        HEX6 : out std_logic_vector(6 downto 0); -- H
        HEX7 : out std_logic_vector(6 downto 0); -- H
		  
		  --LEDs to test if keys are pressed
		  LEDG : out std_logic_vector(6 downto 0));
end Clock;

architecture Behavioral of Clock is
	
	signal press : integer range 0 to 100 := 0;
	signal sec, min : integer range 0 to 60 := 0;
	signal hour : integer range 0 to 23 := 0;
	signal count, cur_sel : integer := 0; 
	signal clk, clk2 : std_logic := '0';
	signal am : std_logic := '1'; --change between AM and  PM
	signal h2BCD1, h2BCD, m2BCD1, m2BCD, s2BCD1, s2BCD, h2Dis1, h2Dis, m2Dis1, m2Dis, s2Dis1, s2Dis : std_logic_vector(7 downto 0);
	signal db_KEY : std_logic_vector(3 downto 0);
begin

	--Convert hours, minutes and seconds to 7Segments
		bin2BCD: entity work.Bin2BCD(Behavioral)
						port map(binIn  => std_logic_vector(to_unsigned(sec,8)),
									binIn1 => std_logic_vector(to_unsigned(min,8)),
									binIn2 => std_logic_vector(to_unsigned(hour,8)),
									bcdMS  => s2BCD1,	--Most Significant Second
									bcdLS  => s2BCD,	--Least Significant Second
									bcdMS1 => m2BCD1,	--Most Significant Minute
									bcdLS1 => m2BCD,	--Least Significant Minute
									bcdMS2 => h2BCD1,	--Most Significant Hour
									bcdLS2 => h2BCD);	--Least Significant Hour 
		
		b7segH : entity work.Bin7SegDecoder(Behavioral) --Most Significant Second
						port map(binInput => s2BCD1(3 downto 0),
									decOut_n =>	s2Dis1(6 downto 0));
				
		b7segL : entity work.Bin7SegDecoder(Behavioral) --Least Significant Second
						port map(binInput => s2BCD(3 downto 0),
									decOut_n => s2Dis(6 downto 0));
						
		b7segH1 : entity work.Bin7SegDecoder(Behavioral) --Most Significant Minute
						port map(binInput => m2BCD1(3 downto 0),
									decOut_n => m2Dis1(6 downto 0));
						
		b7segL1 : entity work.Bin7SegDecoder(Behavioral) --Least Significant Minute
						port map(binInput => m2BCD(3 downto 0),
									decOut_n => m2Dis(6 downto 0));
			
		b7segH2 : entity work.Bin7SegDecoder(Behavioral) --Most Significant Hour
						port map(binInput => h2BCD1(3 downto 0),
									decOut_n => h2Dis1(6 downto 0));
						
		b7segL2 : entity work.Bin7SegDecoder(Behavioral) --Least Significant Hour
						port map(binInput => h2BCD(3 downto 0),
									decOut_n => h2Dis(6 downto 0));
									
	
		freqDiv: entity work.freqDivider(Behavioral) 	--Generate Clock with 1Hz frequency
						generic map(DIV_FACTOR => 50E6)
						port map(clkIn => CLOCK_50,
									clkOut => clk);
		
		freqDiv2: entity work.freqDivider(Behavioral) 	--Generate Clock with 3Hz frequency
						generic map(DIV_FACTOR => 15E6)
						port map(clkIn => CLOCK_50,
									clkOut => clk2);
									
		db0: entity work.debouncer(v1) 						--Debounce for KEY(0)
					generic map(clock_frequency => 50.0E6,
									window_duration => 0.0)
					port map(clock => CLOCK_50,
								dirty => KEY(0),
								clean => db_KEY(0));
								
		db1: entity work.debouncer(v1) 						--Debounce for KEY(1)
					generic map(clock_frequency => 50.0E6,
									window_duration => 0.0)
					port map(clock => CLOCK_50,
								dirty => KEY(1),
								clean => db_KEY(1));
							
		db2: entity work.debouncer(v1) 						--Debounce for KEY(2)
					generic map(clock_frequency => 50.0E6,
									window_duration => 0.0)
					port map(clock => CLOCK_50,
								dirty => KEY(2),
								clean => db_KEY(2));
								
		db3: entity work.debouncer(v1) 						--Debounce for KEY(3)
					generic map(clock_frequency => 50.0E6,
									window_duration => 0.0)
					port map(clock => CLOCK_50,
								dirty => KEY(3),
								clean => db_KEY(3));
								
	
	--Start HH:MM:SS counter	
	process(clk, clk2)
	begin
		--Set once every second
		
		if(rising_edge(clk)) then
			
			--Set Hours(cur_sel = 1), Minutes(cur_sel = 2) or Seconds(cur_sel = 3)
			if(db_KEY(3) = '0' and SW(0) = '1') then
				cur_sel <= cur_sel + 1;
					
				if(cur_sel = 3) then	--Makes a loop HH-MM-SS-HH-MM-SS...
					cur_sel <= 1;
				end if;
				
			elsif(SW(0) = '0') then
				cur_sel <= 0;
			end if;
			
			--Control inc/dec button press
			--This allow to detect if we have a long press (press = 3) or a short press (press < 3)
			
			if(db_KEY(0) = '0' or db_KEY(1) = '0') then
				press <= press + 1;
				
				if(press > 25E6) then
					press <= 3;
				end if;
			else
				press <= 0;
			end if;
			
			
			--Check if user wants to increment or decrement hours, minutes or seconds
			
			if(SW(1) = '0') then						--24h format 
			
				if(SW(0) = '1') then					--Time Adjust Mode
					
					if(press = 3) then 				--Long Press
						
						if(db_KEY(1) = '0') then 		--Decrement 10x Time			
							
							if(cur_sel = 1) then		--Hours
								hour <= hour - 10;
								
								if(hour < 10) then	--Reset Hours when 10-10 hours
									hour <= 23;
								end if;
							
							elsif(cur_sel = 2) then --Minutes
								min <= min - 10;
								
								if(min < 8) then		--Reset Minutes when 8-10 Minutes
									min <= 59;
								end if;
								
							elsif(cur_sel = 3) then --Seconds
								sec <= sec - 10;
								
								if(sec < 8) then		--Reset Seconds when 8-10 Seconds
									sec <= 59;
								end if;
							
							end if;
							
						elsif(db_KEY(0) = '0') then 	--Increment 10x Time
							
							if(cur_sel = 1) then 	--Hours
								hour <= hour + 10;
								
								if(hour > 13) then 	--Reset Hours when 13+10 hours
									hour <= 0;
								end if;
							
							elsif(cur_sel = 2) then --Minutes
								min <= min + 10;
								
								if(min > 49) then 	--Reset Minutes when 49+10 Minutes
									min <= 0;
								end if;
								
							elsif(cur_sel = 3) then --Seconds
								sec <= sec + 10;
								
								if(sec > 49) then 	--Reset Seconds when 49+10 Seconds
									sec <= 0;
								end if;
							
							end if;
						end if;
						
					else									--Short Press
					
						if(db_KEY(1) = '0') then 		--Decrement Time						
							
							if(cur_sel = 1) then 	--Hours
								hour <= hour - 1;
								
								if(hour <= 0) then
									hour <= 23;
								end if;
							
							elsif(cur_sel = 2) then	--Minutes
								min <= min - 1;
								
								if(min <= 0) then
									min <= 59;
								end if;
								
							elsif(cur_sel = 3) then --Seconds
								sec <= sec - 1;
								
								if(sec <= 0) then
									sec <= 59;
								end if;
							
							end if;
							
						elsif(db_KEY(0) = '0') then 	--Increment Time
							
							if(cur_sel = 1) then		--Hours
								hour <= hour + 1;
								
								if(hour >= 23) then
									hour <= 0;
								end if;
							
							elsif(cur_sel = 2) then --Minutes
								min <= min + 1;
								
								if(min >= 59) then
									min <= 0;
								end if;
								
							elsif(cur_sel = 3) then --Seconds
								sec <= sec + 1;
								
								if(sec >= 59) then
									sec <= 0;
								end if;
							
							end if;
						end if;
					end if;
				else 										--Working Mode
					sec <= sec + 1;
				
					if(sec >= 59) then 				
						sec <= 0;
						min <= min + 1;
					
						if(min >= 59) then			
							min <= 0;
							hour <= hour + 1;
							
							if(hour >= 23) then
								hour <= 0;
							end if;
						
						end if;
					end if;
				end if;
			
			else											--12h format
			
				if(SW(0) = '1') then					--Time Adjust Mode			
						
					if(press = 5) then				--Long Press
							
						if(db_KEY(1) = '0') then		--Decrement 10x Times			
								
							if(cur_sel = 1) then		--Hours
								hour <= hour - 10;
									
								if(hour < 10) then   --Reset Hours when 10-10 Hours
									hour <= 12;
								
									if(am = '1') then	--Switch Between AM and PM
										am <= '0';
									else
										am <= '1';
									end if;
								
								end if;
							
							elsif(cur_sel = 2) then	--Minutes
								min <= min - 10;
								
								if(min < 8) then		--Reset Minutes when 8-10 Minutes
									min <= 59;
								end if;
								
							elsif(cur_sel = 3) then	--Seconds
								sec <= sec - 10;
									
								if(sec < 8) then		--Reset Seconds when 8-10 Seconds
									sec <= 59;
								end if;
							
							end if;
								
						elsif(db_KEY(0) = '0') then	--Increment 10x Time
								
							if(cur_sel = 1) then		--Hours
								hour <= hour + 10;
									
								if(hour > 2) then		--Reset Hours when 2+10 Hours
									hour <= 1;
									
									if(am = '1') then	--Switch Between AM and PM
										am <= '0';
									else
										am <= '1';
									end if;
								
								end if;
								
							elsif(cur_sel = 2) then	--Minutes
								min <= min + 10;
									
								if(min > 49) then		--Reset Minutes when 49+10 Minutes
									min <= 0;
								end if;
									
							elsif(cur_sel = 3) then	--Seconds
								sec <= sec + 10;
									
								if(sec > 49) then		--Reset Seconds when 49+10 Seconds
									sec <= 0;
								end if;
							
							end if;
						end if;
						
					else									--Short Press			
						
						if(db_KEY(1) = '0') then		--Decrement Time				
								
							if(cur_sel = 1) then		--Hours
								hour <= hour - 1;
								
								if(hour <= 1 ) then	
									hour <= 12;
									
									if(am = '1') then
										am <= '0';
									else
										am <= '1';
									end if;
								
								end if;
								
							elsif(cur_sel = 2) then	--Minutes
								min <= min - 1;
								
								if(min <= 0) then
									min <= 59;
								end if;
									
							elsif(cur_sel = 3) then	--Seconds
								sec <= sec - 1;
								
								if(sec <= 0) then
									sec <= 59;
								end if;
							
							end if;
								
						elsif(db_KEY(0) = '0') then	--Increment Time
							
							if(cur_sel = 1) then		--Hours
								hour <= hour + 1;
								
								if(hour >= 12) then
									hour <= 1;
									
									if(am = '1') then
										am <= '0';
									else
										am <= '1';
									end if;
								
								end if;
								
							elsif(cur_sel = 2) then	--Minutes
								min <= min + 1;
								
								if(min >= 59) then
									min <= 0;
								end if;
									
							elsif(cur_sel = 3) then	--Seconds
								sec <= sec + 1;
								
								if(sec >= 59) then
									sec <= 0;
								end if;
				
							end if;
						end if;
					end if;
				
				else										--Working Mode
					sec <= sec + 1;
					
					if(sec >= 59) then				
						sec <= 0;
						min <= min + 1;
						
						if(min >= 59) then
							min <= 0;
							hour <= hour + 1;
								
							if(hour >= 12) then
								hour <= 1;
								
								if(am = '1') then
									am <= '0';
								else
									am <= '1';
								end if;
							
							end if;
						end if;
					end if;
				end if;
			end if;
			
			if(SW(1) = '1') then
				if(hour > 12) then 					--Convert hours when switch from 24h format to 12h format
					hour <= hour - 12;			
				end if;
			elsif(Sw(1) = '0' and am = '0') then
				if(hour < 12) then 					--Convert hours when switch from 24h format to 12h format
					hour <= hour + 12;			
				end if;
			end if;
		end if;
		--End HH:MM:SS counter
		
		--The hours, minutes and seconds are set by the user
		--They blink with frequency = 1Hz when in set mod
		
		--Hours
		if(SW(0) = '1' and clk = '1' and cur_sel = 1) then
			HEX6 <= "1111111";
			HEX7 <= "1111111";
		else
			HEX6 <= h2Dis(6 downto 0);
			HEX7 <= h2Dis1(6 downto 0);
		end if;
		
		--Minutes
		if(SW(0) = '1' and clk = '1' and cur_sel = 2) then
			HEX4 <= "1111111";
			HEX5 <= "1111111";
		else
			HEX4 <= m2Dis(6 downto 0);
			HEX5 <= m2Dis1(6 downto 0);
		end if;
		
		--Seconds
		if(SW(0) = '1' and clk = '1' and cur_sel = 3) then
			HEX2 <= "1111111";
			HEX3 <= "1111111";
		else
			HEX2 <= s2Dis(6 downto 0);
			HEX3 <= s2Dis1(6 downto 0);
		end if;
		
		--AM/PM
		if(SW(1) = '1') then
			
			if(am = '1') then	
				HEX1 <= "0001000";
				HEX0 <= "0101011";
			else
				HEX1 <= "0001100";
				HEX0 <= "0101011";
			end if;
		else
			HEX1 <= "1111111";
			HEX0 <= "1111111";
		end if;
	
	end process;
	
	LEDG(0) <= not db_key(0); --On if key(0) is pressed after debounce
	LEDG(2) <= not db_key(1); --On if key(1) is pressed after debounce
	LEDG(4) <= not db_key(2); --On if key(2) is pressed after debounce	
	LEDG(6) <= not db_key(3); --On if key(3) is pressed after debounce	

end Behavioral;