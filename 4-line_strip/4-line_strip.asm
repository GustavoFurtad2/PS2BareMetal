; Based on naken_assembler
; Original author: Michael Kohn
;  Email: mike@mikekohn.net
;   Web: https://www.mikekohn.net/
;  License: GPLv3;
; Original code: https://github.com/mikeakohn/naken_asm/blob/master/samples/playstation2/triangle.asm
; 
;
; Modified version
; Author: Gustavo Furtado
;  Email: gustav0furt.fatality@gmail.com
;
; Copyright (C) 2025 Gustavo Furtado
;
; Changes Made:
;  - Change background color
;  - Change giftag to draw a line strip
;  - Change the name of some labels

.ps2_ee

.include "playstation2/registers_ee.inc"
.include "playstation2/registers_gs_gp.inc"
.include "playstation2/registers_gs_priv.inc" 
.include "playstation2/system_calls.inc"
.include "playstation2/macros.inc"

.entry_point start

.export start
.export installVsyncHandler
.export interruptVsync
.export vsyncCount
.export vsyncID

.org 0x100000

start:

    li $sp, 0x02000000

    jal dmaReset 

    nop

    li $v1, GS_CSR
    li $v0, 0x200
    sd $v0, ($v1)

    li $v1, _GsPutIMR
    li $a0, 0xff00

    syscall
    nop

    li $v1, _SetGsCrt
    li $a0, 1
    li $a1, 2
    li $a2, 0

    syscall
    nop

    li $v1, GS_PMODE
    li $v0, 0xff62
    sd $v0, ($v1)

    li $v1, GS_DISPFB2
    li $v0, 0x1400
    sd $v0, ($v1)

    li $v1, GS_DISPLAY2
    li $at, 0x1bf_9ff
    dsll32 $at, $at, 0

    li $v0, 0x0182_4290
    or $at, $at, $v0
    sd $at, ($v1)

while1:

    jal drawScreen
    nop

    li $v1, GS_CSR
    li $v0, 8
    sw $v0, ($v1)

vsyncWait:

    lw $v0, ($v1)
    andi $v0, $v0, 8
    beqz $v0, vsyncWait
    nop
    b while1
    nop

drawScreen:

    move $s3, $ra

    jal dma02Wait

    li $v0, D2_CHCR
    li $v1, purpleScreen
    sw $v1, 0x10($v0)
    li $v1, 0x101
    sw $v1, ($v0)

    jal dma02Wait
    nop

    li $v0, D2_CHCR
    li $v1, drawSprite
    sw $v1, 0x10($v0)
    li $v1, (drawSpriteEnd - drawSprite) / 16
    sw $v1, 0x20($v0)

    li $v1, 0x101
    sw $v1, ($v0)
    jal dma02Wait
    nop

    move $ra, $s3
    jr $ra
    nop

installVsyncHandler:

    di

    li $v1, _AddIntcHandler
    li $a0, INTC_VBLANK_E
    li $a1, interruptVsync
    li $a2, 0

    syscall
    nop

    li $v1, vsyncID
    sw $v0, ($v1)

    li $v1, __EnableIntc
    li $a0, INTC_VBLANK_E
    syscall 
    nop

    li $v1, vsyncCount
    li $v0, 0xff
    sw $v0, ($v1)

    ei
    jr $ra
    nop

interruptVsync:

    li $s1, vsyncCount
    lw $s0, ($s1)
    addi $s0, $s0, 1
    sw $s0, ($s1)

    li $s1, GS_CSR
    li $s0, 8
    sw $s0, ($s1)

    jr $ra
    nop 

dmaReset:

    li $s0, D2_CHCR
    sw $zero, 0x00($s0)
    sw $zero, 0x30($s0)
    sw $zero, 0x10($s0)
    sw $zero, 0x50($s0)
    sw $zero, 0x40($s0)

    li $s0, D_CTRL

    li $s1, 0xff1f

    sw $s1, 0x10($s0)
    sw $zero, 0x00($s0)
    sw $zero, 0x20($s0)
    sw $zero, 0x30($s0)
    sw $zero, 0x50($s0)
    sw $zero, 0x40($s0)

    lw $s1, 0x00($s0)
    ori $s1, $s1, 1
    nop
    sw $s1, 0x00($s0)
    nop

    jr $ra 
    nop

dma02Wait:

    li $s1, D2_CHCR
    lw $s0, ($s1)
    andi $s0, $s0, 0x100
    bnez $s0, dma02Wait
    nop
    jr $ra
    nop

.align 64

vsyncCount:

    dc64 0

vsyncID:

    dc64 0

.align 128

drawSprite:

    dc64 GIF_TAG(9, 1, 0, 0, FLG_PACKED, 1), REG_A_D
    
    dc64 SETREG_PRIM(PRIM_LINE_STRIP, 1, 0, 0, 0, 0, 0, 0, 0), REG_PRIM
    dc64 SETREG_RGBAQ(128, 128, 0, 0x80, 0x3f80_0000), REG_RGBAQ
    dc64 SETREG_XYZ2(2000 << 4, 2060 << 4, 128), REG_XYZ2
    dc64 SETREG_XYZ2(1900 << 4, 2100 << 4, 128), REG_XYZ2
    dc64 SETREG_XYZ2(2050 << 4, 2200 << 4, 128), REG_XYZ2
    dc64 SETREG_RGBAQ(0, 255, 0, 0x80, 0x3f80_0000), REG_RGBAQ
    dc64 SETREG_XYZ2(1950 << 4, 2250 << 4, 128), REG_XYZ2
    dc64 SETREG_RGBAQ(255, 0, 0, 0x80, 0x3f80_0000), REG_RGBAQ
    dc64 SETREG_XYZ2(2100 << 4, 2150 << 4, 128), REG_XYZ2

drawSpriteEnd:

    .align 128

purpleScreen:

    dc64 GIF_TAG(14, 1, 0, 0, FLG_PACKED, 1), REG_A_D
    dc64 0x00a0000, REG_FRAME_1
    dc64 0x8c, REG_ZBUF_1
    dc64 SETREG_XYOFFSET(1728 << 4, 1936 << 4), REG_XYOFFSET_1
    dc64 SETREG_SCISSOR(0, 639, 0, 447), REG_SCISSOR_1
    dc64 1, REG_PRMODECONT
    dc64 1, REG_COLCLAMP
    dc64 0, REG_DTHE
    dc64 0x70000, REG_TEST_1
    dc64 0x30000, REG_TEST_1
    dc64 PRIM_SPRITE, REG_PRIM
    dc64 0x0000_0000_0060_0074, REG_RGBAQ
    dc64 SETREG_XYZ2(1728 << 4, 1936 << 4, 0), REG_XYZ2
    dc64 SETREG_XYZ2(2368 << 4, 2384 << 4, 0), REG_XYZ2
    dc64 0x70000, REG_TEST_1

purpleScreenEnd: