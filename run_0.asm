.include "m8515def.inc"
.def TMP_1 =r16 ; Temp var 1
.def TMP_2 =r17 ; Temp var 2
.def LED_DISABLED = r18 ; LED disabled flag
.def LED_STATE = r19 ; State of LEDs
.def BTN0_CNTR = r20 ; 0 button counter
.def BTN1_CNTR = r21 ; 1 button counter
.def BTN2_CNTR = r22 ; 2 button counter
.def TC0_CMP_CNTR = r23 ; timer 0 compare counter
.def NAME_ENABLED = r24 ; periodical name output flag
.def UART_RECEIVED_CHAR = r25 ; periodical name output flag

.equ F_CPU = 4000000 ; clk0 frequency
.equ BAUD_RATE = 19200 ; target bitrate
.equ UBRR = F_CPU/(16*BAUD_RATE)-1
.equ BTN_CNTR = 0xff ; initial value for button counter

; timer/counter 0 settings
; 4 MHz / 1024 => 0,256 msec
; 500 msec = 0,256 msec * 243 * 8
.equ TC0_SCALE = (1<<CS02)|(1<<CS00) ; prescale 1024
.equ TC0_OCR = 0xf3 ; 243 - compare counter value
.equ TC0_CMP_INIT = 0x08 ; 8 times by TC0_OCR

;***** Initialization
.org $000 rjmp RESET ; Reset Handler
.org $001 reti ; IRQ0 Handler
.org $002 reti ; IRQ1 Handler
.org $003 reti ; Timer1 Capture Handler
.org $004 reti ; Timer1 Compare A Handler
.org $005 reti ; Timer1 Compare B Handler
.org $006 reti ; Timer1 Overflow Handler
.org $007 reti ; Timer0 Overflow Handler
.org $008 reti ; SPI Transfer Complete Handler
.org $009 rjmp USART_RXC ; USART RX Complete Handler
.org $00a reti ; UDR0 Empty Handler
.org $00b reti ; USART TX Complete Handler
.org $00c reti ; Analog Comparator Handler
.org $00d reti ; IRQ2 Handler
.org $00e rjmp TIM0_CMP ; Timer0 Compare Handler
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
ldi TC0_CMP_CNTR,TC0_CMP_INIT

ser r16
out DDRB,r16 ; Set PORTB to output
out PORTB,LED_DISABLED ; initial state of LEDs

sei ; enable global interrupts

LOOP:
; btn0 enables LEDs
sbis PINC,PINC0 ; if pind0 button pressed
rcall LED_TOGGLE ; decrement BTN0 counter
sbic PINC,PINC0 ; if pind0 button released
ldi BTN0_CNTR,BTN_CNTR ; reset button counter
; btn1 writes name
sbis PINC,PINC1
rcall BTN_WRITE_NAME_1
sbic PINC,PINC1
ldi BTN1_CNTR,BTN_CNTR
; btn2 enables name periodical name output
sbis PINC,PINC2
rcall WRITE_NAME_2_TOGGLE
sbic PINC,PINC2
ldi BTN2_CNTR,BTN_CNTR
rjmp LOOP ;

LED_TOGGLE:
clr TMP_1
cp BTN0_CNTR,TMP_1 ; if counter is zero
breq LED_TOGGLE_EXIT ; then exit
dec BTN0_CNTR ; decrement button counter
brne LED_TOGGLE_EXIT ; if counter is not zero then exit
ser TMP_1
eor LED_DISABLED,TMP_1 ; else toggle LED
ldi LED_STATE,0x01 ; set initial value
LED_TOGGLE_EXIT:
ret

WRITE_NAME_2_TOGGLE:
clr TMP_1
cp BTN2_CNTR,TMP_1 ; if counter is zero
breq WRITE_NAME_2_TOGGLE_EXIT ; then exit
dec BTN2_CNTR ; decrement button counter
brne WRITE_NAME_2_TOGGLE_EXIT ; if counter is not zero then exit
ldi TMP_1,0x01
eor NAME_ENABLED,TMP_1 ; else toggle flag
WRITE_NAME_2_TOGGLE_EXIT:
ret

;***** Timer/Counter 0
TIM0_INIT:
clr TMP_1
out TCNT0,TMP_1
ldi TMP_1,(1<<WGM01)|TC0_SCALE ; CTC mode, prescaler 1024
out TCCR0,TMP_1 ; set timer control register
ldi TMP_1,TC0_OCR 
out OCR0,TMP_1
ldi TMP_1,(1<<OCIE0) ; enable timer compare interrupt
out TIMSK,TMP_1 ; set timer interrupt mask
ret

TIM0_CMP:
dec TC0_CMP_CNTR ; decrement timer 0 counter
brne TIM0_CMP_EXIT ; if counter is not zero then exit
ldi TC0_CMP_CNTR,TC0_CMP_INIT ; else reset counter
; Update LEDs
mov TMP_2,LED_STATE
or TMP_2,LED_DISABLED ; Apply LED disable mask
out PORTB,TMP_2 ; Update LEDS
lsl LED_STATE ; shift LED state
in TMP_2,SREG
sbrc TMP_2,SREG_C ; if carry flag is set
ldi LED_STATE,0x01 ; then set initial value
; Write name 2
sbrc NAME_ENABLED,0x00
rcall TRANSMIT_NAME_2
TIM0_CMP_EXIT:
reti

;***** USART
USART_INIT:
; set baud rate
ldi TMP_1,LOW(UBRR)
out UBRRL,TMP_1
ldi TMP_1,HIGH(UBRR)
out UBRRH,TMP_1
; Enable receiver and transmitter
ldi TMP_1, (1<<RXCIE)|(1<<RXEN)|(1<<TXEN)
out UCSRB,TMP_1
; Set frame format: 8data, 1stop bit
ldi TMP_1, (1<<URSEL)|(3<<UCSZ0)
out UCSRC,TMP_1
ret

USART_RXC:
in UART_RECEIVED_CHAR,UDR
; if char is 'Y'
cpi UART_RECEIVED_CHAR,'Y'; compare received character with'Y'
in TMP_2,SREG
sbrc TMP_2,SREG_Z ; if zero flag is set (char is 'Y')
rcall TRANSMIT_NAME_1 ; then write name
; if char is 'P'
cpi UART_RECEIVED_CHAR,'P'; compare received character with'P'
in TMP_2,SREG
ldi TMP_1,0x01
sbrc TMP_2,SREG_Z ; if zero flag is set (char is 'P')
eor NAME_ENABLED,TMP_1 ; then toggle name flag
reti

USART_TRANSMIT:
; Wait for empty transmit buffer
sbis UCSRA,UDRE
rjmp USART_TRANSMIT
; Put data into buffer, sends the data
out UDR,TMP_2
ret

BTN_WRITE_NAME_1:
clr TMP_1
cp BTN1_CNTR,TMP_1 ; if counter is zero
breq BTN_WRITE_NAME_1_EXIT ; then exit
dec BTN1_CNTR ; decrement button counter
brne BTN_WRITE_NAME_1_EXIT ; if counter is not zero then exit
rcall TRANSMIT_NAME_1
BTN_WRITE_NAME_1_EXIT:
ret

TRANSMIT_NAME_1:
ldi	ZL,LOW(2*NAME_1)		; load Z pointer with
ldi	ZH,HIGH(2*NAME_1)		; string address
rcall TRANSMIT				; transmit string
ret

TRANSMIT_NAME_2:
ldi	ZL,LOW(2*NAME_2)		; load Z pointer with
ldi	ZH,HIGH(2*NAME_2)		; string address
rcall TRANSMIT				; transmit string
ret

TRANSMIT:	
lpm	TMP_2,Z+ ; load character from pmem
cpi	TMP_2,$00 ; check if null
breq TRANSMIT_END ; branch if null
TRANSMIT_WAIT:
sbis UCSRA,UDRE
rjmp TRANSMIT_WAIT ; Wait for empty transmit buffer
out	UDR,TMP_2 ; transmit character
rjmp TRANSMIT ; repeat loop
TRANSMIT_END:
ret

NAME_1:	.db	"Raspopov",0x0d,0x0a,$00
NAME_2:	.db	"Plyashenko",0x0d,0x0a,$00
