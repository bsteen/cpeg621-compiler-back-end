%{
// Benjamin Steenkamer
// CPEG 621 Lab 2 - Calculator Compiler Back End

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_USR_NUM_VARS 30			// Max number of unique user variables allowed
#define MAX_USR_VAR_NAME_LEN 20 	// How long a user variable name can be

int yylex(void);						// Will be generated in lex.yy.c by flex

// Following are defined below in sub-routines section
void yyerror(const char *);				// Following are defined below in sub-routines section
char* gen_tac_code(char * one, char * op, char * three);
void gen_if_start(char * str);
char* lc(char *str);
void gen_c_code();

int num_temp_vars = 0;				// Number of temp vars in use

int num_user_vars = 0;				// Number of user variables in use
int num_user_vars_wo_def = 0;		// Number of user variables that didn't have declarations
char user_vars[MAX_USR_NUM_VARS][MAX_USR_VAR_NAME_LEN];			// List of all unique user vars in proper
char user_vars_wo_def[MAX_USR_NUM_VARS][MAX_USR_VAR_NAME_LEN];	// List of user vars used w/o definition

int lineNum = 1;		// Used for debugging
FILE * yyin;			// Input calc program file pointer
FILE * tac_code;		// Three address code file pointer
FILE * c_code;			// C code produced by backend file pointer
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
							  // fprintf(tac_code, "%s;\n", $1);	// Don't need to print single expressions
							  free($1);								// as they functionally do nothing
							}
	| VARIABLE '=' expr		{
							  fprintf(tac_code, "%s = %s;\n", lc($1), $3);
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
	| '!' expr		  { $$ = gen_tac_code(NULL, "!", $2); }		// Represents bitwise not in calc language
	| expr POWER expr { $$ = gen_tac_code($1, "**", $3); }
	| '(' expr ')'    { $$ = $2; }								// Will give syntax error for unmatched parens
	| '(' expr ')' '?' { gen_if_start($2); } '(' expr ')' { free($2); free($7); }
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
		fprintf(tac_code, "%s = %s %s %s;\n", tmp_var_name, one, op, three);
		free(one);
	}
	else	// Unary operator case
	{
		fprintf(tac_code, "%s = %s%s;\n", tmp_var_name, op, three);
	}

	free(three);
	
	return strdup(tmp_var_name);
}

void gen_if_start(char * str)
{
	fprintf(tac_code, "if(%s) {\n", str);
	// free(str);
	return;
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

// Take the TAC and generate a valid C program code
void gen_c_code()
{
	int i;
	fprintf(c_code, "#include <stdio.h>\n#include <math.h>\nint main() {\n");
	
	// Declare all user variables and initialize them to 0
	if (num_user_vars_vars > 0)
	{
		fprintf(c_code, "\tint ");
	}
	for(i = 0; i < num_user_vars; i++)
	{
		if (i != num_user_vars - 1)
		{
			fprintf("%s, ", user_vars[i]);
		}
		else
		{
			fprintf(c_code, "%s = 0;\n", user_vars[i]);
		}
	}
	
	// Declare all temp variables and initialize them to 0
	if (num_temp_vars > 0)
	{
		fprintf(c_code, "\tint ");
	}
	for(i = 0; i < num_temp_vars; i++)
	{
		if(i != num_temp_vars - 1)
		{
			fprintf(c_code, "_t%d, ", i);
		}
		else
		{
			fprintf(c_code, "%_t%d = 0;\n", i);
		}
	}
	
	// Initialize user variables not assigned (ask user inputs for variables)
	for (i = 0; i < num_user_vars_wo_def; i++)
	{
		printf("printf(\"%s=\");\n", user_vars_wo_def[i]);
		printf("scanf(\"%%d\", &%s);\n\n", user_vars_wo_def[i]);
	}
	
	// Read in TAC file, write to c file with labels
	// Convert lines with ** or ! and replace with pow and ~
	char input_buf[256];
	while(fget(input_buf, 256, tac_code) != NULL)
	{
		
	}
	
	// Print out user variable final values
	for(i = 0; i < num_user_vars; i++)
	{
		fprintf(c_code, "printf(\"%s=%%d\\n\", %s);\n", user_vars[i], user_vars[i]);
	}
	
	fprintf(c_code, "}\n");
	
	return;
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
	tac_code = fopen("frontend-tac.txt", "w");
	
	// Read in the input program
	yyparse();
	
	// Close the files from TAC generation
	fclose(yyin);
	fclose(tac_code);
	
	//Open files for writing C code
	tac_code = fopen("frontend-tac.txt", "r");
	c_code = fopen("backend-c.c", "w");
	
	gen_c_code();	// Generate C code
	
	// Close files from C code generation
	fclose(tac_code);
	fclose(c_code);
	
	return 0;
}