%include "lib/garbage/core.s"
%include "lib/garbage/str.s"
%include "lib/garbage/debug.s"


global cors
global C_STRCT_SIZE

global alloc_cors
global free_cors

global co_init
global resume
global cors_activity
global end_co

global init_all_cors

global get_cell_cors_pointer
global get_scheduler_pointer
global get_printer_pointer

global get_cors_stack_alloc
global get_cors_flag_sp
global get_cors_stack_head
global set_cors_stack_alloc
global set_cors_flag_sp
global set_cors_stack_head

extern printf
extern fprintf

extern malloc
extern calloc
extern free

extern print_grid
extern set_grid_value_at
extern get_grid_value_at
extern get_amount_of_living_neighbours
extern is_debug_mode

extern WorldWidth
extern WorldLength

extern scheduler
extern printer


.asm
	section .data
	cors dd 0
	stt_arr dd 0
	curr dd 0
	SPMAIN dd 0
	C_STRCT_SIZE dd 12
	single_stack_size dd 16384


section .text


; init all cors
def init_all_cors, dword, inp_t, dword, inp_k, dword, inp_max_x, dword, inp_max_y
	let dword, cur_init_x, 0
	let dword, cur_init_y, 0

	; initialize scheduler
	;printd 'initializing scheduler co'
	func_call init_scheduler_co, dword, inp_t, dword, inp_k

	; initialize printer
	;printd 'initializing printer co'
	func_call init_printer_co

	set dword, cur_init_x, 0
	set dword, cur_init_y, 0

	; initialize all cells
	;printd 'initializing cells co'
	while cur_init_y, <, inp_max_y

		;printd '%d %d', cur_init_x, cur_init_y

		func_call init_cell_co, dword, cur_init_x, dword, cur_init_y

		set dword, cur_init_x, cur_init_x, +, 1

		if cur_init_x, >=, inp_max_x
			set dword, cur_init_x, 0
			set dword, cur_init_y, cur_init_y, +, 1
		endif

	endwhile

	return

; init cell's co_routine specifically
def init_cell_co, dword, my_x, dword, my_y
	let pointer, structure_ptr

	; get pointer for cell
	func_call get_cell_cors_pointer, dword, my_x, dword, my_y
	into structure_ptr

	; we pass x, y into ecx, edx so we can save them into our initialized coroutine
	.asm
		mov ecx, my_x
		mov edx, my_y

	; initialize co-routine with given cors pointer, and the CELL function
	func_call co_init, pointer, structure_ptr, pointer, update_cell_liveliness

	return


; init scheduler co_routine specifically
def init_scheduler_co, dword, t, dword, k
	let pointer, s_ptr

	; get pointer for sched
	;printd 'getting scheduler pointer'
	func_call get_scheduler_pointer
	into s_ptr

	;printd "scheduler: %p", s_ptr

	; pass t, k into registers so co_init will register them into the initialized stack :)
	.asm
		mov ecx, t
		mov edx, k

	; initialize co-routine with given cors pointer, and the SCHEDUELER function
	func_call co_init, pointer, s_ptr, pointer, scheduler

	return


; init printer co_routine specifically
def init_printer_co
	let pointer, p_ptr

	; get pointer for sched
	func_call get_printer_pointer
	into p_ptr

	;printd "printer: %p", p_ptr

	; initialize co-routine with given cors pointer, and the PRINTER function
	func_call co_init, pointer, p_ptr, pointer, printer

	return


; general init_co function. expects pointer to cors structure (pointer, NOT index) and pointer to default pc
def co_init, pointer, structure_pointer, pointer, default_pc_pointer
	; check if already initialized
	let dword, flag_is_done
	func_call get_cors_flag_sp, pointer, structure_pointer
	into flag_is_done

	;printd 'checking if initialization is done'

	; don't re-initialize if it is
	if flag_is_done
		return
	endif

	; set default stack head
	;printd 'setting default stack head'
	let pointer, def_stack_head

	; get pointer to stack allocation
	func_call get_cors_stack_alloc, pointer, structure_pointer
	into def_stack_head

	; add 16000 to it
	set pointer, def_stack_head, def_stack_head, +, 16000
	func_call set_cors_stack_head, pointer, structure_pointer, pointer, def_stack_head

	; we move pc pointer into a local variable, which is (according to my garbage language ;)) in
	; .data and not in stack, thus making it available even after the stack switch
	;printd 'moving given pc pointer to .data'
	let pointer, pc_to_push
	set pointer, pc_to_push, default_pc_pointer

	; keep structure pointer on .data, so it will be available later on
	;printd 'storing structure pointer to .data'
	let pointer, strctr_ptr
	set pointer, strctr_ptr, structure_pointer

	; get current esp
	;printd 'storing main esp'
	let pointer, original_esp
	
	.asm
		mov original_esp, esp

	; now things get tricky - we switch into a new stack, so params passed to co_init are NO LONGER AVAILABLE!!
	;printd 'switching into coroutine stack: %p', strctr_ptr
	func_call get_cors_stack_head, pointer, strctr_ptr
	into esp

	;printd 'pushing edx, ecx, pc, registers into stack. switching back to original esp'
	.asm
		; as promised, ecx, edx will be supplied 
		push edx
		push ecx
		push dword 0 ; since we have no actual return address, just put zero
		push dword 0 ; since we have no actual return address, just put zero
		; let ebp know that this is where the activation frame begins for our coroutine
		mov ebp, esp
		mov eax, pc_to_push
		; push ret_address
		push eax
		; push current registers state
		pushfd
		pushad
		; keep esp
		mov edx, esp
		; move back to original stack
		mov esp, original_esp

	;printd 'done pushing'

	; edx should be coroutine's esp now
	func_call set_cors_stack_head, pointer, strctr_ptr, dword, edx
	;printd 'set stack head'

	; mark flag as TRUE. we're done, ffs
	func_call set_cors_flag_sp, pointer, strctr_ptr, dword, true
	;printd 'set init flag'

	return


; contains the hosting function for the whole cors initialization and deinitialization
def cors_activity
	let pointer, first_call_ptr
	func_call get_scheduler_pointer
	into first_call_ptr

	label start_co

	.asm
		mov dword[SPMAIN], esp
		mov ebx, first_call_ptr
		jmp do_resume

	label end_co
	
	.asm
		mov esp, dword[SPMAIN]

	return


; perform as the resume mechanism
def resume_mechanism
	let pointer, esp_holder

	label resume
		; push registers status into stack
		.asm
			pushfd
			pushad
			mov esp_holder, esp

		; save esp to structure
		func_call set_cors_stack_head, pointer, dword[curr], pointer, esp_holder

		; explicitly go to resume!
		goto do_resume

	label do_resume
		; set curr to be next coroutine
		set pointer, dword[curr], ebx

		; get esp from next coroutine cors
		func_call get_cors_stack_head, pointer, dword[curr]
		into esp_holder

		; initialize state and return
		.asm
			mov esp, esp_holder
			popad
			popfd
			ret
	

; holds the cell coroutines since 1992
def cell_co_routine, dword, cur_cell_x, dword, cur_cell_y
	let dword, sched_ptr
	let dword, c_cr_ptr

	%define cell_state ecx
	
	; the first phase of the coroutines loop
	label update_cell_liveliness

		;printd 'cell coroutine %d %d', cur_cell_x, cur_cell_y

		; get my state
		let dword, previous_cell_state
		func_call get_grid_value_at, dword, cur_cell_x, dword, cur_cell_y
		into previous_cell_state

		;printd 'cell value %d', previous_cell_state

		; get amount of living neighbours
		let dword, current_living_neighbours
		func_call get_amount_of_living_neighbours, dword, cur_cell_x, dword, cur_cell_y
		into current_living_neighbours

		; goto corresponding handler
		if previous_cell_state, ==, 1
			goto cell_was_alive
		else
			goto cell_was_dead
		endif

		; cell was alive handler
		label cell_was_alive

			; first, kill it ;)
			.asm
				mov cell_state, 0

			; if amount of living neighbours does not meet criteria, keep it that way
			if current_living_neighbours, <, 3
				printd '[%d, %d] was alive now dead', cur_cell_x, cur_cell_y
				goto done_updating_liveliness
			endif

			if current_living_neighbours, >, 4
				printd '[%d, %d] was alive now dead', cur_cell_x, cur_cell_y
				goto done_updating_liveliness
			endif

			; otherwise, bring it back to life. MAGIC
			.asm
				mov cell_state, 1

			; we're done. go to done label
			goto done_updating_liveliness

		; cell was dead handler
		label cell_was_dead

			; first, keep it dead
			.asm
				mov cell_state, 0

			; if amount of living neighbours does not meet criteria, keep it that way
			if current_living_neighbours, !=, 2
				goto done_updating_liveliness
			endif

			; otherwise, bring it to life (like evanescence)
			.asm
				mov cell_state, 1

			printd '[%d, %d] was dead now alive', cur_cell_x, cur_cell_y

			; we're done. go to done label (it's unnecessary, of course, but we like to explicitly state stuff, now, don't we!)
			goto done_updating_liveliness

		; DONE updating liveliness. let's go back to scheduler
		label done_updating_liveliness

			push ecx

			;printd 'done updating liveliness'

			; get scheduler pointer
			func_call get_scheduler_pointer
			into sched_ptr

			; right before we jump, push our next instruction!
			push update_cell_value

			; off we go D:
			.asm
				mov ebx, sched_ptr
				jmp resume

	; second part of our cell routine, where dreams go to die and cells let other cells know of their situation
	label update_cell_value

		pop ecx

		let dword, new_cell_state

		.asm
			mov new_cell_state, ecx

		; let's save our state. seems like all the needless work we've done on ass3.s had paid off at last
		func_call set_grid_value_at, dword, cur_cell_x, dword, cur_cell_y, dword, new_cell_state

		; get scheduler pointer (might be unneeded as well but yet again - let's state the obvious for the sake of stating of the obvious!)
		func_call get_scheduler_pointer
		into sched_ptr

		; push our next instruction
		push update_cell_liveliness

		; buh bye!
		.asm
			mov ebx, sched_ptr
			jmp resume

	return


; interface to get the cors pointer of a cell from its coordinates
def get_cell_cors_pointer, dword, cors_x, dword, cors_y
	let dword, cors_offset

	;printd '%d %d', cors_x, cors_y
	set dword, cors_offset, cors_y, *, dword[WorldWidth]
	set dword, cors_offset, cors_offset, +, cors_x
	set dword, cors_offset, cors_offset, *, dword[C_STRCT_SIZE]
	set dword, cors_offset, cors_offset, +, dword[C_STRCT_SIZE]
	set dword, cors_offset, cors_offset, +, dword[C_STRCT_SIZE]

	let pointer, cors_ptr
	set pointer, cors_ptr, dword[stt_arr], +, cors_offset

	return cors_ptr


; interface to get the cors pointer of the scheduler
def get_scheduler_pointer
	return dword[stt_arr]


; interface to get the cors pointer of the printer
def get_printer_pointer
	let dword, prtr_ptr
	set dword, prtr_ptr, dword[stt_arr], +, dword[C_STRCT_SIZE]

	return prtr_ptr


; interface to get pc of coroutine from its cors pointer
def get_cors_stack_alloc, pointer, cors_addr_for_cep
	let dword, cep_val

	get_value_at dword, cors_addr_for_cep, 8
	into cep_val

	return cep_val


; interface to get initalization flag of coroutine from its cors pointer
def get_cors_flag_sp, pointer, cors_addr_for_fsp
	let dword, fsp_val
	
	get_value_at dword, cors_addr_for_fsp, 4
	into fsp_val

	return fsp_val


; interface to get stack head of coroutine from its cors pointer
def get_cors_stack_head, pointer, cors_addr_for_shead
	let dword, shead_val
	
	get_value_at dword, cors_addr_for_shead, 0
	into shead_val

	return shead_val


; interface to set pc of coroutine
def set_cors_stack_alloc, pointer, cors_addr_for_set_cep, dword, new_value_for_cep
	set_value_at cors_addr_for_set_cep, 8, new_value_for_cep

	return


; interface to set initialization flag of coroutine
def set_cors_flag_sp, pointer, cors_addr_for_set_fsp, dword, new_value_for_fsp
	set_value_at cors_addr_for_set_fsp, 4, new_value_for_fsp
	
	return


; interface to set stack head of coroutine
def set_cors_stack_head, pointer, cors_addr_for_set_shead, dword, new_value_for_shead
	set_value_at cors_addr_for_set_shead, 0, new_value_for_shead

	; update cors as well, so our friends at the lab can switch to their own sched >_>
	let pointer, corres_cors_ptr
	func_call get_stt_arr_to_cors, pointer, cors_addr_for_set_shead
	into corres_cors_ptr

	set_value_at corres_cors_ptr, 0, new_value_for_shead
	
	return


; gets the cors stack head pointer for a given pointer within state array
def get_stt_arr_to_cors, pointer, stt_arr_add

	let pointer, stt_accum
	set pointer, stt_accum, dword[stt_arr]

	let pointer, cors_accum
	set pointer, cors_accum, dword[cors]

	while stt_accum, <, stt_arr_add
		set pointer, stt_accum, stt_accum, +, dword[C_STRCT_SIZE]
		set pointer, cors_accum, cors_accum, +, 4
	endwhile

	return cors_accum


; allocate cors array into memory
def alloc_cors, dword, amount_of_cells
	let dword, amount_of_cors
	set dword, amount_of_cors, amount_of_cells, +, 2

	let dword, cors_buffer_size
	set dword, cors_buffer_size, amount_of_cors, *, dword[C_STRCT_SIZE]

	func_call calloc, dword, cors_buffer_size
	into dword[stt_arr]

	set dword, cors_buffer_size, amount_of_cors, *, 4
	func_call malloc, dword, cors_buffer_size
	into dword[cors]

	let pointer, current_inited
	set pointer, current_inited, dword[stt_arr]

	let dword, i, 0
	while i, <, amount_of_cors

		let pointer, ptr_to_new_stack

		func_call malloc, dword, dword[single_stack_size]
		into ptr_to_new_stack

		func_call set_cors_stack_alloc, pointer, current_inited, dword, ptr_to_new_stack

		set dword, i, i, +, 1
		set pointer, current_inited, current_inited, +, dword[C_STRCT_SIZE]

	endwhile

	;printd 'allocated cors at: %p, size: %d', dword[stt_arr], cors_buffer_size

	return


; free cors array from memory
def free_cors
	let pointer, current_deinited
	set pointer, current_deinited, dword[stt_arr]

	let dword, max_amt
	set dword, max_amt, dword[WorldWidth]
	set dword, max_amt, max_amt, *, dword[WorldLength]
	set dword, max_amt, max_amt, +, 2

	let dword, j, 0
	while i, <, max_amt

		let pointer, ptr_to_deinited_stack

		func_call get_cors_stack_alloc, pointer, current_deinited
		into ptr_to_deinited_stack

		func_call free, pointer, ptr_to_deinited_stack

		set dword, j, j, +, 1
		set pointer, current_deinited, current_deinited, +, dword[C_STRCT_SIZE]

	endwhile

	func_call free, pointer, dword[cors]
	func_call free, pointer, dword[stt_arr]
	return
