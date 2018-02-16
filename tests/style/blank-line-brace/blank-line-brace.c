#include <stdlib.h>

void func(void)
{
	int test[] = {

		1, 2, 3, 4

	};

	if (1 == 2)
	{

		(void)test;
		func();

	}
}

int main(void)
{

	return (EXIT_SUCCESS);

}
