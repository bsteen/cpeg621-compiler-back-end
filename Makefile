# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# Task 2: Reg alloc
# 	Fix unnecessary liveness overload
# 	Build RIG
#	Profitable algo
# 	Create forward pass
# 	Create reverse pass
#	Spill all registers at end
# 	Print out final reg alloc TAC (reg-alloc-tac.txt)
# Do Task 1
#	Add conditional expression
#		Edit reg alloc to work with if/else
# 	check output files (TAC and C) for all required features
# 		Make sure } doesn't get a line number
# 	Make sure freeing happens
# 	Unnecessary temp register for assignment to user variable? (will have to change reg alloc liveness)
# Lab report

calc: calc.l calc.y reg_alloc.c reg_alloc.h
	bison -d calc.y
	flex calc.l
	gcc -Wall lex.yy.c calc.tab.c reg_alloc.c -o calc
	
# Create calc.output for debugging
debug:
	bison -v calc.y
	
clean:
	rm -f calc.tab.* lex.yy.c calc.output frontend-tac.txt backend-c.c calc a.out