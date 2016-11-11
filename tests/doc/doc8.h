#ifndef _DOC6_H_
#define _DOC6_H_

/**
 * dog - A Dog structure
 *
 * @name: Name
 * @age: Test
 * @owner: The owner
 */
struct dog
{
	char *name;
	float age;
	char *owner;
};

/**
 * test - Test
 *
 * @FIRST: First
 * @SECOND: Second
 * @THIRD: Third
 */
enum test
{
	FIRST = 0,
	SECOND,
	THIRD
};

/**
 * color - Color
 *
 * @rgba: RGBA
 * @value: Value
 */
union color
{
	char rgba[4];
	unsigned int value;
};

/**
 * animal - Animal
 *
 * @name: The name
 * @race: Race
 * @color: color
 */
typedef struct animal
{
	char *name;
	enum test race;
	union color color;
} t_animal;

/**
 * test2 - Test
 *
 * @FIRST: First
 * @SECOND: Second
 * @THIRD: Third
 */
typedef enum test2
{
	FIRST = 0,
	SECOND,
	THIRD
} e_test2;

/**
 * color2 - Color
 *
 * @rgba: RGBA
 * @value: Value
 */
typedef union color2
{
	char rgba[4];
	unsigned int value;
} u_color;

/* No doc is required for func prototypes */
void init_dog(struct dog *d, char *name, float age, char *owner);
void print_dog(struct dog *d);

#endif /* _DOC6_H_ *?
