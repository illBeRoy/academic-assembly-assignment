%include "lib/garbage/core.s"
%include "lib/garbage/str.s"
%include "lib/garbage/debug.s"

global printer

extern get_scheduler_pointer
extern print_grid

extern resume

extern printf
extern fprintf
extern is_debug_mode


section .text

def printer_co_routine
	let pointer, schd_ptr

	label printer

		printd 'printer'

		func_call print_grid

		func_call get_scheduler_pointer
		into schd_ptr

		; right before we jump, push our next instruction!
		push printer

		; off we go D:
		.asm
			mov ebx, schd_ptr
			jmp resume
