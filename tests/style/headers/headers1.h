#ifndef _HEADERS1_H_
#define _HEADERS1_H_

#define sample 98
#define sample1 98 + 402

struct sample_s {
	char *str;
	int i;
};

union sample_u {
	char rgba[4];
	int value;
};

enum sample_e {
	first = 0,
	second,
	third
};

/* ----- */

typedef struct sample_s sample_s;
typedef union sample_u sample_u;
typedef enum sample_e sample_e;

/* ----- */

typedef struct sample1_s {
	char *str;
	int i;
} sample1_s;

typedef union sample1_u {
	char rgba[4];
	int value;
} sample1_u;

typedef enum sample1_e {
	first = 0,
	second,
	third
} sample1_e;

#endif /* _HEADERS1_H_ */
