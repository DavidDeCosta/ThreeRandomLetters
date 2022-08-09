;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;STACK SEGMENT
MyStack SEGMENT STACK

	DW 256 DUP (?)
	

MyStack ENDS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;DATA SEGMENT
MyData SEGMENT

	ScreenMemSeg EQU 0B800h        ; Segment for video RAM.
	startTicks DW 0
	origList DB 3 DUP (?)
	dupList DB 3 DUP (?)
	seed DW 0
	delayTick DW 0
	correctCounter DW 0
	typingPosition DW 0
	

MyData ENDS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;CODE SEGMENT
MyCode SEGMENT
	ASSUME CS:MyCode, DS:MyData

mainProg PROC

    MOV AX, MyData                    ; Make DS address our data segment
	MOV DS, AX                        ; DS points to the data
    MOV AX, ScreenMemSeg              ; Make ES segment register address video memory.
    MOV ES, AX
	MOV typingPosition, (160*16)
	
	
	CALL ClearScreen
	CALL waitRandomTime
	MOV AH, 00h
	INT 1Ah                            ; CX:DX contains the tick count
	MOV startTicks, DX                 ; startTicks now holds the tick count
	MOV seed, DX                       ;seed also holds the tick count
	CALL randomChar
	CALL displayChars
	
	myLoop:
		CALL displayElapsedTime
		MOV AH, 11h                   ;checks the buffer
		INT 16h                       ; calls the interupt
		JZ myLoop                     ;if nothing is in buffer keep checking
		MOV AH, 10H                   ; puts the char into AL
		INT 16h                       ; calls the function
		CMP AL, 27                    ; if it is escape end the program
		JE endProgram
		CALL checkList                ;proc will see if the Char is in our list, if it is.. char is displayed
		MOV CX, correctCounter        ; CX holds how many right chars have been typed
		CMP CX, 3                     ;Have they typed 3 right in a row?
		JE endProgram                 ; If so, they win Exit Program!
		JMP myLoop
		
	endProgram:
	
	MOV     AH, 4Ch                  ; These two instructions use a DOS interrupt which
    INT     21h                      ; "calls" a kernel routine to release the memory for
                                     ; this program and then return control to DOS.
                                     ; This is the logical end of the program.
	
mainProg ENDP

processKey PROC
;on entry: al contains the char to display
;on exit: all registers preserved
	PUSH AX SI
	
	MOV SI, typingPosition
	MOV AH, 00000010b              ; makes The char show up green
	MOV ES:[SI], AX                      ;display the char on screen
	ADD typingPosition, 4
	
	POP SI AX
	RET
processKey ENDP

checkList PROC
;on entry: AL contains a char to compare and possibly display
;on exit: registers preserved, correct counter either reset or incremented
	PUSH AX CX SI DI

	MOV CX, correctCounter             ; CX will be 0 to begin with
	CMP AL, dupList
	JE foundItZero
	CMP AL, dupList + 1
	JE foundItOne
	CMP AL, dupList + 2
	JE founditTwo
	JNE notFound
	
	foundItZero:
		INC correctCounter
		MOV [dupList], 0                    ; makes that spot  0
		CALL processKey                     ;display the Char pressed
		JMP endofProc
		
	foundItOne:
		INC correctCounter
		MOV [dupList+1], 0
		CALL processKey
		JMP endofProc
		
	founditTwo:
		INC correctCounter
		MOV [dupList+2], 0
		CALL processKey
		JMP endofProc
		
	notFound:

		MOV DI, (160*16)
		MOV AX, 0720h
		MOV CX,80
		CLD
		REP STOSW                         ;clear the line
		MOV typingPosition, (160*16)
		MOV correctCounter, 0             ;sets our correct counter back to 0
		CALL reCopyList                    ; copies back over the list

		
	endofProc:
	
		
	POP DI SI CX AX
	RET
checkList ENDP

reCopyList PROC
;on entry: original list holds the chars
;on exit: both the original list and dupList contain the chars
	PUSH SI AX CX BX

	MOV SI,0
	MOV CX,3
	copyLoop:
	MOV BL, [origList+SI]
	MOV [dupList+SI], BL
	INC SI
	LOOP copyLoop                  ;copies over chars 3 times to the dupList

	POP BX CX AX SI
	RET
reCopyList ENDP

ClearScreen PROC
;on entry: stuff is on the screen
;on exit: the screen is cleared

	PUSH DI AX CX SI
	MOV DI,0                        ;start upper left corner
	MOV AX, 0720h
	MOV CX, 2000                    ;the number of times to loop
	CLD                            ; clear direction flag
	REP STOSW                      ;repeat 2,000 times
	
	POP SI CX AX DI
	RET
ClearScreen ENDP

displayElapsedTime PROC
;on entry:
;		 ES points to screen memory
;on exit:
;        All registers are preserved

	PUSH DX AX CX DI BX
	MOV DI, (160*8 + 158)          ;to display the number on the 9th row on right side of screen
	MOV AH, 00h                    ;function to get number of ticks
	INT 1Ah                        ; returns CURRENT CX:DX clock count ' DX holds the number we want'
	MOV AX, startTicks             ;puts our starttick number into AX so we can run operations on it
	SUB DX, AX                    ;gets the elapsed ticks now stored in DX
	MOV AX, DX                    ;puts the elapsed time in AX
	MOV BX, 55
	MUL BX                       ;multipys AX by 55 'to make up for the one timer tick'
	MOV BX, 100
	DIV BX                       ;DX:AX now hold the number to display should be in format 'xx.xx'
	
	MOV BX, 10                      ;to let us show one char at a time
	MOV DX, 0                       ; clear the remainder
	DIV BX                         ;DX hold the remainder  AX holds quotient
	ADD DL, '0'                    ;turns the number into an ascii char
	MOV ES:[DI], DL                ;displays the far right number 'tenths place' of the ticks
	SUB DI, 2                      ;back up screen postion to display the number in correct order
	MOV ES:[DI], BYTE PTR '.'
	SUB DI, 2

showLoop:
    MOV BX, 10                      ;to let us show one char at a time
	MOV DX, 0                       ; clear the remainder
	DIV BX                         ;DX hold the remainder  AX holds quotient
	ADD DL, '0'                    ;turns the number into an ascii char
	MOV ES:[DI], DL                ;displays the far right number 'tenths place' of the ticks
	SUB DI, 2                      ;back up screen postion to display the number in correct order
	CMP AX, 0                      ;; is there more to display? if so repeat
	JA showLoop
	
	POP BX DI CX AX DX
	RET
displayElapsedTime ENDP

ShowNum PROC
;on entry:
;         AX contqains unsigned value to display
;         ES:[DI] points to screen location for Least common denominator
;on exit:
;        All registers are preserved

	PUSH AX BX DX DI CX
	MOV BX, 10                                      ; To divide by 10
	MOV DI, (160*10 + 158)                          ;line 11 all the way to the right side of screen
	
showNumLoop:
	MOV DX, 0                                       ;makes sure DX is clear
	DIV BX                                          ; (DX:AX) / BX....... AX gets quotient, DX gets remainder if any
	ADD DL, '0'                                     ; turns number in DL to show in ASCII char
	MOV ES:[DI], DL                                 ; displays the num
	SUB DI, 2                                       ; back up screen postion to display the number in correct order
	CMP AX, 0                                       ; is there more to display? if so repeat
	JA showNumLoop
	
	POP CX DI DX BX AX
	RET
	
ShowNum ENDP

getRandomNum PROC
;on entry: BX contains upper limit
;on exit: AX contains random number
	PUSH BX DX DI CX
	
	MOV CX, BX                           ; CX now hold the upper limit
	MOV AX, seed                    ;putting seed in AX
	MOV BX, 79                            ;prime num 
	MUL BX                               ; result stored in DX:AX
	ADD AX, 97                             ;adds a prime number to the result in AX
	MOV BX, CX                           ; BX hold the upper limit again
	MOV DX, 0
	DIV BX                               ; AX hold quotient DX holds remainder
	MOV AX, DX                           ;AX has remainder
	MOV seed, AX                         ;this allows us to get a new number on the next itteration
	
	POP CX DI DX BX
	RET
getRandomNum ENDP

randomChar PROC
;on entry:
;on exit: all registers preserved, chars moved into origlist and duplist
	PUSH BX AX DI CX SI
	MOV DI, (160*2+2)
	MOV CX, 3                             ;to loop 3 times
	MOV SI, 0                             ;to increment our list 
topLoop:	
	MOV BX, 26                            ;for the 26 letters of the alphabet
	CALL getRandomNum                     ;returns a random number in AX 0-25
	ADD AL, 'A'                          ;makes the random number a char
	MOV [origList + SI], AL              ;puts char in first spot of origList
	MOV [dupList + SI], AL               ; Also puts in the duplicate list so we can compare later
	INC SI                                ;go to next list spot
	LOOP topLoop                         ; loops 3 times
	
	POP SI CX DI AX BX
	RET
randomChar ENDP

displayChars PROC
;on entry: origList contains the letters to display
;on exit: all registers preserved, chars are displayed on the screen
	PUSH AX SI DI BX
	MOV CX, 3                         ;loop 3 times
	LEA SI, origList                  ; SI points to first char in the original list
anotherLoop:
	MOV BX, 2000
	CALL getRandomNum                   ;puts a random number in AX
	SHL AX, 1                           ; makes sure its an even number 
	MOV DI, AX                          ; DI holds the random even int                          
	MOV AL, [SI]               ;puts the char into AL
	MOV ES:[DI], AL                      ;displays the char on the screen
	INC SI                              ;get the next char in original list
	LOOP anotherLoop                     ;loop 3 times

	POP BX DI SI AX
	RET
displayChars ENDP

waitRandomTime PROC
;on entry:
;on exit: all regisers preserved
	PUSH AX CX BX DI SI DX
	

	MOV AH, 00h
	INT 1Ah                            ; CX:DX contains the tick count
	MOV CX, 0
	MOV BX, 400
	CALL getRandomNum                  ;ax hold a  number returns 0-400
	ADD AX, DX                         ; my target is held in AX
	MOV BX, AX                         ;BX now holds the number to compare to because we clobber AX with the next command

timeLoop:
	MOV AH, 00h
	INT 1Ah                            ; CX:DX contains the tick count 
	MOV CX, 0
	CMP DX, BX                        ;
	JL timeLoop                       ; is DX still less than BX ? if so loop


	exitProc:
	
	POP  DX SI DI BX CX AX
	RET

waitRandomTime ENDP

MyCode ENDS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

END mainProg