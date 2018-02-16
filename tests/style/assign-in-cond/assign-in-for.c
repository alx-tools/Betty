int main(void)
{
	int i = 10;

	/* Assignment is first operand */
	for (i = 10; (i = 0) == 1; i = i + 1)
		return (1);

	/* Assignment is second operand */
	for (i = 10; 1 == (i = 0); i = i + 1)
		return (1);

	/* Assignment with arithmetic */
	for (i = 10; (i *= 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i /= 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i %= 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i += 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i -= 2) == 1; i = i + 1)
		return (1);

	/* Assignment with bitwise */
	for (i = 10; (i &= 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i |= 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i ^= 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i >>= 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i <<= 2) == 1; i = i + 1)
		return (1);

	/* The following are not assignments */
	for (i = 10; (i == 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i != 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i >= 2) == 1; i = i + 1)
		return (1);
	for (i = 10; (i <= 2) == 1; i = i + 1)
		return (1);

	return (0);
}
