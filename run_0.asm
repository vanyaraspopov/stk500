.include "m8515def.inc"
.def TMP_1 =r16 ; Temp var 1
.def TMP_2 =r19 ; Temp var 2
.def DELAY_1 =r17 ; Delay variable 1
.def DELAY_2 =r18 ; Delay variable 2
.def LED_DISABLED = r20 ; LED disabled flag
.def LED_STATE = r21 ; State of LEDs
.def BTN0_CNTR = r22 ; 0 button counter

.equ F_CPU = 4000000 ; clk0 frequency
.equ BAUD_RATE = 19200 ; target bitrate
.equ UBRR = F_CPU/(16*BAUD_RATE)-1
.equ BTN_CNTR = 0xff ; initial value for button counter

;***** Initialization
.org $000 rjmp RESET ; Reset Handler
.org $001 reti ; IRQ0 Handler
.org $002 reti ; IRQ1 Handler
.org $003 reti ; Timer1 Capture Handler
.org $004 reti ; Timer1 Compare A Handler
.org $005 reti ; Timer1 Compare B Handler
.org $006 reti ; Timer1 Overflow Handler
.org $007 rjmp TIM0_OVF ; Timer0 Overflow Handler
.org $008 reti ; SPI Transfer Complete Handler
.org $009 rjmp USART_RXC ; USART RX Complete Handler
.org $00a reti ; UDR0 Empty Handler
.org $00b rjmp USART_TXC ; USART TX Complete Handler
.org $00c reti ; Analog Comparator Handler
.org $00d reti ; IRQ2 Handler
.org $00e reti ; Timer0 Compare Handler
.org $00f reti ; EEPROM Ready Handler
.org $010 reti ; Store Program memory Ready Handler

RESET:
; stack setup
ldi	TMP_1,LOW(RAMEND)  ; load low byte of RAMEND into r16
out	SPL,TMP_1		   ; store r16 in stack pointer low
ldi	TMP_1,HIGH(RAMEND) ; load high byte of RAMEND into r16
out	SPH,TMP_1		   ; store r16 in stack pointer high

rcall TIM0_INIT
rcall USART_INIT

; init variables
ldi LED_DISABLED,0xff ; all disabled
ldi BTN0_CNTR,BTN_CNTR

ser r16
out DDRB,r16 ; Set PORTB to output
out PORTB,LED_DISABLED ; initial state of LEDs

sei ; enable global interrupts

LOOP:
sbis PINC,PINC0 ; if pind0 button pressed
rcall LED_TOGGLE ; decrement BTN0 counter
sbic PINC,PINC0 ; if pind0 button released
ldi BTN0_CNTR,BTN_CNTR ; reset button counter
rjmp LOOP ;

LED_TOGGLE:
clr TMP_1
cp BTN0_CNTR,TMP_1 ; if counter is zero
breq LED_TOGGLE_EXIT ; then exit
dec BTN0_CNTR ; decrement BTN0 counter
brne LED_TOGGLE_EXIT ; if counter is not zero then exit
ser TMP_1
eor LED_DISABLED,TMP_1 ; else toggle LED
ldi LED_STATE,0x01 ; set initial value
LED_TOGGLE_EXIT:
ret

;***** Timer/Counter 0
TIM0_INIT:
clr r16
out TCNT0,r16
ldi r16,(1<<CS02)|(1<<CS00) ; frequency clk0/1024
out TCCR0,r16 ; set timer control register
ldi r16,(1<<TOIE0) ; enable timer overflow interrupt
out TIMSK,r16 ; set timer interrupt mask
ret

TIM0_OVF:
;rcall WRITE_NAME_1
mov TMP_2,LED_STATE
or TMP_2,LED_DISABLED ; Apply disable mask
out PORTB,TMP_2 ; Update LEDS
lsl LED_STATE ; shift LED state
in TMP_2,SREG
sbrc TMP_2,SREG_C ; if carry flag is set
ldi LED_STATE,0x01 ; then set initial value
reti

;***** USART
USART_INIT:
; set baud rate
ldi TMP_1,LOW(UBRR)
out UBRRL,TMP_1
ldi TMP_1,HIGH(UBRR)
out UBRRH,TMP_1
; Enable receiver and transmitter
ldi TMP_1, (1<<RXCIE)|(1<<TXCIE)|(1<<RXEN)|(1<<TXEN)
out UCSRB,TMP_1
; Set frame format: 8data, 1stop bit
ldi TMP_1, (1<<URSEL)|(3<<UCSZ0)
out UCSRC,TMP_1
ret

USART_RXC:
reti

USART_TXC:
reti

USART_TRANSMIT:
; Wait for empty transmit buffer
sbis UCSRA,UDRE
rjmp USART_TRANSMIT
; Put data into buffer, sends the data
out UDR,TMP_2
ret

WRITE_NAME_1:
;Raspopov - 52 61 73 70 6f 70 6f 76
;space - 20
;crlf - 0D 0A
ldi TMP_2,0x52
rcall USART_TRANSMIT
ldi TMP_2,0x61
rcall USART_TRANSMIT
ldi TMP_2,0x73
rcall USART_TRANSMIT
ldi TMP_2,0x70
rcall USART_TRANSMIT
ldi TMP_2,0x6f
rcall USART_TRANSMIT
ldi TMP_2,0x70
rcall USART_TRANSMIT
ldi TMP_2,0x6f
rcall USART_TRANSMIT
ldi TMP_2,0x76
rcall USART_TRANSMIT
ldi TMP_2,0x20
rcall USART_TRANSMIT
mov TMP_2,LED_STATE
rcall USART_TRANSMIT
ldi TMP_2,0x0d
rcall USART_TRANSMIT
ldi TMP_2,0x0a
rcall USART_TRANSMIT
ret
