all: compile package

compile:
	nasm -f elf ass3.s -o ass3.o
	nasm -f elf coroutines.s -o coroutines.o
	nasm -f elf scheduler.s -o scheduler.o
	nasm -f elf printer.s -o printer.o

package:
	gcc -m32 -Wall -g ass3.o coroutines.o scheduler.o printer.o -o ass3
