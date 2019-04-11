# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# Task 2: Reg alloc
#	Spill register after last use
#		Verify
# 	Break register algo into blocks?
# Task 1 + 3
# 	Edit reg alloc to work with if/else including reg alloc TAC output file
#	When to load register in if/else
#	Must wait until outside if/else before spilling dirty register
# Other To Do:
# 	check output files (TAC and C) for all required features
# 	Make sure } doesn't get a line number
# 	Make sure freeing happens (variable names, ints, all strdups)
#	For reverse pass create backups of neighbors instead of recalculating
#	
#	Register assnging to itself in reg TAC (e.g.: _r1 = _r1;)
# Lab report

calc: calc.l calc.y reg_alloc.c reg_alloc.h
	bison -d calc.y
	flex calc.l
	gcc -Wall lex.yy.c calc.tab.c reg_alloc.c -o calc

ccode: c-backend.c c-reg-backend.c
	gcc -o prog c-backend.c
	gcc -o prog-reg c-reg-backend.c

# Create calc.output for debugging
debug:
	bison -v calc.y

clean:
	rm -f calc.tab.* lex.yy.c calc.output calc prog prog-reg a.out
	rm -f tac-frontend.txt tac-reg-alloc.txt c-backend.c c-reg-backend.c
