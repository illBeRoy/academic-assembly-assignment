; GARBAGE.STR
; String utility for garbage
; By Roy Sommer

%ifndef __GARBAGE_STR_M
%define __GARBAGE_STR_M

%macro char_at 2

	push ebx
	mov ebx, %1
	add ebx, %2
	mov eax, 0
	mov al, byte [ebx]
	pop ebx

%endmacro



%endif