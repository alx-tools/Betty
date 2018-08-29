#include <stdlib.h>

int main(void)
{
	char const *str = "Hello;World;!";
	char *s;

	s = _strtok(str, ";", NULL);

	return (EXIT_SUCCESS);
}
