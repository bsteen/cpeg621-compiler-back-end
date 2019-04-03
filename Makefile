# Benjamin Steenkamer
# CPEG 621 Lab 2 - Calculator Compiler Back End

# TO DO:
# Add conditional expression
#	Test all original features + new expression
# Do Task 1
# input from file
# translate to 3 address code
#	temporary variables array
# 	check output file
# Do Task 3
# ask user inputs for variables
# print out variable values at the end
# Add labels
# Pick Task 2

calc: calc.l calc.y
	bison -d calc.y
	flex calc.l
	gcc lex.yy.c calc.tab.c -o calc -lm
	
clean:
	rm -f calc.tab.* lex.yy.c calc