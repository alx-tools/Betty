/*
 * 26 lines with only function call
 */
void more_than_25_lines()
{
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
  line();
}

/*
 * 26 lines with some control statements
 */
void more_than_25_lines_with_control_statements()
{
  char test;
  void *pointer;
  int int1, int2,
      int3;

  if (call_to_function() ||
      second_line())
  {
    /* The following line is blank */

    return ;
  }

  if (condition())
    return ;
  else if (another_condition())
    return ;
  else
    return ;

  line();

  while (42)
  {
    printf("Hello\n");
  }
}
