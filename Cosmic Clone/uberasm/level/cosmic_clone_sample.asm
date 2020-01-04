;##################################################################################################
;# Cosmic Clones v1.0 - Sample UberASM code
;# By lx5
;#
;# This file helps you to set up the Cosmic Clones in your level.
;#

nmi:	
	jsl cosmic_clone_nmi
	rtl

init:	
	jsl cosmic_clone_init
	rtl

main:
	jsl cosmic_clone_main
	rtl