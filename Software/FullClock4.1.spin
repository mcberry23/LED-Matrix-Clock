CON  'Crystal settings
  _clkmode = xtal1+pll16x 
   _XINFREQ = 5_000_000                                  {Crystal frequency 5.000Mhz}       
  '(16*5Mhz) = 80.000Mhz clock
  _STACK = 1024                                         {reserve 1K of longs for stack... overkill!!}
CON  'Pin settings
  Panel1_BasePin =4
  Panel2_BasePin =16
  Panel3_BasePin =22
  ENTER_PIN =    16
  LEFT_PIN =      17  
  UP_PIN =        18
  DOWN_PIN =      20
  RIGHT_PIN =     23
  BUTTON_LIGHT =  24 
  RX_PIN =        27
  TX_PIN =        26
CON  'Initial intensity and color balance settings
  Init_Intensity = 3  'Initial intensity (range is 0 to 31)  
  Bal_Red=255 'The range for each color is 0 to 255
  Bal_Green=255
  Bal_Blue=255
VAR  'Space for pre-calculated outputs (the driver cog continously outputs this to the LED panels)
  long OutputArray[32*8*8]  '32 pixels wide, 8 bits of color, 8 segments
  byte temp
  byte XValue
  byte YValue
  byte Counter
  byte Secs         'Seconds passed 
VAR  'Variables to pass to assembly drivers
  long balance  'variable to scale input RGB values for color balance  
  long Intensity 'variable to reduce brightness by modulating the enable pin  (0..31)
  long BasePin1   'starting pin of 12 pins required for first panel
  long BasePin2   'starting pin of 6 pins required for second panel (or -1 to disable)
  long BasePin3   'starting pin of 6 pins required for third panel (or -1 to disable)
  long EnablePin456  'reserved
  long pOutputArray  'pointer to precalculated array of outputs
VAR 'Time based Variables
  long fulltime
  byte hour
  byte hourstandard  
  byte minute
  byte second
  byte tempsecond  
  byte meridiem
  byte day
  byte month
  byte year  
VAR 'Interface based variables
  byte brightness
  byte prev_brightness
  byte mode
  byte page
  byte PreviousMode
  byte PreviousPage
  byte raspiConnected
VAR 'Weather based variables
  BYTE picture_string[7]
  BYTE temp_current[7]
  BYTE temp_current_num
  BYTE temp_high[7]
  BYTE temp_high_num
  BYTE temp_low[7]
  BYTE temp_low_num  
OBJ 'Reference Other Files
   matrix : "32x16_Driver1"     'Display drivers
   led : "32x16_Graphics1"      'Sets up graphics and characters
   RTC: "RealTimeClock"         'Keeps up with time
   serial : "FullDuplexSerial"  'Serial Communication Drivers
   pst : "Parallax Serial Terminal"      
PUB Main
  Init 'Initialize screen and time 
  repeat      
    CheckMode 'Check button input
    GetTime
    GetBrightness                     
    if (mode==1)                            'Home-Main       
      DisplayTime
      DisplayDate
    elseif (mode == 2 AND page==1)                      'Displays words Set Time and Date
      led.DrawText5x8(0,0,string("Set"),1,2,0)
      led.DrawText5x8(0,8,string("Time"),1,2,0)       
    elseif (mode == 2 AND page==2)                                  'Set Method
      SetTime
PUB DisplayDate 'Displays the date and the meridiem
  if (meridiem == 0)
    led.DrawText(25,11, string("AM"),brightness,7,0,3,5)  
  else
    led.DrawText(25,11, string("PM"),brightness,7,0,3,5)
  if brightness == 1
    led.DrawTwoNum(0,11, month,brightness,3,0,3,5)
    led.SetPixel(7,13,led.GetColor(1,brightness))
    led.DrawTwoNum(8,11, day,brightness,7,0,3,5)
    led.SetPixel(15,13,led.GetColor(1,brightness))
    led.DrawTwoNum(16,11, year,brightness,3,0,3,5)
  else
    led.DrawTwoNum(0,11, month,brightness,0,0,3,5)
    led.SetPixel(7,13,led.GetColor(0,brightness))
    led.DrawTwoNum(8,11, day,brightness,0,0,3,5)
    led.SetPixel(15,13,led.GetColor(0,brightness))
    led.DrawTwoNum(16,11, year,brightness,0,0,3,5)
PUB Init  
  balance:=led.RGB(Bal_Red,Bal_Green,Bal_Blue)  'set color balance
  Intensity:=Init_Intensity   'set intensity  
  pOutputArray:=@OutputArray[0] 'set pin configuration
  BasePin1:=Panel1_BasePin
  BasePin2:=Panel2_BasePin
  BasePin3:=Panel3_BasePin  
  led.Start(@balance) 'Start graphics support  
  matrix.Start(@balance) 'Launch assembly driver cog to output precalculated data
  mode := 1
  page := 1
  PreviousMode := 1
  PreviousPage := 1 
  led.SetAllPixels(led#black)
  ctra[30..26] := %01000        ' Set mode to "POS detector"
  ctra[5..0] := 0               ' Set APIN to 17 (P17)
  frqa := 1                     ' Increment phsa by 1 for each clock tick
  dira[BUTTON_LIGHT] := 1                  ' Set Button Light to Output                                          
  RTC.Start
  RTC.SetTime(12,00,50)
  month := 1
  day := 1
  year := 16
  RTC.SetDate(day,month,year)
  pst.Start(115200)
  serial.Start(RX_PIN, TX_PIN, 0, 115200)              
PUB GetBrightness | time
    dira[0] := outa[0] := 1               ' Set pin to output-high
    waitcnt(clkfreq/100_000 + cnt)          ' Wait for circuit to charge
    phsa~                                   ' Clear the phsa register
    dira[0]~                               ' Pin to input stops charging circuit
    repeat 22
      waitcnt(clkfreq/60 + cnt)        
    time := (phsa - 624) #> 0
    if (time >= 3000000)
      brightness := 0
      outa[BUTTON_LIGHT] := 0 'Turn Button Light Off
    elseif (time < 1000000)
      brightness := 1
      outa[BUTTON_LIGHT] := 1 'Turn Button Light On
    'else no change 
    if NOT(brightness == prev_brightness)
      led.SetAllPixels(0)
    prev_brightness := brightness             
PUB CheckMode      
  if (ina[LEFT_PIN]==1) 'left
    mode--
    page:=1   
  if (ina[RIGHT_PIN]==1) 'right
    mode++
    page:=1
  if (ina[UP_PIN]==1) 'up  
    page++
  elseif (ina[DOWN_PIN]==1) 'down
    page--
  waitcnt(cnt+clkfreq/5) 'wait a second        
  if (mode<1)
    mode:=2
  if (mode>2)
    mode:=1
  if (page<1)
    page:=2
  if (page>2)
    page:=1
  if NOT(PreviousMode == mode AND PreviousPage == page)
    led.SetAllPixels(led#black) 
  PreviousMode := mode
  PreviousPage := page
  raspiConnected := 0
PUB SetTime | select
    select:=1 
  repeat while ina[ENTER_PIN]==0
    brightness := 1 
    if (ina[LEFT_PIN]==1) 'left
      select--
      led.DrawRect (0,5,6,5,0,brightness)
      led.DrawRect (10,5,16,5,0,brightness)
      led.DrawRect (0,13,6,13,0,brightness)
      led.DrawRect (10,13,16,13,0,brightness)
      led.DrawRect (20,13,26,13,0,brightness)       
    elseif (ina[RIGHT_PIN]==1) 'right
      select++
      led.DrawRect (0,5,6,5,0,brightness)
      led.DrawRect (10,5,16,5,0,brightness)
      led.DrawRect (0,13,6,13,0,brightness)
      led.DrawRect (10,13,16,13,0,brightness)
      led.DrawRect (20,13,26,13,0,brightness)  
    if (select>5)
      select:=1
    elseif (select<1)
      select:=5
    if (select==1)
      led.DrawRect (0,5,6,5,1,brightness)
      if (ina[UP_PIN]==1) 'up    
        hour++
      elseif (ina[DOWN_PIN]==1) 'down
        hour--
    elseif (select==2)
      led.DrawRect (10,5,16,5,1,brightness)
      if (ina[UP_PIN]==1) 'up    
        minute++
      elseif (ina[DOWN_PIN]==1) 'down
        minute--
    elseif (select==3)
      led.DrawRect (0,13,6,13,1,brightness)
      if (ina[UP_PIN]==1) 'up    
        month++
      elseif (ina[DOWN_PIN]==1) 'down
        month--
    elseif (select==4)
      led.DrawRect (10,13,16,13,1,brightness)
      if (ina[UP_PIN]==1) 'up    
        day++
      elseif (ina[DOWN_PIN]==1) 'down
        day--
    elseif (select==5)
      led.DrawRect (20,13,26,13,1,brightness)
      if (ina[UP_PIN]==1) 'up    
        year++
      elseif (ina[DOWN_PIN]==1) 'down
        year--           
    ProcessTime
       
    led.DrawTwoNum(0,0, hourstandard,brightness,3,0,3,5)
    led.DrawChar(7,0, ":",brightness,1,0,3,5)
    led.DrawTwoNum(10,0, minute,brightness,7,0,3,5)    
    if (meridiem == 0)
      led.DrawText(18,0, string("AM"),brightness,2,0,3,5)  
    else
      led.DrawText(18,0, string("PM"),brightness,2,0,3,5)
    led.DrawTwoNum(0,8, month,brightness,7,0,3,5)
    led.SetPixel(8,10,led.GetColor(1,brightness))
    led.DrawTwoNum(10,8, day,brightness,3,0,3,5)
    led.SetPixel(18,10,led.GetColor(1,brightness))
    led.DrawTwoNum(20,8, year,brightness,2,0,3,5)
    waitcnt(cnt+clkfreq/10) 'wait a second     
  RTC.SetTime(hour,minute,0)
  RTC.SetDate(day,month,year)                               
  page:=1
  mode:=1
  led.SetAllPixels(led#black)  
PUB GetTime
  tempsecond := RTC.ReadTimeReg(0)                          'Read current second
  minute := RTC.ReadTimeReg(1)
  hour := RTC.ReadTimeReg(2)
  month := RTC.ReadTimeReg(4)                          'Read current second
  day := RTC.ReadTimeReg(3)
  year := RTC.ReadTimeReg(5)
  ProcessTime  
PUB ProcessTime
  if (hour > 24)
    hour:=1
  elseif(hour<1)
    hour:=24
  if (hour > 12)
    hourstandard:=hour-12
    meridiem:=1
  else
    hourstandard:=hour
    meridiem:=0
  if (hour == 24)
    meridiem:=0
  if (hour == 12)
    meridiem:=1
  if (minute > 59)
    minute:=0
  elseif(minute<0)
    minute:=59    
  if (month>12)
    month:=1
  elseif (month<1)
    month:=12
  if (day>31)
    day:=1
  elseif(day<1)
    day:=31
  if (year<0)
    year:=99
PUB DisplayTime
  if NOT(tempsecond == second)
    second := tempsecond
    if hourstandard < 10
      led.DrawChar(0,0,string("0"),brightness,0,0,6,10)  
      led.DrawChar(7,0,hourstandard,brightness,7,0,6,10) 
    else
      led.DrawTwoNum(0,0,hourstandard,brightness,7,0,6,10)
    led.DrawChar(15,0,":",brightness,1,0,2,10)
    led.DrawTwoNum(19,0,minute,brightness,3,0,6,10) 
PUB CompareBuffers(pointer0, pointer1, size)
  repeat size
    if byte[pointer0] <> byte[pointer1]
      result++