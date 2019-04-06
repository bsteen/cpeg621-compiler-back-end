%{
// Benjamin Steenkamer
// CPEG 621 Lab 2 - Calculator Compiler Back End

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_USR_NUM_VARS 30			// Max number of unique user variables allowed
#define MAX_USR_VAR_NAME_LEN 30 	// How long a user variable name can be (not including \0)

int yylex(void);					// Will be generated in lex.yy.c by flex

// Following are defined below in sub-routines section
void yyerror(const char *);				// Following are defined below in sub-routines section
char* gen_tac_code(char * one, char * op, char * three);
void gen_if_else(char * cond_expr, char * expr);
char* lc(char *str);
void gen_c_code();
void track_user_var(char * var, int assigned);

int num_temp_vars = 0;				// Number of temp vars in use

int num_user_vars = 0;				// Number of user variables in use
int num_user_vars_wo_def = 0;		// Number of user variables that didn't have declarations
char user_vars[MAX_USR_NUM_VARS][MAX_USR_VAR_NAME_LEN + 1];			// List of all unique user vars in proper
char user_vars_wo_def[MAX_USR_NUM_VARS][MAX_USR_VAR_NAME_LEN + 1];	// List of user vars used w/o definition

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

// Conditional expressions and expressions values are also string type
%type <str> expr 

// Make grammar unambiguous
// Low to high precedence and associativity within a precedent rank
// https://en.cppreference.com/w/c/language/operator_precedence
%right '?'
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
								free($1);							// as they functionally do nothing
							}
	| VARIABLE '=' expr		{
								track_user_var(lc($1), 1);
								fprintf(tac_code, "%s = %s;\n", lc($1), $3);
								free($1);
								free($3);
							}
	| '(' expr ')' '?' '(' expr ')'
					  {
						gen_if_else($2, $6);
						free($2);
						free($6);
					  }
	;
	
expr :
	INTEGER			  { $$ = $1; }
	| VARIABLE        { $$ = lc($1); track_user_var(lc($1), 0); }
	| expr '+' expr   { $$ = gen_tac_code($1, "+", $3); }
	| expr '-' expr   { $$ = gen_tac_code($1, "-", $3); }
	| expr '*' expr   { $$ = gen_tac_code($1, "*", $3); }
	| expr '/' expr   { $$ = gen_tac_code($1, "/", $3); }
	| '!' expr		  { $$ = gen_tac_code(NULL, "!", $2); }		// Represents bitwise not in calc language
	| expr POWER expr { $$ = gen_tac_code($1, "**", $3); }
	| '(' expr ')'    { $$ = $2; }								// Will give syntax error for unmatched parens
	;

%%

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

void gen_if_else(char * cond_expr, char * expr)
{
	fprintf(tac_code, "if(%s) {\n", cond_expr);
	// fprintf(tac_code, "else {\n\t%s = 0;\n}\n", dest);
	return;
}

// Records all first appearances of user variables for use in C code generation
// If variable is not being defined and hasn't been used before, add it to list of uninitialized variables
void track_user_var(char *var, int assigned)
{
	// Check if variable has been recorded before
	int i;
	for(i = 0; i < num_user_vars; i++)
	{
		if(strcmp(user_vars[i], var) == 0)
		{
			return; // If the variable was already recorded, don't need to record it again
		}
	}

	// Check if variable is valid
	if(num_user_vars >= MAX_USR_NUM_VARS)
	{
		yyerror("Max number of user variables reached");
		exit(1);	// Exit since variable (and therefor the entire program) is not valid
	}
	else if (strlen(var) > MAX_USR_VAR_NAME_LEN)
	{
		yyerror("Variable name too long");
		exit(1); 	// Exit since variable (and therefor the entire program) is not valid
	}

	// If the variable hasn't been seen before, need to record its first appearance
	if(!assigned)	// If variable is not being assigned a value, then it's first use is without a definition
	{
		strcpy(user_vars_wo_def[num_user_vars_wo_def], var);
		num_user_vars_wo_def++;
	}

	strcpy(user_vars[num_user_vars], var);
	num_user_vars++;

	return;
}

// Take the TAC and generate a valid C program code
void gen_c_code()
{
	int i;
	fprintf(c_code, "#include <stdio.h>\n#include <math.h>\n\nint main() {\n");

	// Declare all user variables and initialize them to 0
	if (num_user_vars > 0)
	{
		fprintf(c_code, "\tint ");
	}
	for(i = 0; i < num_user_vars; i++)
	{
		if (i != num_user_vars - 1)
		{
			fprintf(c_code, "%s, ", user_vars[i]);
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
			fprintf(c_code, "_t%d = 0;\n\n", i);
		}
	}

	// Initialize user variables not assigned (ask user inputs for variables)
	for (i = 0; i < num_user_vars_wo_def; i++)
	{
		fprintf(c_code, "\tprintf(\"%s=\");\n", user_vars_wo_def[i]);
		fprintf(c_code, "\tscanf(\"%%d\", &%s);\n\n", user_vars_wo_def[i]);
	}

	// Read in TAC file, write to c file with labels
	// Convert lines with ** or ! and replace with pow and ~
	char line_buf[128];
	char *bitwise;
	char *pow;
	i = 0;
	while(fgets(line_buf, 128, tac_code) != NULL)
	{
		bitwise = strstr(line_buf, "!");
		pow = strstr(line_buf, "**");

		if(bitwise != NULL) // Replace ! with ~
		{
			*bitwise = '~';
		}

		if(pow != NULL)		// Split up the line with a ** and reformat it with a pow() func
		{
			char temp[128];
			strcpy(temp, line_buf);

			char *first = strtok(temp, " =*;");		// Lines with ** will always have 3 operands
			char *second = strtok(NULL, " =*;");
			char *third = strtok(NULL, " =*;");

			sprintf(line_buf, "%s = (int)pow(%s, %s);\n", first, second, third);
		}

		if(strcmp(line_buf, "}\n") == 0)	// Don't print label if line is a closing }
		{
			fprintf(c_code, "\t\t\t%s", line_buf);
			continue;
		}

		// Print c code line with line # label
		if(i < 10)
		{
			fprintf(c_code, "\tS%d:\t\t%s", i, line_buf);
		}
		else
		{
			fprintf(c_code, "\tS%d:\t%s", i, line_buf);
		}

		i++;
	}

	fprintf(c_code, "\n");

	// Print out user variable final values
	for(i = 0; i < num_user_vars; i++)
	{
		fprintf(c_code, "\tprintf(\"%s=%%d\\n\", %s);\n", user_vars[i], user_vars[i]);
	}

	fprintf(c_code, "\n\treturn 0;\n}\n");

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
		yyerror("Need to provide input file");
		exit(1);
	}
	else
	{
		yyin = fopen(argv[1], "r");
		if(yyin == NULL)
		{
			yyerror("Couldn't open input file");
			exit(1);
		}
	}

	// Open the output file where the three address codes will be written
	tac_code = fopen("frontend-tac.txt", "w");
	if (tac_code == NULL)
	{
		yyerror("Couldn't create TAC file");
		exit(1);
	}

	// Read in the input program
	yyparse();

	// Close the files from TAC generation
	fclose(yyin);
	fclose(tac_code);

	// Open files for writing C code
	tac_code = fopen("frontend-tac.txt", "r");
	c_code = fopen("backend-c.c", "w");
	if (tac_code == NULL)
	{
		yyerror("Couldn't open TAC file");
		exit(1);
	}
	if (c_code == NULL)
	{
		yyerror("Couldn't create C code file");
		exit(1);
	}

	gen_c_code();	// Generate C code

	// Close files from C code generation
	fclose(tac_code);
	fclose(c_code);

	return 0;
}