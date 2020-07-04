;##################################################################################################
;# Super Mario Maker 2's P-Balloon
;# by lx5
;# 
;# A P-Balloon powerup inspired by Super Mario Maker 2's variant in its Super Mario World style.
;# It recreates the controls and behavior of the SMM2's one and it's contained in a single sprite.
;#
;# NOTES:
;# - THIS SPRITE ONLY WORKS ON SA-1.
;# - This sprite doesn't work with slopes! Mario goes through them.
;# - It fails to detect moving layer 2 and layer 3 smashers as well.
;# - It doesn't work with solid sprites, however, it does work with platforms passable from below.
;# - Mario is able to carry sprite while in this form. It allows some interesting situations so I
;#   didn't bother fixing that.
;# - Mario is NOT able to carry the powerup to another level or sublevel. The sprite will despawn
;#   the very moment Mario is not under the player's control.
;# - The sprite makes use of SA-1's Background Mode in order to rotate its graphics and uses
;#   4 Character Conversion DMA slots. Probably no one will have issues with this.
;# - If you want to create graphics for the Inflated Mario, you have to create an image and rip
;#   each frame separately with SNESGFX with the 4bpp Linear option selected.

;################################################
;# Customization

;#######################
;# Constants

!max_slow_speed 	= $08			; Maximum speed when using ONLY the D-Pad
!max_fast_speed 	= $24			; Maximum speed when using ABXY
!fast_acceleration	= $02			; Acceleration when using ABXY
						; Not every number grants optimal results
						; Stick to the ones that can divide !max_fast_speed
						; without leaving a remainder.

!sfx_fast		= $06			; SFX that will play when using ABXY
!bank_fast		= $1DF9			; Port for the SFX above
			
!item_tile		= $E4			; Top left tile where the P-Balloon item is located.
!mario_tile		= $C0			; Top left tile where Mario's inflated tiles will
						; be uploaded to.
						; YXPPCCCT properties are handled by the .json file
						; The item and Mario shares the same properties!

!vram_dest	= $7000|(!mario_tile<<4)	; It may not be a good idea to change this one
						; VRAM destination for the inflated player graphics
						; It's automagically calculated.

;#######################
;# RAM definitions
						
!update_graphics	= $31EE			; Flag used to only run ONCE per frame the GFX
						; rotation routine via Background Mode.

!speed			= $6003			; Contains the current magnitude of the total speed.
!scale			= $6001			; Controls the size of the inflated Mario.
						; Range: $0000-$7FFF, $0100 = 100%
!angle			= $6000			; Current angle, it's shifted 90°.
!previous_angle		= $6004			; Previous angle.
!processed_angle	= $6005			; Angle being processed. Used by the smoke particles.
!in_balloon		= $6006			; Balloon state.
!balloon_grab		= $6007			; Has a ballon been grabbed in the level.

!dest_bwram		= $402000		; It may not be a good idea to change this one
!dest_virtual_ram	= $604000		; It may not be a good idea to change this one

!source_bwram		= $402400		; It may not be a good idea to change this one
						; Requires 0xC00 consecutive bytes in BW-RAM
	
;##################################################################################################
;# Init code

print "INIT ",pc
	lda !balloon_grab
	beq +
	lda $0100|!addr
	cmp #$14
	beq +
+	
	stz !in_balloon
+	
	phb
	phk
	plb
	
	lda.b #!source_bwram
	sta $00
	lda.b #!source_bwram>>8
	sta $01
	ldx #$00
	rep #$20
.decompress_frames
	ldy.b #%11000100
	sty $2230
	lda.w .frames,x
	sta $2232
	lda.w .frames+1,x
	sta $2233
	lda #$0400
	sta $2238
	lda $00
	sta $2235
	clc
	adc #$0400
	sta $00
	ldy.b #!source_bwram>>16
	sty $2237
..wait	
	ldy $318C
	beq ..wait
	ldy #$00
	sty $318C
	sty $2230
	inx #3
	cpx #$07
	bcc .decompress_frames

	sep #$20
	ldx $15E9|!addr
	plb
	rtl

.frames
	dl p_balloon_idle_gfx
	dl p_balloon_slow_gfx
	dl p_balloon_fast_gfx

;##################################################################################################
;# Main code

print "MAIN ",pc
	phb
	phk
	plb
	lda !157C,x
	bne .in_balloon
	lda #$00
	%SubOffScreen()
	jsr item_main
	plb
	rtl
	
.in_balloon
	jsr p_balloon_main
	lda $71
	beq ..skip
	stz !14C8,x
	stz $318B
	stz !balloon_grab
	stz !in_balloon
..skip	
	plb
	rtl

;################################################
;# Main routine for the item state.

item_main:
	jsr .graphics
.float_movement
	inc !151C,x
	lda !151C,x
	lsr #3
	and #$07
	tay
	lda.w .wave,y
	sta !AA,x
	stz !B6,x
	jsl $01801A
	jsl $018022
	
	jsl $01A7DC
	bcc .no_contact
	lda #$1E
	sta $1DF9|!addr
	lda !in_balloon
	bne .inflated_mario_exists
	lda #$01
	sta !in_balloon
	sta !balloon_grab
	sta !157C,x
	stz !angle
	stz !speed
	stz !previous_angle
	stz !scale
	stz !scale+1
	lda #$01
	sta $19
	lda !E4,x
	sec
	sbc #$08
	sta !E4,x
	lda !14E0,x
	sbc #$00
	sta !14E0,x
	lda !D8,x
	sec
	sbc #$10
	sta !D8,x
	lda !14D4,x
	sbc #$00
	sta !14D4,x
	jsr mario_movements_setup_mario
.no_contact
	rts
.inflated_mario_exists
	stz !14C8,x
	rts

.wave	
	db $00,$03,$08,$03,$00,$FD,$F8,$FD

.graphics
	%GetDrawInfo()
	lda $00
	sta $0300|!addr,y
	lda $01
	sta $0301|!addr,y
	lda #!item_tile
	sta $0302|!addr,y
	lda !15F6,x
	ora $64
	sta $0303|!addr,y
	ldy #$02
	lda #$00
	jsl $01B7B3
	rts

;################################################
;#  Main routine for the Inflated state.

	%CircleX()
	%CircleY()
	%Aiming()

p_balloon_main:
	jsr mario_graphics
	lda $9D
	bne +
	jsr mario_movements
+	
	rts
	
rotation_angle:
	dw $0100		;no
	dw $0040		;right
	dw $00C0		;left
	dw $0100		;left+right
	dw $0080		;down
	dw $0060		;down+right
	dw $00A0		;down+left
	dw $0080		;down+left+right
	dw $0000		;up
	dw $0020		;up+right
	dw $00E0		;up+left
	dw $0000		;up+left+right
	dw $0100		;up+down
	dw $0100		;up+down+right
	dw $0100		;up+down+left
	dw $0100		;up+down+left+right


zoom_vals:
	dw $0100
	dw $0107
	dw $0110
	dw $0107
	dw $0100
	dw $00F9
	dw $00F0
	dw $00F9

mario_movements:
.rotate_balloon
	phx
	lda $15
	and #$0F
	asl
	tay
	lda.w rotation_angle+1,y
	and #$01
	bne ..skip
	ldx #$04
	lda !angle
	cmp.w rotation_angle,y
	beq ..skip
	sec
	sbc.w rotation_angle,y
	bmi +
	ldx #$FC
+	
	txa
	clc
	adc !angle
	sta !angle
..skip	
	
	lda !speed
	cmp #!max_slow_speed+1
	bcs ..faster
	lda $15
	and #$C0
	bne ..faster
..slower
	ldx !previous_angle
	lda $15
	beq +
	lda.w rotation_angle,y
	sta !previous_angle
	tax
+	
	txa
	ldy #$20
	jsr calculate_target
	
	lda $15
	bne ...max_speed
	lda !speed
	beq ...no_dec_speed
	dec
	bra ...no_dec_speed
...max_speed
	lda.b #!max_slow_speed
...no_dec_speed
	bra ..update_speeds

..faster
	lda !angle
	ldy #$20
	jsr calculate_target
	lda $15
	and #$C0
	bne ...max_speed
	lda !speed
	beq ...no_dec_speed
	dec
	bra ...no_dec_speed
...max_speed
	lda !speed
	clc
	adc #!fast_acceleration
	cmp #!max_fast_speed
	bcc ...no_dec_speed
...force_max
	lda.b #!max_fast_speed
...no_dec_speed
	
..update_speeds
	sta !speed
	
	%Aiming()
	plx
	
	lda $00
	sta !1602,x
	lda $02
	sta !160E,x

.friction
.check_x
	lda !B6,x
	cmp !1602,x
	beq ..done
	bmi ..neg
..pos	
	dec
	dec
..neg	
	inc
..done	
	sta !B6,x
	
.check_y
	lda !AA,x
	cmp !160E,x
	beq ..done
	bmi ..neg
..pos	
	dec
	dec
..neg	
	inc
..done	
	sta !AA,x
	
.blocked
..check_right
	lda $77
	and #$01
	beq ...nope
	lda !B6,x
	beq ...nope
	bmi ...nope
	stz !B6,x
...nope
..check_left
	lda $77
	and #$02
	beq ...nope
	lda !B6,x
	bpl ...nope
	stz !B6,x
...nope	
..check_down
	lda $77
	and #$04
	beq ...nope
	lda !AA,x
	beq ...nope
	bmi ...nope
	stz !AA,x
...nope
..check_up
	lda $77
	and #$08
	beq ...nope
	lda !AA,x
	bpl ...nope
	stz !AA,x
...nope
	
	jsl $01801A
	jsl $018022
	
.setup_mario
	lda #$04
	sta $73
	lda #$FF
	sta $78
	lda !E4,x
	clc
	adc #$08
	sta $94
	lda !14E0,x
	adc #$00
	sta $95
	lda !D8,x
	sec
	sbc #$08
	sta $96
	lda !14D4,x
	sbc #$00
	sta $97
	stz $7A
	stz $7B
	stz $7D
	stz $74
	lda #$0B
	sta $72
	stz $148F|!addr
	stz $1470|!addr
	lda #$80
	sta $1406|!addr
	rts 

calculate_target:
	sta !processed_angle
	clc
	adc #$40
	asl
	sta $04
	adc #$00
	sta $05
	sty $06
	%CircleX()
	%CircleY()
	rep #$20
	lda $07
	sta $00
	lda $09
	sta $02
	sep #$20
	rts
	
mario_graphics:
	jsr .draw_inflated_player
	inc !151C,x
	lda !speed
	beq .idle_mario
	lda $15
	and #$C0
	bne .fast_mario
.slow_mario
	lda !151C,x
	lsr #3
	and #$01
	sta !update_graphics
	bra .shared_anim
.fast_mario
	lda #$02
	sta !update_graphics
	lda !151C,x
	and #$07
	bne +
	lda #!sfx_fast
	sta !bank_fast|!addr
	lda !processed_angle
	ldy #$10
	jsr calculate_target
	lda $07
	clc
	adc #$08
	sta $00
	lda $09
	clc
	adc #$08
	sta $01
	lda #$1B
	sta $02
	lda #$01
	%SpawnSmoke()
+	
	lda !151C,x
	asl
	bra .shared_anim_2
.idle_mario
	stz !update_graphics
.shared_anim
	lda !151C,x
	lsr
.shared_anim_2
	and #$0E
	tay
	rep #$20
	lda.w zoom_vals,y
	sta !scale
	sep #$20

.clear_canvas
	rep #$30
	ldx #$01FE
	lda #$0000
-	
	sta.l !dest_bwram,x
	dex #2
	bpl -
	sep #$30
	
.setup_parallel_mode
	lda.b #parallel_rotate_gfx
	sta $3186
	lda.b #parallel_rotate_gfx>>8
	sta $3187
	lda.b #parallel_rotate_gfx>>16
	sta $3188
	lda #$01
	sta $318B

.setup_cc_dma
	lda $31EF
	bne .end
	lda $317F
	cmp #$07
	beq .end
	asl #3
	tay
	lda.b #%00001001
	sta $3190,y
	sta $3190+8,y
	sta $3190+16,y
	sta $3190+24,y
	lda.b #!dest_bwram>>16
	sta $3195,y
	sta $3195+8,y
	sta $3195+16,y
	sta $3195+24,y
	rep #$20
	lda.w #!vram_dest
	sta $3191,y
	lda.w #!vram_dest+$0100
	sta $3191+8,y
	lda.w #!vram_dest+$0200
	sta $3191+16,y
	lda.w #!vram_dest+$0300
	sta $3191+24,y
	lda.w #!dest_bwram
	sta $3193,y
	lda.w #!dest_bwram+$0080
	sta $3193+8,y
	lda.w #!dest_bwram+$0100
	sta $3193+16,y
	lda.w #!dest_bwram+$0180
	sta $3193+24,y
	lda.w #$0080
	sta $3196,y
	sta $3196+8,y
	sta $3196+16,y
	sta $3196+24,y
	sep #$20
	lda $317F
	clc
	adc #$04
	sta $317F
	lda #$01
	sta $31EF
.end	
	ldx $15E9|!addr
	rts
	

.draw_inflated_player
	%GetDrawInfo()
	lda #$10
	sta !15EA,x
	tay
	lda $00
	sta $0300|!addr,y
	sta $0308|!addr,y
	clc
	adc #$10
	sta $0304|!addr,y
	sta $030C|!addr,y
	lda $01
	sta $0301|!addr,y
	sta $0305|!addr,y
	clc
	adc #$10
	sta $0309|!addr,y
	sta $030D|!addr,y
	lda.b #!mario_tile
	sta $0302|!addr,y
	lda.b #!mario_tile+2
	sta $0306|!addr,y
	lda.b #!mario_tile+$20
	sta $030A|!addr,y
	lda.b #!mario_tile+$22
	sta $030E|!addr,y
	lda !15F6,x
	ora $64
	sta $0303|!addr,y
	sta $0307|!addr,y
	sta $030B|!addr,y
	sta $030F|!addr,y
	ldy #$02
	lda #$03
	jsl $01B7B3
	rts

;################################################
;# Sets up Background Mode for rotating graphics

parallel_rotate_gfx:
	phb
	phk
	plb
.loop	
	lda $8B
	cmp #$FF
	beq .end
	lda $3071
	bne .end
	lda $EF
	beq .loop
	lda.b #!dest_virtual_ram
	sta $14
	lda.b #!dest_virtual_ram>>8
	sta $15
	lda.b #!dest_virtual_ram>>16
	sta $16
	lda.b !update_graphics
	asl
	clc
	adc.b !update_graphics
	tax
	lda.w .offsets,x
	sta $17
	lda.w .offsets+1,x
	sta $18
	lda.w .offsets+2,x
	sta $19
	jsr SUB_ROTATE
	stz $EF
	bra .loop
.end	
	plb
	rtl

.offsets
	dl !source_bwram+$0000
	dl !source_bwram+$0400
	dl !source_bwram+$0800

incsrc rotate.asm

p_balloon_idle_gfx:
	incbin p_balloon_idle.bin
p_balloon_slow_gfx:
	incbin p_balloon_slow.bin
p_balloon_fast_gfx:
	incbin p_balloon_fast.bin