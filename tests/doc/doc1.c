int op_add(int arg1, int arg2)
{
	return (arg1 + arg2);
}

int main(int ac, char **av)
{
	(void)ac;
	(void)av;
	op_add(1, 2);
	return (0);
}
