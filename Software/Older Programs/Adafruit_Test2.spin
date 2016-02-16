'Adafruit Test#1
'Basic test of Prop control of LED matrix

CON  'Crystal settings

  _clkmode = xtal1+pll16x
  _clkfreq = 80_000_000

CON  'Pin settings

  Pin_R1 = 4    '1  on connector
  Pin_G1 = 5    '2
  Pin_B1 = 6    '3
  Pin_R2 = 7    '5
  Pin_G2 = 8    '6
  Pin_B2 = 9    '7
  Pin_A  = 10   '9     'ABC select section
  Pin_B  = 11   '10
  Pin_C  = 12   '11
  Pin_CLK= 13   '13    'clock
  Pin_LE = 14   '14    'latch enable
  Pin_EN = 15   '15    'display enable

PUB Main  'Start
  'Try shift in a bit and enabling

  'Set all pins to output low
  OUTA[Pin_R1..Pin_EN]~  
  DIRA[Pin_R1..Pin_EN]~~

  'Select 1 of 8 sections
  OUTA[Pin_A]~
  OUTA[Pin_B]~
  OUTA[Pin_C]~
  
  'Set R1 high, clock, latch, and enable
  'disable output
  OUTA[Pin_EN]~~

  'Shift in some data
  OUTA[pin_B1]~~
  OUTA[pin_R2]~~ 
  repeat 1
    OUTA[Pin_CLK]~~
    OUTA[Pin_CLK]~

  OUTA[pin_B1]~
  OUTA[pin_R2]~
  repeat 31
    OUTA[Pin_CLK]~~
    OUTA[Pin_CLK]~    

  'Latch the data
  repeat 1
    OUTA[Pin_LE]~~
    OUTA[Pin_LE]~

  'Enable the display
  OUTA[Pin_EN]~

  'Need to toggle the A line or else the protection circuit will turn off the de-multiplexer.
  repeat
      OUTA[Pin_A..Pin_C]++
   
