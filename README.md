# Game of Life
An academic assignment written in a self made dialect of assembly

### Abstract

In 2016, as part of a mandatory course in Systems Architecture, we were assigned with programming an implementation of [Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) in x86 assembly (NASM).

Seeing the sheer amount of code that I had to write, and realizing that the assignment's constraints forbid us from writing a single line of code in anything **but** assembly, I've had to come up with a reasonable way to handle that.

My (not so efficient, but nontheless fun) solution was to implement a more "readable" macro-powered language which I named "garbage". It provided the necessary tools to easily delcare variables and functions, assign values, and control the program flow with conditionals and loops.

### The assignment

The assignment was about implementing coroutines and a scheduler in assembly, where they run interwoven printing and logic "threads".

### The garbage "language"

As I said, in order to work around the "only assembly" rule, I've come up with a simple, macro powered "language", called garbage. As I said, it's not a real language with a real BNF syntax, since it is all based on syntactic sugaring around assembly using macros.

The implementation of garbage can be found under the directory `lib`. Examples of garbage "code" (it's not really interpreted or compiled in any conventional way, but rather expanded using macros) are:

**Example A:**

```
def add_two_numbers, dword, a, dword be
	let dword, result
	set dword, result, a, +, b

	return result
```

As you can see, function definition is allowed using the `def` macro, which accepts tuples of (type, parameter name).

The `let` macro lets you define variables (and behind the scenes creates them on either `.data` or `.rodata` for hardcoded strings).

The `set` macro assigns values to said vars. Pay attention that it supports arithmetics.

And `return` fetches the first operand, moves it to `eax`, and then calls `ret`.

**Example B**

```
def some_function
	let dword, score
	let dword, win
	
	func_call add_two_numbers, dword, 5, dword, 10
	into score
	
	if score, >, 9
		set dword, win, true
	else
		set dword, win, false
	endif
	
	return win
```

As you can see here, given the constraints of gcc macros, calling functions is being done using the `func_call` macro, and fetching their values is being done using the `into` macro.

Another thing would be conditionals: if blocks are supported. Unfortunately, given the restrictions I was working under (time and complexity), nested ifs and loops are not supported and will not compile.

### Usage

In order to compile, make sure that you have gcc installed and simply run:

`$ make`

And then, running it is as simple as:

`$ ass3 [-d] <filename> <length> <width> <t> <k>`

Where:

* `d` - activate debug mode (optional)
* `filename` - name of initial board state file to read (you can use "example_input", which is found in the directory)
* `length` - height of board
* `width` - width of board
* `t` - amount of logic "turns" before their thread resumes the scheduler
* `k` - amount of generations (full board updates) to perform before ending the game

The program was tested only on linux.

