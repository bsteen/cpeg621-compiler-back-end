# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# Task 2: Reg alloc
#	Convert variables to registers
#		Verify
#	Load variables into register
#	Spill register after last use
# 	Break register algo into blocks?
# Task 1 + 3
# 	Edit reg alloc to work with if/else including reg alloc TAC output file
# Other To Do:
# 	check output files (TAC and C) for all required features
# 	Make sure } doesn't get a line number
# 	Make sure freeing happens (variable names, ints, all strdups)
#	For reverse pass create backups of neighbors instead of recalculating
# Lab report

calc: calc.l calc.y reg_alloc.c reg_alloc.h
	bison -d calc.y
	flex calc.l
	gcc -Wall lex.yy.c calc.tab.c reg_alloc.c -o calc

ccode: backend-c.c
	gcc -Wall backend-c.c
	
# Create calc.output for debugging
debug:
	bison -v calc.y

clean:
	rm -f calc.tab.* lex.yy.c calc.output calc a.out
	rm -f frontend-tac.txt reg-alloc-tac.txt backend-c.c backend-reg-c.c