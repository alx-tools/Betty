void func0(int var1, int var2)
{
	int *addr;

	addr = & var1;
	var2 = * addr;
	var1 = + var2;
	var1 = - var2;
	var1 = ~ var2;
	var1 = ! var2;
}

void func1(int var1)
{
	var1 ++;
	var1 --;
	++ var1;
	-- var1;
}
