int main(void)
{
	int i = 10;

	/* Assignment is first operand */
	if ((i = 0) == 1)
		return (1);

	/* Assignment is second operand */
	if (1 == (i = 0))
		return (1);

	/* Assignment with arithmetic */
	if ((i *= 2) == 1)
		return (1);
	if ((i /= 2) == 1)
		return (1);
	if ((i %= 2) == 1)
		return (1);
	if ((i += 2) == 1)
		return (1);
	if ((i -= 2) == 1)
		return (1);

	/* Assignment with bitwise */
	if ((i &= 2) == 1)
		return (1);
	if ((i |= 2) == 1)
		return (1);
	if ((i ^= 2) == 1)
		return (1);
	if ((i >>= 2) == 1)
		return (1);
	if ((i <<= 2) == 1)
		return (1);

	/* The following are not assignments */
	if ((i == 2) == 1)
		return (1);
	if ((i != 2) == 1)
		return (1);
	if ((i >= 2) == 1)
		return (1);
	if ((i <= 2) == 1)
		return (1);

	return (0);
}
