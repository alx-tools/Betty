int main(void)
{
	int i = 10;

	/* Assignment is first operand */
	switch ((i = 0) == 1)
		return (1);

	/* Assignment is second operand */
	switch (1 == (i = 0))
		return (1);

	/* Assignment with arithmetic */
	switch ((i *= 2) == 1)
		return (1);
	switch ((i /= 2) == 1)
		return (1);
	switch ((i %= 2) == 1)
		return (1);
	switch ((i += 2) == 1)
		return (1);
	switch ((i -= 2) == 1)
		return (1);

	/* Assignment with bitwise */
	switch ((i &= 2) == 1)
		return (1);
	switch ((i |= 2) == 1)
		return (1);
	switch ((i ^= 2) == 1)
		return (1);
	switch ((i >>= 2) == 1)
		return (1);
	switch ((i <<= 2) == 1)
		return (1);

	/* The following are not assignments */
	switch ((i == 2) == 1)
		return (1);
	switch ((i != 2) == 1)
		return (1);
	switch ((i >= 2) == 1)
		return (1);
	switch ((i <= 2) == 1)
		return (1);

	return (0);
}
