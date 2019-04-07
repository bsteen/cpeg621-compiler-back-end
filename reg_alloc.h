#define MAX_USR_NUM_VARS 30			// Max number of unique user variables allowed
#define MAX_USR_VAR_NAME_LEN 30 	// How long a user variable name can be (not including \0)
#define MAX_TOTAL_VARS	128
#define MAX_LIVE_PERIODS 128	// Max number of distinct periods in which a var can be alive

void allocate_registers(char* file_name);