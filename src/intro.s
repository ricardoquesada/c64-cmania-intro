;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; Commodore Mania Intro
;
; code: riq
; Some code snippets were taken from different places. Credit added in those snippets.
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; c64 helpers
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode
.include "c64.inc"                      ; c64 constants

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Imports/Exports
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.import __SPRITES_LOAD__, __SCREEN_RAM_LOAD__

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
DEBUG = 3                               ; rasterlines:1, music:2, all:3
SPRITE0_POINTER = ($3400 / 64)

INIT_MUSIC = $be00
PLAY_MUSIC = $be20

BITMAP_ADDR = $2000 + 8 * 40 * 20

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "CODE"
        sei

        lda #$35                        ; no basic, no kernal
        sta $01

        lda $dd00                       ; Vic bank 0: $0000-$3FFF
        and #$fc
        ora #3
        sta $dd00

        lda #0
        sta $d020                       ; border color
        lda #0
        sta $d021                       ; background color

        lda #%00011000                  ; no scroll, multi-color, 40-cols
        sta $d016

        lda #%00011011                  ; charset mode, default scroll-Y position, 25-rows
        sta $d011

        lda #%11001000                  ; screen ram: $3000 (%1100xxxx), charset addr: $2000 (%xxxx100x)
        sta $d018

        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda #01                         ; enable raster irq
        sta $d01a

        ldx #<irq_a                     ; setup IRQ vector
        ldy #>irq_a
        stx $fffe
        sty $ffff

        lda #$00
        sta $d012

        lda $dc0d                       ; ack possible interrupts
        lda $dd0d
        asl $d019

        lda #1                          ; second song
        jsr INIT_MUSIC

        jsr init_color_ram
        jsr init_sprites
        jsr init_bitmap

        cli

main_loop:
        lda sync_music                  ; raster triggered ?
        beq next_1

.if (::DEBUG & 2)
        inc $d020
.endif
        dec sync_music
        jsr PLAY_MUSIC
.if (::DEBUG & 2)
        dec $d020
.endif

next_1:
        lda sync_anims
        beq next_2

.if (::DEBUG & 1)
        inc $d020
.endif
        dec sync_anims
        jsr anim_sprite
        jsr anim_scroll
        jsr cycle_sine_table
.if (::DEBUG & 1)
        dec $d020
.endif

next_2:

        jmp main_loop

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_bitmap
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_bitmap
        ldx #0
        lda #0

loop:
        sta $3700,x
        sta $3800,x
        sta $3900,x
        sta $3a00,x
        sta $3b00,x
        sta $3c00,x
        sta $3d00,x
        sta $3e00,x
        sta $3f00,x
        dex
        bne loop
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_color_ram
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_color_ram
        ldx #0
loop_a:
        lda __SCREEN_RAM_LOAD__,x               ; c logo has 360 chars (9*40). Paint 360 chars
        tay
        lda c_logo_colors,y
        sta $d800,x

        lda __SCREEN_RAM_LOAD__+104,x           ; second part (256 + 104 = 360)
        tay
        lda c_logo_colors,y
        sta $d800+104,x

        dex
        bne loop_a

        ldx #0
loop_b:
        lda __SCREEN_RAM_LOAD__+9*40,x          ; maina has 360 chars (9*40), staring from char 360
        tay
        lda mania_colors,y
        sta $d800+360,x

        lda __SCREEN_RAM_LOAD__+9*40+104,x      ; second part (256 + 104 = 360)
        tay
        lda mania_colors,y
        sta $d800+360+104,x

        dex
        bne loop_b


        ldx #0
loop_c:
        lda #$10                                ; white over black
        sta __SCREEN_RAM_LOAD__+19*40,x
        lda #$b0                                ; dark gray over black
        sta __SCREEN_RAM_LOAD__+22*40,x
        inx
        cpx #(3*40)
        bne loop_c

        rts
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_sprites
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_sprites
        lda #%00000011                  ; enable sprite #0, #1
        sta VIC_SPR_ENA
        sta $d01c                       ; multi-color sprite #0,#1

        lda #0
        sta $d017                       ; double y resolution
        sta $d01d                       ; double x resolution

        lda #%00000010
        sta $d010                       ; 8-bit on for sprites x


        lda #30                        ; set x position
        sta VIC_SPR0_X
        lda #60                        ; set x position
        sta VIC_SPR1_X
        lda #208                        ; set y position
        sta VIC_SPR0_Y
        sta VIC_SPR1_Y
        lda #7                          ; set sprite color
        sta VIC_SPR0_COLOR
        sta VIC_SPR1_COLOR
        lda #SPRITE0_POINTER            ; set sprite pointers
        sta __SCREEN_RAM_LOAD__ + $3f8
        sta __SCREEN_RAM_LOAD__ + $3f9

        lda #0
        sta $d025
        lda #10
        sta $d026

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; anim_scroll
; uses $fa-$ff as temp variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc anim_scroll

        ; uses fa-ff
        lda #0
        sta $fa                         ; tmp variable

        ldx #<charset
        ldy #>charset
        stx $fc
        sty $fd                         ; pointer to charset

load_scroll_addr = * + 1
        lda scroll_text                 ; self-modifying
        cmp #$ff
        bne next
        ldx #0
        stx bit_idx
        ldx #<scroll_text
        ldy #>scroll_text
        stx load_scroll_addr
        sty load_scroll_addr+1
        lda scroll_text

next:
        clc                             ; char_idx * 8
        asl
        rol $fa
        asl
        rol $fa
        asl
        rol $fa

        tay                             ; char_def = ($fc),y
        sty $fb                         ; to be used in the bottom part of the char

        clc
        lda $fd
        adc $fa                         ; A = charset[char_idx * 8]
        sta $fd


        ; scroll top 8 bytes 
        ; YY = char rows
        ; SS = bitmap cols
        .repeat 8, YY
                lda ($fc),y
                ldx bit_idx             ; set C according to the current bit index
:               asl
                dex
                bpl :-

                php
                .repeat 34, SS
                        ; straight
                        rol BITMAP_ADDR + (36 - SS) * 8 + YY
                .endrepeat

                plp

                .repeat 34, SS
                        ; reflection
                        rol BITMAP_ADDR + 320 * 3 + (36 - SS) * 8 + (7-YY)
                .endrepeat


                iny                     ; byte of the char
        .endrepeat


        ; fetch bottom part of the char
        ; and repeat the same thing
        ; which is 1024 chars appart from the previous.
        ; so, I only have to add #4 to $fd
        clc
        lda $fd
        adc #04                         ; the same thing as adding 1024
        sta $fd

        ldy $fb                         ; restore Y from tmp variable

        ; scroll middle 8 bytes
        ; YY = char rows
        ; SS = bitmap cols
        .repeat 8, YY
                lda ($fc),y
                ldx bit_idx             ; set C according to the current bit index
:               asl
                dex
                bpl :-

                php

                .repeat 34, SS
                        rol BITMAP_ADDR + 40 * 8 + (36 - SS) * 8 + YY
                .endrepeat

                plp

                .repeat 34, SS
                        ; reflection
                        rol BITMAP_ADDR + 320 * 2 + (36 - SS) * 8 + (7-YY)
                .endrepeat
                iny                     ; byte of the char
        .endrepeat


        ldx bit_idx
        inx
        cpx #8
        bne l1

        ldx #0
        inc load_scroll_addr
        bne l1
        inc load_scroll_addr+1
l1:
        stx bit_idx

        rts

bit_idx:
        .byte 0                         ; points to the bit displayed
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; anim_sprite
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc anim_sprite
        dec delay
        bmi anim
        rts
anim:
        lda #5
        sta delay

        ldx sprite_frame_idx
        lda sprite_frame_spr0,x
        sta __SCREEN_RAM_LOAD__ + $3f8
        lda sprite_frame_spr1,x
        sta __SCREEN_RAM_LOAD__ + $3f9

        inx
        cpx #SPRITE_MAX_FRAMES
        bne :+
        ldx #0
:
        stx sprite_frame_idx
        rts

delay:
        .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; cycle_sine_table
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc cycle_sine_table
        lda sine_table
        sta sine_tmp

        ldx #0
loop:
        lda sine_table + 1,x
        sta sine_table,x
        inx
        cpx #SINE_TABLE_SIZE-1
        bne loop

        lda sine_tmp
        sta sine_table + SINE_TABLE_SIZE-1

        rts

sine_tmp: .byte 0
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq vectors
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_a
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt

        lda #14
        sta $d022
        lda #2
        sta $d023

        lda #%00011000                  ; no scroll, multi-color, 40-cols
        sta $d016

        lda #%00011011                  ; charset mode, default scroll-Y position, 25-rows
        sta $d011

        lda #%11001000                  ; screen ram: $3000 (%1100xxxx), charset addr: $2000 (%xxxx100x)
        sta $d018

        lda #(50 + 9 * 8 + 1)               ; next irq at row 9
        sta $d012

        ldx #<irq_b
        ldy #>irq_b
        stx $fffe
        sty $ffff

        inc sync_anims

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

.proc irq_b
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt

        lda #11
        sta $d022
        lda #14
        sta $d023

        lda #%11001010                  ; screen ram: $3000 (%1100xxxx) (unchanged), charset addr: $2800 (%xxxx101x)
        sta $d018

        lda #50 + 19 * 8
        sta $d012

        ldx #<irq_c
        ldy #>irq_c
        stx $fffe
        sty $ffff

        inc sync_music

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

.proc irq_c
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt

        lda #%00111011                  ; bitmap mode, default scroll-Y position, 25-rows
        sta $d011

        lda #%11001000                  ; screen ram: $3000 (%1100xxxx) (unchanged), bitmap: $2000 (%xxxx1xxx)
        sta $d018

        lda #%00001011                  ; no scroll, hires, 40-cols. x scroll: mid
        sta $d016

        lda #226
        sta $d012

        ldx #<irq_d
        ldy #>irq_a
        stx $fffe
        sty $ffff


        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

.proc irq_d
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt


        .repeat 16, YY
:               lda $d012
                cmp #(227+YY)
                bne :-
                lda sine_table + YY
                sta $d016
                sta $d020
        .endrepeat

        lda #250
        sta $d012

        ldx #<irq_a
        ldy #>irq_a
        stx $fffe
        sty $ffff


        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; global variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "MORECODE"
sync_music:        .byte 0                 ; boolean
sync_anims:        .byte 0                 ; boolean

c_logo_colors:
        .incbin "c_logo-colors.bin"
mania_colors:
        .incbin "mania-colors.bin"

sprite_frame_idx:
        .byte 0
sprite_frame_spr0:
        .byte 208, 209, 210, 209
sprite_frame_spr1:
        .byte 211, 212, 213, 212
SPRITE_MAX_FRAMES = * - sprite_frame_spr1

scroll_text:
        scrcode "                *    *    *    *    *    *    "
        scrcode " Probando scroll con reflejo... todavia le falta hacer la parte de que se mueva el aguita... ese efectito con el seno y demas"
        scrcode ". Despues se lo agrego y vemos como queda. "
        .byte $ff

sine_table:
; autogenerated table: easing_table_generator.py -s64 -m7 -aTrue -r easeInSine
.byte   0,  0,  0,  0,  0,  0,  0,  0
.byte   0,  0,  0,  0,  1,  1,  1,  1
.byte   1,  1,  1,  1,  1,  1,  2,  2
.byte   2,  2,  2,  2,  2,  2,  3,  3
.byte   3,  3,  3,  3,  3,  4,  4,  4
.byte   4,  4,  4,  4,  5,  5,  5,  5
.byte   5,  5,  5,  6,  6,  6,  6,  6
.byte   6,  6,  6,  7,  7,  7,  7,  7
; reversed
.byte   7,  7,  7,  7,  6,  6,  6,  6
.byte   6,  6,  6,  6,  5,  5,  5,  5
.byte   5,  5,  5,  4,  4,  4,  4,  4
.byte   4,  4,  3,  3,  3,  3,  3,  3
.byte   3,  2,  2,  2,  2,  2,  2,  2
.byte   2,  1,  1,  1,  1,  1,  1,  1
.byte   1,  1,  1,  0,  0,  0,  0,  0
.byte   0,  0,  0,  0,  0,  0,  0,  0
SINE_TABLE_SIZE = * - sine_table


; charset to be used for sprites here
charset:
        .incbin "font_caren_1x2-charset.bin"


.segment "SPRITES"
.incbin "sprites.bin"

.segment "SIDMUSIC"
.incbin "sanxion.sid", $7e

.segment "CHARSET_LOGO"
.incbin "c_logo-charset.bin"

.segment "CHARSET_MANIA"
.incbin "mania-charset.bin"

.segment "SCREEN_RAM"
.include "screen_ram.s"

