# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
#	Fix liveness issue inside if/else
# 		Git commit
#		Variables the are initialized inside an if else
# 		Verify
#	Compare no reg and reg c file outputs
#	Read instructions
# 	check output files (TAC and C) for all required features
# 	Make sure freeing happens (variable names, ints, all strdups)
# Other To Do:
# 	Break register algo into blocks?
#	For reverse pass create backups of neighbors instead of recalculating
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
ccode: Output/c-backend.c Output/c-reg-backend.c
	gcc -o Output/prog Output/c-backend.c -lm
	gcc -o Output/prog-reg Output/c-reg-backend.c -lm

# Same as above, but print warnings (will show unused labels)
ccodew: Output/c-backend.c Output/c-reg-backend.c
	gcc -Wall -o Output/prog Output/-backend.c -lm
	gcc -Wall -o Output/prog-reg Output/c-reg-backend.c -lm

clean:
	rm -f calc.tab.* lex.yy.c calc.output calc
	rm -f Output/tac-frontend.txt Output/tac-reg-alloc.txt Output/opt-tac-reg-alloc.txt
	rm -f Output/c-backend.c Output/c-reg-backend.c
	rm -f Output/prog Output/prog-reg
