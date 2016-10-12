#ifndef _HEADERS0_H_
#define _HEADERS0_H_

#define SAMPLE 98
#define SAMPLE1 (98 + 402)

struct sample_s
{
	char *str;
	int i;
};

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

/* ----- */

typedef struct sample_s sample_s;
typedef union sample_u sample_u;
typedef enum sample_e sample_e;

/* ----- */

typedef struct sample1_s
{
	char *str;
	int i;
} sample1_s;

typedef union sample1_u
{
	char rgba[4];
	int value;
} sample1_u;

typedef enum sample1_e
{
	FIRST = 0,
	SECOND,
	THIRD
} sample1_e;

#endif /* _HEADERS0_H_ */
