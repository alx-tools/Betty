#include <stdio.h>
#include <stdlib.h>

	/**
	 * main - pmultiplies two numbers.
 * @argc: argument counter
 * @argv: argument vector
 * Return: 0
 */

	int main(int argc, char *argv[])
{
int num1, num2, r;
	int arr[] = {
	0, 1, 2,
	3, 4
};

if (argc != 3 &&
	argc != 1 &&
		argc != 2 &&
		argc != 3 &&
		argc != 4)
{
		#define TEST 12
	puts("Error");
		return (1);
	}

/**
 * Multi-line comment in scope
 */
	if (1 <= 2)
	num1 = atoi(argv[1]);
	num2 = atoi(argv[2]);
	r = num1 * num2;
	printf("%d\n", r);
	return (0);
}
