
.MODEL SMALL
.STACK 100H

.DATA
HI DB 'Hello Prof. Sujit',13,10,'$'
R DB 'RED    - STOP',13,10,'$'
G DB 'GREEN  - GO',13,10,'$'
Y DB 'YELLOW - READY',13,10,'$'

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX              ; point DS to the data segment

    MOV AH, 09H             ; print greeting once
    LEA DX, HI
    INT 21H

AGAIN:
    LEA DX, R
    CALL SHOW               ; red
    LEA DX, Y
    CALL SHOW               ; yellow
    LEA DX, G
    CALL SHOW               ; green

    MOV AH, 01H             ; check keyboard (ZF = 1 if no key)
    INT 16H
    JZ AGAIN                ; no key -> repeat the cycle

    MOV AH, 4CH             ; key pressed -> exit to DOS
    INT 21H
MAIN ENDP

; SHOW: prints the string at DX, then waits 3 seconds
SHOW PROC
    MOV AH, 09H             ; print '$'-terminated string
    INT 21H
    MOV AH, 86H             ; BIOS wait: CX:DX = microseconds
    MOV CX, 002DH           ; 3,000,000 us = 002D C6C0h
    MOV DX, 0C6C0H
    INT 15H
    RET
SHOW ENDP

END MAIN