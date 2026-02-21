# MSP430 VGA Sprite Example in ASM

Exactly as it says.  Proof of concept assembly code for sprite drawing for MSP430FR2355LP development board. Could be cleaned up and optimized probably.

### Program Flow:
- Set SMCLK from 1MHz to 24MHz (max speed)
- Setup timer, PWM output for HSYNC and timer interrupt for sprite drawing and VSYNC
- Loop forever, drawing sprite

