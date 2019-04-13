# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# 	Variables the are initialized inside an if else
# Other To Do:
#	Remove line count global var
# 	check output files (TAC and C) for all required features
#	Compare no reg and reg c file outputs
# 	Check for warnings in c files
#	Register assigning to itself in reg TAC (e.g.: _r1 = _r1;)
# 	Make sure freeing happens (variable names, ints, all strdups)
#	For reverse pass create backups of neighbors instead of recalculating
# Task 2: Reg alloc
# 	Break register algo into blocks?
# Lab report

# Create calculator language compiler with frontend scanner+parser,
# tac generation with register allocation, and backend c code output
calc: calc.l calc.y reg_alloc.c reg_alloc.h
	bison -d calc.y
	flex calc.l
	gcc -Wall lex.yy.c calc.tab.c reg_alloc.c -o calc

# Create calc.output for debugging
debug:
	bison -v calc.y
	
# Create compiled programs from backend c output
# Create program using the c code with no registers and one with register
ccode: c-backend.c c-reg-backend.c
	gcc -o prog c-backend.c -lm
	gcc -o prog-reg c-reg-backend.c -lm

# Same as above, but print warnings (will show unused labels)
ccodew: c-backend.c c-reg-backend.c
	gcc -Wall -o prog c-backend.c -lm
	gcc -Wall -o prog-reg c-reg-backend.c -lm

clean:
	rm -f calc.tab.* lex.yy.c calc.output calc prog prog-reg a.out
	rm -f tac-frontend.txt tac-reg-alloc.txt c-backend.c c-reg-backend.c
