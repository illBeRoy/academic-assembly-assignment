%include "lib/garbage/core.s"
%include "lib/garbage/str.s"
%include "lib/garbage/debug.s"

global scheduler

extern get_cell_cors_pointer
extern get_scheduler_pointer
extern get_printer_pointer

extern get_cors_flag_sp
extern get_cors_stack_head
extern set_cors_flag_sp
extern set_cors_stack_head

extern printf
extern fprintf
extern is_debug_mode

extern WorldWidth
extern WorldLength

extern resume
extern end_co


section .text

def scheduler_co_routine, dword, t, dword, k
	let dword, cur_x, 0
	let dword, cur_y, 0
	let dword, target_t, 0
	let dword, t_passed, 0
	let dword, k_passed, 0

	let pointer, pass_control_to

	; where we decide where to go
	label scheduler

		;printd 'scheduler: %d / %d, %d / %d', t_passed, t, k_passed, k

		; check if we reached maximum t
		;printd 'checking for done'
		set dword, target_t, t, *, 2
		if t_passed, ==, target_t
			func_call get_printer_pointer
			into pass_control_to

			push scheduler_end

			.asm
				mov ebx, pass_control_to
				jmp resume
		endif

		; check if we reached desired k
		;printd 'checking for printer'
		if k_passed, >=, k
			printd 'printer time'
			set dword, k_passed, 0

			func_call get_printer_pointer
			into pass_control_to

			push scheduler

			.asm
				mov ebx, pass_control_to
				jmp resume
		endif

		; get current cell's cors
		;printd 'getting cell cors %d %d', cur_x, cur_y
		func_call get_cell_cors_pointer, dword, cur_x, dword, cur_y
		into pass_control_to
		;printd 'got cors ptr: %p', pass_control_to

		; after resuming this coroutine, we wanna update stuff, so go to after_cell subroutine
		push scheduler_after_cell

		; sayonara
		.asm
			mov ebx, pass_control_to
			jmp resume

	; where we update our data
	label scheduler_after_cell

		;printd 'done with cell'

		; move to next cell
		set dword, cur_x, cur_x, +, 1

		; if cell is out of bounds, next line
		if cur_x, >=, dword[WorldWidth]
			set dword, cur_x, 0
			set dword, cur_y, cur_y, +, 1
		endif

		; if line is out of bounds, restart, set t->t+1
		if cur_y, >=, dword[WorldLength]
			set dword, cur_y, 0
			set dword, t_passed, t_passed, +, 1
		endif

		; update k
		set dword, k_passed, k_passed, +, 1

		; next iteration
		goto scheduler

	; endgame
	label scheduler_end

		;printd 'leaving to endco'

		jmp end_co

	return
