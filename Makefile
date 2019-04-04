# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# How does 3 address code go from step 1 to step 2, in what format / program?

# Do Task 3
# 	Keep track of user variables as they are used
# 	Note if they are used in assignment
#	Read in TAC file, write to c file with labels, close file
# Do Task 1
# 	translate to 3 address code
#		Add conditional expression
# 		Make sure freeing happens
# 		Unnecessary temp register for assignment to user variable
# 	Remove unneeded includes
# 	check output file for all required features
# Read notes
# Pick Task 2

calc: calc.l calc.y
	bison -d calc.y
	flex calc.l
	gcc -Wall lex.yy.c calc.tab.c -o calc
	
# Create calc.output for debugging
debug:
	bison -v calc.y
	
clean:
	rm -f calc.tab.* lex.yy.c calc.output frontend-tac.txt calc