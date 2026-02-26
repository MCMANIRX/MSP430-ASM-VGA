; MCMANIRX 2/21/2026

;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h" ; Include device header file
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack                  ; Make stack linker segment ?known?
;-------------------------------------------------------------------------------
            .global _main
            .text                           ; Assemble to Flash memory
            .retain                         ; Ensure current section gets linked
            .retainrefs
_main
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW+WDTHOLD,&WDTCTL  ; Stop WDT

            ; Configure two FRAM waitstate as required by the device datasheet for MCLK
            ; operation at 24MHz(beyond 8MHz) _before_ configuring the clock system.
            mov.w   #FRCTLPW+NWAITS_2,&FRCTL0

XT1on       bis.b   #BIT6+BIT7,&P2SEL1      ; P2.6~P2.7: crystal pins
XT1chk      bic.w   #XT1OFFG+DCOFFG,&CSCTL7 ; Clear XT1,DCO fault flags
            bic.w   #OFIFG,&SFRIFG1         ; Clear fault flags
            bit.w   #OFIFG,&SFRIFG1         ; Test oscilator fault flag
            jnz     XT1chk                  ; If set, attempt to clear again
                                            ; If clear, continue

            bis.w   #SCG0,SR                ; Disable FLL
            bis.w   #SELREF__XT1CLK,&CSCTL3 ; Set XT1 as FLL reference source
            mov.w   #0,&CSCTL0              ; clear DCO and MOD registers
            bis.w   #DCORSEL_7,&CSCTL1      ; Clear DCO frequency select bits first
           ;; bis.w   #DCORSEL_5,&CSCTL1      ; Set DCO = 16MHz, max in FR413x
            mov.w   #FLLD_0+731,&CSCTL2     ; DCODIV = 24MHz
            nop
            nop
            nop
            bic.w   #SCG0,SR                ; Enable FLL
Unlock      mov.w   &CSCTL7,R13
            and.w   #FLLUNLOCK0|FLLUNLOCK1,R13
            jnz     Unlock                  ; Check if FLL is locked
            
            mov.w   #SELMS__DCOCLKDIV+SELA__XT1CLK,&CSCTL4


; below: small code to increment every pixel value
;=================================

  ;          mov.w   #IMG, R7
  ;          mov.w   #84, R6

;inc_loop:
         ;   inc.b   0(R7)
           ; inc.w   R7
         ;   dec     R6
         ;   jnz     inc_loop

            bis.b #BIT0, &P1DIR


            mov.w   #Mariow1, SPRITE_PTR
            
            mov.w   SPRITE_PTR, R7 ; load img into R7

            bis.b   #BIT0|BIT1|BIT2, &P6DIR ; 3-bit RGB
            bis.b   #BIT6|BIT4,&P1DIR   ; HSYNC, VSYNC out                  
            bis.b   #BIT6,&P1SEL1 ; set HSYNC to capture compare output mode (PWM)                  
            bis.b #BIT4,&P1OUT  ; VSYNC

            bic.w   #LOCKLPM5,PM5CTL0
  

            mov.w   ACTIVE, R5
            ; add.w   PORCH,  R5
            mov.w   #OUTMOD_2, &TB0CCTL1    ; setup for pwm output               
            mov.w   HSYNC_PULSE,&TB0CCR1               ; pulse period     

            bis.w   #CCIE,&TB0CCTL0 ; TBCCR0 interrupt enabled
            mov.w   R5,&TB0CCR0                        ; PWM period
            bis.w   #TBSSEL__SMCLK|MC__UP,&TB0CTL      ; use SMCLK, timer count up
            
          nop
         ;bis.w #GIE,SR ; Enter LPM3 w/ interrupt
         eint
  
          nop ; for debug
          
gfx_loop 
 
            cmp.w   CYCLE_TIME, COUNT_TIME
            jnz gfx_loop
            nop 
            mov.w #0, COUNT_TIME


            cmp.w   COUNT_FRAME, FRAMES
            jz reset_animation
            nop
            inc.b COUNT_FRAME

            jmp load_animation

reset_animation 
            mov.b #0, COUNT_FRAME

load_animation

            mov.w #Mariow1, R6
            mov.w #FRAME_CYCLE, R4
            add.w COUNT_FRAME, R4
            mov.b 0(R4), R5
            tst.w       R5
            jz skip_mult
        
mult        
        
            add.w #208,R6
            dec   R5
            jnz mult

skip_mult
          mov.w R6, SPRITE_PTR
          mov.w SPRITE_PTR, R7



          jmp gfx_loop
          ;------------------------



TIMER0_B0_ISR;    ISR for TB0CCR0
;-------------------------------------------------------------------------------
                mov.w   #0x30, R4
killcycles
                dec R4
                jnz killcycles
nop
                
            ; logic to move sprite down a little 
            cmp.w   #84, LINES
            jl zerolines
            nop

            ; skip draw if sprite already written (total image y height == drawn y height) 
            cmp.w   IMG_Y,img_dy
            jge zerolines
            nop
          

            ; blit sprite pixels to screen       
pixel_blit
            mov.b #0,&P6OUT
            mov.b   0(R7), &P6OUT
            mov.b   1(R7), &P6OUT
            mov.b   2(R7), &P6OUT
            mov.b   3(R7), &P6OUT
            mov.b   4(R7), &P6OUT
            mov.b   5(R7), &P6OUT
            mov.b   6(R7), &P6OUT
            mov.b   7(R7), &P6OUT
            mov.b   8(R7), &P6OUT
            mov.b   9(R7), &P6OUT
            mov.b   10(R7), &P6OUT
            mov.b   11(R7), &P6OUT
            mov.b   12(R7), &P6OUT         
            mov.b #0,&P6OUT            

            inc.w   LINE_HEIGHT ; increment lines of sprite pixel line written 

zerolines   ; start VSYNC    
            tst.w   &LINES
            jnz twolines   
            nop
            bic.b   #BIT4,P1OUT
            jmp exit

twolines    ; end VSYNC
            cmp.w   #2, &LINES
            jnz framelines
            nop
            bis.b   #BIT4,P1OUT
            jmp exit

framelines  ; reset draw and prepare for VSYNC
            cmp.w   FRAME_LINES, &LINES
            jnz exit
            nop
            mov.w   #0, &LINES
            mov.w   #0, &img_dy
            mov.w   SPRITE_PTR, R7
            inc.w COUNT_TIME
            jmp exit_no_inc ; exit without increment to start VSYNC on next ISR call
            
exit        
            ; increment line count 
            add.w   #1, LINES

            ; increment sprite pixel row if enough lines written 
            cmp.w   PIXEL_SCALE, LINE_HEIGHT
            jnz exit_no_inc
            nop
            
            inc.w   img_dy  
            mov.w   #0,&LINE_HEIGHT
            add.w   IMG_X, R7


            
exit_no_inc
            reti


;------------------------------------------------------------------------------
;           Data Section
;------------------------------------------------------------------------------

            .data

PIXEL_SCALE     .word 8 ; y-scale of pixels
LINE_HEIGHT     .word 0 ; keep track of lines written of pixel line
HSYNC_PULSE     .word 92 ; 96 pixels in 24MHz
ACTIVE          .word 765 ; 800 pixels in 24MHz (800/(1/24))


LINES          .word 0  ; total lines written
VSYNC_PULSE     .word 2 ; in lines
FRAME_LINES     .word 525 ; 480 video + 45 extra lines

;   scale variables
IMG_X           .word 13
IMG_Y           .word 16

img_dy          .word 0 ;track

;   image data
Mariow1
        .byte 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0
        .byte 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
        .byte 0, 0, 0, 2, 2, 2, 2, 3, 3, 2, 3, 0, 0
        .byte 0, 0, 2, 2, 3, 2, 3, 3, 3, 2, 3, 3, 3
        .byte 0, 0, 2, 2, 3, 2, 2, 3, 3, 3, 2, 3, 3
        .byte 0, 0, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2
        .byte 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 0
        .byte 0, 2, 2, 2, 2, 2, 1, 1, 2, 2, 0, 0, 0
        .byte 3, 3, 2, 2, 2, 2, 1, 1, 1, 2, 2, 2, 3
        .byte 3, 3, 3, 2, 2, 2, 1, 3, 1, 1, 1, 2, 2
        .byte 3, 3, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 2
        .byte 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2
        .byte 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2
        .byte 2, 2, 2, 1, 1, 1, 0, 0, 1, 1, 1, 1, 2
        .byte 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0

Mariow2
        .byte 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0
        .byte 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0
        .byte 0, 0, 2, 2, 2, 2, 3, 3, 2, 3, 0, 0, 0
        .byte 0, 2, 2, 3, 2, 3, 3, 3, 2, 3, 3, 3, 0
        .byte 0, 2, 2, 3, 2, 2, 3, 3, 3, 2, 3, 3, 3
        .byte 0, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2, 0
        .byte 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0
        .byte 0, 0, 2, 2, 2, 1, 2, 2, 2, 0, 0, 0, 0
        .byte 0, 2, 2, 2, 2, 2, 1, 1, 2, 2, 0, 0, 0
        .byte 0, 2, 2, 2, 2, 1, 1, 3, 1, 1, 3, 0, 0
        .byte 0, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 0, 0
        .byte 0, 1, 1, 2, 2, 3, 3, 3, 1, 1, 1, 0, 0
        .byte 0, 0, 1, 1, 2, 3, 3, 1, 1, 1, 0, 0, 0
        .byte 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 0, 0, 0
        .byte 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0
        .byte 0, 0, 0, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0

Mariow3
        .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0
        .byte 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
        .byte 0, 0, 0, 2, 2, 2, 2, 3, 3, 2, 3, 0, 0
        .byte 0, 0, 2, 2, 3, 2, 3, 3, 3, 2, 3, 3, 3
        .byte 0, 0, 2, 2, 3, 2, 2, 3, 3, 3, 2, 3, 3
        .byte 0, 0, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2
        .byte 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 0
        .byte 0, 0, 0, 2, 2, 2, 2, 2, 1, 2, 3, 3, 0
        .byte 0, 0, 3, 3, 2, 2, 2, 2, 2, 2, 3, 3, 3
        .byte 0, 3, 3, 3, 1, 2, 2, 2, 2, 2, 3, 3, 0
        .byte 0, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 0, 0
        .byte 0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0
        .byte 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0
        .byte 2, 2, 0, 0, 0, 2, 2, 2, 2, 0, 0, 0, 0
        .byte 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 0, 0, 0

FRAME_CYCLE   .byte 0,1,2
COUNT_FRAME .word 0
COUNT_CYCLES .word 0

FRAMES .word 2
CYCLE_TIME    .word 0x4
COUNT_TIME    .word 0


        .bss  SPRITE_PTR, 2


;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR                        ; MSP430 RESET Vector
            .short  RESET                               
            .sect   TIMER0_B0_VECTOR                    ; Timer_B0 Vector
            .short  TIMER0_B0_ISR                             
            .end


