BITS 16
[global _start]
[extern main]

WinCol equ 20
WinRow equ 12
GridWidth equ 16

_start:
	mov ax, cs
	mov ds, ax
	mov ax, 0
	mov ss, ax
	mov sp, 7c00h

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

	mov dx, 0x3c6
	mov al,0xff
	out dx, al

	mov cl, 255

SetColor:
	mov dx, 0x3c8
	mov al, cl
	;Set Index
	out dx, al

	mov dx, 0x3c9
	
	mov al, cl
	shr al, 2
	and al, 0x38
	out dx, al
	
	mov al, cl
	shl al, 1
	and al, 0x38
	out dx, al

	mov al, cl
	shl al, 4
	and al, 0x30
	out dx, al

loop SetColor

	;mov bx, PIC
	;mov cx, GridWidth * 2
	;mov dx, GridWidth * 10
	;call DRAW

	;mov bx, PIC + GridWidth * GridWidth * 1
	;mov cx, GridWidth
	;mov dx, 0
	;call DRAW

	call DrawMap

	mov word[cs:DrawRectW], 40
	mov word[cs:DrawRectH], 40
	mov bx, G
	mov cx, GridWidth * 10
	mov dx, GridWidth * 3
	call DRAW

	jmp $

DrawMap:
	push si
	push dx
	push cx
	push bx
	push ax

	mov si, 0
	mov cx, 0
	mov dx, 0

	DrawMapIn:

	mov al, byte [cs:MAP0 + si]
	mov ah, 0
	mov bx, GridWidth * GridWidth
	push dx
	mul bx
	pop dx
	add ax, PIC
	mov bx, ax
	call DRAW

	add cx, GridWidth
	cmp cx, GridWidth * WinCol
	jne DrawMapNotGW
	mov cx, 0
	add dx, GridWidth
	DrawMapNotGW:
	inc si
	cmp si, WinRow * WinCol
	jne DrawMapIn

	pop ax
	pop bx
	pop cx
	pop dx
	pop si
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
	mov ax, cs
	mov ds, ax
	mov ax, 0A000h
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

DrawCount dw 0
DrawXCount dw 0
DrawCol dw 0
DrawMapCol dw 0
DrawRectW dw 16
DrawRectH dw 16

PIC:
%include "map256.asm"
G:
%include "g.asm"
MAP0:
%include "map0.asm"
