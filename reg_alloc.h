#define MAX_USR_NUM_VARS 		30		// Max number of unique user variables allowed
#define MAX_USR_VAR_NAME_LEN 	30 		// How long a user variable name can be (not including \0)
#define MAX_TOTAL_VARS			128		// Total number of unique variables (user and temp) that can appear
#define MAX_LIVE_PERIODS 		128		// Max number of distinct periods in which a var can be alive
#define NUM_REG					4		// Number of registers available ("k" value for graph coloring)

#define NO_SPILL				0
#define MAY_SPILL				1

int FRONTEND_TAC_LINES;		// Count how many lines are in fronted TAC output file
void allocate_registers(char * frontend_tac_file_name, char * reg_tac_file_name);
