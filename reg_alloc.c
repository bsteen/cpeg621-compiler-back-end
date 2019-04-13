#include "reg_alloc.h"
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct node
{
	char var_name[MAX_USR_VAR_NAME_LEN];

	int assigned_reg;						// Register variable is assigned to
	int undefined;							// Variables first appears without definition (i.e. no var = ...;)
	int loaded;								// Has variable been loaded in a register for first read
	int dirty;								// Has the var been written to while stored in a register
	int reg_tag;							// no spill, may spill

	int profit;								// The profitability of a variable
	int num_live_periods;					// Number of liveness start/end periods
	int live_starts[MAX_LIVE_PERIODS];		// Line in TAC where variable starts life
	int live_ends[MAX_LIVE_PERIODS];		// Last line in TAC where variable is used
	int num_neighbors;						// Total number of variables this variable interferes with
	int neighbors[MAX_TOTAL_VARS];
} Node;

// Assuming only two-deep nested ifs are allowed for this project
typedef struct if_spills
{
	int inside_if_1;
	int if_1_start_line;
	int num_spilled1;
	int vars_spilled1[MAX_TOTAL_VARS];

	int inside_if_2;
	int if_2_start_line;
	int num_spilled2;
	int vars_spilled2[MAX_TOTAL_VARS];

} If_Spills;

If_Spills if_spill_tracker;			// Tracks spills that occur inside if/else statements

int num_nodes = 0;					// Number of notes in RIG
Node node_graph[MAX_TOTAL_VARS];	// Register interference graph (RIG)

int stack_ptr = 0;					// points to next open spot at top of stack
Node node_stack[MAX_TOTAL_VARS];

// Given index for a node in node_graph, return variable name of that node
// Wrapper for code_graph[index].var_name;
char * get_node_name(int index)
{
	if(index >= num_nodes || index < 0)
	{
		printf("Index out of bounds\n");
		exit(1);
	}

	return node_graph[index].var_name;
}

// Helper function used by update_node
// Find variable's node index in node_graph
// Return -1 if variable node not found
int get_node_index(char * var_name)
{
	int i = 0;
	for(i = 0; i < num_nodes; i++)
	{
		if(strcmp(get_node_name(i), var_name) == 0)
		{
			return i;
		}
	}

	return -1;
}

// Used for debugging
// Print out all nodes in RIG and their values
void print_node_graph()
{
	printf("RIG: Var_name\tregister profit undefined [live start, live end] ... [neighbors]\n");
	int i, j;
	for(i = 0; i < num_nodes; i++)
	{
		Node temp = node_graph[i];
		printf("%s\tr=%d p=%d u=%d l=", temp.var_name, temp.assigned_reg, temp.profit, temp.undefined);

		for (j = 0; j < temp.num_live_periods; j++)
		{
			printf("[%d, %d] ", temp.live_starts[j], temp.live_ends[j]);
		}

		printf("n=[");
		for(j = 0; j < temp.num_neighbors; j++)
		{
			printf("%s ", get_node_name(temp.neighbors[j]));
		}
		printf("]\n");
	}
	printf("\n");

	return;
}

// Used for debugging
// Print out all nodes in node stack
void print_node_stack()
{
	printf("\nNode stack: Var name\tregister spill label\n");
	int i;
	for(i = stack_ptr - 1; i >= 0; i--)
	{
		if (node_stack[i].reg_tag == NO_SPILL)
		{
			printf("%s\t%s\n", node_stack[i].var_name, "NO_SPILL");
		}
		else
		{
			printf("%s\t%s\n", node_stack[i].var_name, "MAY_SPILL");
		}
	}

	printf("\n");
}

// Helper function used by initialize_nodes
// Either creates new node entry or updates existing ones
// Initializes or updates liveness of variable
void update_node(char * var_name, int line_num, int assigned)
{
	if (var_name == NULL || var_name[0] < 'A')	// Ignore empty tokens and constants
	{
		return;
	}

	int index = get_node_index(var_name);

	// if not found, create node with live_start = live_end
	if(index == -1)
	{
		if(num_nodes >= MAX_TOTAL_VARS)
		{
			printf("Maximum number of nodes created\n");
			exit(1);
		}

		// Initialize node values
		strcpy(node_graph[num_nodes].var_name, var_name);
		node_graph[num_nodes].assigned_reg = -1;
		node_graph[num_nodes].loaded = 0;
		node_graph[num_nodes].dirty = 0;
		node_graph[num_nodes].reg_tag = -1;
		node_graph[num_nodes].profit = 1;
		node_graph[num_nodes].num_live_periods = 1;
		node_graph[num_nodes].num_neighbors = 0;

		if(assigned)	// If variable is being assigned value on first use, then it's defined
		{
			node_graph[num_nodes].undefined = 0;
			node_graph[num_nodes].live_starts[0] = line_num + 1;
			node_graph[num_nodes].live_ends[0] = line_num + 1;
		}
		else
		{
			node_graph[num_nodes].undefined = 1;	// Variables first appears as undefined value
			node_graph[num_nodes].live_starts[0] = line_num;
			node_graph[num_nodes].live_ends[0] = line_num;
		}

		num_nodes++;
	}
	else // The node already exists, update values
	{
		node_graph[index].profit++;

		if (assigned)	// If variable is being assigned new a value, start new liveness period
		{
			int n = node_graph[index].num_live_periods;
			node_graph[index].live_starts[n] = line_num + 1;
			node_graph[index].live_ends[n] = line_num + 1;
			node_graph[index].num_live_periods++;
		}
		else	// If not being assigned, update end liveness time if new value occurs later
		{
			int n = node_graph[index].num_live_periods - 1;

			if(line_num > node_graph[index].live_ends[n])
			{
				node_graph[index].live_ends[n] = line_num;
			}
		}
	}

	return;
}

// Read in the frontend TAC file and find each variable
// Initialize the node for each variable
void initialize_nodes(char* file_name)
{
	FILE * tac_code = fopen(file_name, "r");
	if(tac_code == NULL)
	{
		printf("Can't open frontend TAC file in register allocation stage\n");
		exit(1);
	}

	char line[MAX_USR_VAR_NAME_LEN * 4];
	int line_num = 1;
	while(fgets(line, MAX_USR_VAR_NAME_LEN * 4, tac_code) != NULL)
	{
		if (strstr(line, "if(") != NULL)
		{
			strtok(line, "()");		//Skip over "if"
			update_node(strtok(NULL, "()"), line_num, 0);
		}
		else if(strstr(line, "else {") == NULL && strstr(line, "}") == NULL)
		{
			// At most 3 tokens per TAC line
			update_node(strtok(line, " +-*/!=;"), line_num, 1);	// First token will be variable assignment
			update_node(strtok(NULL, " +-*/!=;"), line_num, 0);
			update_node(strtok(NULL, " +-*/!=;"), line_num, 0);	// Will return NULL if no 3rd token
		}

		line_num++;
	}

	fclose(tac_code);

	return;
}

// Helper function for find_neighbors
// Determines if two nodes interfere (liveness periods overlap)
int does_interfere(int node_idx1, int node_idx2)
{
	Node node1 = node_graph[node_idx1];
	Node node2 = node_graph[node_idx2];
	int i, j = 0;

	for(i = 0; i < node1.num_live_periods; i++)	// Iterate over node 1's liveness periods
	{
		for(j = 0; j < node2.num_live_periods; j++)	// Compare to node 2's liveness periods
		{
			if((node1.live_ends[i] >= node2.live_starts[j])
			&& (node1.live_starts[i] <= node2.live_ends[j]))
			{
				return 1;
			}
		}
	}

	return 0;
}

// Finish the register interference graph by marking edges between each variable
// node that interfere with each other
// Interference is when two variables are alive at the same time
void find_all_neighbors()
{
	int i;	// Index of node currently being looked at
	int j;	// Index of potential neighbor node to i

	for(i = 0; i < num_nodes; i++)
	{
		for(j = 0; j < num_nodes; j++)
		{
			if(i != j && does_interfere(i, j))	// Ignore self and check interference with other nodes
			{
				int n = node_graph[i].num_neighbors;
				node_graph[i].neighbors[n] = j;	// Add node j to node i's neighbor list
				node_graph[i].num_neighbors++;
			}
		}
	}

	return;
}

// Remove all node's edges to neighbor nodes, push node to stack with tag, remove node from RIG
// Nodes are removed from RIG by setting their name to an empty string
void remove_and_push(int node_idx, int node_tag)
{
	// Remove neighbors' edges to node
	int i, j;
	for(i = 0; i < node_graph[node_idx].num_neighbors; i++)	// Go to each neighbor of node
	{
		int neighbor_idx = node_graph[node_idx].neighbors[i];
		int found = 0;

		// Go through each neighbor's neighbor list, find index of node being removed
		for(j = 0; j < node_graph[neighbor_idx].num_neighbors; j++)
		{
			if(node_graph[neighbor_idx].neighbors[j] == node_idx)
			{
				found = 1;
				break;		// j is index in the neighbor's neighbor list that contains node to be removed
			}
		}

		if(!found)	// Make sure it actually found the correct edge and didn't just reach the end of the loop
		{
			printf("Did not find edge to %s in neighbor node %s's neighbor list\n", get_node_name(node_idx), get_node_name(neighbor_idx));
			exit(1);
		}

		// Reorder neighbor's neighbor list by shifting next item on top of previous
		// Overwrites edge to node being removed from RIG in process
		for(; j < node_graph[neighbor_idx].num_neighbors - 1; j++)
		{
			node_graph[neighbor_idx].neighbors[j] = node_graph[neighbor_idx].neighbors[j + 1];
		}

		node_graph[neighbor_idx].num_neighbors--;

	}

	// Push node to stack with tag
	node_stack[stack_ptr] = node_graph[node_idx];		// Copy node from RIG to stack
	node_stack[stack_ptr].reg_tag = node_tag;			// Set register tag
	node_stack[stack_ptr].num_neighbors = 0;			// Clear pushed node's neighbor values
	stack_ptr++;

	node_graph[node_idx].var_name[0] = '\0'; 			// "Remove" node from graph by making name blank

	return;
}

// Select register for node that hasn't already been assigned to one of it's neighbors
// All nodes with NO_SPILL will get a register; nodes with MAY_SPILL may or may not get one
void select_register(int node_idx)
{
	int taken_regs[NUM_REG];	// List of registers that are already used by node's neighbors
	memset(taken_regs, 0, sizeof(int) * NUM_REG);	// Zero means register index+1 not in use

	int i;
	for(i = 0; i < node_graph[node_idx].num_neighbors; i++)
	{
		int neighbor_idx = node_graph[node_idx].neighbors[i];
		int neighbor_reg_num = node_graph[neighbor_idx].assigned_reg;

		if(neighbor_reg_num != -1)
		{
			taken_regs[neighbor_reg_num - 1] = 1;		// Register are r1, r2, ...
		}
	}

	for(i = 0; i < NUM_REG; i++)
	{
		if(taken_regs[i] == 0)
		{
			node_graph[node_idx].assigned_reg = i + 1;	// Register are r1, r2, ...
			return;
		}
	}

	if(node_graph[node_idx].reg_tag == NO_SPILL)	// Node with NO_SPILL label should always get register
	{
		printf("Node %s with NO_SPILL label didn't get register\n", get_node_name(node_idx));
		exit(1);
	}

	node_graph[node_idx].assigned_reg = -1;		// Only node with MAY_SPILL can get no register assigned
}

// Write the variable to the output TAC file
// If the variable was assigned a register, switch variable name for register
// If the variable is in a register and is READ for the first time, load the variable into the register
void write_out_variable(FILE * output_tac_file, char * output_line, char * var, int assigned, int line_num)
{
	int node_idx = get_node_index(var);

	if(node_idx == -1)
	{
		printf("Variable name \"%s\" not found when writing to reg alloc TAC file\n", var);
		exit(1);
	}

	int reg = node_graph[node_idx].assigned_reg;

	if(reg != -1)
	{
		// Load undefined variable into register BEFORE first read
		// Checks if value was already loaded to prevent unnecessary double load in edge cases (e.g.: x = a + a)
		// Don't do this if variable's first use is an assignment/is defined (initial value will be overwritten)
		if(!node_graph[node_idx].loaded && node_graph[node_idx].live_starts[0] == line_num
			&& node_graph[node_idx].undefined)
		{
			fprintf(output_tac_file, "_r%d = %s;\n", reg, var);
			node_graph[node_idx].loaded = 1;
		}

		char reg_name[13]; 				// register name can be _r##########
		sprintf(reg_name, "_r%d", reg);
		strcat(output_line, reg_name);

		// If a user variable stored in a register is being assigned a value, mark as dirty
		// Ignore temporary variables (which start with an '_'), they don't need to be spilled
		if (assigned)
		{
			if(var[0] != '_')
			{
				node_graph[node_idx].dirty = 1;
			}
			strcat(output_line, " = ");
		}
	}
	else	// Variable was not placed a register (don't need to load to register or mark as dirty)
	{
		strcat(output_line, var);

		if(assigned)
		{
			strcat(output_line, " = ");
		}
	}

	return;
}

// Spill register values back to user variables if their register value is dirty
// and they are at the end of a liveness period (conservative spilling algo)
// 
void spill_to_variables(FILE * output_tac_file, int line_num)
{
	int i;
	for(i = 0; i < num_nodes; i++)	// Go through each variable and see if it needs to be spilled
	{
		if(node_graph[i].dirty)
		{
			int num_live_periods = node_graph[i].num_live_periods;
			int do_spill = 0;
			int j;
			
			// See if one of the variable's liveness periods ends at current line
			for(j = 0; j < num_live_periods; j++)
			{
				if(node_graph[i].live_ends[j] == line_num)
				{
					do_spill = 1;
					break;
				}
			}
			
			// Spill the register back to the user variable
			if(do_spill)
			{
				fprintf(output_tac_file, "%s = _r%d;\n", node_graph[i].var_name, node_graph[i].assigned_reg);
				node_graph[i].dirty = 0;	// Reset dirty value

				int current_live_start = node_graph[i].live_starts[j];	// Get the starting point of the current live period

				// Handle case where variable is spilled inside an if/else statement
				if(if_spill_tracker.inside_if_2 && (current_live_start <= if_spill_tracker.if_2_start_line))
				{
					if_spill_tracker.vars_spilled2[if_spill_tracker.num_spilled2] = i;
					if_spill_tracker.num_spilled2++;
					
					// If var was defined even before the start of outer if statement, it also needs to be spilled
					// in the outer if statement incase the inner if statement is not run
					if((current_live_start <= if_spill_tracker.if_1_start_line))
					{
						if_spill_tracker.vars_spilled1[if_spill_tracker.num_spilled1] = i;
						if_spill_tracker.num_spilled1++;
					}
				}
				else if(if_spill_tracker.inside_if_1 && (current_live_start <= if_spill_tracker.if_1_start_line))
				{
					if_spill_tracker.vars_spilled1[if_spill_tracker.num_spilled1] = i;
					if_spill_tracker.num_spilled1++;
				}
			}
		}
	}

	return;
}

// Certain registers that were spilled in the if statement also
// need to be spilled in the else statement
void after_if_spill(FILE * output_tac_file, int if_num)
{
	int num_spilled;
	int * vars_spilled;

	if(if_num == 1) // Outer if
	{
		num_spilled = if_spill_tracker.num_spilled1;
		vars_spilled = if_spill_tracker.vars_spilled1;
		if_spill_tracker.num_spilled1 = 0; 	// Reset for next use
	}
	else 	// if_num == 2, inner if
	{
		num_spilled = if_spill_tracker.num_spilled2;
		vars_spilled = if_spill_tracker.vars_spilled2;
		if_spill_tracker.num_spilled2 = 0;	// Reset for next use
	}

	printf("Spilling variables from if#%d: ", if_num);

	int i;
	for(i = 0; i < num_spilled; i++)
	{
		int node_idx = vars_spilled[i];
		fprintf(output_tac_file, "%s = _r%d;\n", node_graph[node_idx].var_name, node_graph[node_idx].assigned_reg);
		printf("%s ", node_graph[node_idx].var_name);
	}
	printf("\n");

	return;
}

// Initialize values of if_spill_tracker
void init_if_spill_tracker()
{
	if_spill_tracker.inside_if_1 = 0;
	if_spill_tracker.if_1_start_line = 0;
	if_spill_tracker.num_spilled1 = 0;

	if_spill_tracker.inside_if_2 = 0;
	if_spill_tracker.if_2_start_line = 0;
	if_spill_tracker.num_spilled2 = 0;

	return;
}

// Create the TAC with register assignment
// Reads in frontend TAC and replaces variables with assigned registers
// Also inserts spilling
void gen_reg_tac(char * input_tac_file_name, char * output_tac_file_name)
{
	FILE * input_tac_file = fopen(input_tac_file_name,"r");
	FILE * output_tac_file = fopen(output_tac_file_name,"w");

	if(input_tac_file == NULL)
	{
		printf("Can't open input TAC file (%s) in register allocation stage\n", input_tac_file_name);
		exit(1);
	}
	else if(output_tac_file == NULL)
	{
		printf("Can't create output TAC file (%s) in register allocation stage\n", output_tac_file_name);
		exit(1);
	}

	// Read in front end TAC and insert registers
	char input_line[MAX_USR_VAR_NAME_LEN * 4];		// Frontend TAC line read in
	char output_line[MAX_USR_VAR_NAME_LEN * 4];		// TAC line with register assignment written out

	int line_num = 1;

	// Initial tracker for spills inside ifs
	init_if_spill_tracker();

	while(fgets(input_line, MAX_USR_VAR_NAME_LEN * 4, input_tac_file) != NULL)
	{
		strcpy(output_line, ""); 							// Clear output line for next use
		spill_to_variables(output_tac_file, line_num);		// Write back register values to vars on their last use

		// Handle if/else statements
		if(strstr(input_line, "if(") != NULL)
		{
			strtok(input_line, " ()");			// Skip over if
			char * token = strtok(NULL, " ()");	// Token is value inside the ()

			strcat(output_line, "if(");

			if(token[0] < 'A')	// Is a constant
			{
				strcat(output_line, token);
			}
			else
			{
				write_out_variable(output_tac_file, output_line, token, 0, line_num);
			}

			strcat(output_line, ") {\n");

			if(!if_spill_tracker.inside_if_1)
			{
				if_spill_tracker.inside_if_1 = 1;
				if_spill_tracker.if_1_start_line = line_num;
				printf("if 1 starts at line# %d\n", line_num);
			}
			else
			{
				if_spill_tracker.inside_if_2 = 1;
				if_spill_tracker.if_2_start_line = line_num;
				printf("if 2 starts at line# %d\n", line_num);
			}

			fprintf(output_tac_file, output_line);		// Write out the completed line
			line_num++;

			continue;
		}
		else if(strstr(input_line, "} else {") != NULL)
		{
			fprintf(output_tac_file, input_line);
			line_num++;

			if(if_spill_tracker.inside_if_2)
			{
				if_spill_tracker.inside_if_2 = 0;	// Leaving 2nd if and entering its else
				after_if_spill(output_tac_file, 2);
			}
			else
			{
				if_spill_tracker.inside_if_1 = 0;	// Leaving 1st if and entering its else
				after_if_spill(output_tac_file, 1);
			}

			continue;
		}
		else if(strstr(input_line, "}") != NULL)	// Ending of else statement
		{
			fprintf(output_tac_file, input_line);
			line_num++;
			
			continue;
		}


		// Not counting if/else statements, the first token will always be an assignment
		char * token = strtok(input_line, " =");
		write_out_variable(output_tac_file, output_line, token, 1, line_num);

		token = strtok(NULL, " =;\n");

		while(token != NULL)
		{
			if(token[0] == '!')
			{
				if(token[1] < 'A')	 // Write out !constant
				{
					strcat(output_line, token);
				}
				else				// Write out !variable or !register
				{
					strcat(output_line, "!");
					write_out_variable(output_tac_file, output_line, token + 1, 0, line_num);	// Don't include ! in variable name
				}
			}
			else if(token[0] < '0')	// Write out operators: +, -, *, /, **
			{
				strcat(output_line, " ");
				strcat(output_line, token);
				strcat(output_line, " ");
			}
			else
			{
				if(token[0] < 'A')	// Write out constant value
				{
					strcat(output_line, token);
				}
				else				// Write out variable
				{
					write_out_variable(output_tac_file, output_line, token, 0, line_num);
				}
			}

			token = strtok(NULL, " =;\n");
		}

		strcat(output_line, ";\n");

		fprintf(output_tac_file, output_line);		// Write out the completed line
		line_num++;
	}

	// Need to spill registers of variables that die after the last TAC file line
	spill_to_variables(output_tac_file, line_num);

	fclose(input_tac_file);
	fclose(output_tac_file);

	return;
}

// Allocate registers using a RIG and a heuristic "optimistic" algorithm
// Then write out TAC code with register assignment
// This is the main logic function for this file
void allocate_registers(char * frontend_tac_file_name, char * reg_tac_file_name)
{
	// First two functions create the RIG
	initialize_nodes(frontend_tac_file_name);
	find_all_neighbors();

	// print_node_graph();

	// Forward pass
	int nodes_left = num_nodes;
	while(nodes_left > 0)
	{
		int continue_simplify = 1;
		while(continue_simplify)	// Remove nodes until no nodes where num_neighbors < NUM_REG
		{
			continue_simplify = 0;
			int i;
			for(i = 0; i < num_nodes; i++)
			{
				// Nodes with empty name have already been removed
				if(strcmp(get_node_name(i), "") != 0 && node_graph[i].num_neighbors < NUM_REG)
				{
					remove_and_push(i, NO_SPILL);
					nodes_left--;
					continue_simplify = 1;
				}
			}
		}

		if(nodes_left > 0)	// Spill step
		{
			int least_profit = INT_MAX;
			int i, least_prof_idx;

			for(i = 0; i < num_nodes; i++)
			{
				// Find variable that is least profitable
				if(strcmp(get_node_name(i), "") != 0 && node_graph[i].profit < least_profit)
				{
					least_prof_idx = i;
					least_profit = node_graph[i].profit;
				}
			}

			remove_and_push(least_prof_idx, MAY_SPILL);
			nodes_left--;
		}
	}

	// print_node_stack();

	// Reverse pass
	int i;
	int j = 0;
	for(i = stack_ptr - 1; i >= 0; i--)		// Put values from stack back into graph array
	{										// (top is left most, bottom is right most)
		node_graph[j] = node_stack[i];
		j++;
	}

	find_all_neighbors();		// Rebuild neighbor list

	for(i = 0; i < num_nodes; i++)
	{
		select_register(i);		// Assign registers
	}

	print_node_graph();

	// Create output TAC with register assignment inserted
	gen_reg_tac(frontend_tac_file_name, reg_tac_file_name);

	return;
}
