#include <stdio.h>
#include <stdlib.h>

extern char *str_g;

char *str_g = "Hello Wrorld";

int main(void)
{
	printf("Global string: %s\n", str_g);

	return (EXIT_SUCCESS);
}

