/**
 * get_op_func - Get operator function
 *
 * @s: The operator
 *
 * Return: The function associated to the operator @s
 */
int (*get_op_func(char *s))(int, int)
{
	_op_t ops[] = {
		{"+", op_add},
		{"-", op_sub},
		{"*", op_mul},
		{"/", op_div},
		{"%", op_mod},
		{NULL, NULL}
	};
	int i;

	i = 0;
	while (ops[i].op != NULL)
	{
		if (strcmp(ops[i].op, s) == 0)
		{
			return (ops[i].f);
		}
		i++;
	}
	return (NULL);
}

/**
 * get_op_func - Get operator function
 *
 * @s: The operator
 *
 * Return: The function associated to the operator @s
 */
int (*get_op_func(char *s)) (int, int)
{
	_op_t ops[] = {
		{"+", op_add},
		{"-", op_sub},
		{"*", op_mul},
		{"/", op_div},
		{"%", op_mod},
		{NULL, NULL}
	};
	int i;

	i = 0;
	while (ops[i].op != NULL)
	{
		if (strcmp(ops[i].op, s) == 0)
		{
			return (ops[i].f);
		}
		i++;
	}
	return (NULL);
}

/**
 * get_valid_type - Test
 *
 * @s: Test
 *
 * Return: Test
 */
char *(*get_valid_type(char s))(void)
{
	return (NULL);
}
