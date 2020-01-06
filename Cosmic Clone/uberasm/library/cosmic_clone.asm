;##################################################################################################
;# Cosmic Clones v1.0 - UberASM Library
;# By lx5
;#  
;# This library acts as a helper for the Cosmic Clones to update their graphics and info buffer.
;# It's required to get the Cosmic Clones to work at all.
;# 
;# To use this routine check the included ASM file in the level folder.
;# 

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

!buffer_size		= !max_positions*!data_size

;##################################################################################################
;# Main routine
;# Updates buffer with newer info and updates the internal index.

main:	
	lda $9D
	ora $13D4|!addr
	bne .no_update
	
	lda $13E0|!addr
	sta $0A
	
	lda $13F9|!addr
	and #$03
	asl 
	ora $76
	sta $0B
	lda $13DB|!addr
	and #$03
	asl #3
	ora $0B
	sta $0B
	lda $13E3|!addr
	clc
	and #$07
	ror #4
	ora $0B
	sta $0B
	
	lda $188B|!addr
	sta $0C
	
	lda $19
	sta $0D
	
	rep #$30
	lda !buffer_internal_index
	clc
	adc.w #!data_size
	cmp.w #!buffer_size
	bcc .transfer
	sec
	sbc.w #!buffer_size
.transfer
	sta !buffer_internal_index
	tax
	
	lda $94
	sta.l !buffer,x
	lda $96
	sta.l !buffer+2,x
	lda $0A
	sta.l !buffer+4,x
	lda $0C
	sta.l !buffer+6,x
	
	sep #$30	

.no_update
	rtl

;##################################################################################################
;# NMI Routine
;# Uploads GFX depending on how many Cosmic Clones are there.

nmi:
	lda !cosmic_clones_num
	bne ++
	jmp +
++	
	dec
	lsr
	sta $00
	stz $01
	tay

	rep #$20
	ldx #$80
	stx $2115
	lda #$1801
	sta $4310
	
	lda $14
	and #$0001
	asl #3
	tax 
	ldy #$02
-	
	phx
	txa
	lsr #3
	tax
	lda !cosmic_clones_bank,x
	tax
	stx $4314
	plx
	
	lda.l .vram_dests,x
	sta $2116
	lda.l !cosmic_clones_ptrs,x
	sta $4312
	lda #$0040
	sta $4315
	sty $420B

	lda.l .vram_dests+$2,x
	sta $2116
	lda.l !cosmic_clones_ptrs+$4,x
	sta $4312
	lda #$0040
	sta $4315
	sty $420B

	lda.l .vram_dests+$4,x
	sta $2116
	lda.l !cosmic_clones_ptrs+$2,x
	sta $4312
	lda #$0040
	sta $4315
	sty $420B

	lda.l .vram_dests+$6,x
	sta $2116
	lda.l !cosmic_clones_ptrs+$6,x
	sta $4312
	lda #$0040
	sta $4315
	sty $420B

	txa
	clc
	adc #$0010
	tax
	dec $00
	lda $00
	bpl -
	
	sep #$20
+	
	lda #$00
	sta !cosmic_clones_num
	rtl

.vram_dests
	dw $7EC0,$7EE0,$7FC0,$7FE0
	dw $7E80,$7EA0,$7F80,$7FA0
	dw $7E40,$7E60,$7F40,$7F60
	dw $7E00,$7E20,$7F00,$7F20

;##################################################################################################
;# Init routine.
;# Initializes RAM. Probably not super required, but just in case.

init:	
	lda #$00
	sta !cosmic_clones_num
	sta !buffer_internal_index
	sta !buffer_internal_index+1
	ldx #$1E
-	
	sta !cosmic_clones_ptrs,x
	dex
	bpl -
	rtl