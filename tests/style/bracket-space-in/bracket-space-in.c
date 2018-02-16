#include <stdlib.h>
#include <stdio.h>

int main(void)
{
	int a[ 10 ];
	int b[  10  ][   10   ];

	a[ 1] = 2;
	a[2 ] = 1;

	b[  2][2  ] = 3;
	b[2   ][   3] = 4;

	printf("a[ 1] = %d\n", a[1 ]);
	printf("b[2  ][  2] = %d\n", b[ 2  ][  2 ]);
	printf("b[   2][3   ] = %d\n", b[   2 ][ 3   ]);
	return (EXIT_SUCCESS);
}
