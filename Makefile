# Benjamin Steenkamer
# CPEG 621, Lab 2 - Calculator Compiler Back End

calc: calc.l calc.y
	bison -d calc.y
	flex calc.l
	gcc lex.yy.c calc.tab.c -o calc -lm
	
clean:
	rm -f calc.tab.* lex.yy.c calc