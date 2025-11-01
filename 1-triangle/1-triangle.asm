.ps2_ee ; this directive let the assembler know which CPU this source file is assembled for

.include "playstation2/registers_ee.inc" ; this is an include file provided by naken_asm which gave to us the EE Registers
.include "playstation2/registers_gs_gp.inc" ; this is an include file provided by naken_asm which gave to us the GS General Registers
.include "playstation2/registers_gs_priv.inc" ; this is an include file provided by naken_asm which gave to us the GS Privileged Registers
.include "playstation2/system_calls.inc" ; this is an include file provided by naken_asm which gave to us the system calls
.include "playstation2/macros.inc" ; this is an include file provided by naken_asm which gave to us macros for GIF

.entry_point start ; defines start as a entry point

.export start
.export installVsyncHandler
.export interruptVsync
.export vsyncCount
.export vsyncID

.org 0x100000 ; defines that the code starts at 0x100000 in the EE memory

start:

    ; li pseudo-instruction -> li (load immediate) loads an immediate value into a register
    li $sp, 0x02000000 ; set the sp(stack pointer) register at adress 0x02000000 (principal RAM region)

    ; jal instruction -> jal (jump and link) saves the return address in the register $ra (GPR[31]), this address is PC + 8, 
    ; and diverts execution to the specified destination, allowing functions to be called and then returned with jr $ra
    jal dmaReset 
    
    ; nop instruction -> nop (no operation) the EE is pipelined, so some instructions take an extra cycle to update registers or complete jumps, 
    ; after jal the return address is stored in the $ra register, but in the next cycle, the pipeline may still be reading $ra, 
    ; the nop prevents you from using $ra before the correct value is updated
    nop

    ; $v1 i'll use as a temporary register, let's write the GS privileged register, 
    li $v1, GS_CSR
    ; $v0 i'll use as a temporary register, let's write 0x200,
    ; this value enables and disables specific functions of the status controller (such as resetting interrupts or enabling DMA)
    li $v0, 0x200
    ; let's then write the value of $v0(0x200) to the address of the register $v1(GS_CSR)
    sd $v0, ($v1)

    ; loads the value of the GsPutIMR syscall into register $v1
    li $v1, _GsPutIMR
    ; loads 0xff00 into register $a0 which is argument 0 (or first argument) for a function, then in this argument we pass to the IMR register (Interrupt Mask Register) the value of 0xff00 disables all GS interrupts
    li $a0, 0xff00 ; (1111111100000000)

    ; now let's call this system call
    syscall
    nop

    ; loads the value of the SetGsCrt syscall into register $v1
    li $v1, _SetGsCrt
    ; let's load 3 arguments: 1, 2, 0
    ; t
    li $a0, 1 ; interlace
    li $a1, 2 ; video mode
    li $a2, 0 ; frame mode

    syscall
    nop

    ; let's write the GS_PMODE privileged register, GS_PMODE config settings for the PCRTC
    li $v1, GS_PMODE
    ; with this configuration, the video will be rendered taking the output from Read Circuit 2, with alpha fixed at maximum, and without mixing with the background color
    li $v0, 0xff62 ; in binary this value is 1111111101100010
    ; let's then write the value of $v0(0xff62) to the adress of the register $v1(GS_PMODE)
    sd $v0, ($v1)

    ; the GS renders in the memory area called framebuffer, but the PCRTC (video controller) needs to know where in the VRAM to read the pixels to send to the video cable (TV output), this register does just that
    li $v1, GS_DISPFB2
    ; with this configuration, says that PCRTC will start reading the framebuffer at VRAM position 0x1400. 
    ; The PS2 divides VRAM into 64-byte blocks (each PCRTC addressing unit is a multiple of 64 bytes),
    ; so the framebuffer address needs to be aligned with these blocks. This ensures that the video is read correctly,
    ; prevents memory corruption, and allows for techniques like double buffering.
    li $v0, 0x1400 ; in binary this value is 1010000000000
    ; let's then write the value of $v0(0x1400) to the adress of the register $v1(GS_DISPFB2)
    sd $v0, ($v1)

    ; the DISPLAY2 register controls the area of ​​the screen that will be displayed by PCRTC 2 (used in video setups with the GS)
    li $v1, GS_DISPLAY2
    ; in this part we will use 64 bits, first we will load the high part (bits 63-32)
    ; this part sets the DH(Display height) being 0x1BF which is 447 in decimal,
    ; the DW(Display width) being 0x9FF which is 2559 in decimal, (the real height is these two numbers + 1),
    ; so the width is 2560 VCK units(video clock units), and height 448 pixels
    ; $at is also a temporary register
    li $at, 0x1bf_9ff ; in binary this value is 110111111100111111111
    ; let's shift 32 bits to the left, so it will be 0x1BF9FF00_00000000
    dsll32 $at, $at, 0
    ; now the low part (bits 31-0)
    ; this part sets DX (Display X position) being 0x290 which is in decimal 656 (in VCK units), that is, the window starts at horizontal position 656
    ; sets the DY (Display Y position), being 0x182 which in decimal is 386 (in raster units, the window starts at vertical position 386
    ; set the MAGH (magnification H), being 0x4 which in decimal is 4, the image will be enlarged 4 times horizontally
    ; set the MAGV (magnification V), being 0x0 which in decimal is 0, the image maintains the original size vertically
    li $v0, 0x0182_4290
    ; let's use an OR to combine the two pieces of information
    or $at, $at, $v0
    ; now let's save this double world $at(0x1BF9FF00_01824290) at the address of register $v1(GS_DISPLAY2)
    sd $at, ($v1)

while1:

    ; draw picture
    jal drawScreen
    nop

    ; let's load the GS_CSR register
    li $v1, GS_CSR
    ; activate bit 3, which will activate VSINT (VSync Interrupt Control)
    li $v0, 8
    ; so let's write it in GS_CSR
    sw $v0, ($v1)

vsyncWait:

    ; let's load the value of GS_CSR into $v0
    lw $v0, ($v1)
    ; let's clear the other bits, but we will keep the value of bit 3
    andi $v0, $v0, 8
    ; if $v0 is equal to 0 it returns to vsyncWait, so if the VSINT bit is not set, it will continue waiting
    beqz $v0, vsyncWait
    nop
    ; let's jump to while1
    b while1
    nop

drawScreen:

    ; copies the value of $ra to $s3
    move $s3, $ra

    ; jump to dma02Wait
    jal dma02Wait

    ; let's load D2_CHCR
    li $v0, D2_CHCR
    ; let's load the address where the data packet is
    li $v1, redScreen
    ; let's save into MADR
    sw $v1, 0x10($v0)
    ; let's load 100000001, so then I activate the STR flag to start the transfer, and I also set the direction flag to 1, to then transfer from RAM to GIF
    li $v1, 0x101
    ; then I will write 0x101 in D2_CHCR
    sw $v1, ($v0)

    jal dma02Wait
    nop

    ; le'ts load D2_CHCR
    li $v0, D2_CHCR
    ; let's load the adress wherethe data packet is
    li $v1, drawTriangle
    ; let's save into MADR
    sw $v1, 0x10($v0)
    ; let's calculate the size of the data in quadwords being 16 bytes each, so drawTriangleEnd - drawTriangle is the total size in bytes, then divide 16 to convert to quadwords
    li $v1, (drawTriangleEnd - drawTriangle) / 16
    ; stores in QWC (quadword count)
    sw $v1, 0x20($v0)

    ; just as I did previously a few lines above, I will start the DMA transfer
    li $v1, 0x101
    sw $v1, ($v0)
    jal dma02Wait
    nop

    ; we had previously moved $ra so as not to lose this information, now we can go back to the $ra register and then return
    move $ra, $s3
    jr $ra
    nop

installVsyncHandler:

    ; the di(disable interrupts) instruction temporarily disables interrupts, preventing race conditions during handler installation
    di

    ; loads AddIntCHandler syscall code into $v1
    li $v1, _AddIntcHandler
    ; VBlank end interrupt (end of vertical blanking period)
    li $a0, INTC_VBLANK_E
    ; address of the handler function, this will be the function that will be executed when VSync occurs
    li $a1, interruptVsync
    li $a2, 0

    syscall
    nop

    ; the previous syscall returned an ID in $v0, the vsyncID is a global variable that will store this ID, the ID is necessary to later remove this handler
    li $v1, vsyncID
    sw $v0, ($v1)

    ; loads EnableIntc syscall code into $v1, which enables the bit indicated in the INTC_MASK register
    li $v1, __EnableIntc
    ; is the bit number corresponding to VBlank
    ; will return true if the bit was at 0 and was enabled, and false if the bit was already at 1 (already enabled)
    li $a0, INTC_VBLANK_E
    ; INTC_MASK works so that when it is 0 it is masked, and 1 in the case of interrupt enabled, it can be triggered
    ; hardware can now generate VBlank interrupts
    syscall 
    nop

    ; mow let's finish installing the VSync handler and return from the function
    li $v1, vsyncCount
    ; let's initialize vsyncCount to 255
    li $v0, 0xff
    sw $v0, ($v1)

    ; let's re-enable outages globally
    ei
    ; now let's go back
    jr $ra
    nop

; this is the VSync interrupt handler that is automatically executed by the hardware every frame
interruptVsync:

    ; loads the vsyncCount address into $v0
    li $s1, vsyncCount
    ; read the current value of vsyncCount for $s0
    lw $s0, ($s1)
    ; increment the counter
    addi $s0, $s0, 1
    sw $s0, ($s1)

    ; loads the address of GS_CSR into $v1
    li $s1, GS_CSR
    ; loads the value to modify bit 3, that is, VSINT
    li $s0, 8
    sw $s0, ($s1)

    ; now let's return
    jr $ra
    nop 

dmaReset: ; this function resets the DMA channels, preparing the PS2 to send commands to the GS without problems

    ; let's load the value of D2_CHCR into register $s0, $s0 is a preserved general-purpose register.
    ; In MIPS, $s0 to $s7 are "saved registers," meaning the value is preserved between functions.
    ; D2_CHCR represents the address of the CHCR(channel control register) for DMA channel 2. So now $s0 contains the value of D2_CHCR

    ; The PS2 has 7 main DMA channels numbered 0 through 9
    ; since we are using D2_CHCR, this means that what we are loading belongs to channel 2 which is the GIF

    li $s0, D2_CHCR

    ; sw instruction -> sw (store word), sw stores a word, where a word is 32 bits of EE in memory, 
    ; first you will give the register with the data you want to save, our register in this case is $zero,
    ; inside the parentheses it contains the base address in memory where this will happen, which in this case is $ s0,
    ; before the parentheses we have 0x00 which will be a constant value that will be added to the base address 0x00 to form the final address, that is, an offset

    ; let's write 0 to the DMA2 channel control register for any transfer in progress, to then reset the registers
    sw $zero, 0x00($s0)

    ; reset the TADR (tag address register) which is the address of the next DMA tag
    sw $zero, 0x30($s0)

    ; reset the MADR (memory address register) which will be the memory address of the packet to be sent
    sw $zero, 0x10($s0)

    ; reset ASR1 (tag address save register) which is the DMA address stack
    sw $zero, 0x50($s0)

    ; reset ASR0 (tag address save register) which is the DMA address stack
    sw $zero, 0x40($s0)

    ; now let's prepare the global DMA controller
    ; $s0 receives the address of the DMA global control register (D_CTRL)
    li $s0, D_CTRL

    ; we will save in $s1 the value of 0xff1f, which is a fixed value that configures the default modes of the DMA controller (priority bits, etc.)

    ; $s1 receives, 0xff1f a value used to reset the DMA status register and enable
    ; all DMA channels with default settings
    li $s1, 0xff1f

    ; store the value of $s1 (0xff1f) at the adress $s0 + 0x10
    ; the offset 0x10 points to the DMA_STAT register (DMA status register), which holds flags for channel status,
    ; clear old flags, and enables the DMA channels
    ; writing 0xff1f here:
    ; - clear any pending status/interrupt flags
    ; - enables all channels (including DMA2 used for GIF transfers)
    ; - sets default priority bits for the channels
    ; this prepares the DMA controller to accept new transfers safely
    sw $s1, 0x10($s0)

    ; reset DMA_CTRL to restart global DMA
    sw $zero, 0x00($s0)

    ; reset the DMA_PCR to reset old priorities and flags
    sw $zero, 0x20($s0)

    ; reset DMA_SQWC to clear the transfer size counters
    sw $zero, 0x30($s0)

    ; reset DMA_RBOR to clear the final address of the ring buffer
    sw $zero, 0x50($s0)

    ; reset DMA_RBSR to clear the starting address of the ring buffer
    sw $zero, 0x40($s0)

    ; $s0 contains the base address of the global DMA (D_CTRL), 0x00($s0) points to the D_CTRL register,
    ; which is the global DMA control register of the EE, so we will load the current value of D_CTRL to $s1, 
    ; for now $s1 will contain 0, because before we did sw $zero, 0x00($s0)
    ; bit 0 means DMAE(DMA enable)
    lw $s1, 0x00($s0)

    ; ori instruction -> ori (or immediate), performs a bitwise OR operation, the first $s1 is where we will store the result, 
    ; while the second $s2 is the register that will be used in the operation, finally we will compare it to an immediate 16-bit value which is 1
    ; let's do an OR to ensure that bit 0, which is DMAE, will be 1, unlike a $li, this preserves all the other bits in the register (if any bit was set before, it remains the same)
    ; 1 is written in binary, this means that only bit 0 (the least significant) is set to 1
    ; 0000 0000 0000 0000 0000 0000 0000 0001
    ;                                       ^
    ;                                     bit 0
    ; the OR compares each bit of $s1 with the immediate one: if either is 1 then the result is 1, if both are 0 then the result is 0
    ; example:
    ; $s1       = 1010 1100 ... 0000 0000
    ; immediate = 0000 0000 ... 0000 0001
    ; or result = 1010 1100 ... 0000 0001
    ; if we use 2 which would be 0x00000002 it would turn on bit 1, if we use 3 which would be 0x00000003 it would turn on bit 0 and 1 because 0x00000003 in binary would be 0011
    ori $s1, $s1, 1
    nop
    ; writes back the value to DMA_CTRL
    sw $s1, 0x00($s0)
    nop

    ; return of the subroutine, which is the address stored in $ra
    jr $ra 
    nop

dma02Wait:

    ; let's load the D2_CHCR
    li $s1, D2_CHCR
    ; read the value of D2_CHCR which has 32 bits, so we will use the lw(load word) instruction, a word on the Playstation 2 has 32 bits, so using lw
    lw $s0, ($s1)
    ; let's do the addi instruction, we will use 0x100 because its value in binary is 100000000,
    ; we want to modify bit 8 because it is the STR flag, which controls whether the DMA is stopped or operating, if it is operating it must be 1
    andi $s0, $s0, 0x100
    ; if the previous addi operation is different from 0 then it goes back to dma02Wait, 
    ; we are waiting for dma, that's why we are doing this in a loop, otherwise it will continue the code
    bnez $s0, dma02Wait
    nop
    ; back from where the jal was called
    jr $ra
    nop

; we need to align the memory to start at multiple addresses of 64 bytes
.align 64

vsyncCount:

    ; let's define a 64-bit constant as 0
    dc64 0

vsyncID:

    dc64 0

; we need to align the memory to start at multiple addresses of 128 bytes
.align 128

; our triangle packet
drawTriangle:

    ; packet header for GS, 7(NLOOP) which would be the following 7 registers, 1 being EOP(End of Packet), FLG_PACKED format packed(register + data), REG_A_D being Address Mode + Data
    dc64 GIF_TAG(7, 1, 0, 0, FLG_PACKED, 1), REG_A_D
    ; primitive configuration
    ; PRIM_STRIANGLE_STRIP being the triangle type, 1 means gourad shading enabled, other parameters would be texture, fog, etc (disabled)
    dc64 SETREG_PRIM(PRIM_TRIANGLE_STRIP, 1, 0, 0, 0, 0, 0, 0, 0), REG_PRIM
    ; vertice 1 (green), 0x80 would be alpha 128, 0x3f80_0000 would be Q = 1.0 in float (perspective)
    dc64 SETREG_RGBAQ(0, 255, 0, 0x80, 0x3f80_0000), REG_RGBAQ
    ; XYZ2 would be the coordinates, << 4 multiplied by 16 (sub-pixel precision), and 128 would be the Z-Depth
    dc64 SETREG_XYZ2(2050 << 4, 2050 << 4, 128), REG_XYZ2

    dc64 SETREG_RGBAQ(255, 0, 0, 0x80, 0x3f80_0000), REG_RGBAQ
    dc64 SETREG_XYZ2(1900 << 4, 2260 << 4, 128), REG_XYZ2

    dc64 SETREG_RGBAQ(0, 0, 255, 0x80, 0x3f80_0000), REG_RGBAQ
    dc64 SETREG_XYZ2(2200 << 4, 2260 << 4, 128), REG_XYZ2

; label that we will use to calculate the size, must be aligned as a multiple of 128 bytes
drawTriangleEnd:

    .align 128

redScreen:

    ; 14 registers
    dc64 GIF_TAG(14, 1, 0, 0, FLG_PACKED, 1), REG_A_D
    ; framebuffer base address
    dc64 0x00a0000, REG_FRAME_1
    ; z-bb configuration
    dc64 0x8c, REG_ZBUF_1
    ; screen offset
    dc64 SETREG_XYOFFSET(1728 << 4, 1936 << 4), REG_XYOFFSET_1
    ; clipping 640x448
    dc64 SETREG_SCISSOR(0, 639, 0, 447), REG_SCISSOR_1
    ; primitive context
    dc64 1, REG_PRMODECONT
    ; color clamping
    dc64 1, REG_COLCLAMP
    ; dithering off
    dc64 0, REG_DTHE
    ; z/alpha test
    dc64 0x70000, REG_TEST_1
    ; test setup
    dc64 0x30000, REG_TEST_1
    ; sprite primitive
    dc64 PRIM_SPRITE, REG_PRIM
    ; set color
    dc64 0x0000_0000_0060_0074, REG_RGBAQ
    ; top left corner
    dc64 SETREG_XYZ2(1728 << 4, 1936 << 4, 0), REG_XYZ2
    ; bottom right corner
    dc64 SETREG_XYZ2(2368 << 4, 2384 << 4, 0), REG_XYZ2
    ; restore test
    dc64 0x70000, REG_TEST_1

; label used to calculate size
redScreenEnd: