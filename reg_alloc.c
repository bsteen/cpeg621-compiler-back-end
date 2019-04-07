#include "reg_alloc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct node {
	char var_name[MAX_USR_VAR_NAME_LEN];
	
	int num_live_periods;					// Number of liveness start/end periods
	int live_starts[MAX_LIVE_PERIODS];		// Line in TAC where variable starts life
	int live_ends[MAX_LIVE_PERIODS];		// Last line in TAC where variable is used
	
	int num_neighbors;	// Total number of variables this variable interferes with
	int neighbors[MAX_TOTAL_VARS];
} Node;

Node node_list[MAX_TOTAL_VARS];
int num_nodes = 0;

// Print out all nodes and their values
// Used for debugging
void print_nodes()
{
	int i, j;
	for(i = 0; i < num_nodes; i++)
	{
		Node temp = node_list[i];
		printf("%s: ", temp.var_name);
		
		for (j = 0; j < temp.num_live_periods; j++)
		{
			printf("[%d, %d] ", temp.live_starts[j], temp.live_ends[j]);
		}
		
		printf("[");
		for(j = 0; j < temp.num_neighbors; j++)
		{
			printf("%s ", node_list[temp.neighbors[j]].var_name);
		}
		printf("]\n");
	}
	
	return;
}

// Find variable's node index in node_list
// Return -1 if variable node not found
int get_node_index(char * var_name)
{
	int i = 0;
	for(i = 0; i < num_nodes; i++)
	{
		if(strcmp(node_list[i].var_name, var_name) == 0)
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
		strcpy(node_list[num_nodes].var_name, var_name);
		
		node_list[num_nodes].live_starts[0] = line_num;
		node_list[num_nodes].live_ends[0] = line_num;
		node_list[num_nodes].num_live_periods = 1;
		node_list[num_nodes].num_neighbors = 0;
		
		num_nodes++;
	}
	else // The node already exists, update live periods
	{
		if (assigned)	// If variable is being assigned new a value, start new liveness period
		{	
			int n = node_list[index].num_live_periods;
			node_list[index].live_starts[n] = line_num;
			node_list[index].live_ends[n] = line_num;
			node_list[index].num_live_periods++;
		}
		else
		{
			int n = node_list[index].num_live_periods - 1;
			node_list[index].live_ends[n] = line_num;
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
	Node node1 = node_list[node_idx1];
	Node node2 = node_list[node_idx2];
	int i, j=0;
	
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
				int n = node_list[i].num_neighbors;
				node_list[i].neighbors[n] = j;	// Mark node j as a neighbor to i
				node_list[i].num_neighbors++;
			}
		}
	}
	
	return;
}

void allocate_registers(char* file_name)
{
	
	// First two functions create the RIG
	initialize_nodes(file_name);
	find_neighbors();
	
	print_nodes();
	
	return;
}


