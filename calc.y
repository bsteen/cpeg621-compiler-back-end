%{
// Benjamin Steenkamer
// CPEG 621 Lab 2 - Calculator Compiler Back End

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "reg_alloc.h"

int yylex(void);					// Will be generated in lex.yy.c by flex

// Following are defined below in sub-routines section
void my_free(char * ptr);
char* lc(char *str);
void gen_tac_assign(char * var, char * expr);
char* gen_tac_expr(char * one, char * op, char * three);
void gen_tac_if(char * cond_expr);
void gen_tac_assign_else(char * expr);
void gen_tac_empty_else();
void track_user_var(char * var, int assigned);
void gen_c_code();
void yyerror(const char *);

int do_gen_else = 0;				// When set do the else part of the if/else statement
int num_temp_vars = 0;				// Number of temp vars in use
int num_user_vars = 0;				// Number of user variables in use
int num_user_vars_wo_def = 0;		// Number of user variables that didn't have declarations
char user_vars[MAX_USR_NUM_VARS][MAX_USR_VAR_NAME_LEN + 1];			// List of all unique user vars in proper
char user_vars_wo_def[MAX_USR_NUM_VARS][MAX_USR_VAR_NAME_LEN + 1];	// List of user vars used w/o definition

int flex_line_num = 1;		// Used for debugging
FILE * yyin;				// Input calc program file pointer
FILE * tac_file;			// Three address code file pointer
FILE * c_code_file;			// C code produced by backend file pointer
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
%right '='
%right '?'
%left '+' '-'
%left '*' '/'
%precedence '!'		// Unary bitwise not; No associativity b/c it is unary
%right POWER		// ** exponent operator

%start calc

%%

calc :
	calc expr '\n'		{ my_free($2); gen_tac_empty_else(); }
	|
	;

expr :
	INTEGER				{ $$ = $1; }
	| VARIABLE        	{ $$ = lc($1); track_user_var(lc($1), 0); }
	| VARIABLE '=' expr	{ $$ = lc($1); gen_tac_assign(lc($1), $3); my_free($3); }
	| expr '+' expr		{ $$ = gen_tac_expr($1, "+", $3); my_free($1); my_free($3); }
	| expr '-' expr		{ $$ = gen_tac_expr($1, "-", $3); my_free($1); my_free($3); }
	| expr '*' expr		{ $$ = gen_tac_expr($1, "*", $3); my_free($1); my_free($3); }
	| expr '/' expr		{ $$ = gen_tac_expr($1, "/", $3); my_free($1); my_free($3); }
	| '!' expr			{ $$ = gen_tac_expr(NULL, "!", $2); my_free($2); }		// Bitwise not in calc lang
	| expr POWER expr	{ $$ = gen_tac_expr($1, "**", $3); my_free($1); my_free($3);}
	| '(' expr ')'		{ $$ = $2; }					// Will give syntax error for unmatched parens
	| '(' expr ')' '?' { gen_tac_if($2); } '(' expr ')'
						{
							$$ = $7;
							do_gen_else++;	// Keep track of how many closing elses are need for 
							my_free($2);	// nested if/else cases
						}
	;

%%

// Used for debugging
// Print out token being freed
void my_free(char * ptr)
{
	if(ptr == NULL)
	{
		yyerror("Tried to free null pointer!");
	}
	else
	{
		// printf("Freed token: %s\n", ptr);
		free(ptr);
	}

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

// For case where variable is being assigned an expression
void gen_tac_assign(char * var, char * expr)
{
	track_user_var(var, 1);

	fprintf(tac_file, "%s = %s;\n", var, expr);

	gen_tac_assign_else(var);

	return;
}

// Generates and writes out string of three address code
// Returns temporary variable's name (that must be freed later)
char* gen_tac_expr(char * one, char * op, char * three)
{
	char tmp_var_name[13]; 	// temp var names: _t0123456789

	// Create the temp variable name
	sprintf(tmp_var_name, "_t%d", num_temp_vars);
	num_temp_vars++;

	if (one != NULL)
	{
		// Write out three address code
		fprintf(tac_file, "%s = %s %s %s;\n", tmp_var_name, one, op, three);
	}
	else	// Unary operator case
	{
		fprintf(tac_file, "%s = %s%s;\n", tmp_var_name, op, three);
	}

	return strdup(tmp_var_name);
}

// Print out the if part of the if/else statement
void gen_tac_if(char * cond_expr)
{
	fprintf(tac_file, "if(%s) {\n", cond_expr);

	return;
}

// Print out closing brace of if statement and the whole else statement
// else will be a variable being assigned to a value of zero
void gen_tac_assign_else(char * expr)
{
	for (; do_gen_else > 0; do_gen_else--)
	{
		fprintf(tac_file, "} else {\n%s = 0;\n}\n", expr);
	}

	return;
}

// If the result of the conditional expression is not being written to a variable
// the else part will be empty
void gen_tac_empty_else()
{
	for (; do_gen_else > 0; do_gen_else--)
	{
		fprintf(tac_file, "} else {\n}\n");
	}

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
void gen_c_code(char * input, char * output, int regs)
{
	// Open files for reading TAC and writing C code
	tac_file = fopen(input, "r");
	c_code_file = fopen(output, "w");
	if (tac_file == NULL)
	{
		yyerror("Couldn't open TAC file in C code generation step");
		exit(1);
	}
	if (c_code_file == NULL)
	{
		yyerror("Couldn't create C code output file");
		exit(1);
	}

	int i;
	fprintf(c_code_file, "#include <stdio.h>\n#include <math.h>\n\nint main() {\n");

	// Declare all user variables and initialize them to 0
	if (num_user_vars > 0)
	{
		fprintf(c_code_file, "\tint ");
	}
	for(i = 0; i < num_user_vars; i++)
	{
		if (i != num_user_vars - 1)
		{
			fprintf(c_code_file, "%s = 0, ", user_vars[i]);
		}
		else
		{
			fprintf(c_code_file, "%s = 0;\n", user_vars[i]);
		}
	}

	// Declare all temp variables and initialize them to 0
	if (num_temp_vars > 0)
	{
		fprintf(c_code_file, "\tint ");
	}
	for(i = 0; i < num_temp_vars; i++)
	{
		if(i < num_temp_vars - 1)
		{
			fprintf(c_code_file, "_t%d = 0, ", i);
		}
		else
		{
			fprintf(c_code_file, "_t%d = 0;\n", i);
		}
	}

	// Create register variables
	if(regs)
	{
		fprintf(c_code_file, "\tint ");
		for(i = 0; i < NUM_REG; i++)
		{
			if(i < NUM_REG - 1)
			{
				fprintf(c_code_file, "_r%d = 0, ", i + 1);
			}
			else
			{
				fprintf(c_code_file, "_r%d = 0;\n", i + 1);
			}
		}
	}

	fprintf(c_code_file, "\n");

	// Initialize user variables not assigned (ask user input for variables)
	for (i = 0; i < num_user_vars_wo_def; i++)
	{
		fprintf(c_code_file, "\tprintf(\"%s=\");\n", user_vars_wo_def[i]);
		fprintf(c_code_file, "\tscanf(\"%%d\", &%s);\n\n", user_vars_wo_def[i]);
	}

	// Read in TAC file, write to c file with line labels
	// Convert lines with ** or ! and replace with pow or ~
	char line_buf[MAX_USR_VAR_NAME_LEN * 4];
	char *bitwise;
	char *pow;
	i = 0;
	while(fgets(line_buf, MAX_USR_VAR_NAME_LEN * 4, tac_file) != NULL)
	{
		// Don't print label if line is a closing } or else statement
		if(strcmp(line_buf, "}\n") == 0 || strcmp(line_buf, "} else {\n") == 0)
		{
			fprintf(c_code_file, "\t\t\t%s", line_buf);
			continue;
		}

		bitwise = strstr(line_buf, "!");
		pow = strstr(line_buf, "**");

		if(bitwise != NULL) 		// Replace ! with ~
		{
			*bitwise = '~';
		}
		else if(pow != NULL)		// Split up the line with a ** and reformat it with a pow() func
		{
			char temp[MAX_USR_VAR_NAME_LEN * 4];
			strcpy(temp, line_buf);

			char *first = strtok(temp, " =*;");		// Lines with ** will always have 3 operands
			char *second = strtok(NULL, " =*;");
			char *third = strtok(NULL, " =*;");

			sprintf(line_buf, "%s = (int)pow(%s, %s);\n", first, second, third);
		}

		// Print c code line with line # label
		if(i < 10)
		{
			fprintf(c_code_file, "\tS%d:\t\t%s", i, line_buf);
		}
		else
		{
			fprintf(c_code_file, "\tS%d:\t%s", i, line_buf);
		}

		i++;	// Increment line number
	}

	fprintf(c_code_file, "\n");

	// Print out user variable final values
	for(i = 0; i < num_user_vars; i++)
	{
		fprintf(c_code_file, "\tprintf(\"%s=%%d\\n\", %s);\n", user_vars[i], user_vars[i]);
	}

	fprintf(c_code_file, "\n\treturn 0;\n}\n");

	// Close files from C code generation
	fclose(tac_file);
	fclose(c_code_file);

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
	char * frontend_tac_name = "Output/tac-frontend.txt";
	tac_file = fopen(frontend_tac_name, "w");
	
	if (tac_file == NULL)
	{
		yyerror("Couldn't create TAC file");
		exit(1);
	}

	yyparse();	// Read in the input program and parse the tokens

	// Close the files from initial TAC generation
	fclose(yyin);
	fclose(tac_file);

	char * reg_tac_file_name = "Output/tac-reg-alloc.txt";
	allocate_registers(frontend_tac_name, reg_tac_file_name);			// Take input TAC and allocate registers, output new TAC
	
	char * opt_reg_tac_file_name = "Output/opt-tac-reg-alloc.txt";
	remove_self_assignment(reg_tac_file_name, opt_reg_tac_file_name);	// Remove useless self assignment lines from TAC
	
	gen_c_code(frontend_tac_name, "Output/c-backend.c", 0);				// Generate C code from initial TAC (has not regs)
	gen_c_code(opt_reg_tac_file_name, "Output/c-reg-backend.c", 1); 	// Generate C code from optimized register alloc TAC

	return 0;
}
