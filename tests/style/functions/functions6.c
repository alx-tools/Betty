int test_lexer(test_chain_t *chain)
{
	const char	*line = chain->line;
	t_t	        *t = t_create();
	char		quote = 0;
	int		error = 0;

	while (*line && !error)
	{
		const char	*start = test_skip_space(line);
		test_t		*test = test_find_test(start);
		const char	*end = line;

		if (test->test)
		{
			end = process_test(chain, &t, test, start);
		}
		else
		{
			end = test_skip_any(start, &quote);
			if (end - start > 0)
			{
				if (!t->test &&
					(t->test_type == MACRO_TEST_0 ||
					t->test_type == MACRO_TEST_1 ||
					t->test_type == MACRO_TEST_2 ||
					t->test_type == MACRO_TEST_3))
				{
					t->test = hstrndup(start, end - start);
				}
				else
				{
					ARRAY_ADD(t->v, hstrndup(start, end - start), V_BUFFER_SIZE);
				}
			}
			else if (*end)
			{
				end++;
			}
		}
		line = end;
	}
	if (error)
	{
		hprintf("parsing error @ %s", line);
	}
	ARRAY_ADD(t->v, NULL, V_BUFFER_SIZE);
	ARRAY_ADD(chain->root.tests, t, 2);
	ARRAY_ADD(chain->root.tests, NULL, 1);
	return (!quote);
}
