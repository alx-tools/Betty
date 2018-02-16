#include <stdio.h>
#include <stdlib.h>

extern void test_func(void)
{
	printf("Hello world\n");
}

int main(void)
{
	test_func();
	return (EXIT_SUCCESS);
}

