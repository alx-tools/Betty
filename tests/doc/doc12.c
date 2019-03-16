/**
 * tester - return updated struct
 * @s: structure to get
 *
 * Return: s but with s.item multiplied by 2
 */
struct test tester(struct test s)
{
	s.item *= 2;
	return (s);
}
