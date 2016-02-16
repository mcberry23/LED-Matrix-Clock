OBJ
  SqrWave : "SquareWave" 
VAR
             
  ''Global vars...
  long Cog                                              'Cog issued tracking
  long ALMStack[32]                                     'Stack for RTC object in new cog

PUB Start:Success 'Start the RTC object in a new cog...

  If not cog                                            'RTC not already started
    Success := Cog := Cognew(SoundAlarm,@ALMStack)  'Start in new cog
 
PUB Stop 'Stops the Real Time Clock object, frees a cog.

  If Cog
    Cogstop(Cog)
PUB SoundAlarm | index, pin, duration, x   
  spr[8+0] := (%00100 << 26) + 1
  dira[1]~~
  repeat
    repeat index from 0 to 2
      frqa := SqrWave.NcoFrqReg(1047)    
      duration := clkfreq/4
      waitcnt(duration + cnt)
      frqa := SqrWave.NcoFrqReg(0)
      duration := clkfreq/2
      waitcnt(duration + cnt)
    duration := clkfreq/1
      waitcnt(duration + cnt)   