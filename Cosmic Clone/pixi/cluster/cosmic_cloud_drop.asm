tiles:
	db $66,$6E,$64,$62

oam_tbl:
	db $40,$44,$48,$4C
	db $50,$54,$58,$5C
	db $60,$64,$68,$6C	
	db $80,$84,$88,$8C
	db $B0,$B4,$B8,$BC


print "MAIN ",pc
	stz $00
	stz $01
	ldx oam_tbl,y
	lda !cluster_y_low,y
	sec
	sbc $1C
	cmp #$F0
	beq ++
	sta $0201|!addr,x
	lda !cluster_x_low,y
	sec
	sbc $1A
	sta $0200|!addr,x
	lda !cluster_x_high,y
	sbc $1B
	beq +
	inc $00
+	
	lda $0F4A|!addr,y
	lsr #2
	and #$03
	phy
	tay
	lda tiles,y
	ply
	sta $0202|!addr,x
	lda $0F72|!addr,y
	sta $0203|!addr,x
	txa
	lsr #2
	tax
	lda $00
	sta $0420|!addr,x
++	
	lda $9D
	bne ++
	lda $0F4A|!addr,y
	dec
	bne +
	lda #$00
	sta !cluster_num,y
++	
	rtl
+	
	sta $0F4A|!addr,y
	rtl