; GARBAGE
; A macro-generated abstraction language for good old x86 NASM, providing assignment, allocation and flow control.
; By Roy Sommer

%ifndef __GARBAGE_M
%define __GARBAGE_M

%assign if_endif_counter 0
%assign if_else_counter 0
%assign while_counter 0

%define returned_value eax

%xdefine true 1
%xdefine false 0
%xdefine forever 0, ==, 0

%define .asm

%macro let 2-3
; lets you define a variable inline! so very amazing.
; example: let str, greet, 'hi there, I am Roy, my age is %i'

	%ifidn %1, str
		section .rodata
		%2 db %3, 0
		section .text
	%endif

	%ifidn %1, line
		section .rodata
		%2 db %3, 10, 0
		section .text
	%endif

	%ifidn %1, char
		section .data
		%if %0 > 2
			%%t db %3
		%else
			%%t db 0
		%endif
		section .text
		%xdefine %2 byte[%%t]
	%endif

	%ifidn %1, dword
		section .data
		%if %0 > 2
			%%t dd %3
		%else
			%%t dd 0
		%endif
		section .text
		%xdefine %2 dword[%%t]
	%endif

	%ifidn %1, pointer
		section .data
		%if %0 > 2
			%%t dd %3
		%else
			%%t dd 0
		%endif
		section .text
		%xdefine %2 dword[%%t]
	%endif

	%ifidn %1, buffer
		section .bss
		%2: resb %3
		section .text
	%endif

%endmacro


%macro set 3-5
; exactly as it sounds ;)
; example:
; let dword, a, 5
; let dword, b, 2
; set dword, a, b

	push eax

	%ifidn %1, char
		mov al, %3
	%endif

	%ifidn %1, word
		mov ax, %3
	%endif	

	%ifidn %1, dword
		mov eax, %3
	%endif

	%ifidn %1, pointer
		mov eax, %3
	%endif

	%if %0 > 3

		push edx
		mov edx, 0
		mov edx, %5

		%ifidn %4, +
			add eax, edx
		%endif

		%ifidn %4, -
			sub eax, edx
		%endif

		%ifidn %4, *
			push ebx
			push ecx

			mov ebx, eax
			mov ecx, edx
			mov eax, 0
			%%mult_start:
			cmp ecx, 0
			jle %%mult_end

			add eax, ebx
			sub ecx, 1

			jmp %%mult_start
			%%mult_end:

			pop ecx
			pop ebx
		%endif

		pop edx

	%endif

	%ifidn %1, char
		mov %2, al
	%endif

	%ifidn %1, word
		mov %2, ax
	%endif	

	%ifidn %1, dword
		mov %2, eax
	%endif

	%ifidn %1, pointer
		mov %2, eax
	%endif

	pop eax

%endmacro


%macro func_call 1-*
; allows you to make c-convention calls, with as many parameters as you want!
; example: func_call printf, dword, greet, dword, 24
	
	%assign params_length 0

	push ebx

	%rep (%0-1)/2
		%rotate -2

		%ifidn %1, char
			%assign params_length params_length+2
			mov ebx, 0
			mov bl, %2
			push bx
		%endif 

		%ifidn %1, word
			%assign params_length params_length+2
			mov bx, %2
			push bx
		%endif 

		%ifidn %1, dword
			%assign params_length params_length+4
			mov ebx, %2
			push ebx
		%endif

		%ifidn %1, pointer
			%assign params_length params_length+4
			mov ebx, %2
			push ebx
		%endif

	%endrep

	%rotate -1
	call %1

	add esp, params_length

	pop ebx

%endmacro


%macro into 1
; assigns the result of the previously invoked function into the given variable
; example:
; let dword, a, 0
; func_call this_function_makes_one
; into a

	mov %1, eax
%endmacro


%macro def 1-*
; defines a c conventioned function that accepts named parameters! would you believe?
; example: def main, dword, argc, dword, argv

	%1:

		%assign current_arg_accessor 8

		%rotate 1
		%rep (%0-1)/2

			%ifidn %1, char
				%xdefine %{2} byte[ebp + current_arg_accessor]
				%assign current_arg_accessor current_arg_accessor+1
			%endif 

			%ifidn %1, word
				%xdefine %{2} word[ebp + current_arg_accessor]
				%assign current_arg_accessor current_arg_accessor+2
			%endif 

			%ifidn %1, dword
				%xdefine %{2} dword[ebp + current_arg_accessor]
				%assign current_arg_accessor current_arg_accessor+4
			%endif

			%ifidn %1, pointer
				%xdefine %{2} dword[ebp + current_arg_accessor]
				%assign current_arg_accessor current_arg_accessor+4
			%endif

			%rotate 2
		%endrep

		push ebp
	    mov ebp, esp
	    pushad

%endmacro


%macro return 0-1
; every function has an end :( this one allows for conventional returning of value into eax!
; example: return 5

	%if %0 = 1
		section .bss
			%%temp resb 4
		section .text
			mov eax, %1
			mov dword[%%temp], eax
	%endif

	popad
	mov esp, ebp
	pop ebp

	%if %0 = 1
		mov eax, dword[%%temp]
	%endif

	ret

%endmacro


; internal if flow control functions
%macro __elsegoto 2
	%{1} __else__%{2}
%endmacro


%macro __elselabel 1
	__else__%{1}:
%endmacro


%macro __endifgoto 2
	%{1} __endif__%{2}
%endmacro


%macro __endiflabel 1
	__endif__%{1}:
%endmacro
; end of internal


%macro if 1-3
; flow control goodness!
; example: if, a, >, b

	push eax
	push ebx
	mov eax, %1
	%if %0 < 3
		mov ebx, 1
	%else
		mov ebx, %3
	%endif
	cmp eax, ebx
	pop ebx
	pop eax

	%if %0 < 3

		__elsegoto jne, if_else_counter

	%else

		%ifidn %2, ==
			__elsegoto jne, if_else_counter
		%endif

		%ifidn %2, !=
			__elsegoto je, if_else_counter
		%endif

		%ifidn %2, <
			__elsegoto jge, if_else_counter
		%endif

		%ifidn %2, >
			__elsegoto jle, if_else_counter
		%endif

		%ifidn %2, <=
			__elsegoto jg, if_else_counter
		%endif

		%ifidn %2, >=
			__elsegoto jl, if_else_counter
		%endif

	%endif

%endmacro


%macro else 0
; the ELSE flag ;)
; example:
;
; if a, >, b
; 	set dword, a_is_bigger, 1
; else
;	set dword, a_is_bigger, 0
; endif

	__endifgoto jmp, if_endif_counter
	__elselabel if_else_counter
	%assign if_else_counter if_else_counter+1

%endmacro


%macro endif 0
; yeah you guessed it.
; example: look @else

	%if if_else_counter = if_endif_counter
		else
	%endif

	__endiflabel if_endif_counter
	%assign if_endif_counter if_endif_counter+1

%endmacro

%define char(a) byte, a
%define word(a) word, a
%define dword(a) dword, a
%define pointer(a) pointer, a

%macro value_at_pointer 1
	mov eax, %1
	mov eax, dword[eax]
%endmacro


%macro get_value_at 3
; gets the value at offset from the given pointer
; example: value_at_index pointer, my_array, 1

	push ebx
	mov eax, %2
	mov ebx, %3

	%ifidn %1, char
		%define type_size 1
		%define type_width byte
	%endif

	%ifidn %1, word
		%define type_size 2
		%define type_width word
	%endif

	%ifidn %1, dword
		%define type_size 4
		%define type_width dword
	%endif

	%ifidn %1, pointer
		%define type_size 4
		%define type_width dword
	%endif

	%%mult_loop:
		cmp ebx, 0
		je %%end_mult_loop

		add eax, type_size
		sub ebx, 1
		jmp %%mult_loop
	%%end_mult_loop:

	mov eax, type_width[eax]
	pop ebx

%endmacro


%macro set_value_at 3

	push ecx
	push ebx
	push eax

	mov ebx, %1
	mov ecx, %2

	%%loop:
		cmp ecx, 0
		je %%endloop

		add ebx, 4
		sub ecx, 1
		jmp %%loop
	%%endloop:

	mov eax, %3

	mov dword [ebx], eax

	pop eax
	pop ebx
	pop ecx

%endmacro


%macro mod 2

	push ebx
	push ecx

	mov eax, 0
	mov ebx, %1
	mov ecx, %2

	%%loop:
		cmp eax, ebx
		jg %%endloop
		add eax, ecx
		jmp %%loop
	%%endloop:

	sub eax, ecx
	sub ebx, eax
	mov eax, ebx

	pop ebx
	pop ecx

%endmacro


%macro label 1
	%1:
%endmacro

%macro goto 1
	jmp %1
%endmacro


%macro __whilegoto 2
	%{1} __while__%{2}
%endmacro


%macro __whilelabel 1
	__while__%{1}:
%endmacro


%macro __whileendgoto 2
	%{1} __while_end__%{2}
%endmacro


%macro __whileendlabel 1
	__while_end__%{1}:
%endmacro


%macro while 3

	__whilelabel while_counter

	if %1, %2, %3
	else
		__whileendgoto jmp, while_counter
	endif
%endmacro


%macro breakwhile 0

	__whileendgoto jmp, while_counter

%endmacro


%macro endwhile 0

	__whilegoto jmp, while_counter
	__whileendlabel while_counter

	%assign while_counter while_counter+1
%endmacro


%endif
