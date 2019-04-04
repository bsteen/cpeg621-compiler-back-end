# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# How does 3 address code go from step 1 to step 2, in what format / program?

# Do Task 1
# 	translate to 3 address code
# 		Make sure freeing happens
#		Add unary ! function
#       Add conditional expression
# 		Unnecessary temp register for assignment
# 	Remove unneeded includes
# 	check output file for all required features

# Do Task 3
# ask user inputs for variables
# print out variable values at the end
# Add labels
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