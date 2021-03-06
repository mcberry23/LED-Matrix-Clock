' Copyright (c) 2011 Rayslogic.com, LLC
CON  'Crystal settings
  _clkmode = xtal1+pll16x 
   _XINFREQ = 5_000_000                                  {Crystal frequency 5.000Mhz}       
  '(16*5Mhz) = 80.000Mhz clock
  _STACK = 1024                                         {reserve 1K of longs for stack... overkill!!}
CON 'Date string return format type constants..
  UkFormat = 0                                          'False (zero)
  UsaFormat = 1                                         'True (non-zero)
CON  'Pin settings
  Panel1_BasePin = 4
  Panel2_BasePin = 16
  Panel3_BasePin = 22
  RX_PIN = 29
  TX_PIN = 28
CON  'Initial intensity and color balance settings
  Init_Intensity = 20  'Initial intensity (range is 0 to 31)
  'A single panel draws 3 Amps on full white and with Intesity=31.
  'Current draw is linear with intensity.
  'The Adafruit panels are balanced nicely, but you can fine tune the balance with these settings.
  'The range is 0 to 255
  'The input color levels are limited to these values
  Bal_Red=255
  Bal_Green=255
  Bal_Blue=255
VAR  'Space for pre-calculated outputs (the driver cog continously outputs this to the LED panels)
  long OutputArray[32*8*8]  '32 pixels wide, 8 bits of color, 8 segments
  byte temp
  byte XValue
  byte YValue
  byte Counter
  byte Secs                                             'Seconds passed
  byte mode
  byte page
  byte PreviousMode
  byte PreviousPage
  long color1
  long color2
  long color3
  long color4
  long alarm1
  long alarm2
  long alarm3
  long alarm4
  byte colorpalette
  byte brightness  
VAR  'Variables to pass to assembly drivers
  long balance  'variable to scale input RGB values for color balance  
  long Intensity 'variable to reduce brightness by modulating the enable pin  (0..31)
  long BasePin1   'starting pin of 12 pins required for first panel
  long BasePin2   'starting pin of 6 pins required for second panel (or -1 to disable)
  long BasePin3   'starting pin of 6 pins required for third panel (or -1 to disable)
  long EnablePin456  'reserved
  long pOutputArray  'pointer to precalculated array of outputs
'  long nPanels 'Number of panels connected
  long Arrangement 'organization of panels
VAR
  long fulltime
  byte hour
  byte minute
  byte second
  byte tempsecond
  byte hourone
  byte hourtwo
  byte minone
  byte mintwo
  byte meridiem
  byte day
  byte dayone
  byte daytwo
  byte month
  byte monthone
  byte monthtwo
  byte year
  byte yearone
  byte yeartwo
  byte fullstring[6]  
  
OBJ
   matrix : "32x16_Driver1"
   led : "32x16_Graphics1"
   RTC: "RealTimeClock"
   serial : "FullDuplexSerial"        
   'SqrWave : "SquareWave"
   'ALM : "AlarmSound"
   
PUB Main
  Init 
  repeat      
    CheckMode
    GetTime
    'CheckAlarms 
    if (mode==1 AND page==1)                            'Home-Main       
      DisplayTime
      Main2
    elseif (mode == 1 AND page==2)                      'Set Time and Date
      SetTime        
    elseif (mode == 2 AND page==1)                      'Alarms-Main    
      led.DrawText5x8(0,0,string("Alarms"),led#green,led#black)
    elseif (mode==2 AND page==2)                        'Set Alarm
      led.DrawText5x8(0,0,string("Alarm1"),led#green,led#black)
    elseif (mode == 3)                                  'Date
      led.DrawText5x8(0,0,string("Date"),led#red,led#black)
    elseif (mode==4)                                    'Temperature 
      led.DrawText5x8(0,0,string("Temp"),led#cyan,led#black)
    
PUB Main2 | i, errorFlag, light
  light := 1
  serial.Start(RX_PIN, TX_PIN, 0, 115200)
  
  led.DrawPic(0,11,@weather[0],1,5,5)
  
  led.DrawTwoNum(6,11, 51,light,1,0,3,5)
  led.DrawTwoNum(15,11, 55 ,light,3,0,3,5)
  led.DrawText(22,11, string("/") ,light,1,0,3,5) 
  led.DrawTwoNum(25,11, 47 ,light,7,0,3,5)

  'repeat
    'piRead
    'if (CompareBuffers(@fullstring,@name,6)==0)
    '  led.DrawText5x8(0,0, @fullstring ,led#white,led#black)
    'else   
    '  led.DrawText5x8(0,0, @fullstring  ,led#blue,led#black)       
PUB piRead | i, errorFlag   
  i:=0
  errorFlag := 0
  repeat i from 0 to 5
    fullstring[i] := serial.Rx
  serial.RxFlush       
             
PUB piWrite    


PUB CompareBuffers(pointer0, pointer1, size)
  repeat size
    if byte[pointer0] <> byte[pointer1]
      result++
       
   
PUB Init'|'i, j, k, section, bit,bits, c0, Pin_A, Pin_EN  'Show a 1bpp bitmap
  'set initial balance and intensity
    
  balance:=led.RGB(Bal_Red,Bal_Green,Bal_Blue)  'set maximum brightness by dividing input, range 0 to 256
  Intensity:=Init_Intensity   'max brightness via enable too, range 0 to 31
  'set up pin configuration
  pOutputArray:=@OutputArray[0]
  BasePin1:=Panel1_BasePin
  BasePin2:=Panel2_BasePin
  BasePin3:=Panel3_BasePin  
  Arrangement:=0 'Set up panel arrangement 
  led.Start(@balance) 'Start graphics support  
  matrix.Start(@balance) 'Launch assembly driver cog to output precalculated data
  mode := 1
  page := 1
  color1:=led#dimorange
  color2:=led#dimblue
  color3:=led#dimwhite
  PreviousMode := 1
  PreviousPage := 1 
  colorpalette := 1 
  led.SetAllPixels(led#black)
  ctra[30..26] := %01000                     ' Set mode to "POS detector"
  ctra[5..0] := 0                          ' Set APIN to 17 (P17)
  frqa := 1                                  ' Increment phsa by 1 for each clock tick
  RTC.Start
  RTC.SetTime(12,00,50)                                 '10 seconds to midnight
  
  month:=5
  day:=20
  year:=15
  RTC.SetDate(day,month,year)                                 'New years eve, 2007
PUB GetBrightness | time
    dira[0] := outa[0] := 1               ' Set pin to output-high
    waitcnt(clkfreq/100_000 + cnt)          ' Wait for circuit to charge
    phsa~                                   ' Clear the phsa register
    dira[0]~                               ' Pin to input stops charging circuit
    repeat 22
      waitcnt(clkfreq/60 + cnt)        
    time := (phsa - 624) #> 0
    if (time >= 1400000)
        brightness := 1
    else
        brightness := 0            
PUB CheckMode      
  if (ina[23]==1) 'left
    mode--
    page:=1   
  if (ina[17]==1) 'right
    mode++
    page:=1
  if (ina[20]==1) 'up  
    page++
  elseif (ina[18]==1) 'down
    page--
 ' if (mode:=1)
 '   SetColors
  waitcnt(cnt+clkfreq/5) 'wait a second        
  if (mode<1)
    mode:=4
  if (mode>4)
    mode:=1
  if (page<1)
    page:=2
  if (page>2)
    page:=1
  if NOT(PreviousMode == mode AND PreviousPage == page)
    led.SetAllPixels(led#black) 
  PreviousMode := mode
  PreviousPage := page
PUB ConvertTime
  return second + (minute*100) + (hour*10000)
{{PUB CheckAlarms
  alarm1 := 120100
  if alarm1== ConvertTime
    SoundAlarm
PUB SoundAlarm | index, pin, duration, x   
  spr[8+0] := (%00100 << 26) + 1
  dira[1]~~
  x:=0
  repeat while (x==0)
    repeat index from 0 to 2
      if (ina[16]==1)
        x:=1
      led.DrawOutline(0,0,31,15,led#white)        
      frqa := SqrWave.NcoFrqReg(1047)    
      duration := clkfreq/4        
      waitcnt(duration + cnt)
      if (ina[16]==1)
        x:=1
      led.DrawOutline (0,0,31,15,led#dimwhite)  
      frqa := SqrWave.NcoFrqReg(0)
      if (ina[16]==1)
        x:=1
      duration := clkfreq/2
      waitcnt(duration + cnt)
    duration := clkfreq/1
      waitcnt(duration + cnt)
  led.DrawOutline (0,0,31,15,led#black)}}       
PUB SetColors       
'  if (ina[20]==1) 'up    
'    colorpalette++
'  elseif (ina[18]==1) 'down
'    colorpalette-- 
'  if (colorpalette<1)
'    colorpalette:=4
'  if (colorpalette>4)
'    colorpalette:=1
  if (colorpalette==1 and brightness==0)
    color1:=led#orange
    color2:=led#blue
    color3:=led#white
    color4:=led#white
  if (colorpalette==1 and brightness==1)
    color1:=led#dimorange
    color2:=led#dimblue
    color3:=led#dimwhite
    color4:=led#dimwhite
'  if (colorpalette==2)
'    color1:=led#red
'    color2:=led#purple
'    color3:=led#blue
'  if (colorpalette==3)
'    color1:=led#green
'    color2:=led#blue
'    color3:=led#yellow
'  if (colorpalette==4)
'    color1:=led#green
'    color2:=led#red
'    color3:=led#green     
PUB SetTime | select
    select:=1 
  repeat while ina[16]==0   
    if (ina[23]==1) 'left
      select--
      led.DrawRect (0,5,6,5,led#black)
      led.DrawRect (10,5,16,5,led#black)
      led.DrawRect (0,13,6,13,led#black)
      led.DrawRect (10,13,16,13,led#black)
      led.DrawRect (20,13,26,13,led#black)       
    elseif (ina[17]==1) 'right
      select++
      led.DrawRect (0,5,6,5,led#black)
      led.DrawRect (10,5,16,5,led#black)
      led.DrawRect (0,13,6,13,led#black)
      led.DrawRect (10,13,16,13,led#black)
      led.DrawRect (20,13,26,13,led#black)  
    if (select>5)
      select:=1
    elseif (select<1)
      select:=5
    if (select==1)
      led.DrawRect (0,5,6,5,led#white)
      if (ina[20]==1) 'up    
        hour++
      elseif (ina[18]==1) 'down
        hour--
    elseif (select==2)
      led.DrawRect (10,5,16,5,led#white)
      if (ina[20]==1) 'up    
        minute++
      elseif (ina[18]==1) 'down
        minute--
    elseif (select==3)
      led.DrawRect (0,13,6,13,led#white)
      if (ina[20]==1) 'up    
        month++
      elseif (ina[18]==1) 'down
        month--
    elseif (select==4)
      led.DrawRect (10,13,16,13,led#white)
      if (ina[20]==1) 'up    
        day++
      elseif (ina[18]==1) 'down
        day--
    elseif (select==5)
      led.DrawRect (20,13,26,13,led#white)
      if (ina[20]==1) 'up    
        year++
      elseif (ina[18]==1) 'down
        year--
           
    ProcessTime    
    {{if (hourone == 0)
      led.DrawChar3x5(0,0,hourone,led#black,led#black)
      led.DrawChar3x5(4,0,hourtwo,color1,led#black)
    else
      led.DrawChar3x5(0,0,hourone,color1,led#black)
      led.DrawChar3x5(4,0,hourtwo,color1,led#black)      
    led.DrawChar3x5(7,0,":",led#white,led#black)
    led.DrawChar3x5(10,0,minone,color2,led#black)
    led.DrawChar3x5(14,0,mintwo,color2,led#black)       
    if (meridiem == 0)
      led.DrawText3x5(18,0,STRING("AM"),color3,led#black)
    else
      led.DrawText3x5(18,0,STRING("PM"),color3,led#black)
    
    led.DrawText3x5(0,8,monthone,color1,led#black)
    led.SetPixel(8,10,led#white)
    led.DrawText3x5(10,8,dayone,color2,led#black)
    led.SetPixel(18,10,led#white)
    led.DrawText3x5(20,8,yearone,color3,led#black)}}  
    waitcnt(cnt+clkfreq/5) 'wait a second 
  RTC.SetTime(hour,minute,0)
  RTC.SetDate(day,month,year+2000)                               
  page:=1
  mode:=1
  led.SetAllPixels(led#black) 
       
PUB GetTime
  tempsecond := RTC.ReadTimeReg(0)                          'Read current second
  minute := RTC.ReadTimeReg(1)
  hour := RTC.ReadTimeReg(2)
  ProcessTime
PUB ProcessTime|hourtemp
  if (hour > 24)
    hour:=1
  elseif(hour<1)
    hour:=24
  if (minute > 59)
    minute:=0
  elseif(minute<0)
    minute:=59    
  if (hour > 12)
      hourtemp:=hour-12
      meridiem:=1
  else
    hourtemp:=hour
    meridiem:=0
  if (hour == 24)
    meridiem:=0
  if (hour == 12)
    meridiem:=1    
  hourone := hourtemp/10
  hourtwo := hourtemp//10
  minone := minute/10
  mintwo := minute//10
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
  
  dayone := String("??")
  RTC.IntAscii(dayone,day)
  monthone := String("??")
  RTC.IntAscii(monthone,month)
  yearone := String("??")
  RTC.IntAscii(yearone,year)
  'dayone := day/10
  'daytwo := day//10
  'monthone := month/10
  'monthtwo := month//10
  'yearone := year/10
  'yeartwo := year//10
  
PUB DisplayTime
  if NOT(tempsecond == second)
      second := tempsecond
        GetBrightness
        SetColors
      if (hourone == 0)
        DrawNumber(0,0,led#black,GetNumArray(1))
        DrawNumber(7,0,color1,GetNumArray(hourtwo))
      else
        DrawNumber(0,0,color1,GetNumArray(hourone))
        DrawNumber(7,0,color1,GetNumArray(hourtwo))
      DrawColon(15,0,color4)    
      DrawNumber(19,0,color2,GetNumArray(minone))
      DrawNumber(26,0,color2,GetNumArray(mintwo))   
      {{if (meridiem == 0)
        led.DrawText3x5(25,11,STRING("AM"),color3,led#black)
      else
        led.DrawText3x5(25,11,STRING("PM"),color3,led#black) }}
      
PUB DrawNumber(XStart, YStart, Color, Num)
   repeat YValue from YStart to YStart+9
    repeat XValue from XStart to XStart+5
         temp := BYTE[Num+((YValue-YStart)*6)][XValue-XStart]
         if temp == 1
            led.SetPixel(XValue,YValue,Color)
         else
            led.SetPixel(XValue,YValue,led#black)
PUB DrawColon(XStart, YStart, Color)
   repeat YValue from YStart to YStart+9
    repeat XValue from XStart to XStart+1
         temp := BYTE[@colon+((YValue-YStart)*2)][XValue-XStart]
         if temp == 1
            led.SetPixel(XValue,YValue,Color)
         else
            led.SetPixel(XValue,YValue,led#black)
PUB GetNumArray (Num)
  if Num == 1
    return @numberone
  elseif Num == 2
    return @numbertwo
  elseif Num == 3
    return @numberthree
  elseif Num == 4
    return @numberfour
  elseif Num == 5
    return @numberfive
  elseif Num == 6
    return @numbersix
  elseif Num == 7
    return @numberseven
  elseif Num == 8
    return @numbereight
  elseif Num == 9
    return @numbernine
  else
    return @numberzero

DAT
weather byte "clear1","pcloud","mcloud","thunde","herain","lirain","snowy1",0

Text byte "1", 0
input byte 0
numberone     byte 0,1,1,1,0,0
              byte 1,1,1,1,0,0
              byte 0,0,1,1,0,0
              byte 0,0,1,1,0,0
              byte 0,0,1,1,0,0
              byte 0,0,1,1,0,0
              byte 0,0,1,1,0,0
              byte 0,0,1,1,0,0
              byte 1,1,1,1,1,1
              byte 1,1,1,1,1,1

numbertwo     byte 0,1,1,1,1,0
              byte 1,1,1,1,1,1
              byte 1,1,0,0,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,1,1,0
              byte 0,0,1,1,0,0
              byte 0,1,1,0,0,0
              byte 1,1,0,0,0,0
              byte 1,1,1,1,1,1
              byte 1,1,1,1,1,1
              
numberthree   byte 0,1,1,1,1,0
              byte 1,1,1,1,1,1
              byte 1,1,0,0,1,1
              byte 0,0,0,0,1,1
              byte 0,0,1,1,1,0
              byte 0,0,1,1,1,0
              byte 0,0,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,1,1,1,1
              byte 0,1,1,1,1,0

numberfour    byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,1,1,1,1
              byte 1,1,1,1,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,0,1,1
              
numberfive    byte 1,1,1,1,1,1
              byte 1,1,1,1,1,1
              byte 1,1,0,0,0,0
              byte 1,1,0,0,0,0
              byte 1,1,1,1,1,0
              byte 1,1,1,1,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,0,1,1
              byte 1,1,1,1,1,1
              byte 1,1,1,1,1,0
              
numbersix     byte 0,0,0,1,1,0
              byte 0,0,1,1,0,0
              byte 0,1,1,0,0,0
              byte 1,1,0,0,0,0
              byte 1,1,1,1,1,0
              byte 1,1,1,1,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,1,1,1,1
              byte 0,1,1,1,1,0
              
numberseven   byte 1,1,1,1,1,1
              byte 1,1,1,1,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,1,1,0
              byte 0,0,0,1,1,0
              byte 0,0,1,1,0,0
              byte 0,0,1,1,0,0
              byte 0,1,1,0,0,0
              byte 0,1,1,0,0,0
              byte 1,1,0,0,0,0
              
numbereight   byte 0,1,1,1,1,0
              byte 1,1,1,1,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 0,1,1,1,1,0
              byte 0,1,1,1,1,0
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,1,1,1,1
              byte 0,1,1,1,1,0
              
numbernine    byte 0,1,1,1,1,0
              byte 1,1,1,1,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,1,1,1,1
              byte 0,1,1,1,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,0,1,1
              byte 0,0,0,0,1,1
              
numberzero    byte 0,1,1,1,1,0
              byte 1,1,1,1,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,0,0,1,1
              byte 1,1,1,1,1,1
              byte 0,1,1,1,1,0
              
colon         byte 0,0
              byte 0,0
              byte 1,1
              byte 1,1
              byte 0,0
              byte 0,0
              byte 1,1
              byte 1,1
              byte 0,0
              byte 0,0             
CON
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}

  