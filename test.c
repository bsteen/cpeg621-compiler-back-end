#include <stdio.h>
#include <string.h>

#define MAX_USR_VAR_NAME_LEN 20

int main(){
	FILE *test = fopen("test_input0.txt", "r");
	
	char input_buf[128];
	while(fgets(input_buf, 128, test) != NULL)
	{
		printf("%s", input_buf);
		// printf("%d\n", strcmp(input_buf, "{\n") == 0);
		
		// char * bitwise = strstr(input_buf, "!");
		
		// if( bitwise != NULL)
		// {
			// *bitwise = '~';	// Replace ! with ~
		// }
		
		char * pow = strstr(input_buf, "**");
		if (pow != NULL)
		{
			char temp[128];
			strcpy(temp, input_buf);
			
			char *first = strtok(temp, " =*;");
			char *second = strtok(NULL, " =*;");
			char *third = strtok(NULL, " =*;");
	
			int x = sprintf(input_buf, "%s = (int)pow(%s, %s);\n", first, second, third);
			printf("%d\n", x);
		}

		printf("%s", input_buf);
	}
	
	fclose(test);
	
	return 0;
}