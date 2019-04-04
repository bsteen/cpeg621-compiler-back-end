# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# How does 3 address code go from step 1 to step 2, in what format / program?
# Add conditional expression
# Do Task 1
# 	translate to 3 address code  frontend-tac-output.txt
#	temporary variables array
# 	check output file
# Do Task 3
# ask user inputs for variables
# print out variable values at the end
# Add labels
# Read notes
# Pick Task 2

calc: calc.l calc.y
	bison -d calc.y
	flex calc.l
	gcc lex.yy.c calc.tab.c -o calc -lm
	
# Create calc.output for debugging
debug:
	bison -v calc.y
	
clean:
	rm -f calc.tab.* lex.yy.c calc.output calc