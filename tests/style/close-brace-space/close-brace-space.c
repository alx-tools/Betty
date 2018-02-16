/*
 * The check 'close-brace-space' should never be triggered
 * It was implemented at first because 'else` was allowed on
 * the same line as the closing brace of the preceeding 'if'
 *
 * if (cond) {
 * } else {
 * }
 *
 * We keep it, so it is here in case we need it in the future :)
 */

#include <stdlib.h>

int main(void)
{
	struct test_s arr[2] = {
		{12, {1, 2, 3, 4}},
		{12, {1, 2, 3, 4}},
	};

	return (EXIT_SUCCESS);
}
