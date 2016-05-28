BITS 16
[global _start]
[extern main]

WinCol equ 20
WinRow equ 12
GridWidth equ 16
UpdateTimes equ 60

VideoBuffer equ 0x8000

MAPPIC0_SEG equ 0x4000
HUOYING_SEG equ MAPPIC0_SEG + 0x800 
PEOPLE_SEG equ HUOYING_SEG + 0x800
FOOTBALL_SEG equ PEOPLE_SEG + 0x200
BOSS_SEG equ FOOTBALL_SEG + 0x200
POWER_SEG equ BOSS_SEG + 0x800 

%include "keyboard.asm"
KEY_UP equ 0x4800
KEY_DOWN equ 0x5000
KEY_LEFT equ 0x4b00
KEY_RIGHT equ 0x4d00

;写入中断向量表
%macro WriteIVT 2
	mov ax,%1
	mov bx,4
	mul bx
	mov si,ax
	mov ax,%2
	mov [cs:si],ax ; offset
	mov ax,cs
	mov [cs:si + 2],ax
%endmacro

%macro LoadFile 3
	;Name, Segment, Offset
	;NOte, num, num
	;ex: LoadFile Miku, 39, 0
	mov word[cs:FileNameP], %1
	mov word[cs:FileSegment], %2
	mov word[cs:FileOffset], %3
	call ReadFloppy
%endmacro

_start:
	mov ax, cs
	mov ds, ax
	mov ss, ax
	mov sp, 100h

	;清屏
	mov ax, 3
	int 10h

	;视频模式
	;使用VGA 320x400 256色
	mov ah, 0
	mov al, 13h
	int 10h
	;使用SVGA, 640x480 256色
	;mov ax, 4F02H
	;mov bx, 101H
	;int 10h

	%include "color.asm"

	;Resource
	LoadFile MAPPIC0, MAPPIC0_SEG, 0
	LoadFile HUOYING, HUOYING_SEG, 0
	LoadFile FOOTBALL, FOOTBALL_SEG, 0
	LoadFile PEOPLE, PEOPLE_SEG, 0
	LoadFile BOSSName, BOSS_SEG, 0

	;SetTimer
	mov al,34h
	out 43h,al ; write control word
	mov ax,1193182/UpdateTimes	;X times / seconds
	out 40h,al
	mov al,ah
	out 40h,al

	;当这个被执行时， 时钟中断会马上开始！
	WriteIVT 08h,WKCNINTTimer ; Timer Interupt

	sti

	jmp $

%include "disk.asm"

DrawMap:
	pusha

	mov word [cs:DrawRectW], GridWidth
	mov word [cs:DrawRectH], GridWidth

	mov word [cs:DrawSegment], MAPPIC0_SEG
	mov si, MAP0
	call DrawMapLayer

	mov word [cs:DrawSegment], PEOPLE_SEG
	mov si, MAP3
	call DrawMapLayer

	popa
	ret

DrawMapLayer:

	pusha 

	mov word [cs:DrawRectW], GridWidth
	mov word [cs:DrawRectH], GridWidth

	mov di, 0
	mov cx, 0
	mov dx, 0

	DrawMapIn:

	mov al, byte [cs:si]
	cmp al, 0
	je DRAWEND
	mov ah, 0
	mov bx, GridWidth * GridWidth
	push dx
	mul bx
	pop dx
	;add ax, MAPPIC - GridWidth * GridWidth
	sub ax, GridWidth * GridWidth
	mov bx, ax
	call DRAW

	DRAWEND:
	add cx, GridWidth
	cmp cx, GridWidth * WinCol
	jne DrawMapNotGW
	;换行
	mov cx, 0
	add dx, GridWidth
	DrawMapNotGW:
	inc si
	inc di
	cmp di, WinRow * WinCol

	jne DrawMapIn

	popa

	ret

DrawPlayer:
	pusha
	HY_W equ 40
	HY_H equ 40
	mov word [cs:DrawRectW], HY_W
	mov word [cs:DrawRectH], HY_H
	mov word [cs:DrawSegment], HUOYING_SEG

	mov ax, word [cs:(si + _GRAPH_OFFSET)]
	mov word [cs:DrawSegment], ax

	mov bx, 0
	mov ax, word [cs:(si + _PAT_OFFSET)]
	mov cx, HY_W * HY_H 
	mul cx
	add bx, ax
	mov ax, word [cs:(si + _DIR_OFFSET)]
	mov cx, HY_W * HY_H * 4 
	mul cx
	add bx, ax
	xor cx, cx
	mov cx, word [cs:(si + _X_OFFSET)]	
	shr cx, 4
	mov dx, word [cs:(si + _Y_OFFSET)] 	
	shr dx, 4
	;sub cx, HY_W / 2
	;sub dx, HY_H
	sub cx, - (GridWidth - HY_W) / 2
	add dx, (GridWidth - HY_H)
	call DRAW

	popa
	ret

DrawBomb:
	pusha
	BombSize equ 18
	mov word [cs:DrawRectW], BombSize
	mov word [cs:DrawRectH], BombSize

	mov ax, word [cs:(si + _GRAPH_B_OFFSET)]
	mov word [cs:DrawSegment], ax

	mov bx, 0
	mov ax, word [cs:(si + _PAT_B_OFFSET)]
	mov cx, BombSize * BombSize
	mul cx
	add bx, ax
	xor cx, cx
	mov cx, word [cs:(si + _X_B_OFFSET)]	
	shr cx, 4
	mov dx, word [cs:(si + _Y_B_OFFSET)] 	
	shr dx, 4
	;sub cx, BombSize / 2
	;sub dx, BombSize
	sub cx, - (GridWidth - BombSize) / 2
	add dx, (GridWidth - BombSize)
	call DRAW

	popa
	ret


;Draw
;bx = offset PIC
;cx = column
;dx = row
DRAW:
	push ds
	push es
	pusha
	;[ds:si] -> [es:di]
	mov si, bx
	mov ax, word[cs:DrawSegment]
	mov ds, ax
	mov ax, VideoBuffer
	mov es, ax
	;设置di
	mov ax, dx
	mov bx, WinCol * GridWidth
	mul bx
	add ax, cx
	mov di, ax
	mov ax, word[cs:DrawRectH] ; 绘制行数
	DRAW_ONE_LINE:

	;mov cx, GridWidth / 2
	;rep movsw

	;绘制一行
	mov cx, word[cs:DrawRectW] ; 绘制列数
	MOVSWLOOP:
	mov bl, [ds:si]
	cmp bl, 11100011b ; opacity
	je IS_OPACITY
	mov [es:di], bl
	IS_OPACITY:
	inc si
	inc di
	loop MOVSWLOOP

	;换行
	sub di, word[cs:DrawRectW]
	add di, WinCol * GridWidth

	dec ax 
	jnz DRAW_ONE_LINE

	popa
	pop es
	pop ds
	ret

UpdatePlayer:
	pusha
	mov cx, word [cs:(si + _V_OFFSET)]
	;CMP X
	mov ax, word [cs:(si + _X_OFFSET)]
	mov bx, word [cs:(si + _TX_OFFSET)]
	cmp ax, bx
	je XEQU
	ja XA 
	;X < TX
	mov word [cs:(si + _DIR_OFFSET)], 2; turn right
	add word [cs:(si + _X_OFFSET)], cx
	cmp word [cs:(si + _X_OFFSET)], bx
	ja FIX_X
	jmp MovePlayer
	XA:
	;X > TX
	mov word [cs:(si + _DIR_OFFSET)], 1; turn left	
	sub word [cs:(si + _X_OFFSET)], cx
	cmp word [cs:(si + _X_OFFSET)], bx
	jb FIX_X
	jmp MovePlayer
	XEQU:

	;CMP Y
	mov ax, word [cs:(si + _Y_OFFSET)]
	mov bx, word [cs:(si + _TY_OFFSET)]
	cmp ax, bx
	je YEQU
	ja YA 
	;Y < TY
	mov word [cs:(si + _DIR_OFFSET)], 0; turn down
	add word [cs:(si + _Y_OFFSET)], cx
	cmp word [cs:(si + _Y_OFFSET)], bx
	ja FIX_Y
	jmp MovePlayer
	YA:
	;Y > TY
	mov word [cs:(si + _DIR_OFFSET)], 3; turn up
	sub word [cs:(si + _Y_OFFSET)], cx
	cmp word [cs:(si + _Y_OFFSET)], bx
	jb FIX_Y
	jmp MovePlayer
	YEQU:

	;mov word [cs:(si + _PAT_OFFSET)], 0
	cmp word [cs:(si + _PAT_OFFSET)], 0
	je UpdatePlayerEND
	jmp MovePlayer

	FIX_X:
	mov word [cs:(si + _X_OFFSET)], bx
	jmp MovePlayer

	FIX_Y:
	mov word [cs:(si + _Y_OFFSET)], bx
	jmp MovePlayer

	MovePlayer:
    inc word [cs:(si + _ANI_OFFSET)]
	cmp word [cs:(si + _ANI_OFFSET)], 6
	jb UpdatePlayerEND
	mov word [cs:(si + _ANI_OFFSET)], 0
	inc word [cs:(si + _PAT_OFFSET)]
	and word [cs:(si + _PAT_OFFSET)], 11b
	UpdatePlayerEND:
	popa
	ret

UpdateBomb:
	pusha
	;爆炸判断
	dec word [cs:(si + _COUNT_B_OFFSET)]
	jnz MOVEJUDGE

	mov byte [cs:(si + _USED_B_OFFSET)], 0

	MOVEJUDGE:
	;移动判断
	mov cx, word [cs:(si + _V_B_OFFSET)]
	;CMP X
	mov ax, word [cs:(si + _X_B_OFFSET)]
	mov bx, word [cs:(si + _TX_B_OFFSET)]
	cmp ax, bx
	je XEQU_B
	ja XA_B
	;X < TX
	add word [cs:(si + _X_B_OFFSET)], cx
	cmp word [cs:(si + _X_B_OFFSET)], bx
	ja FIX_X_B
	jmp MoveBomb
	XA_B:
	;X > TX
	sub word [cs:(si + _X_B_OFFSET)], cx
	cmp word [cs:(si + _X_B_OFFSET)], bx
	jb FIX_X_B
	jmp MoveBomb
	XEQU_B:

	;CMP Y
	mov ax, word [cs:(si + _Y_B_OFFSET)]
	mov bx, word [cs:(si + _TY_B_OFFSET)]
	cmp ax, bx
	je YEQU_B
	ja YA_B
	;Y < TY
	add word [cs:(si + _Y_B_OFFSET)], cx
	cmp word [cs:(si + _Y_B_OFFSET)], bx
	ja FIX_Y_B
	jmp MoveBomb
	YA_B:
	;Y > TY
	sub word [cs:(si + _Y_B_OFFSET)], cx
	cmp word [cs:(si + _Y_B_OFFSET)], bx
	jb FIX_Y_B
	jmp MoveBomb
	YEQU_B:

	jmp MovePlayer

	FIX_X_B:
	mov word [cs:(si + _X_B_OFFSET)], bx
	jmp MoveBomb

	FIX_Y_B:
	mov word [cs:(si + _Y_B_OFFSET)], bx
	jmp MoveBomb

	MoveBomb:
    inc word [cs:(si + _ANI_B_OFFSET)]
	cmp word [cs:(si + _ANI_B_OFFSET)], 6
	jb UpdateBombEND
	mov word [cs:(si + _ANI_B_OFFSET)], 0
	inc word [cs:(si + _PAT_B_OFFSET)]
	and word [cs:(si + _PAT_B_OFFSET)], 11b
	UpdateBombEND:
	popa
	ret

KeyJudge:
	pusha

	mov ah, 1
	int 16h
	jz KEYEND
	mov ah, 0
	int 16h

	PlayerVV equ 0x080

	mov cx, word [cs:(si + _X_OFFSET)]
	mov dx, word [cs:(si + _TX_OFFSET)]
	cmp cx, dx
	jne KEYEND

	mov cx, word [cs:(si + _Y_OFFSET)]
	mov dx, word [cs:(si + _TY_OFFSET)]
	cmp cx, dx
	jne KEYEND


	mov cx, word [cs:(si + _X_OFFSET)]
	mov dx, word [cs:(si + _Y_OFFSET)]

	add cx, 0x80
	add dx, 0x80
	shr cx, 8
	shr dx, 8

	cmp ax, KEY_UP
	jne NextJudge2

	mov word[cs:(si + _DIR_OFFSET)], 3
	dec dx
	call IsPassed
	jne YBLOCK
	sub word[cs:(si + _TY_OFFSET)], PlayerVV

	jmp KEYEND
	NextJudge2:
	cmp ax, KEY_DOWN
	jne NextJudge3


	mov word[cs:(si + _DIR_OFFSET)], 0
	inc dx
	call IsPassed
	jne YBLOCK
	add word[cs:(si + _TY_OFFSET)], PlayerVV

	jmp KEYEND
	NextJudge3:
	cmp ax, KEY_LEFT
	jne NextJudge4

	mov word[cs:(si + _DIR_OFFSET)], 1
	dec cx
	call IsPassed
	jne XBLOCK
	sub word[cs:(si + _TX_OFFSET)], PlayerVV

	jmp KEYEND
	NextJudge4:
	cmp ax, KEY_RIGHT
	jne KEYEND


	mov word[cs:(si + _DIR_OFFSET)], 2
	inc cx
	call IsPassed
	jne XBLOCK
	add word[cs:(si + _TX_OFFSET)], PlayerVV

	jmp KEYEND

	XBLOCK:
	mov cx, word [cs:(si + _TX_OFFSET)]
	add cx, 0x80
	shr cx, 8
	shl cx, 8
	mov word [cs:(si + _TX_OFFSET)], cx
	jmp KEYEND

	YBLOCK:
	mov cx, word [cs:(si + _TY_OFFSET)]
	add cx, 0x80
	shr cx, 8
	shl cx, 8
	mov word [cs:(si + _TY_OFFSET)], cx

	KEYEND:
	popa
	ret

UpdateScreen:
	push es
	push ds
	push si
	push di
	push ax
	;[ds:si] -> [es:di]
	mov ax, VideoBuffer
	mov ds, ax
	mov ax, 0A000h
	mov es, ax
	mov si, 0
	mov di, 0
	mov cx, WinCol * WinRow * GridWidth * GridWidth/ 2
	rep movsw
	pop ax
	pop di
	pop si
	pop ds
	pop es
	ret

IsPassed:
	;cx: column
	;dx: row
	;passed = je = zf
	;Check Border
	;类似检测数组越界, 用无符号判定
	push dx
	push cx
	push bx
	push ax
	cmp cx, WinCol
	jae NotPassed
	cmp dx, WinRow
	jae NotPassed
	mov ax, dx
	mov dx, WinCol
	mul dx
	add ax, cx
	mov bx, ax
	cmp byte[cs:PASSED_DATA + bx], 0
	jmp IsPassedEnd
	NotPassed:
	;设置ZF = 0
	mov bx, 0
	cmp bx, 1
	IsPassedEnd:
	pop ax
	pop bx
	pop cx
	pop dx
	ret

WKCNINTTimer:
	call DrawMap

	mov si, Players
	call KeyJudge
	call UpdatePlayer
	call DrawPlayer

	mov si, BOSS
	call UpdatePlayer
	call DrawPlayer

	mov si, Bombs

	cmp byte[cs:(si + _USED_B_OFFSET)], 0
	je NoUsedBomb
	call UpdateBomb

	cmp byte[cs:(si + _USED_B_OFFSET)], 0
	je NoUsedBomb

	call DrawBomb

	NoUsedBomb:

	call UpdateScreen

	mov al,20h
	out 20h,al
	out 0A0h,al
	iret



DrawCount dw 0
DrawXCount dw 0
DrawCol dw 0
DrawMapCol dw 0
DrawSegment dw 0x3000
DrawRectW dw 16
DrawRectH dw 16


%macro SetOffset 1
	%1_OFFSET equ (%1 - Players)
%endmacro

SetOffset _GRAPH
SetOffset _DIR
SetOffset _PAT
SetOffset _X
SetOffset _Y
SetOffset _TX
SetOffset _TY
SetOffset _ANI
SetOffset _V

Players:
	_GRAPH dw HUOYING_SEG
	_DIR dw 2
	_PAT dw 0
	_X	dw 700h
	_Y	dw 600h
	_TX	dw 700h
	_TY	dw 600h
	_ANI dw 0
	_V	dw 0x20
BOSS:
	_GRAPH2 dw BOSS_SEG
	_DIR2 dw 1
	_PAT2 dw 0
	_X2	dw 0b00h
	_Y2	dw 600h
	_TX2	dw 0b00h
	_TY2	dw 600h
	_ANI2 dw 0
	_V2	dw 0x30


%macro SetOffset_B 1
	%1_OFFSET equ (%1 - Bombs)
%endmacro

SetOffset_B _GRAPH_B
SetOffset_B _USED_B
SetOffset_B _POWER_B
SetOffset_B _COUNT_B
SetOffset_B _PAT_B
SetOffset_B _X_B
SetOffset_B _Y_B
SetOffset_B _TX_B
SetOffset_B _TY_B
SetOffset_B _ANI_B
SetOffset_B _V_B

Bombs:
	_GRAPH_B dw FOOTBALL_SEG
	_USED_B db 1
	_POWER_B db 3
	_COUNT_B dw 5 * UpdateTimes
	_PAT_B dw 0
	_X_B	dw 000h
	_Y_B	dw 000h
	_TX_B	dw 000h
	_TY_B	dw 000h
	_ANI_B dw 0
	_V_B	dw 0x20

%macro SetOffset_P 1
	%1_OFFSET equ (%1 - Powers)
%endmacro

SetOffset_P _USED_P
SetOffset_P _PAT_P
SetOffset_P _COUNT_P
SetOffset_P _X_P
SetOffset_P _Y_P

Powers:
	_USED_P db 1
	_PAT_P dw 0
	_COUNT_P dw 5 * UpdateTimes
	_X_P dw 1000h
	_Y_P dw 1000h


MAPPIC0 db "MAPPIC  RES"
HUOYING db "HUOYING RES"
FOOTBALL db "FOOTBALLRES"
PEOPLE db "PEOPLE  RES"
BOSSName db "BOSS    RES"
POWERNAME db "POWER   RES"
MAP0:
%include "map0.asm"
MAP3:
%include "map3.asm"
PASSED_DATA:
%include "map3.asm" ; 非0的均不能走
