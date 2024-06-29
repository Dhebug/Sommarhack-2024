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


enable_proper_setup		equ 1     ; Enables the tabbed out code

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
 ifne enable_proper_setup
	; We call the main routine in supervisor mode
	; and when we come back, we return to the caller 
	move.l #super_main,-(sp)
	move.w #$26,-(sp)         ; XBIOS: SUPEXEC
	trap #14
	addq.w #6,sp

	clr.w -(sp)               ; GEMDOS: PTERM(0)
	trap #1
 else
	; We switch to supervisor, but never come back
	; so no need to correct the stack pointer
	clr.l -(sp)
	move.w #$20,-(sp)  ; GEMDOS: SUPER
	trap #1
 endc
	

super_main
 lea $ffff8240.w,a6
 move.l #$07770727,$ffff8242.w  ; The White and Purple crosses [Could be 2(a6) but same size]

 ifne enable_proper_setup
	;
	; Save context
	;
	move.b $fffffa07.w,save_iera
	move.b $fffffa09.w,save_ierb
	move.b $ffff8260.w,save_resol

	clr.w -(sp)
	pea -1.w
	pea -1.w
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp
 endc

  
	;
	; VSync and disable interrupts
	;
	move.w #37,-(sp)       ; VSYNC
	trap #14
 ifne enable_proper_setup
	addq.l #2,sp
 endc

	;
	; Main loop
	;
	move.w #$2700,sr
loop
	move.w #37,-(sp)       	 ; Vertical Synchronization (adds a 1/71th of a second delay)
	trap #14
	addq.l #2,sp

	move.w #$0,(a6)          ; Black top background
 
 ; We do the key check before the synchronisation to avoid wobbly rasters
 ifne enable_proper_setup
	cmp.b #$39,$fffffc02.w
	beq exit
 endc

	lea Whatever,a0

	move.w #$370,d6        ; Color of first tile
	move.w #$263,d7        ; Color of second tile
	move.w #$fff,8(a6)

	;add.w #1,ShiftOffset

	; Line zero synchronisation
	moveq #14,d2
.wait_sync
	move.b $ffff8209.w,d0
	beq.s .wait_sync
	sub.b d0,d2
	lsl.b d2,d0

	;bra MindBender
	bra MonoSlide

Whatever	 dc.l 0  
ShiftOffset  dc.w 8,8

MonoSlide
	move.l #$0000FFFF,d6   ; Color of tile

	move.l ShiftOffset,d5              ; Shifter 

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
	; d0 - trash register used by the "pause" macro and the various delays
	; d1 - sections counter
	; d2 - squares counter
	; d3 - alternate counter
	; d4
	; d5
	; d6 - Contains the color of the tiles (each of the words has a different color)
	; d7
	moveq #3-1,d3
.loop_alternate	
	moveq #3-1,d1 
.loop_lines
	; 247
	move.w #16-1,d2
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
	dbra d2,.loop_squares          ; 12/3 if branches / 16/4 if not taken

	; Intermediate line
	move.w #$000,(a6)             ; 12/3
	pause 128-3
	move.w #$333,(a6)             ; 12/3
	pause 128-3
	move.w #$000,(a6)             ; 12/3
	pause 128-3-1-2-2-1-1-4

	lsl.w d5,d0                   ; 6+2n

	dbra d1,.loop_lines 
	dbra d3,.loop_alternate	
	bra loop



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
	bra loop

exit

 ;
 ; Restore system
 ;
 ifne enable_proper_setup
	move.w #$2700,sr

	moveq #0,d0
	move.b save_resol,d0
	move.w d0,-(sp)
	pea -1.w
	pea -1.w
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	move.b save_iera,$fffffa07.w
	move.b save_ierb,$fffffa09.w
	move.b save_resol,$ffff8260.w

	move.w #$700,$ffff8242.w
	move.w #$000,$ffff8244.w
	move.w #$000,$ffff8246.w

	move.w #$777,$ffff8240.w

	move.w #$2300,sr
	rts
 endc


 
 ifne enable_proper_setup

	SECTION BSS

save_iera			ds.b 1	; Interrupt enable register A
save_ierb			ds.b 1	; Interrupt enable register B
save_resol			ds.b 1	; Screen resolution

 endc

 end

