.include "m8515def.inc"
.def Temp =r16 ; Temporary register
.def Delay =r17 ; Delay variable 1
.def Delay2 =r18 ; Delay variable 2
.def LED =r19
.equ DELAY_VAR = 0xFF
;***** Initialization
RESET:
ldi LED,0x01
ser Temp
out DDRB,Temp ; Set PORTB to output
;**** Test input/output
LOOP:
rol LED
out PORTB,LED ; Update LEDS
;**** Now wait a while to make LED changes visible.
DLY:
dec Delay
brne DLY
dec Delay2
brne DLY
rjmp LOOP ; Repeat loop forever
