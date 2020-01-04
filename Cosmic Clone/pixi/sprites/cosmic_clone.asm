;##################################################################################################
;# Cosmic Clones v1.0
;# By lx5
;# 
;# This sprite creates a Cosmic Clone that follows the same path as Mario followed in the previous
;# frames, it evens imitates some of Mario's poses!
;# 
;# Notes:
;#	1) The Cosmic Clones can only be delayed by 255 frames.
;# 	2) Some poses (such as the cape flight poses) are replaced with an generic frame.
;#	3) While they aren't exactly incompatible with Yoshi, they will look weird and they won't
;#	   make Mario lose Yoshi on contact.
;#	4) It's NOT compatible with purple triangles (wall running) AND P-Balloons.
;# 	5) There's a hard limit of 4 Cosmic Clones on screen due to V-Blank time limitations.
;#	   If more than 5 are on screen, there will be graphical issues.
;#	   The sprite tries to not process the fifth Cosmic Clone, but it fails at such task.
;#	   Might be fixed later.
;#	6) Cosmic Clones will upload their graphics at 30fps to avoid NMI overflow problems.
;#	7) If you ever have problem with black bars at the top of the screen, try using less Cosmic
;#	   Clones at the same time.
;#	8) For non SA-1 ROMs, you require to use an external patch to make $7FB000 to be free.
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
;# 	Format: -----ikd
;# 		d = Enables Cosmic Marios to disappear upon damaging Mario.
;#		k = Instantly kills Mario instead of just hurting him.
;#		i = Disable any sort of interaction with Mario.
;# 		- = Unused.
;#

;##################################################################################################
;# Customization
;# The defines below SHOULD match the ones on the UberASM library code.

;#################################################
;# Cluster Sprites

	!cosmic_smoke_num	= $00
	!cosmic_smoke_drop_num	= $01

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
endif

;#################################################
;# Internal defines, do not touch.

!buffer_size		= !max_positions*!data_size

!sprite_powerup		= !C2
!sprite_current_pose	= !160E
!sprite_previous_pose	= !1528
!sprite_behind_layers	= !1602
!sprite_direction	= !157C
!sprite_blocked		= !1588
!sprite_walking_pose	= !1534
!sprite_y_image		= !1594
!sprite_frame_timer	= !151C
!sprite_cosmic_num	= !1510

!sprite_pal		= !15F6

!sprite_x_lo		= !E4
!sprite_x_hi		= !14E0
!sprite_y_hi		= !14D4
!sprite_y_lo		= !D8

;##################################################################################################
;# Init routine

print "INIT ", pc

init:
	phb
	phk
	plb
	
	lda #$01
	sta $18B8|!addr			; Enables Cluster Sprites processing.
	
	lda !extra_byte_1,x
	sta !1540,x			; Saves the amount of delay frames.

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
	jsr mario_gfx
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
	ldy #$10
	cmp #$01
	beq +
	lda $14
	and #$03
	beq ++
	ldy #$25
+	
	sty $1DF9|!addr
++	
	jmp compute_upload
	
.running
	lda !1540,x			; If clouds are still being processed, skip position update
	bne .clouds
	
	lda !sprite_current_pose,x	; Keep a record of the previous shown pose.
	sta !sprite_previous_pose,x
	
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
	sta !sprite_blocked,x
	lda $0B
	lsr #5
	and #$07
	sta !sprite_walking_pose,x
	
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

mario_gfx:	
	%GetDrawInfo()				; Calls GetDrawInfo (probably unneeded).

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
	xba
	lda !sprite_current_pose,x
	tax
	rep #$20
	xba
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
	
	lda $00
	sta $0300|!addr,y			; Writes X position within the camera.
	sta $0304|!addr,y

	lda $02
	sta $0305|!addr,y			; Writes Y position within the camera.
	sec
	sbc #$10
	sta $0301|!addr,y
	
	lda !sprite_cosmic_num,x
	tax
	lda.w .slots-1,x			; Select the appriopiate tiles for this Cosmic
	sta $0302|!addr,y			; Clone.
	clc
	adc #$02
	sta $0306|!addr,y

	lda $0B
	sta $0303|!addr,y			; Writes YXPPCCCT settings.
	sta $0307|!addr,y
	
	tya
	clc
	adc #$08				; Shifts the OAM index by 8 bytes.
	tay
	
	lda $05
	clc
	adc #$04				; Requeriments for the routine below.
	sta $05
	inc $06
	inc $06
	
	jsr .sub				; These two draws Cosmic Clone's 8x8 tiles.
	jsr .sub
	
	ldx $15E9|!addr
	ldy #$02				; Let SMW handle Mario's 16x16 tiles.
	lda #$01
	jsl $01B7B3|!bank
	rts

.slots
	db $EC
	db $E8
	db $E4
	db $E0

;########################
;# Draws 8x8 tiles for Cosmic Clones.
;# Taken from SMW. Gonna skip most comments for this one.

.sub	
	lda !sprite_previous_pose,x
	cmp !sprite_current_pose,x		; If the pose is the same as the previous one,
	beq ..process				; show the 8x8 tile.
	
	lda $14
	and #$01
	sta $00
	lda !sprite_cosmic_num,x
	and #$01				; Skip if the 8x8 tile doesn't match Cosmic Clone's 
	eor $00					; GFX update rate (30fps).
	beq ..finish_drawing
..process	

	ldx $06
	lda.l $00DFDA,x
	bmi ..finish_drawing
	sta $0302|!addr,y
	lda $02FF|!addr,y
	and #$FE
	sta $0303|!addr,y
	ldx $05
	rep #$20
	lda $02
	sbc #$0011
	clc
	adc.l $00DE32,x
	pha
	clc
	adc #$0010
	cmp #$0100
	pla
	sep #$20
	bcs ..finish_drawing
	sta $0301|!addr,y
	
	rep #$20
	lda $0C
	sec
	sbc $1A
	clc
	adc.l $00DD4E,x
	pha
	clc
	adc #$0080
	cmp #$0200
	pla
	sep #$20
	bcs ..finish_drawing
	sta $0300|!addr,y
	xba
	lsr
..finish_drawing	
	php
	tya
	lsr #2
	tax
	plp
	rol
	and #$01
	sta $0460|!addr,x
	iny #4
	inc $05
	inc $05
	inc $06
	rts

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
	lda.l $00E00C,x
	sta $0A
	lda.l $00E0CC,x
	sta $0B
	
	lda.l $00DF1A,x
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
	lda.l $00DCEC,x
	ora $02
	tax
	lda.l $00DD32,x
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
	adc #$2000
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
	adc #$2000
	sta.l !cosmic_clones_ptrs+$04,x
	clc
	adc #$0200
	sta.l !cosmic_clones_ptrs+$06,x
	sep #$20
	ldx $15E9|!addr
	rts

.powerup_disp
	db $00,$46,$83,$46