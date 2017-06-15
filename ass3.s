%include "lib/garbage/core.s"
%include "lib/garbage/str.s"
%include "lib/garbage/debug.s"


global main

global WorldWidth
global WorldLength

global print_grid
global set_grid_value_at
global get_grid_value_at
global get_amount_of_living_neighbours
global is_debug_mode

extern malloc
extern calloc
extern free

extern printf
extern strcmp

extern fopen
extern fread
extern fclose

extern alloc_cors
extern init_all_cors
extern cors_activity
extern free_cors


.asm
	section .data
	WorldWidth dd 0
	WorldLength dd 0

section .text


let line, newline, ''

let dword, debug_mode, false

let pointer, filename

let dword, grid_length
let dword, grid_width
let dword, grid_size
let pointer, grid

let dword, t_val
let dword, k_val


def main, dword, argc, pointer, argv

	; parse command line args. if invalid, let user know and quit.
	func_call parse_cmdline_args, dword, argc, pointer, argv
	if returned_value, ==, false
		let line, proper_usage_notification, 'Usage: ass3 [-d] <filename> <length> <width> <t> <k>'
		func_call printf, pointer, proper_usage_notification

		return 0
	endif

	printd 'filename: %s, length: %d, width: %d, t: %d, k: %d', filename, grid_length, grid_width, t_val, k_val

	; initialize game world from file. if failed, let user know and quit.
	printd 'Initializing game world...'

	func_call prepare_grid
	if returned_value, ==, false
		let line, failed_to_initialize_game, 'error: failed to initialize game'
		func_call printf, pointer, failed_to_initialize_game

		return 1
	endif

	; allocate cors array
	printd 'allocating CORS...'
	let dword, desired_cors_size
	set dword, desired_cors_size, grid_size
	func_call alloc_cors, dword, desired_cors_size

	; initialize cors
	printd 'initializing CORS...'
	func_call init_all_cors, dword, t_val, dword, k_val, dword, grid_width, dword, grid_length

	; start cors
	printd 'Starting game!'

	if debug_mode
		func_call print_grid
	endif

	func_call cors_activity

	; free cors array
	func_call free_cors

	; free grid
	func_call clean_grid

	; finish and out ;)
	printd 'Game over!'

	return 0


; parses command line arguments and fills the corresponding vars. returns true/false in accordance to validity of input.
def parse_cmdline_args, dword, p_argc, pointer, p_argv

	; we look for at least 6 arguments
	if p_argc, <, 6
		return false
	endif

	; pointer to the argument on which we currently work
	let pointer, current_arg_ptr, 0
	let dword, current_arg_index
	set dword, current_arg_index, 1

	get_value_at pointer, p_argv, current_arg_index
	into current_arg_ptr

	; if we have -d, activate debug mode and move our index by 1
	let str, debug_arg, '-d'
	func_call strcmp, pointer, current_arg_ptr, pointer, debug_arg
	if returned_value, ==, 0
		func_call activate_debug_mode
		set dword, current_arg_index, current_arg_index, +, 1
	endif

	; if there are no 5 arguments beside -d, not good.
	; todo

	; filename
	get_value_at pointer, p_argv, current_arg_index
	into current_arg_ptr

	set pointer, filename, current_arg_ptr
	set dword, current_arg_index, current_arg_index, +, 1

	printd '%s', filename

	; length
	get_value_at pointer, p_argv, current_arg_index
	into current_arg_ptr

	func_call str_to_number, pointer, current_arg_ptr
	into grid_length

	; export variable needed by the scheduler
	set dword, dword[WorldLength], grid_length

	set dword, current_arg_index, current_arg_index, +, 1

	; width
	get_value_at pointer, p_argv, current_arg_index
	into current_arg_ptr

	func_call str_to_number, pointer, current_arg_ptr
	into grid_width

	; export variable needed by the scheduler
	set dword, dword[WorldWidth], grid_width
	
	set dword, current_arg_index, current_arg_index, +, 1

	; size
	set dword, grid_size, grid_width, *, grid_length

	; t
	get_value_at pointer, p_argv, current_arg_index
	into current_arg_ptr

	func_call str_to_number, pointer, current_arg_ptr
	into t_val
	
	set dword, current_arg_index, current_arg_index, +, 1

	; k
	get_value_at pointer, p_argv, current_arg_index
	into current_arg_ptr

	func_call str_to_number, pointer, current_arg_ptr
	into k_val
	
	set dword, current_arg_index, current_arg_index, +, 1

 	return true


; converts string to number
def str_to_number, pointer, str_ptr
	let dword, generated_number
	let dword, index

	set dword, generated_number, 0
	set dword, index, 0

	; not actually forever ;) stops at first character that's not a digit using breakwhile.
	while forever
		let dword, c
		char_at str_ptr, index
		into c

		; if c is not in the ascii range of '0'-'9', end the loop.
		if c, <, '0'
			breakwhile
		endif

		if c, >, '9'
			breakwhile
		endif

		; subtract the ascii value of '0' to get the actual numeric value
		set dword, c, c, -, '0'

		; since we read the string from left to right, multiply current value by 10 (shift all digits to the left) and add new value
		set dword, generated_number, generated_number, *, 10
		set dword, generated_number, generated_number, +, c

		; onwards to glory (next char, actually)
		set dword, index, index, +, 1
	endwhile

	return generated_number


; sets up the environment for debug mode. printd will now work.
def activate_debug_mode
	set dword, debug_mode, true

	printd 'activating debug mode'

	return


; an accessor, for external modules
def is_debug_mode
	return debug_mode


; prepares the game grid: allocates memory for it and loads its initial state from the file
def prepare_grid
	let dword, filedesc
	let str, open_access_mode, 'r'

	; open file
	func_call fopen, pointer, filename, pointer, open_access_mode
	into filedesc

	; if file not open, exit
	if filedesc, ==, 0
		let line, failed_open_file, 'error: failed to open file'
		func_call printf, pointer, failed_open_file

		return false
	endif

	; calculate needed size to allocate
	let dword, grid_array_size
	set dword, grid_array_size, grid_length, *, grid_width
	set dword, grid_array_size, grid_array_size, *, 4

	printd 'grid size is: %d', grid_array_size

	; allocate
	func_call malloc, dword, grid_array_size
	into grid

	printd 'grid allocated at: %p', grid

	; allocate buffer in the size of a line
	let pointer, read_line_buffer

	let dword, line_buffer_len
	set dword, line_buffer_len, grid_width, *, 2

	func_call malloc, dword, line_buffer_len
	into read_line_buffer

	printd 'allocated line buffer at %p, size: %d', read_line_buffer, line_buffer_len

	; start from line 1
	let dword, current_line, 0

	let dword, array_cursor
	set dword, array_cursor, 0

	; following actions are needed for reading a single line
	label read_file_line
		let dword, cursor
		set dword, cursor, 0

		let dword, line_width
		set dword, line_width, grid_width, *, 2

		; read next line
		func_call fread, pointer, read_line_buffer, dword, line_width, dword, 1, pointer, filedesc

		; we have to treat odd and even lines differently
		mod current_line, 2
		if returned_value, ==, 0
			set dword, cursor, 0
		else
			set dword, cursor, 1
		endif

		; read the line
		while cursor, <, line_width
			let dword, current_val

			; read char from loaded buffer
			char_at read_line_buffer, cursor
			into current_val

			; 
			set dword, current_val, current_val, -, '0'

			set_value_at grid, array_cursor, current_val

			set dword, array_cursor, array_cursor, +, 1
			set dword, cursor, cursor, +, 2
		endwhile

		; just read the extra \n char
		func_call fread, pointer, read_line_buffer, dword, 1, dword, 1, pointer, filedesc

		set dword, current_line, current_line, +, 1

		if current_line, <, grid_length
			goto read_file_line
		endif

	printd 'done reading file!'
	
	; free line buffer
	printd 'freeing line buffer at: %p', read_line_buffer
	func_call free, pointer, read_line_buffer

	; close file
	func_call, fclose, dword, filedesc

	return true


; print current grid
def print_grid
	let dword, current_cell
	set dword, current_cell, 0

	let dword, line_number
	set dword, line_number, 0

	let dword, last_in_line
	set dword, last_in_line, grid_width, -, 1

	; iterate until grid size
	while current_cell, <, grid_size

		let dword, mod_result

		mod current_cell, grid_width
		into mod_result

		if mod_result, !=, 0
			goto not_start_line
		endif

		let dword, is_line_odd
		mod line_number, 2
		into is_line_odd

		if is_line_odd
			let str, space, ' '
			func_call printf, pointer, space
		endif

		label not_start_line

		let dword, current_char
		get_value_at dword, grid, current_cell
		into current_char

		set dword, current_char, current_char, +, '0'

		; if last character in line, print without space *sigh*
		if mod_result, !=, last_in_line
			let str, print_cell_str, '%c '
			func_call printf, pointer, print_cell_str, dword, current_char
		else
			let str, print_cell_str_no_space, '%c'
			func_call printf, pointer, print_cell_str_no_space, dword, current_char
		endif

		if mod_result, ==, last_in_line
			func_call printf, pointer, newline

			set dword, line_number, line_number, +, 1
		endif

		set dword, current_cell, current_cell, +, 1

	endwhile

	return


; set grid value at position
def set_grid_value_at, dword, set_grid_x, dword, set_grid_y, dword, value
	let dword, actual_index

	set dword, actual_index, set_grid_y, *, grid_width
	set dword, actual_index, actual_index, +, set_grid_x

	set_value_at grid, actual_index, value

	return


; get grid value at position
def get_grid_value_at, dword, get_grid_x, dword, get_grid_y
	let dword, g_actual_index

	set dword, g_actual_index, get_grid_y, *, grid_width
	set dword, g_actual_index, g_actual_index, +, get_grid_x

	let dword, grid_result
	get_value_at dword, grid, g_actual_index
	into grid_result

	return grid_result


; calculate the amount of living neighbours for given coords
def get_amount_of_living_neighbours, dword, get_lv_x, dword, get_lv_y
	let dword, l_neighbour
	let dword, r_neighbour
	let dword, t_neighbour
	let dword, b_neighbour

	; calculate coordinates overflow and underflow, and fix them to be rotating
	set dword, l_neighbour, get_lv_x, -, 1
	if l_neighbour, <, 0
		set dword, l_neighbour, grid_width, -, 1
	endif

	set dword, r_neighbour, get_lv_x, +, 1
	if r_neighbour, >=, grid_width
		set dword, r_neighbour, 0
	endif

	set dword, t_neighbour, get_lv_y, -, 1
	if t_neighbour, <, 0
		set dword, t_neighbour, grid_length, -, 1
	endif

	set dword, b_neighbour, get_lv_y, +, 1
	if b_neighbour, >=, grid_length
		set dword, b_neighbour, 0
	endif

	; start accumulating neighbour statuses
	let dword, current_cell_status

	let dword, amount_alive
	set dword, amount_alive, 0

	let dword, is_line_not_even

	mod get_lv_y, 2
	into is_line_not_even

	if is_line_not_even

		; top right
		func_call get_grid_value_at, dword, r_neighbour, dword, t_neighbour
		into current_cell_status
		set dword, amount_alive, amount_alive, +, current_cell_status

		; bottom right
		func_call get_grid_value_at, dword, r_neighbour, dword, b_neighbour
		into current_cell_status
		set dword, amount_alive, amount_alive, +, current_cell_status

	else

		; top left
		func_call get_grid_value_at, dword, l_neighbour, dword, t_neighbour
		into current_cell_status
		set dword, amount_alive, amount_alive, +, current_cell_status

		; bottom left
		func_call get_grid_value_at, dword, l_neighbour, dword, b_neighbour
		into current_cell_status
		set dword, amount_alive, amount_alive, +, current_cell_status

	endif	

	; top
	func_call get_grid_value_at, dword, get_lv_x, dword, t_neighbour
	into current_cell_status
	set dword, amount_alive, amount_alive, +, current_cell_status

	; bottom
	func_call get_grid_value_at, dword, get_lv_x, dword, b_neighbour
	into current_cell_status
	set dword, amount_alive, amount_alive, +, current_cell_status

	; left
	func_call get_grid_value_at, dword, l_neighbour, dword, get_lv_y
	into current_cell_status
	set dword, amount_alive, amount_alive, +, current_cell_status

	; right
	func_call get_grid_value_at, dword, r_neighbour, dword, get_lv_y
	into current_cell_status
	set dword, amount_alive, amount_alive, +, current_cell_status

	return amount_alive


; free grid from memory
def clean_grid
	func_call free, pointer, grid
	return
