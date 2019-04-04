%{
// Benjamin Steenkamer
// CPEG 621 Lab 2 - Calculator Compiler Back End

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


int yylex(void);						// Will be generated in lex.yy.c by flex

// Following are defined below in sub-routines section
void yyerror(const char *);				// Following are defined below in sub-routines section
char* lc(char *str);
char* gen_tac_code(char * one, char * op, char * three);

int num_temp_vars = 0;					// Number of temp vars in use

int lineNum = 1;						// Used for debugging
FILE * yyin;							// Input file pointer
FILE * tac_output;						// Three address code output file pointer
%}

%define parse.error verbose		// Enable verbose errors
%token INTEGER POWER VARIABLE	// bison adds these #defines in calc.tab.h for use in flex
								// Tells flex what the tokens are

// Union defines all possible values a token can have associated with it
// Allow yylval to hold either an integer or a string
%union 
{
	int dval;
	char * str;
}

// When %union is used to specify multiple value types, must declare the 
// value type of each token for which values are used
// In this case, all values associated with tokens are to be strings
%type <str> INTEGER POWER VARIABLE

// Statements and expressions values are also string type
%type <str> statement expr


// Make grammar unambiguous
// Low to high precedence and associativity within a precedent rank
// https://en.cppreference.com/w/c/language/operator_precedence
%precedence '?'
%left '+' '-'
%left '*' '/'
%precedence '!'		// Unary bitwise not; No associativity b/c it is unary
%right POWER		// ** exponent operator

%start calc

%%

calc :
	calc statement '\n'
	|
	;

statement:
	expr					{
							  // fprintf(tac_output, "%s;\n", $1);	// Don't need to print single expressions
							  free($1);								// as they functionally do nothing
							}
	| VARIABLE '=' expr		{
							  fprintf(tac_output, "%s = %s;\n", lc($1), $3);
							  free($1);
							  free($3);
							}
	;

expr :
	INTEGER			  { $$ = $1; }
	| VARIABLE        { $$ = lc($1); }
	| expr '+' expr   { $$ = gen_tac_code($1, "+", $3); }
	| expr '-' expr   { $$ = gen_tac_code($1, "-", $3); }
	| expr '*' expr   { $$ = gen_tac_code($1, "*", $3); }
	| expr '/' expr   { $$ = gen_tac_code($1, "/", $3); }
	| '!' expr		  { $$ = gen_tac_code(NULL, "!", $2); }
	| expr POWER expr { $$ = gen_tac_code($1, "**", $3); }
	| '(' expr ')'    { $$ = $2; }		// Will give syntax error for unmatched parens
	| '(' expr ')' '?' { /*create if header*/ } '(' expr ')' { }
	;

%%

// Generates and writes out string of three address code
// Frees the input strings
// Returns temporary variable's name (that must be freed later)
char* gen_tac_code(char * one, char * op, char * three)
{
	char tmp_var_name[13]; 	// temp var names: _t0123456789
	
	// Create the temp variable name
	sprintf(tmp_var_name, "_t%d", num_temp_vars);
	num_temp_vars++;
	
	if (one != NULL)
	{
		// Write out three address code
		fprintf(tac_output, "%s = %s %s %s;\n", tmp_var_name, one, op, three);
		free(one);
	}
	else	// Unary operator case
	{
		fprintf(tac_output, "%s = %s%s;\n", tmp_var_name, op, three);
	}

	free(three);
	
	return strdup(tmp_var_name);
}

// Convert a string to lower case
// Use to this to help enforce variable names being case insensitive
char* lc(char *str)
{
	int i;
	for (i = 0; i < strlen(str); i++)
	{
		str[i] = tolower(str[i]);
	}
	return str;
}

void yyerror(const char *s)
{
	printf("%s\n", s);
}

int main(int argc, char *argv[])
{
	// Open the input program file
	if (argc != 2)
	{
		printf("Need to provide input file\n");
		exit(1);
	}
	else
	{
		yyin = fopen(argv[1], "r");
	}
	
	// Open the output file where the three address codes will be written
	tac_output = fopen("frontend-tac.txt", "w");
	
	// Read in the input program
	yyparse();
	
	// Close the files
	fclose(yyin);
	fclose(tac_output);
	
	return 0;
}