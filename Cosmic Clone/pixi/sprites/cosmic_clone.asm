;##################################################################################################
;# Cosmic Clones v1.1
;# By lx5
;# 
;# This sprite creates a Cosmic Clone that follows the same path as Mario followed in the previous
;# frames, it evens imitates some of Mario's poses!
;# 
;# Notes:
;#	1) The Cosmic Clones can only be delayed by 255 frames.
;# 	2) Some poses (such as the cape flight poses) are replaced with a generic frame.
;#	3) While they aren't exactly incompatible with Yoshi, they will look weird and they won't
;#	   make Mario lose Yoshi on contact.
;# 	4) There's a hard limit of 4 Cosmic Clones on screen due to V-Blank time limitations.
;#	   If more than 5 are on screen, there will be graphical issues.
;#	   The sprite tries to not process the fifth Cosmic Clone, but it fails at such task.
;#	   Might be fixed later.
;#	5) Cosmic Clones will upload their graphics at 30fps to avoid NMI overflow problems.
;#	6) If you ever have problem with black bars at the top of the screen, try using less Cosmic
;#	   Clones at the same time.
;#	7) For non SA-1 ROMs, you require to use an external patch to make $7F0000 to be free.
;#         Unless you're planning to remap the FreeRAM define.
;#	   Patch for above: https://www.smwcentral.net/?p=section&a=details&id=19580
;#
;# The sprite uses 2 extra bytes to determine its behavior.
;# 
;# Extra byte 1:
;# 	Determines how many frames will the Cosmic Clone be behind the real Mario.
;# 
;# Extra byte 2:
;# 	Each bit has a different function.
;# 	Format: p-ts-ikd
;# 		d = Enables Cosmic Marios to disappear upon damaging Mario.
;#		k = Instantly kills Mario instead of just hurting him.
;#		i = Disable any sort of interaction with Mario.
;#		s = Skip drawing 8x8 tiles.
;#		t = Skip leaving small clouds after appearing.
;#		p = Override default palette (F) with Extra Byte 3 info.
;# 		- = Unused.
;#
;# Extra byte 3:
;# 	Palette that will be used for the clones if the most significant bit of Extra byte 2 was
;#	enabled.
;#	Format: ----ccct
;#		ccc = CCC bits from YXPPCCCT
;#		t = T bit from YXPPCCCT
;#

;##################################################################################################
;# Customization
;# The defines below SHOULD match the ones on the UberASM library code.

;#################################################
;# Cluster Sprites

	!cosmic_smoke_num	= $00		; Cluster sprite number of the big smoke cloud.
	!cosmic_smoke_drop_num	= $01		; Cluster sprite number of the small smoke cloud.

;#################################################
;# SFX Customization

	!animation_sfx		= $25		; SFX for the cloud effect.
	!spawn_sfx		= $10		; SFX for the spawn effect.
	!shared_sfx_port	= $1DF9		; SFX Port for the sound effect above.
						; They MUST be in the same port due to how it was
						; programmed.

;#################################################
;# Data logging

	!data_size		= 8		; This option determines how many bytes
						; will be saved per frame
	!max_positions		= 256		; This define determines how many frames will be
						; kept in a buffer.

;#################################################
;# FreeRAM

;########################
;# SA-1 Defines
if !sa1
	!buffer			= $416000	; Buffer that holds the data collected in the
						; previous frames.
						; It currently uses 0x800 bytes of consecutive RAM.
						
	!buffer_internal_index	= $40BFDE	; Index used to determine which byte are we reading
						; from the buffer above.
						; This holds a 16-bit value.

	!cosmic_clones_num	= $40BFDD	; Holds the number of Cosmic Clones on screen.
						; It's a single byte.

	!cosmic_clones_ptrs	= $40BFE0	; Has the pointer to the current graphic that the
						; clone has to show.
						; Uses 8 bytes per clone.
						
	!cosmic_clones_bank	= $40BFD8	; Has the bank byte for the pointers above.
						; 1 byte per clone.
	
;########################
;# LoROM Defines
else
	!buffer			= $7F0000	; Buffer that holds the data collected in the
						; previous frames.
						; It currently uses 0x800 bytes of consecutive RAM.
						
	!buffer_internal_index	= $7F2020	; Index used to determine which byte are we reading
						; from the buffer above.
						; This holds a 16-bit value.
						
	!cosmic_clones_num	= $7F2022	; Holds the number of Cosmic Clones on screen.
						; It's a single byte.
						
	!cosmic_clones_ptrs	= $7F2000	; Has the pointer to the current graphic that the
						; clone has to show.
						; Uses 8 bytes per clone.
						
	!cosmic_clones_bank	= $7F2023	; Has the bank byte for the pointers above.
						; 1 byte per clone.
endif

;#################################################
;# Internal defines, do not touch.

!buffer_size			= !max_positions*!data_size

!sprite_powerup			= !C2
!sprite_current_pose		= !160E
!sprite_previous_pose		= !1528
!sprite_behind_layers		= !1602
!sprite_direction		= !157C
!sprite_wallrun			= !1588
!sprite_walking_pose		= !1534
!sprite_y_image			= !1594
!sprite_frame_timer		= !151C
!sprite_cosmic_num		= !1510

!sprite_previous_index_06	= !1570
!sprite_previous_index_05	= !1504
!sprite_previous_index_04	= !1FD6

!sprite_pal			= !15F6

!sprite_x_lo			= !E4
!sprite_x_hi			= !14E0
!sprite_y_hi			= !14D4
!sprite_y_lo			= !D8

;##################################################################################################
;# Init routine

print "INIT ", pc

init:
	phb
	phk
	plb
	
	lda #$01
	sta $18B8|!addr			; Enables processing cluster sprites.
	
	lda !extra_byte_1,x
	sta !1540,x			; Saves the amount of delay frames.

	lda !extra_byte_2,x
	bpl .default_pal
	lda !extra_byte_3,x
	and #$0F
	sta !sprite_pal,x
.default_pal
	
if !sa1
	stz $2250
	sta $2251
	stz $2252
	lda.b #!data_size
	sta $2253
	stz $2254			; Computes !data_size * delay frames
else	
	sta $211B
	stz $211B
	lda.b #!data_size
	sta $211C
endif	

	lda #$01			; Searchs for a free Cosmic Clone sprite slot.
	sta $00				; $00 = Cosmic Clone slot
	sta $01				; $01 = Current slot being searched
	lda !7FAB9E,x
	sta $02				; $02 = This sprite's number.
	ldy #$03			; Y = amount of times to loop
.search_again	
	ldx.b #!SprSize-1
.loop	
	lda !14C8,x
	cmp #$08
	bcc .next_sprite
	lda !7FAB10,x
	and #$08
	beq .next_sprite		; Discards dead sprites, non custom sprites, sprites
	lda !7FAB9E,x			; without the same sprite number and this sprite being
	cmp $02				; processed
	bne .next_sprite
	cpx $15E9|!addr	
	beq .next_sprite
	lda !sprite_cosmic_num,x
	cmp $01				; Checks if the found Cosmic Clone has the ID/slot we're 
	beq .same_id			; searching for.
	
.next_sprite	
	dex 
	bpl .loop
	bra .end_search			; If no sprites meet the first criteria, we consider the
					; current slot as free.
.same_id
	inc $00
	inc $01				; If a sprite with the desired ID was found, the loop is
	dey				; broken and a new search begins
	bpl .search_again
	
	stz !14C8,x			; If there are no slots, we're deleting this sprite.
	plb
	rtl
	
.end_search	
	ldx $15E9|!addr
	lda $00
	sta !sprite_cosmic_num,x	; Save the free Cosmic Clone slot into a table.
	
	lda $94
	sec
	sbc #$04
	sta !sprite_x_lo,x
	lda $95
	sbc #$00
	sta !sprite_x_hi,x		; Set up the initial coordinates.
	lda $96
	clc
	adc #$0B
	sta !sprite_y_lo,x
	lda $97
	adc #$00
	sta !sprite_y_hi,x
	
	plb
	rtl
	
;##################################################################################################
;# Main routine

print "MAIN ", pc
main_rt:
	phb
	phk
	plb
	
	jsr main			; Main routine call.
	
	lda !1540,x			; If we're still waiting on that delay, spawn smoke clouds
	bne .draw_clouds		; if not, draw the Cosmic Clone.
	jsr cosmic_gfx
	bra .skip_clouds
.draw_clouds
	jsr cloud_gfx
.skip_clouds


	lda !cosmic_clones_num
	inc				; Add 1 to the total Cosmic Clones being processed.
	sta !cosmic_clones_num
	
	plb
	rtl

;#################################################
;# Actual main routine.
;# Handles movement and graphics pointer computing.

main:		
	lda $9D				; If the game is frozen, skip movement update, go straight
	beq .running			; to graphics pointer computing.
	jmp compute_upload
.clouds	
	ldy.b #!spawn_sfx
	cmp #$01
	beq +
	lda $14
	and #$03
	beq ++
	ldy.b #!animation_sfx
+	
	sty.w !shared_sfx_port|!addr
++	
	jmp compute_upload
	
.running
	lda !1540,x			; If clouds are still being processed, skip position update
	bne .clouds
	
	lda !sprite_current_pose,x	; Keep a record of the previous shown pose.
	sta !sprite_previous_pose,x
	
	lda !extra_byte_2,x
	and #$20
	bne +
	inc !sprite_frame_timer,x	; Spawn small smoke effects in front of the Cosmic Clone.
	lda !sprite_frame_timer,x
	and #$03
	bne +
	jsr spawn_cloud_drop
+	

;########################
;# Cosmic Clone position update code.

	lda !extra_byte_1,x
if !sa1
	stz $2250
	sta $2251
	stz $2252
	lda.b #!data_size
	sta $2253			; Computes !data_size * delay frames
	stz $2254
else	
	sta $211B
	stz $211B
	lda.b #!data_size
	sta $211C
endif	

	rep #$30
	lda !buffer_internal_index
	sec
if !sa1
	sbc $2306			; Set the delay between Mario's positon and this
else					; Cosmic Clone position.
	sbc $2134
endif	
	bpl .update_index
	clc
	adc.w #!buffer_size
.update_index
	tax
	
	lda !buffer,x
	sta $06
	lda !buffer+2,x			; Read data from buffer.
	sta $08
	lda !buffer+4,x
	sta $0A
	lda !buffer+6,x
	sta $0C
	sep #$30
	
	ldx $15E9|!addr
	
	lda $06
	sta !sprite_x_lo,x		; Update X position.
	lda $07
	sta !sprite_x_hi,x

	lda $08
	clc
	adc #$0F			; Update and displace Y position.
	sta !sprite_y_lo,x
	lda $09
	adc #$00
	sta !sprite_y_hi,x

	lda $0A
	cmp #$2A
	bcc +
	cmp #$30			; Update and fix current pose being shown.
	bcs +
	lda #$24
+	
	sta !sprite_current_pose,x
	
	lda $0B
	and #$01
	sta !sprite_direction,x		; Unpacks this info into several tables.
	lda $0B				; Updates Cosmic Clone's direction, layer priority,
	lsr #1				; blocked status and walking pose number.
	and #$03
	sta !sprite_behind_layers,x
	lda $0B
	lsr #3
	and #$03
	sta !sprite_walking_pose,x
	lda $0B
	lsr #5
	and #$07
	sta !sprite_wallrun,x
	
	lda $0C				; Updates Y position visual displacement.
	sta !sprite_y_image,x
	
	lda $0D				; Updates powerup status of the Cosmic Clone.
	sta !sprite_powerup,x
	
	lda !extra_byte_2,x
	and #$04
	bne .disable_interaction
	jsr interaction			; Processes interaction with Mario.
.disable_interaction
	
	jmp compute_upload		; Processes graphics pointer calculation.

;########################
;# Cosmic Clone interaction code.

interaction:
	pei ($94)
	pei ($96)			; Saves Mario's coordinates, powerup status, ducking status
	lda $19				; and Yoshi's status.
	pha
	lda $73
	pha
	lda $187A|!addr
	pha

	lda !sprite_x_lo,x
	sta $94
	lda !sprite_x_hi,x		; Replaces Mario's info with the Cosmic Clone's info.
	sta $95
	lda !sprite_y_lo,x
	sec
	sbc #$10
	sta $96
	lda !sprite_y_hi,x
	sbc #$00
	sta $97
	ldy #$00
	lda !sprite_current_pose,x
	cmp #$3C
	beq +
	iny
+	
	sty $73
	lda !sprite_powerup,x
	sta $19
	stz $187A|!addr			;This approach was chosen to keep compatibilty with patches
	jsl $03B664|!bank		;that changes Mario's hitboxes.
	pla 
	sta $187A|!addr
	pla	
	sta $73
	pla				; Recovers Mario's info.
	sta $19
	rep #$20
	pla
	sta $96
	pla
	sta $94
	
	lda $00
	sta $04
	lda $02
	sta $06				; Transfers Cosmic Clone's info to Slot A.
	lda $08
	sta $0A
	sep #$20
	
	jsl $03B664|!bank		; Gets Mario's clipping.
	jsl $03B72B|!bank		; Check for contact.
	bcc .return

	lda $1490|!addr			; If Mario has a Star, kill the Cosmic Clone upon touching
	bne .kill_clone			; it.
	
	lda $1497|!addr
	bne .return
	
	lda !extra_byte_2,x
	and #$02			; Kill Mario if bit 1 is set.
	bne .kill_mario
	jsl $00F5B7|!bank		; Hurt Mario.
	bra .more_checks
.kill_mario
	jsl $00F606|!bank		; Kill Mario.
.more_checks
	
	lda !extra_byte_2,x		; Skip erasing the Cosmic Clone if bit 0 is set.
	and #$01
	beq .return
.kill_clone
	stz !14C8,x

	jsr .reorganize			; Calls a routine to reorganize Cosmic Clone's slots.

	lda !sprite_behind_layers,x
	eor #$01
	and #$01
	asl #5
	ora !sprite_pal,x		; Fill information necessary to spawn a cluster sprite.
	and #$FE
	sta $01
	lda !sprite_y_lo,x
	sta $02
	lda !sprite_y_hi,x
	sta $03
	lda !sprite_x_lo,x
	sta $04
	lda !sprite_x_hi,x
	sta $05
	
	ldx #$04
	ldy #$13			; Draws a smoke explosion in Cosmic Clone's coordinates.
-	
	lda !cluster_num,y
	beq +
	cmp.b #!cosmic_smoke_drop_num+!ClusterOffset
	beq +
	dey
	bpl -
	ldx $15E9|!addr
.return	
	rts
+	
	lda.b #!cosmic_smoke_num+!ClusterOffset
	sta !cluster_num,y
	lda $02
	clc
	adc .y_lo_disp,x
	sta !cluster_y_low,y
	lda $03
	adc .y_hi_disp,x
	sta !cluster_y_high,y
	lda $04
	clc
	adc .x_lo_disp,x
	sta !cluster_x_low,y
	lda $05
	adc .x_hi_disp,x
	sta !cluster_x_high,y
	lda #$0F
	sta $0F4A|!addr,y
	txa
	clc
	and #$03
	ror #3
	ora $01
	sta $0F72|!addr,y
	dex
	bpl -
	ldx $15E9|!addr
	rts

.y_lo_disp
	db $00,$F3,$F3,$07,$07
.y_hi_disp
	db $00,$FF,$FF,$00,$00
.x_lo_disp
	db $00,$FA,$04,$FA,$04
.x_hi_disp
	db $00,$FF,$00,$FF,$00

;########################
;# Reorganizes Cosmic Clone's slots.

.reorganize
	lda !sprite_cosmic_num,x
	sta $00				; $00 = This Cosmic Clone ID.
	lda !7FAB9E,x
	sta $01				; $01 = This Cosmic Clone sprite number.
	ldx.b #!SprSize-1
-	
	lda !14C8,x
	cmp #$08
	bcc ..next			; Excludes dead sprites, non custom sprites and non Cosmic
	lda !7FAB10,x			; Clones sprites.
	and #$08
	beq ..next
	lda !7FAB9E,x
	cmp $01
	bne ..next
	
	cpx $15E9|!addr			; If we find this Cosmic Clone, reset its number.
	beq ..reset
	lda !sprite_cosmic_num,x
	cmp $00
	bcc ..next			; If the Cosmic Clone number of the other Clones is smaller
	dec !sprite_cosmic_num,x	; than the one from this Clones', don't modify it.
	bra ..next			; If it's greater than this Clones', decrease it by 1.
..reset	
	stz !sprite_cosmic_num,x
..next	
	dex
	bpl -
	ldx $15E9|!addr
	rts

;#################################################
;# Cosmic Clone graphics routine.

cosmic_gfx:
	;%GetDrawInfo()
	lda !sprite_cosmic_num,x
	tay
	lda.w .slots-1,y			; Select the appriopiate tiles for this Cosmic
	sta $0A
	
	lda !sprite_behind_layers,x
	and #$01
	eor #$01
	asl #5
	ldy !sprite_direction,x			; Processes Cosmic Clone's YXPPCCCT properties.
	beq +
	ora #$40
+	
	ora !sprite_pal,x
	sta $0B

	lda !sprite_x_lo,x
	sta $0C
	lda !sprite_x_hi,x
	sta $0D					; Saves Cosmic Clone's position.
	lda !sprite_y_lo,x
	sta $0E
	lda !sprite_y_hi,x
	sta $0F
	
	lda !sprite_walking_pose,x
	sta $02					; Saves CC's walking pose and powerup status.
	lda !sprite_powerup,x
	sta $03
	
	lda !sprite_y_image,x
	sta $09
	lda !sprite_wallrun,x
	sta $08
	
	lda !sprite_current_pose,x
	tax
	
	lda #$05
	cmp $08
	bcs .calc_x_pos
	lda $08
	ldy $03
	beq .no_powerup
	cpx #$13
	bne .skip_inv
.no_powerup
	eor #$01
.skip_inv
	lsr
.calc_x_pos
	rep #$20
	lda $0C
	sbc $1A
	sta $00
	
.calc_y_pos
	lda $09
	and #$00FF
	clc
	adc $0E
	ldy $03
	cpy #$01
	ldy #$01				; Taken from SMW and adapted for Cosmic Clones.
	bcs +					; It basically recreates that small 1px movement
	dec					; when Mario walks.
	dey 
+	
	cpx #$0A
	bcs +
	cpy $02
+	
	sbc $1C
	cpx #$1C
	bne +
	adc #$0001
+	
	clc
	adc #$0002
	sta $02					; Saves the Y position within the camera of the
	sep #$20				; Cosmic Clone.
	
	ldx $15E9|!addr
	ldy !15EA,x

	lda $0B
	sta $0303|!addr,y
	sta $0307|!addr,y
	sta $030F|!addr,y			; Sets up Cosmic Clone's YXPPCCCT props before 
	ldx $04					; everything else.
	cpx #$E8
	bne .dont_flip				; Also hardcodes P-Balloon workaround.
	eor #$40
.dont_flip
	sta $030B|!addr,y

	ldx $15E9|!addr
	lda !sprite_previous_pose,x
	cmp !sprite_current_pose,x		; If the pose is the same as the previous one,
	beq .skip_remap				; show the 8x8 tile.
	
	lda $14
	and #$01
	sta $09
	lda !sprite_cosmic_num,x
	and #$01				; Remap if the tile doesn't match Cosmic Clone's 
	eor $09					; GFX update rate (30fps).
	bne .skip_remap
.use_previous_tile
	lda !sprite_previous_index_06,x
	sta $06
	lda !sprite_previous_index_05,x
	sta $05
	lda !sprite_previous_index_04,x
	sta $04
	beq .begin_draw
.skip_remap
		
	lda $06
	sta !sprite_previous_index_06,x
	lda $05
	sta !sprite_previous_index_05,x
	lda $04
	sta !sprite_previous_index_04,x
	
.begin_draw
	jsr draw_cosmic_tile			; These two draws Cosmic Clone's 8x8 tiles.
	jsr draw_cosmic_tile
	
	ldx $15E9|!addr
	lda !extra_byte_2,x
	and #$10
	bne .skip_small_tiles
	
	jsr draw_cosmic_tile
	jsr draw_cosmic_tile
	
.skip_small_tiles
	
	ldx $15E9|!addr
	rts

.slots
	db $EC
	db $E8
	db $E4
	db $E0

;########################
;# Draws 8x8 tiles for Cosmic Clones.
;# Taken from SMW. Gonna skip most comments for this one.

draw_cosmic_tile:
	ldx $06
	lda.w cosmic_tiles,x
	cmp #$80
	beq .finish_drawing
	cmp #$00
	beq .fix_tile
	cmp #$02
	bne .dont_fix
.fix_tile
	clc
	adc $0A
.dont_fix
	sta $0302|!addr,y
	
	ldx $05
	rep #$20
	lda $02
	sec
	sbc #$0011
	clc
	adc.w cosmic_y_disp,x
	pha
	clc
	adc #$0010
	cmp #$0100
	pla
	sep #$20
	bcs .finish_drawing
	sta $0301|!addr,y
	
	rep #$20
	lda $00
	clc
	adc.w cosmic_x_disp,x
	pha
	clc
	adc #$0080
	cmp #$0200
	pla
	sep #$20
	bcs .finish_drawing
	sta $0300|!addr,y
	xba
	lsr
.finish_drawing	
	php
	tya
	lsr #2
	tax
	asl $04
	rol
	plp
	rol
	and #$03
	sta $0460|!addr,x
	iny #4
	inc $05
	inc $05
	inc $06
	rts

cosmic_tiles:				; Same format as $00DF1A
	db $00,$02,$80,$80
	db $00,$02,$C2,$80
	db $00,$02,$D0,$D1
	db $00,$02,$C3,$80
	db $00,$02,$C6,$C7
	db $00,$02,$D6,$D7
	db $00,$02,$C0,$C1
	db $00,$02,$D4,$D5
	db $00,$02,$C4,$C5
	db $00,$02,$D2,$80
	db $00,$02,$02,$80
	db $04,$D3,$C8,$D9,$C9,$D8

cosmic_x_disp:				; Same format as $00DD4E
	db $00,$00,$00,$00,$10,$00,$10,$00
	db $00,$00,$00,$00,$F8,$FF,$F8,$FF
	db $0E,$00,$06,$00,$F2,$FF,$FA,$FF
	db $17,$00,$07,$00,$0F,$00,$EA,$FF
	db $FA,$FF,$FA,$FF,$00,$00,$00,$00
	db $00,$00,$00,$00,$10,$00,$10,$00
	db $00,$00,$00,$00,$F8,$FF,$F8,$FF
	db $00,$00,$F8,$FF,$08,$00,$00,$00
	db $08,$00,$F8,$FF,$00,$00,$00,$00
	db $F8,$FF,$00,$00,$00,$00,$10,$00
	db $02,$00,$00,$00,$FE,$FF,$00,$00
	db $00,$00,$00,$00,$FC,$FF,$05,$00
	db $04,$00,$FB,$FF,$FB,$FF,$06,$00
	db $05,$00,$FA,$FF,$F9,$FF,$09,$00
	db $07,$00,$F7,$FF,$FD,$FF,$FD,$FF
	db $03,$00,$03,$00,$FF,$FF,$07,$00
	db $01,$00,$F9,$FF,$0A,$00,$F6,$FF
	db $08,$00,$F8,$FF,$08,$00,$F8,$FF
	db $00,$00,$04,$00,$FC,$FF,$FE,$FF
	db $02,$00,$0B,$00,$F5,$FF,$14,$00
	db $EC,$FF,$0E,$00,$F3,$FF,$08,$00
	db $F8,$FF,$0C,$00,$14,$00,$FD,$FF
	db $F4,$FF,$F4,$FF,$0B,$00,$0B,$00
	db $03,$00,$13,$00,$F5,$FF,$05,$00
	db $F5,$FF,$09,$00,$01,$00,$01,$00
	db $F7,$FF,$07,$00,$07,$00,$05,$00
	db $0D,$00,$0D,$00,$FB,$FF,$FB,$FF
	db $FB,$FF,$FF,$FF,$0F,$00,$01,$00
	db $F9,$FF,$00,$00

cosmic_y_disp:				; Same format as $00DE32
	db $01,$00,$11,$00,$11,$00,$19,$00
	db $01,$00,$11,$00,$11,$00,$19,$00
	db $0C,$00,$14,$00,$0C,$00,$14,$00
	db $18,$00,$18,$00,$28,$00,$18,$00
	db $18,$00,$28,$00,$06,$00,$16,$00
	db $01,$00,$11,$00,$09,$00,$11,$00
	db $01,$00,$11,$00,$09,$00,$11,$00
	db $01,$00,$11,$00,$11,$00,$01,$00
	db $11,$00,$11,$00,$01,$00,$11,$00
	db $11,$00,$01,$00,$11,$00,$11,$00
	db $01,$00,$11,$00,$01,$00,$11,$00
	db $11,$00,$05,$00,$04,$00,$14,$00
	db $04,$00,$14,$00,$0C,$00,$14,$00
	db $0C,$00,$14,$00,$10,$00,$10,$00
	db $10,$00,$10,$00,$10,$00,$00,$00
	db $10,$00,$00,$00,$10,$00,$00,$00
	db $10,$00,$00,$00,$0B,$00,$0B,$00
	db $11,$00,$11,$00,$FF,$FF,$FF,$FF
	db $10,$00,$10,$00,$10,$00,$10,$00
	db $10,$00,$10,$00,$10,$00,$15,$00
	db $15,$00,$25,$00,$25,$00,$04,$00
	db $04,$00,$04,$00,$14,$00,$14,$00
	db $04,$00,$14,$00,$14,$00,$04,$00
	db $04,$00,$14,$00,$04,$00,$04,$00
	db $14,$00,$00,$00,$08,$00,$00,$00
	db $00,$00,$08,$00,$00,$00,$00,$00
	db $10,$00,$18,$00,$00,$00,$10,$00
	db $18,$00,$00,$00,$10,$00,$00,$00
	db $10,$00,$F8,$FF

cosmic_top_tilemap:			; Same format as $00E00C
	db $50,$50,$50,$09,$50,$50,$50,$50
	db $50,$50,$09,$2B,$50,$2D,$50,$D5
	db $2E,$C4,$C4,$C4,$D6,$B6,$50,$50
	db $50,$50,$50,$50,$50,$C5,$D7,$2A
	db $E0,$50,$D5,$29,$2C,$B6,$D6,$28
	db $E0,$E0,$C5,$C5,$C5,$C5,$C5,$C5
	db $5C,$5C,$50,$5A,$B6,$50,$28,$28
	db $C5,$D7,$28,$70,$C5,$70,$1C,$93
	db $C5,$C5,$0B,$85,$90,$84,$70,$70
	db $70,$A0,$70,$70,$70,$70,$70,$70
	db $A0,$74,$70,$80,$70,$84,$17,$A4
	db $A4,$A4,$B3,$B0,$70,$70,$70,$70
	db $70,$70,$70,$E2,$72,$0F,$61,$70
	db $63,$82,$C7,$90,$B3,$D4,$A5,$C0
	db $08,$54,$0C,$0E,$1B,$51,$49,$4A
	db $48,$4B,$4C,$5D,$5E,$5F,$E3,$90
	db $5F,$5F,$C5,$70,$70,$70,$A0,$70
	db $70,$70,$70,$70,$70,$A0,$74,$70
	db $80,$70,$84,$17,$A4,$A4,$A4,$B3
	db $B0,$70,$70,$70,$70,$70,$70,$70
	db $E2,$72,$0F,$61,$70,$63,$82,$C7
	db $90,$B3,$D4,$A5,$C0,$08,$64,$0C
	db $0E,$1B,$51,$49,$4A,$48,$4B,$4C
	db $5D,$5E,$5F,$E3,$90,$5F,$5F,$C5

cosmic_bottom_tilemap:			; Same format as $00E0CC
	db $71,$60,$60,$19,$94,$96,$96,$A2
	db $97,$97,$18,$3B,$B4,$3D,$A7,$E5
	db $2F,$D3,$C3,$C3,$F6,$D0,$B1,$81
	db $B2,$86,$B4,$87,$A6,$D1,$F7,$3A
	db $F0,$F4,$F5,$39,$3C,$C6,$E6,$38
	db $F1,$F0,$C5,$C5,$C5,$C5,$C5,$C5
	db $6C,$4D,$71,$6A,$6B,$60,$38,$F1
	db $5B,$69,$F1,$F1,$4E,$E1,$1D,$A3
	db $C5,$C5,$1A,$95,$10,$07,$02,$01
	db $00,$02,$14,$13,$12,$30,$27,$26
	db $30,$03,$15,$04,$31,$07,$E7,$25
	db $24,$23,$62,$36,$33,$91,$34,$92
	db $35,$A1,$32,$F2,$73,$1F,$C0,$C1
	db $C2,$83,$D2,$10,$B7,$E4,$B5,$61
	db $0A,$55,$0D,$75,$77,$1E,$59,$59
	db $58,$02,$02,$6D,$6E,$6F,$F3,$68
	db $6F,$6F,$06,$02,$01,$00,$02,$14
	db $13,$12,$30,$27,$26,$30,$03,$15
	db $04,$31,$07,$E7,$25,$24,$23,$62
	db $36,$33,$91,$34,$92,$35,$A1,$32
	db $F2,$73,$1F,$C0,$C1,$C2,$83,$D2
	db $10,$B7,$E4,$B5,$61,$0A,$55,$0D
	db $75,$77,$1E,$59,$59,$58,$02,$02
	db $6D,$6E,$6F,$F3,$68,$6F,$6F,$06

cosmic_tilemap_expansion:		; Same format as $00DF1A
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$28,$00,$00,$00,$00
	db $00,$00,$04,$04,$04,$00,$00,$00
	db $00,$00,$08,$00,$00,$00,$00,$0C
	db $0C,$0C,$00,$00,$10,$10,$14,$14
	db $18,$18,$00,$00,$1C,$00,$00,$00
	db $00,$20,$00,$00,$00,$00,$24,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$04
	db $04,$04,$00,$00,$00,$00,$00,$08
	db $00,$00,$00,$00,$0C,$0C,$0C,$00
	db $00,$10,$10,$14,$14,$18,$18,$00
	db $00,$1C,$00,$00,$00,$00,$20,$00
	db $00,$00,$00,$24,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00

cosmic_disp_selector:			; Same format as $00DCEC
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $02,$04,$04,$04,$0E,$08,$00,$00
	db $00,$00,$00,$00,$00,$00,$08,$08
	db $08,$08,$08,$08,$00,$00,$00,$00
	db $0C,$10,$12,$14,$16,$18,$1A,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$06,$00,$00
	db $00,$00,$00,$0A,$00,$00

cosmic_disp_indexes:			; Same format as $00DD32
	db $00,$08,$10,$14,$18,$1E,$24,$24
	db $28,$30,$38,$3E,$44,$4A,$50,$54
	db $58,$58,$5C,$60,$64,$68,$6C,$70
	db $74,$78,$7C,$80

;#################################################
;# Spawn clouds routine.
;# Taken from SMW. Gonna skip comments for this one.

cloud_gfx:
	lda !1540,x
	and #$01
	bne ++
spawn_cloud_drop:
	lda #$0B
	%Random()
	sta $0F
	lda !sprite_x_lo,x
	clc
	adc $0F
	sta $02
	lda !sprite_x_hi,x
	adc #$00
	sta $03

	lda #$1B
	%Random()
	sta $0E
	stz $0F
	lda !sprite_y_hi,x
	xba
	lda !sprite_y_lo,x
	rep #$20
	sec
	sbc #$0011
	clc
	adc $0E
	sta $00
	sep #$20
	
	jsr spawn_cloud
++	
	rts

spawn_cloud:
	ldy #$13

	lda !1540,x
	beq .small_clouds
.big_clouds
..loop	
	lda !cluster_num,y
	beq .found_big
	cmp.b #!cosmic_smoke_drop_num+!ClusterOffset
	beq .found_big
	dey
	bpl ..loop
	rts
	
.small_clouds
-	
	lda !cluster_num,y
	beq .found_small
	dey
	bpl -
	rts
	
.found_small
	lda.b #!cosmic_smoke_drop_num+!ClusterOffset
	bra .process
.found_big
	lda.b #!cosmic_smoke_num+!ClusterOffset
.process
	sta !cluster_num,y
	lda $00
	sta !cluster_y_low,y
	lda $01
	sta !cluster_y_high,y
	lda $02
	sta !cluster_x_low,y
	lda $03
	sta !cluster_x_high,y
	lda #$0F
	sta $0F4A|!addr,y
	lda !sprite_behind_layers,x
	eor #$01
	and #$01
	asl #5
	ora !sprite_pal,x
	and #$FE
	sta $0F72|!addr,y
	rts

;#################################################
;# GFX pointer routine.
;# Taken from SMW. Gonna skip comments for this one.

compute_upload:
	lda !sprite_direction,x
	sta $02
	ldy.w !sprite_powerup,x
	sty $01
	lda !sprite_current_pose,x
	sta $00
	cmp #$3D
	bcs +
	adc.w .powerup_disp,y
+	
	txy
	tax 
	lda.w cosmic_top_tilemap,x
	sta $0A
	lda.w cosmic_bottom_tilemap,x
	sta $0B
	
	lda.w cosmic_tilemap_expansion,x
	sta $06
	ldx $00
	lda #$C8
	cpx #$43
	bne +
	lda #$E8
+	
	sta $04
	cpx #$29
	bne +
	lda $01
	bne +
	ldx #$20
+	
	lda.w cosmic_disp_selector,x
	ora $02
	tax
	lda.w cosmic_disp_indexes,x
	sta $05


	
	lda !sprite_cosmic_num,y
	dec
	and #$03
	asl #3
	tax

	rep #$20
	lda $09
	ora #$0800
	cmp $09
	beq .code_00F644
	clc
.code_00F644
	and #$F700
	ror
	lsr
	adc.w #cosmic_clone_gfx
	sta.l !cosmic_clones_ptrs+$00,x
	clc
	adc #$0200
	sta.l !cosmic_clones_ptrs+$02,x
	
	lda $0A
	ora #$0800
	cmp $0A
	beq .code_00F662
	clc
.code_00F662
	and #$F700
	ror
	lsr
	adc.w #cosmic_clone_gfx
	sta.l !cosmic_clones_ptrs+$04,x
	clc
	adc #$0200
	sta.l !cosmic_clones_ptrs+$06,x
	sep #$20
	
	txa
	lsr #3
	tax
	lda.b #cosmic_clone_gfx/$10000
	sta !cosmic_clones_bank,x

	ldx $15E9|!addr
	rts

.powerup_disp
	db $00,$46,$83,$46

cosmic_clone_gfx:
	incbin cosmic_clone.bin