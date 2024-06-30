;
;      Dbug's Zero Bitplan intro for Sommarhack 2024
;                    2020, 28th of May
;
; https://sommarhack.se/2024/compo.php#themed1
;
; 1. Zero Bitplane Demo
;
; This one might need a bit of thought! 
; Make a demo with no bitmap graphics, screen memory should be blank from any data.
; 
; Rules:
; - Atari ST (no STe, no Mega ST, no blitter)
; - Colour monitor
; - 1MB RAM
; - No bitmap data on screen at all, blank screen buffer
; - Floppydisk or harddrive
; - More than one entry per participant/crew allowed
;
; For ideas check out these demos:
; - Onedimensional from Shadow (R.I.P.):  https://demozoo.org/productions/195225/
; - Phosphorizer by Logicoma & Loonies:   https://demozoo.org/productions/292526/
;
; MindBender (2020): https://demozoo.org/productions/280163/
; MonoSlide (2022):  https://demozoo.org/productions/310182/
;

 opt o+,w+


;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;% Macro qui fait une attente soit avec une succession de NOPs %
;% (FAST=1), soit en optimisant avec des instructions neutres  %
;% prenant plus de temps machine avec la mˆme taille	       %
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pause macro
t6 set (\1)/6
t5 set (\1-t6*6)/5
t4 set (\1-t6*6-t5*5)/4
t3 set (\1-t6*6-t5*5-t4*4)/3
t2 set (\1-t6*6-t5*5-t4*4-t3*3)/2
t1 set (\1-t6*6-t5*5-t4*4-t3*3-t2*2)
	dcb.w t6,$e188  ; lsl.l #8,d0        6
	dcb.w t5,$ed88  ; lsl.l #6,d0        5
	dcb.w t4,$e988  ; lsl.l #4,d0        4
	dcb.w t3,$1090  ; move.b (a0),(a0)   3
	dcb.w t2,$8080  ; or.l d0,d0         2
	dcb.w t1,$4e71  ; nop                1
	endm
   
 SECTION TEXT
  

; ------------------
;   Program start
; ------------------
ProgStart 
 	; We call the main routine in supervisor mode
	; and when we come back, we return to the caller 
	move.l #super_main,-(sp)
	move.w #$26,-(sp)         ; XBIOS: SUPEXEC
	trap #14
	addq.w #6,sp

	clr.w -(sp)               ; GEMDOS: PTERM(0)
	trap #1
 	

super_main
 	;
	; Save context
	;
	move.w #$2700,sr
	move.b $fffffa07.w,save_iera
	sf $fffffa07.w					; iera

	move.b $fffffa09.w,save_ierb
	sf $fffffa09.w					; ierb

	move.b $ffff8260.w,save_resol

 	move.b $ffff8201.w,save_screen_addr_1	; Screen base pointeur (STF/E)
 	move.b $ffff8203.w,save_screen_addr_2	; Screen base pointeur (STF/E)

	move.w $ffff8240.w,save_background

 	move.l $70.w,save_70					          ; Save original VBL handler
 	move.l #VblDoNothing,$70.w
	move.w #$2300,sr

	;
	; Set the screen at the right adress
	;
	lea $ffff8201.w,a0               	; Screen base pointeur (STF/E)
	move.l #screen_buffer+256,d0
	clr.b d0
	lsr.l #8,d0					        ; Allign adress on a byte boudary for STF compatibility
	movep.w d0,0(a0) 
	sf.b 12(a0)					        ; For STE low byte to 0


	;
	; Main loop
	;
	move.l #VblFlipFlop,$70.w
.loop
 	; We do the key check before the synchronisation to avoid wobbly rasters
 	cmp.b #$39,$fffffc02.w
	bne.s .loop

	;
	; Restore system
	;
 	move.w #$2700,sr

	move.b #0,YmDataAVolume
	bsr UpdateYM

 	move.l save_70,$70.w

	move.b save_iera,$fffffa07.w
	move.b save_ierb,$fffffa09.w
	move.b save_resol,$ffff8260.w

 	move.b save_screen_addr_1,$ffff8201.w
 	move.b save_screen_addr_2,$ffff8203.w

	move.w save_background,$ffff8240.w

	move.w #$2300,sr
	rts
 



VblFlipFlop
	movem.l d0-d7/a0-a6,-(sp)

	lea $ffff8240.w,a6

	move.w #$0,(a6)          ; Black top background

	lea Whatever,a0

	move.w ShiftPosition,d0	
	subq #1,ShiftCounter
	bne .skip
	move #50,ShiftCounter
	addq.w #2,d0
	and.w #15,d0
	move.w d0,ShiftPosition 
.skip

	; Do some weird noise with the YM using the current shift registers
	move.b d0,YmDataAFrequency
	move.b d0,YmDataNoiseFrequency
	bsr UpdateYM

	; Line zero synchronisation
	moveq #14,d2
.wait_sync
	move.b $ffff8209.w,d0
	beq.s .wait_sync
	sub.b d0,d2
	lsl.b d2,d0

	;bsr MindBender
	bsr MonoSlide

	movem.l (sp)+,d0-d7/a0-a6
VblDoNothing
	rte


UpdateYM
	rts ; no sound at the moment
	; Do some weird noise with the YM using the current shift registers
	lea YmData(pc),a0
	moveq #5-1,d0
.loop_ym
	move.b (a0)+,$ffff8800.w
	move.b (a0)+,$ffff8802.w
	dbra d0,.loop_ym 
	rts


ShiftCounter    dc.w 50
ShiftPosition 	dc.w 0

MonoSlide
	move.l #$0000FFFF,d6   ; Color of tile
	
	moveq #0,d1
	moveq #0,d2
	move ShiftPosition,d1
	sub.l d1,d2

	; Complete the top black line (+ offset to show the start)
	pause 25

	; The alternated color grid
	; d0 - trash register used by the "pause" macro and the various delays
	; d1 
	; d2 
	; d3
	; d4 - Contains the shifting offset increment
	; d5 - Contains the shifting offset
	; d6 - Contains the color of the tiles (each of the words has a different color)
	; d7 - Line counter

	; One direction
	moveq #0,d5
	bsr DrawBlackAndWhiteTiles
	move.l d1,d5
	bsr DrawBlackAndWhiteTiles
	nop
	bsr DrawBlackAndWhiteTiles
	move.l d2,d5
	bsr DrawBlackAndWhiteTiles
	nop
	bsr DrawBlackAndWhiteTiles
	move.l d1,d5
	bsr DrawBlackAndWhiteTiles
	nop
	bsr DrawBlackAndWhiteTiles
	move.l d2,d5
	bsr DrawBlackAndWhiteTiles
	nop
	bsr DrawBlackAndWhiteTiles
	nop
	bsr DrawLastSeparatorLine
	rts


DrawLastSeparatorLine
	; Intermediate line
	pause 64-6-1-4-3
	move.w #$333,(a6)             ; 12/3
	pause 128-3
	move.w #$000,(a6)             ; 12/3
	pause 114
	rts

DrawBlackAndWhiteTiles
	; Intermediate line
	pause 64-6-1-4-3
	move.w #$333,(a6)             ; 12/3
	pause 128-3
	move.w #$000,(a6)             ; 12/3
	pause 114

	; Shifting
	moveq #16,d0
	add.l d5,d0
	lsl.l d0,d0                   ; 6+2n

	; 16 lines of alternative black and white squares
	move.w #16-1,d7
.loop_squares
	REPT 15
	move.w d6,(a6)                ;    8/2   background color change
	swap d6                       ;    4/1
	nop                           ;    4/1
	move.w d6,(a6)                ;    8/2   background color change
	swap d6                       ;    4/1
	nop                           ;    4/1
	ENDR                          ; = 32/8
	pause 8-3
	dbra d7,.loop_squares          ; 12/3 if branches / 16/4 if not taken

	; Next black line
	move.w #$000,(a6)             ; 12/3
	pause 57+3
	rts             ; 16/4





MindBender
	; 366*3=1098
	; 274*4=1098

	; To leave room for the "Dbug" line
	; 64 nops*8 = 
	;move.w #138-1,d0
	move.w #157-1,d0
.delay
	subq.w #1,8(a6)
	dbra d0,.delay    ; 3

	; The alternated color grid
	moveq #7-1,d1 
.loop_lines
	; 247
	move.w #242-1,d0
.loop_squares
	move.w d6,(a6)                ; 8/2   background color change

	lsl.l #8,d3        		   	  ; 24/6 (DELAY)

	move.w d7,(a6)                ; 8/2    background color change

	move.w (a6),(a6) ;pause 3     ; (DELAY)

	dbra d0,.loop_squares          ; 12/3 if branches / 16/4 if not taken

	;pause 2                      ; (DELAY)
	addq #1,d6
	;addq #1,d7
	nop

	dbra d1,.loop_lines 
	rts


YmData
 dc.b 0
 dc.b 0                ; Channel A frequency (low byte)

 dc.b 1
YmDataAFrequency
 dc.b 0                ; Channel A frequency (high byte)

 dc.b 6
YmDataNoiseFrequency 
 dc.b 0                ; Noise generator frequency

 dc.b 7,%11110110      ; Enable Channel A tone and noise

 dc.b 8
YmDataAVolume
 dc.b 15             ; Channel A volume


	SECTION BSS

save_70      		ds.l 1	; VBL handler

save_background     ds.w 1 

save_iera			ds.b 1	; Interrupt enable register A
save_ierb			ds.b 1	; Interrupt enable register B
save_resol			ds.b 1	; Screen resolution
save_screen_addr_1 	ds.b 1
save_screen_addr_2 	ds.b 1

	even


Whatever	 ds.l 1
screen_buffer       ds.l (256+32000)/4


 end

