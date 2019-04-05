# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# How does 3 address code go from step 1 to step 2, in what format / program?
# Do Task 1
#	Add conditional expression
# 	check output files (TAC and C) for all required features
# 		Make sure } doesn't get a line number
# 	Make sure freeing happens
# 	Unnecessary temp register for assignment to user variable?
# Read notes
# Pick Task 2

calc: calc.l calc.y
	bison -d calc.y
	flex calc.l
	gcc -Wall lex.yy.c calc.tab.c -o calc
	
test: test.c
	gcc -Wall test.c
	
# Create calc.output for debugging
debug:
	bison -v calc.y
	
clean:
	rm -f calc.tab.* lex.yy.c calc.output frontend-tac.txt backend-c.c calc a.out