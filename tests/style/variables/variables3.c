struct test1_s *_getline(const int fd,
	struct test_s *test,
	enum test_e test2)
{
	return (test);
}

typedef unsigned int sample;

struct sample_s
{
	int data;
};

enum sample_e
{
	FIRST = 0,
	SECOND
};

union sample_u
{
	char rgba[4];
	int value;
};

int main(void)
{
	struct dog my_dog;

	my_dog.name = "Django";
	my_dog.age = 3.5;
	my_dog.owner = "Jay";
	printf("My name is %s, and I am %.1f :) - Woof!\n", my_dog.name, my_dog.age);
	return (0);
}
