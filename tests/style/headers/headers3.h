#ifndef _PROTECTION_H_
#define TEST 5

struct sample_s
{
	char *str;
	int i;
};

#endif
#ifndef _TEST_H_
#define _TEST_H_
union sample_u
{
	char rgba[4];
	int value;
};

enum sample_e
{
	FIRST = 0,
	SECOND,
	THIRD
};
#endif
/* ----- */

typedef struct sample_s sample_s;
typedef union sample_u sample_u;
typedef enum sample_e sample_e;
