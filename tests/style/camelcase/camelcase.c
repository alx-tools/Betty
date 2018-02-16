#include <stdlib.h>

void CamelFunc(void);
void (*CamelFunc2(void))(void);

int main(void)
{
	int CamelCaseVar = 0;
	int camelCaseVar = 0;
	int Camelcasevar = 0;
	int camelcasevar = 0; /* This is ok */
	int CamelCase_Var = 0;
	int Camel_Case_Var = 0;
	int camel_Case_Var = 0;
	int camel_case_Var = 0;
	int camel_case_var = 0; /* This is ok */
	int Camel_case_var = 0;

	return (EXIT_SUCCESS);
}
