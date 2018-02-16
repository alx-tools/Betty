int main(void)
{
	int i = 10;

	if (i == -1)
		return (-1);

	/* Assignment is first operand */
	else if ((i = 0) == 1)
		return (1);

	/* Assignment is second operand */
	else if (1 == (i = 0))
		return (1);

	/* Assignment with arithmetic */
	else if ((i *= 2) == 1)
		return (1);
	else if ((i /= 2) == 1)
		return (1);
	else if ((i %= 2) == 1)
		return (1);
	else if ((i += 2) == 1)
		return (1);
	else if ((i -= 2) == 1)
		return (1);

	/* Assignment with bitwise */
	else if ((i &= 2) == 1)
		return (1);
	else if ((i |= 2) == 1)
		return (1);
	else if ((i ^= 2) == 1)
		return (1);
	else if ((i >>= 2) == 1)
		return (1);
	else if ((i <<= 2) == 1)
		return (1);

	/* The following are not assignments */
	else if ((i == 2) == 1)
		return (1);
	else if ((i != 2) == 1)
		return (1);
	else if ((i >= 2) == 1)
		return (1);
	else if ((i <= 2) == 1)
		return (1);

	return (0);
}
