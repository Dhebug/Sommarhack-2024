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

enable_music  equ 0

alignment_marker equ $770     ; $770 Yellow is nice to tweak positions, but sucks when it's visible on screen


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

  ifne enable_music
	jsr Music+4             ; Stop music
	jsr YmSilent
  endc
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
	jsr HandleDemoTrack

 ifne enable_music
	moveq #1,d0             ; Subtune number
	jsr Music+0             ; Init music
  endc

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

snval			dc.w	0

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

	;
	; Demo part is here
	;
	movem.l d0-d7/a0-a6,-(sp)

	lea $ffff8240.w,a6
	lea Whatever,a0

	bsr DefenceForceLogo
_auto_jsr	
	jsr DoNothing

 ifne enable_music
	;move.w #$700,$ffff8240.w
	jsr Music+8             ; Play music
	;move.w #$333,$ffff8240.w
 endc 

	jsr HandleDemoTrack

	movem.l (sp)+,d0-d7/a0-a6

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

DoNothing
	rts


HandleDemoTrack
	subq.l #1,DemoTrackCounter
	bne .continue
	move.l DemoTrackPtr,a0
	move.l (a0)+,DemoTrackCounter
	bmi exit                              ; Negative value to quit
	bne .not_the_end
	lea DemoTrackPartList,a0
	move.l (a0)+,DemoTrackCounter
.not_the_end	
	move.l (a0)+,_auto_jsr+2
	move.l (a0)+,._auto_init+2
	move.l a0,DemoTrackPtr
._auto_init
	jsr InitCredits	
.continue	
	rts


DemoTrackCounter	dc.l 1
DemoTrackPtr		dc.l DemoTrackPartList

; MARK: Track List
; Number of frames, part
DemoTrackPartList
	dc.l 50*2,DisplayRasters,DoNothing
	dc.l 0

	; Wait a second or so before starting
	dc.l 50*2,DoNothing,DoNothing

	; Display the title scrolling horizontally
	dc.l 40,DisplayTitleMove,InitTitle
	dc.l 50*5,DisplayTitleStatic,DoNothing
	dc.l 40,DisplayTitleMove,DoNothing

	; Display the bouncing bomb #1
	dc.l 50*5,SurpriseBomb,DoNothing

	; Display the made in 5 days
	dc.l 40,DisplayMadeIn5DaysMove,InitMadeIn5Days
	dc.l 50*5,DisplayMadeIn5DaysStatic,DoNothing
	dc.l 40,DisplayMadeIn5DaysMove,DoNothing

	; Display the credits scrolling vertically
	dc.l 18,DisplayCreditsMove,InitCredits
	dc.l 50*5,DisplayCreditsStatic,DoNothing
	dc.l 18,DisplayCreditsMove,DoNothing

	; Display the Mono Slide scrolling diagonally
	dc.l 40,DisplayMonoSlideMove,InitMonoSlide
	dc.l 50*5,DisplayMonoSlideStatic,DoNothing
	dc.l 40,DisplayMonoSlideMove,DoNothing

	; Display the Mono Slide effect
	dc.l 50*10,MonoSlide,DoNothing

	; Display the slide show scrolling horizontally
	dc.l 40,DisplaySlideShowMove,InitSlideShow
	dc.l 50*4,DisplaySlideShowStatic,DoNothing     ; First picture
	dc.l 40,DisplaySlideShowMove,DoNothing
	dc.l 50*4,DisplaySlideShowStatic,DoNothing     ; Second picture
	dc.l 40,DisplaySlideShowMove,DoNothing
	dc.l 50*4,DisplaySlideShowStatic,DoNothing     ; Third picture
	dc.l 40,DisplaySlideShowMove,DoNothing
	dc.l 50*4,DisplaySlideShowStatic,DoNothing     ; Fourth picture
	dc.l 40,DisplaySlideShowMove,DoNothing

	; Display the vertical greetings lists
	dc.l 486-18,DisplayGreetings,InitGreetings

	; Display the Mind Bender scrolling diagonally
	dc.l 40,DisplayMindBenderMove,InitMindBender
	dc.l 50*5,DisplayMindBenderStatic,DoNothing
	dc.l 40,DisplayMindBenderMove,DoNothing

	; Display the Mind Bender effect
	dc.l 50*10,MindBender,DoNothing
	
	; Display the end
	dc.l 216,DisplayTheEndMove,InitTheEnd
	dc.l 50*5,DisplayTheEndStatic,DoNothing
	dc.l 216,DisplayTheEndMove,DoNothing

	dc.l -1   ; Back to desktop



; MARK: MonoSlide
MonoSlide
	move.l #$0000FFFF,d6   ; Color of tile
	
	moveq #0,d1
	moveq #0,d2
	move ShiftPosition,d1
	sub.l d1,d2

	; Complete the top black line (+ offset to show the start)
	pause 128-20-20-20-20-16

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

	move.l d1,d5
	bsr DrawBlackAndWhiteTiles
	nop
	bsr DrawBlackAndWhiteTiles

	bsr DrawLastSeparatorLine

	; Variable time here
	move.w ShiftPosition,d0	
	subq #1,ShiftCounter
	bne .skip
	move #50,ShiftCounter
	addq.w #2,d0
	and.w #15,d0
	move.w d0,ShiftPosition 
.skip
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
	move.w #$703,d5        ; Color of the marker
 	move.w #$370,d6        ; Color of first tile
 	move.w #$263,d7        ; Color of second tile

	; The alternated color grid
	pause 24+64+20
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
	;bsr DrawGradientColorTilesFlop
	;addq #1,d6

	move.w #$000,(a6)              ; Black at the end
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
SurpriseBomb
 	lea DbugSurprise80x80,a0
	add.l SurpriseBombOffset,a0
	move.w #80*2,d7
	bsr Display40x18Picture

	; Variable time
	; See about 33 tiles horizontally, about 18 tiles vertically
	move.w SurpriseBombXPos,d0
	add.w SurpriseBombXDir,d0
	bpl .no_left_bounce
	sub.w SurpriseBombXDir,d0
	neg.w SurpriseBombXDir
.no_left_bounce

	cmp.w #80-33,d0
	ble .no_right_bounce
	sub.w SurpriseBombXDir,d0
	neg.w SurpriseBombXDir
.no_right_bounce
	move.w d0,SurpriseBombXPos


	move.w SurpriseBombYPos,d1
	add.w SurpriseBombYDir,d1
	bpl .no_top_bounce
	sub.w SurpriseBombYDir,d1
	neg.w SurpriseBombYDir
.no_top_bounce

	cmp.w #80-18,d1
	ble .no_bottom_bounce
	sub.w SurpriseBombYDir,d1
	neg.w SurpriseBombYDir
.no_bottom_bounce
	move.w d1,SurpriseBombYPos


	ext.l d0
	add.l d0,d0
	move.l d0,SurpriseBombOffset

	mulu #80*2,d1
	add.l d1,SurpriseBombOffset

	rts

SurpriseBombOffset 		dc.l 0

SurpriseBombXPos        dc.w 0
SurpriseBombXDir        dc.w 1

SurpriseBombYPos        dc.w 0
SurpriseBombYDir        dc.w 1




; MARK: Picture Top
DefenceForceLogoOffset	dc.w 0

DefenceForceLogo
	pause 14-4

 	lea DefenceForce320x5,a0
	move DefenceForceLogoOffset,d0
	and #512*2-1,d0
	add DefenceForceLogoOffset,a0
	add #2,d0
	move d0,DefenceForceLogoOffset

	REPT 6

	; First lines
	REPT 7
	move.l a0,a1       ; 4/1
	move.w #alignment_marker,(a6)  ; 12/3
	REPT 40
	move.w (a1)+,(a6)  ; 12/3
	ENDR               ; 40*3=120
	pause 4
	ENDR

	; Skip to next line
	move.l a0,a1       ; 4/1
	move.w #alignment_marker,(a6)  ; 12/3
	REPT 40
	move.w (a1)+,(a6)  ; 12/3
	ENDR               ; 40*3=120
	pause 4-2
	lea 512*2(a0),a0    ; 16/4

	ENDR
 
	move.w #0,(a6)   ; Final black marker
	rts



; MARK: Picture 5 days
MadeIn5DaysPosition	dc.l 0

InitMadeIn5Days
 	move.l #MadeIn5Days,MadeIn5DaysPosition
	rts

DisplayMadeIn5DaysMove
 	move.l MadeIn5DaysPosition,a0
	move.w #120*2,d7
	bsr Display40x18Picture
	add.l #2,MadeIn5DaysPosition
	rts

DisplayMadeIn5DaysStatic
 	move.l MadeIn5DaysPosition,a0
	move.w #120*2,d7
	bsr Display40x18Picture
	rts



; MARK: Picture Title
TitlePosition	dc.l 0

InitTitle	
 	move.l #Title,TitlePosition
	rts

DisplayTitleMove
 	move.l TitlePosition,a0
	move.w #120*2,d7
	bsr Display40x18Picture
	add.l #2,TitlePosition
	rts

DisplayTitleStatic
 	move.l TitlePosition,a0
	move.w #120*2,d7
	bsr Display40x18Picture
	rts


; MARK: Picture Credits
CreditsPosition	dc.l 0

InitCredits
 	move.l #Credits,CreditsPosition
	rts

DisplayCreditsMove
 	move.l CreditsPosition,a0
	move.w #40*2,d7
	bsr Display40x18Picture
	add.l #40*2,CreditsPosition
	rts

DisplayCreditsStatic
 	move.l CreditsPosition,a0
	move.w #40*2,d7
	bsr Display40x18Picture
	rts


; MARK: Picture Mind
MindBenderPosition	dc.l 0

InitMindBender
 	move.l #PictureMindBender,MindBenderPosition
	rts

DisplayMindBenderMove
 	move.l MindBenderPosition,a0
	move.w #120*2,d7
	bsr Display40x18Picture
	add.l #120*2+2,MindBenderPosition
	rts

DisplayMindBenderStatic
 	move.l MindBenderPosition,a0
	move.w #120*2,d7
	bsr Display40x18Picture
	rts


; MARK: Picture Mono
MonoSlidePosition	dc.l 0

InitMonoSlide
 	move.l #PictureMonoSlide,MonoSlidePosition
	rts

DisplayMonoSlideMove
 	move.l MonoSlidePosition,a0
	move.w #120*2,d7
	bsr Display40x18Picture
	add.l #120*2+2,MonoSlidePosition
	rts

DisplayMonoSlideStatic
 	move.l MonoSlidePosition,a0
	move.w #120*2,d7
	bsr Display40x18Picture
	rts


; MARK: Picture Greets
greetingsPosition	dc.l 0

InitGreetings
 	move.l #Greetings,greetingsPosition   ; 40x486
	rts

DisplayGreetings
 	move.l greetingsPosition,a0
	move.w #40*2,d7
	bsr Display40x18Picture
	add.l #40*2,greetingsPosition
	rts


; MARK: Display Picture
; 40x18 picture made of 16x12 pixels -> About 384x216 pixels
Display40x18Picture
	pause 100

	REPT 18

	; First lines
	REPT 11
	move.l a0,a1       ; 4/1
	REPT 40
	move.w (a1)+,(a6)  ; 12/3
	ENDR               ; 40*3=120
	pause 4+3
	ENDR

	; Skip to next line
	move.l a0,a1       ; 4/1
	REPT 40
	move.w (a1)+,(a6)  ; 12/3
	ENDR               ; 40*3=120
	pause 4+3-2
	add d7,a0          ;  8/2 ; 16/4

	ENDR
	move.w #0,(a6)   ; Final black marker
	rts


; MARK: Slideshow
SlideShowPosition	dc.l 0

InitSlideShow
 	move.l #PictureSlideShow,SlideShowPosition
	rts

DisplaySlideShowMove
 	move.l SlideShowPosition,a1
	move.w #200*2,d7
	bsr DisplayHighResPicture
	add.l #2,SlideShowPosition
	rts

DisplaySlideShowStatic
 	move.l SlideShowPosition,a1
	move.w #200*2,d7
	bsr DisplayHighResPicture
	rts

; MARK: Slideshow
TheEndPosition	dc.l 0

InitTheEnd
 	move.l #PictureTheEnd,TheEndPosition
	rts

DisplayTheEndMove
 	move.l TheEndPosition,a1
	move.w #0,d7
	bsr DisplayHighResPicture
	add.l #40*2,TheEndPosition
	rts

DisplayTheEndStatic
 	move.l TheEndPosition,a1
	move.w #0,d7
	bsr DisplayHighResPicture
	rts


; MARK: Display Highrez
DisplayHighResPicture	
	pause 100

	move.w #216-1,d6
.loop	
	move.w #alignment_marker,(a6)
	REPT 40
	move.w (a1)+,(a6)  ; 12/3
	ENDR               ; 40*3=120
	;pause 2
	add d7,a1          ;  8/2 ; 16/4
	dbra d6,.loop
	move.w #0,(a6)   ; Final black marker
	rts


; MARK: Display rasters
DisplayRasters
	pause 100 ;+20

	lea RastersBuffer,a0

	move.w #216-1,d6
.loop	
	move.w #alignment_marker,(a6)
	move.w (a0)+,(a6)  ; 12/3
	pause 2+39*3
	dbra d6,.loop
	move.w #0,(a6)   ; Final black marker

	; Generate rasters
	lea sine_255,a6

 ifne 0
	; Erase raster buffer
	lea RastersBuffer,a0
	moveq #0,d0
	moveq #0,d1
	moveq #0,d2
	moveq #0,d3
	moveq #216*2/16-1,d7
.clear
	move.l d0,(a0)+
	move.l d1,(a0)+
	move.l d2,(a0)+
	move.l d3,(a0)+
	dbra d7,.clear
 endc	

	; Draw the curtains
	; 216/32=6.75
	; 216/16=13.5
	; 216/8=27
	move.w CurtainRasterOffset,d0
	add.w #2,d0
	and.w #64*2-1,d0
	move.w d0,CurtainRasterOffset

	lea RastersBuffer,a0
	lea CurtainRaster,a1
	add.w d0,a1
	REPT 8
	move.l (a1),12*32(a0)
	move.l (a1),11*32(a0)
	move.l (a1),10*32(a0)
	move.l (a1),9*32(a0)
	move.l (a1),8*32(a0)
	move.l (a1),7*32(a0)
	move.l (a1),6*32(a0)
	move.l (a1),5*32(a0)
	move.l (a1),4*32(a0)
	move.l (a1),3*32(a0)
	move.l (a1),2*32(a0)
	move.l (a1),1*32(a0)
	move.l (a1)+,(a0)+
	ENDR


	; Draw the bouncing rasters
	; The sinus table goes from 0 to 128, so need to center on the buffer
	lea RastersBuffer,a0

	; Wobble the center axis
	move.w RasterPositionAngle,d0
	add.w #2,d0
	and.w #510,d0
	move.w d0,RasterPositionAngle
	move.w (a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	lsr.w #1,d1         ; 00 to 63
	add.w d1,d1
	add.w d1,a0

	move.w RasterAngle,d0
	add.w #8,d0
	and.w #510,d0
	move.w d0,RasterAngle

	; Blue
	lea BlueRaster,a1
	move.w 63*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR


	; Blue Cyan 
	lea BlueCyanRaster,a1
	move.w 56*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR

	; Cyan
	lea CyanRaster,a1
	move.w 48*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR

	; Cyan-Green
	lea CyanGreenRaster,a1
	move.w 40*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR

	; Green
	lea GreenRaster,a1
	move.w 32*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR

	; Lime
	lea LimeRaster,a1
	move.w 24*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR

	; Yellow
	lea YellowRaster,a1
	move.w 16*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR

	; Orange
	lea OrangeRaster,a1
	move.w 8*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR

	; Red
	lea RedRaster,a1
	move.w 0*2(a6,d0),d1   ; 16 bits, unsigned between 00 and 127
	add.w d1,d1
	lea (a0,d1),a5
	REPT 7
	move.l (a1)+,(a5)+
	ENDR

	rts

RasterPositionAngle
	dc.w 0

RasterAngle	
	dc.w 0

	ds.w 216
RastersBuffer
	ds.w 216
	ds.w 216


BlueRaster  	dc.w $001,$002,$003,$004,$005,$006,$007,$006,$000,$004,$003,$002,$001,$000	
BlueCyanRaster 	dc.w $011,$012,$023,$024,$035,$036,$047,$036,$035,$024,$023,$012,$011,$000	
CyanRaster   	dc.w $011,$022,$033,$044,$055,$066,$077,$066,$055,$044,$033,$022,$011,$000	
CyanGreenRaster dc.w $011,$021,$032,$042,$053,$063,$074,$063,$053,$042,$032,$021,$011,$000	
GreenRaster   	dc.w $010,$020,$030,$040,$050,$060,$070,$060,$050,$040,$030,$020,$010,$000	
LimeRaster   	dc.w $010,$120,$130,$240,$350,$460,$470,$460,$350,$240,$130,$120,$010,$000	
YellowRaster   	dc.w $110,$220,$330,$440,$550,$660,$770,$660,$550,$440,$330,$220,$110,$000	
OrangeRaster   	dc.w $100,$210,$310,$420,$520,$630,$730,$630,$520,$420,$310,$210,$100,$000	
RedRaster   	dc.w $100,$200,$300,$400,$500,$600,$700,$600,$500,$400,$300,$200,$100,$000	
  dc.w $777

CurtainRasterOffset
	dc.w 0

CurtainRaster	; About 32 lines
	; Black
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	; Color
	dc.w $000
	dc.w $100
	dc.w $200
	dc.w $300
	dc.w $400
	dc.w $500
	dc.w $600
	dc.w $700
	dc.w $710
	dc.w $720
	dc.w $730
	dc.w $740
	dc.w $750
	dc.w $760
	dc.w $770
	dc.w $771
	dc.w $772
	dc.w $773
	dc.w $774
	dc.w $775
	dc.w $776
	dc.w $777
	dc.w $666
	dc.w $555
	dc.w $444
	dc.w $333
	dc.w $222
	dc.w $111
	; Black
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000
	dc.w $000


; MARK: - DATA -
	SECTION DATA

DbugSurprise80x80
	incbin "export\surprise.bin"

DefenceForce320x5
	incbin "export\top_banner.bin"
	ds.w 512

MadeIn5Days
	incbin "export\made_in_5_days.bin"

Credits
	incbin "export\credits.bin"

Greetings
	incbin "export\greetings.bin"

Title
	incbin "export\title.bin"
	
PictureMindBender
	incbin "export\mind_bender.bin"

PictureMonoSlide
	incbin "export\mono_slide.bin"

PictureSlideShow
	incbin "export\slide_show.bin"

PictureTheEnd
	incbin "export\the_end.bin"

sine_255				; 16 bits, unsigned between 00 and 127
	incbin "export\sine_255.bin"
	incbin "export\sine_255.bin"
	incbin "export\sine_255.bin"
	incbin "export\sine_255.bin"


Music
	incbin "musics\SOS.SND"

	even

ShiftCounter    dc.w 50
ShiftPosition 	dc.w 0


; MARK: - BSS -
	SECTION BSS

	even

bss_start:

settings        ds.b    256
screen_buffer	ds.b	160*276+256

	even

Whatever	 		ds.l 1

	end

 