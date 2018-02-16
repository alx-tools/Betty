int main(void)
{
	int i = 10;

	/* Assignment is first operand */
	while ((i = 0) == 1)
		return (1);

	/* Assignment is second operand */
	while (1 == (i = 0))
		return (1);

	/* Assignment with arithmetic */
	while ((i *= 2) == 1)
		return (1);
	while ((i /= 2) == 1)
		return (1);
	while ((i %= 2) == 1)
		return (1);
	while ((i += 2) == 1)
		return (1);
	while ((i -= 2) == 1)
		return (1);

	/* Assignment with bitwise */
	while ((i &= 2) == 1)
		return (1);
	while ((i |= 2) == 1)
		return (1);
	while ((i ^= 2) == 1)
		return (1);
	while ((i >>= 2) == 1)
		return (1);
	while ((i <<= 2) == 1)
		return (1);

	/* The following are not assignments */
	while ((i == 2) == 1)
		return (1);
	while ((i != 2) == 1)
		return (1);
	while ((i >= 2) == 1)
		return (1);
	while ((i <= 2) == 1)
		return (1);

	return (0);
}
