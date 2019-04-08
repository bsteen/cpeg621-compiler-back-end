#include "reg_alloc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct node
{
	char var_name[MAX_USR_VAR_NAME_LEN];
	
	int reg;								// Register variable is assigned to
	int reg_tag;							// no spill, may spill
	int profit;								// The profitability of a variable

	int num_live_periods;					// Number of liveness start/end periods
	int live_starts[MAX_LIVE_PERIODS];		// Line in TAC where variable starts life
	int live_ends[MAX_LIVE_PERIODS];		// Last line in TAC where variable is used

	int num_neighbors;						// Total number of variables this variable interferes with
	int neighbors[MAX_TOTAL_VARS];
} Node;

int num_nodes = 0;					// Number of notes in RIG
Node node_graph[MAX_TOTAL_VARS];	// Register interference graph (RIG)

int stack_ptr = 0;					// points to next open spot at top of stack
Node node_stack[MAX_TOTAL_VARS];

// Used for debugging
// Print out all nodes in RIG and their values
void print_node_graph()
{
	int i, j;
	for(i = 0; i < num_nodes; i++)
	{
		Node temp = node_graph[i];
		printf("%s (%d): ", temp.var_name, temp.profit);

		for (j = 0; j < temp.num_live_periods; j++)
		{
			printf("[%d, %d] ", temp.live_starts[j], temp.live_ends[j]);
		}

		printf("[");
		for(j = 0; j < temp.num_neighbors; j++)
		{
			printf("%s ", node_graph[temp.neighbors[j]].var_name);
		}
		printf("]\n");
	}

	return;
}

// Used for debugging
// Print out all nodes in node stack
void print_node_stack()
{
	int i;
	for(i = stack_ptr - 1; i >= 0; i--)
	{
		printf("%s %d\n", node_stack[i].var_name, node_stack[i].reg_tag);
	}
}

// Helper function used by create_node
// Find variable's node index in node_graph
// Return -1 if variable node not found
int get_node_index(char * var_name)
{
	int i = 0;
	for(i = 0; i < num_nodes; i++)
	{
		if(strcmp(node_graph[i].var_name, var_name) == 0)
		{
			return i;
		}
	}

	return -1;
}

// Helper function used by initialize_nodes
// Either creates new node entry or updates existing ones
// Initializes or updates liveness of variable
void create_node(char * var_name, int line_num, int assigned)
{
	if (var_name == NULL || var_name[0] < 'A')	// Ignore empty tokens and constants
	{
		return;
	}

	int index = get_node_index(var_name);

	// if not found create node with live_start = live_end
	if(index == -1)
	{
		if(num_nodes >= MAX_TOTAL_VARS)
		{
			printf("Maximum number of nodes created\n");
			exit(1);
		}

		// Initialize node values
		strcpy(node_graph[num_nodes].var_name, var_name);
		node_graph[num_nodes].profit = 1;
		node_graph[num_nodes].live_starts[0] = line_num + 1;
		node_graph[num_nodes].live_ends[0] = line_num + 1;
		node_graph[num_nodes].num_live_periods = 1;
		node_graph[num_nodes].num_neighbors = 0;
		
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
		else	// If not being assigned, update end period time if new value occurs later
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

// Read in the TAC file and find each variable
// Initialize the node for each variable
void initialize_nodes(char* file_name)
{
	FILE * tac_code = fopen(file_name, "r");
	if(tac_code == NULL)
	{
		printf("Can't open TAC file in register allocation stage\n");
		exit(1);
	}

	char line[128];
	int line_num = 1;
	while(fgets(line, 128, tac_code) != NULL)
	{
		// CHECK IF FOR IF/ELSE LINES HERE

		// At most 3 tokens per TAC line
		create_node(strtok(line, " +-*/!=;"), line_num, 1);	// First token will be variable assignment
		create_node(strtok(NULL, " +-*/!=;"), line_num, 0);
		create_node(strtok(NULL, " +-*/!=;"), line_num, 0);	// Will return NULL if no 3rd token
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
void find_neighbors()
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

// Remove all edge to neighbor nodes, push node to stack with tag, remove node from RIG, 
void remove_and_push(int node_idx, int node_tag)
{
	// Remove neighbors' edges to node
	int i, j;
	for(i = 0; i < node_graph[node_idx].num_neighbors; i++)
	{
		int neighbor_idx = node_graph[node_idx].neighbors[i];

		// Go through each neighbor's neighbor list, find reference to self
		for(j = 0; j < node_graph[neighbor_idx].num_neighbors; j++)
		{
			if(node_graph[neighbor_idx].neighbors[j] == node_idx)
			{
				break;
			}
		}
		
		// Reorder neighbor's neighbor list by shifting next item on top of previous
		// Deletes reference to self in process
		for(j = j; j < node_graph[neighbor_idx].num_neighbors - 1; j++)
		{
			node_graph[neighbor_idx].neighbors[j] = node_graph[neighbor_idx].neighbors[j + 1];
		}
		
		node_graph[neighbor_idx].num_neighbors--;
	}
	
	// Push node to stack with tag
	node_stack[stack_ptr] = node_graph[node_idx];
	node_stack[stack_ptr].reg_tag = node_tag;
	stack_ptr++;
	node_graph[node_idx].var_name[0] = '\0'; // "Remove" node from graph by making name blank
	
	return;
}

// Allocate registers using a RIG and a heuristic "optimistic" algorithm
void allocate_registers(char* file_name)
{
	// First two functions create the RIG
	initialize_nodes(file_name);
	find_neighbors();

	print_node_graph();

	int nodes_left = num_nodes;
	
	// Forward pass
	while(nodes_left > 0)
	{
		int continue_simplify = 1;
		while(continue_simplify)	// Continue to remove nodes until no nodes where num_neighbors < NUM_REG
		{
			continue_simplify = 0;
			int i;
			for(i = 0; i < num_nodes; i++)
			{
				// Nodes with empty name have already been removed
				if(strcmp(node_graph[i].var_name, "") != 0 && node_graph[i].num_neighbors < NUM_REG)
				{
					remove_and_push(i, NO_SPILL);
					nodes_left--;
					continue_simplify = 1;
				}
			}
		}

	}
	
	print_node_stack();

	return;
}