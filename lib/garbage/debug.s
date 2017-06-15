; GARBAGE.STR
; String utility for garbage
; By Roy Sommer

%ifndef __GARBAGE_DBG_M
%define __GARBAGE_DBG_M

%macro printd 1-*

	section .rodata
		%%formatted_str db %1, 10, 0

	section .text

		pushad

		func_call is_debug_mode

		mov ebx, true
		cmp eax, ebx
		jne %%skip

		%assign mem_to_free 4
		%rep (%0-1)
			%rotate -1
			%assign mem_to_free mem_to_free+4
			mov eax, %1
			push eax
		%endrep

		push %%formatted_str
		call printf

		add esp, mem_to_free

		%%skip:

		popad

%endmacro

%endif