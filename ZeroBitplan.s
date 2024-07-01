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
; Credits:
; - Top Border synchronisation code by Zerkman / Sector One
; - Effects by Dbug
; - Music by someone else
;




; MARK: Macros
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
;  MARK: Program start
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
	move.l sp,usp
	bsr SaveSettings
	bsr Initialization
.loop_forever
	bra.s	.loop_forever		; infinite wait loop


exit
	move	#$2700,sr
	move.l	usp,sp
	bsr RestoreSettings
	move	#$2300,sr
	rts

SaveSettings
	lea settings,a0
	move.l	$ffff8200.w,(a0)+
	move.b	$ffff820a.w,(a0)+
	move.b	$ffff8260.w,(a0)+
	move.l	$68.w,(a0)+
	move.l	$70.w,(a0)+
	move.l	$120.w,(a0)+
	move.l	$134.w,(a0)+
	move.b	$fffffa07.w,(a0)+
	move.b	$fffffa09.w,(a0)+
	movem.l $ffff8240.w,d1-d7/a1
	movem.l d1-d7/a1,(a0)
	rts


RestoreSettings
	lea settings,a0
	move.l	(a0)+,$ffff8200.w
	move.b	(a0)+,$ffff820a.w
	move.b	(a0)+,$ffff8260.w
	move.l	(a0)+,$68.w
	move.l	(a0)+,$70.w
	move.l	(a0)+,$120.w
	move.l	(a0)+,$134.w
	move.b	(a0)+,$fffffa07.w
	move.b	(a0)+,$fffffa09.w
	movem.l (a0)+,d1-d7/a1
	movem.l d1-d7/a1,$ffff8240.w
	clr.b	$fffffa19.w
	clr.b	$ffff820a.w

	jsr Music+4             ; Stop music
	jsr YmSilent
	rts


SetScreen
	lea $ffff8201.w,a0               	; Screen base pointeur (STF/E)
	move.l #screen_buffer+256,d0
	clr.b d0
	lsr.l #8,d0					        ; Allign adress on a byte boudary for STF compatibility
	movep.w d0,0(a0) 
	sf.b 12(a0)					        ; For STE low byte to 0
	rts


YmSilent
	move.b #8,$ffff8800.w		; Volume register 0
	move.b #0,$ffff8802.w      	; Null volume
	move.b #9,$ffff8800.w		; Volume register 1
	move.b #0,$ffff8802.w      	; Null volume
	move.b #10,$ffff8800.w		; Volume register 2
	move.b #0,$ffff8802.w      	; Null volume
	rts


Initialization
	bsr SetScreen
	
	moveq #1,d0             ; Subtune number
	jsr Music+0             ; Init music

	clr.b	$fffffa07.w		; iera
	clr.b	$fffffa09.w		; ierb

	bset	#5,$fffffa07.w	; activate timer A
	bset	#5,$fffffa13.w	; unmask timer A
	bset	#0,$fffffa07.w	; activate timer B
	bset	#0,$fffffa13.w	; unmask timer B

	clr.b	$fffffa19.w		; timer A - stop
	clr.b	$fffffa1b.w		; timer B - stop
	lea	timer_a_cfg(pc),a0
	move.l	a0,$134.w
	lea	timer_b(pc),a0
	move.l	a0,$120.w

	lea	hbl(pc),a0
	move.l	a0,$68.w
	lea	vbl(pc),a0
	move.l	a0,$70.w

	moveq	#0,d0
	lea	$ffff820a.w,a0
	lea	$ffff8260.w,a1
	stop	#$2300
	move.b	d0,(a1)
	move	a0,(a0)
	rts



vbl:
	clr.b	$fffffa19.w				; timer A - stop
decale:	move.b	#$c2,$fffffa1f.w	; timer A - set counter
	move.b	#4,$fffffa19.w			; timer A - delay mode,divide by 50
	clr.b	$fffffa1b.w				; timer B - stop
	move.b	#228,$fffffa21.w		; timer B - set counter
	;move.b	#199,$fffffa21.w	; timer B - set counter
	move.b	#8,$fffffa1b.w	; timer B - event count mode

	cmp.b	#$39,$fffffc02.w
	beq	exit
	rte

hbl:
	rte

; On first frame, record HBL delay for lines 62 to 66.
; Since the delay is periodic every 5 lines, delay for lines 62-66
; is the same as lines 32-36 and line 32 is that which we use for
; synchronisation before we open the border between lines 32 and 33.
timer_a_cfg:
	clr.b	$fffffa19.w
	bclr.b	#5,$fffffa0f.w
	move	#$2300,sr

	moveq	#0,d5
	moveq	#12,d3
	moveq	#4,d2
	stop	#$2100
tacglp:
	stop	#$2100
	moveq	#0,d4
	move.b	$ffff8209.w,d4
	sub.b	d3,d4
	subq	#4,d4
	neg	d4
	add.b	#$a0,d3
	lsr	#2,d5
	lsl	#7,d4
	or	d4,d5
	dbra	d2,tacglp

	lea	snval(pc),a2
	move	d5,(a2)
	lea	decale+3(pc),a2
	move.b	#100,(a2)
	lea	timer_a(pc),a2
	move.l	a2,$134.w

	bsr	nextshift

	rte

; Shift HBL sync delays so the next delay is the (nth+3) mod 5
nextshift:
	lea	snval(pc),a2
	move	(a2),d2
	moveq	#$3f,d3
	and	d2,d3
	lsl	#4,d3
	lsr	#6,d2
	or	d3,d2
	move	d2,(a2)

	rts

timer_a:
	clr.b	$fffffa19.w	; timer A - stop
	bclr.b	#5,$fffffa0f.w
	stop	#$2100
	stop	#$2100
	move	#$2300,sr

; sync using the HBL delays table
	moveq	#3,d0
	and	snval(pc),d0
	add	d0,d0
	lsr	d0,d0

 ifne 0
	dcb.w	90,$4e71
; Generic top border opening
	move.b	d0,(a0)	; LineCycles=488
	dcb.w	2,$4e71
	move	a0,(a0)	; LineCycles=504 - L16:16
 endc
	bsr	nextshift

	;bsr MonoSlide
	;bsr SurpriseBomb
	bsr MindBender

	move.w #$700,$ffff8240.w
	jsr Music+8             ; Play music
	move.w #$333,$ffff8240.w


	bclr.b	#5,$fffffa0f.w
	rte

timer_b:
	clr.b	$fffffa1b.w	; timer B - stop
	movem.l	d0-d1,-(sp)
	move.b	$ffff8209.w,d0
tbwbc:
	move.b	$ffff8209.w,d1
	cmp.b	d0,d1
	beq.s	tbwbc
	sub.b	d1,d0
	lsr.l	d0,d0		; now we're on sync with display
	rept	51
	nop
	endr
	move.b	#44,$fffffa21.w	; timer B - set counter
	move.b	#8,$fffffa1b.w	; timer B - event count mode
	clr.b	$ffff820a.w
	rept	6
	nop
	endr
	move.b	#2,$ffff820a.w
	movem.l	(sp)+,d0-d1
	
	bclr.b	#0,$fffffa0f.w
	rte



; MARK: MonoSlide
MonoSlide
	movem.l d0-d7/a0-a6,-(sp)
	lea $ffff8240.w,a6
	lea Whatever,a0

	move.w ShiftPosition,d0	
	subq #1,ShiftCounter
	bne .skip
	move #50,ShiftCounter
	addq.w #2,d0
	and.w #15,d0
	move.w d0,ShiftPosition 
.skip

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

	movem.l (sp)+,d0-d7/a0-a6
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




; MARK: MindBender
MindBender
	movem.l d0-d7/a0-a6,-(sp)
	lea $ffff8240.w,a6
	lea Whatever,a0

	move.w #$703,d5        ; Color of the marker
 	move.w #$370,d6        ; Color of first tile
 	move.w #$263,d7        ; Color of second tile

	; The alternated color grid
	pause 64-20-10-8-2
	bsr DrawGradientColorTilesFlip
	addq #1,d6
	bsr DrawGradientColorTilesFlop
	addq #1,d6
	bsr DrawGradientColorTilesFlip
	addq #1,d6
	bsr DrawGradientColorTilesFlop
	addq #1,d6
	bsr DrawGradientColorTilesFlip
	addq #1,d6
	bsr DrawGradientColorTilesFlop
	addq #1,d6
	bsr DrawGradientColorTilesFlip
	addq #1,d6
	bsr DrawGradientColorTilesFlop
	addq #1,d6

	move.w #$000,(a6)              ; Black at the end

	movem.l (sp)+,d0-d7/a0-a6
	rts


DrawGradientColorTilesFlip
	; Top line with the red marker
	REPT 7
	move.w d5,(a6)
	move.w d6,(a6)                ;    8/2   background color change
	pause 6-2
	move.w d5,(a6)
	move.w d7,(a6)                ;    8/2   background color change
	pause 6-2
	ENDR                          ; = 32/8
	pause 8
	move.w #$700,(a6)

	moveq #30-1,d2
.loop_squares
	pause 5
	REPT 7
	move.w d6,(a6)                ;    8/2   background color change
	pause 6
	move.w d7,(a6)                ;    8/2   background color change
	pause 6
	ENDR                          ; = 32/8
	pause 5
	move.w #$700,(a6)
	dbra d2,.loop_squares          ; 12/3 if branches / 16/4 if not taken

	; One last line with the red marker
	pause 4-1
	REPT 7
	move.w d5,(a6)
	move.w d6,(a6)                ;    8/2   background color change
	pause 6-2
	move.w d5,(a6)
	move.w d7,(a6)                ;    8/2   background color change
	pause 6-2
	ENDR                          ; = 32/8
	pause 6
	rts             ; 16/4

DrawGradientColorTilesFlop
	; Top line with the red marker
	REPT 7
	move.w d5,(a6)
	move.w d7,(a6)                ;    8/2   background color change
	pause 6-2
	move.w d5,(a6)
	move.w d6,(a6)                ;    8/2   background color change
	pause 6-2
	ENDR                          ; = 32/8
	pause 8
	move.w #$700,(a6)

	moveq #30-1,d2
.loop_squares
	pause 5
	REPT 7
	move.w d7,(a6)                ;    8/2   background color change
	pause 6
	move.w d6,(a6)                ;    8/2   background color change
	pause 6
	ENDR                          ; = 32/8
	pause 5
	move.w #$700,(a6)
	dbra d2,.loop_squares          ; 12/3 if branches / 16/4 if not taken

	; One last line with the red marker
	pause 4-1
	REPT 7
	move.w d5,(a6)
	move.w d7,(a6)                ;    8/2   background color change
	pause 6-2
	move.w d5,(a6)
	move.w d6,(a6)                ;    8/2   background color change
	pause 6-2
	ENDR                          ; = 32/8
	pause 6
	rts             ; 16/4


; MARK: Surprise
;
; move.w #$xxx,(a6)   ; 12   512/12 = 42.666 blocs
; move.w (a0)+,(a6)   ; 12 
; move.w dn,(a6)      ; 8    512/8 = 64 blocs
SurpriseBomb
	movem.l d0-d7/a0-a6,-(sp)
	lea $ffff8240.w,a6
	lea Whatever,a0

	pause 64-20-10

 	lea DbugSurprise80x80+160*20+2*20,a0
	REPT 33

	; First lines
	REPT 7
	move.l a0,a1       ; 4/1
	move.w #$770,(a6)  ; 12/3
	REPT 40
	move.w (a1)+,(a6)  ; 12/3
	ENDR               ; 40*3=120
	pause 4
	ENDR

	; Skip to next line
	move.l a0,a1       ; 4/1
	move.w #$770,(a6)  ; 12/3
	REPT 40
	move.w (a1)+,(a6)  ; 12/3
	ENDR               ; 40*3=120
	pause 4-2
	lea 80*2(a0),a0    ; 16/4

	ENDR

 
	move.w #0,(a6)   ; Final black marker
	movem.l (sp)+,d0-d7/a0-a6
	rts


	SECTION DATA

DbugSurprise80x80
	incbin "surprise.bin"

Music
	incbin "musics\SOS.SND"

	even

ShiftCounter    dc.w 50
ShiftPosition 	dc.w 0


	SECTION BSS

	even

bss_start:

snval			ds.w	1
settings        ds.b    256
screen_buffer	ds.b	160*276+256

	even

Whatever	 		ds.l 1

	end

 