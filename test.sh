#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

tests_folder="tests"
tests_style_folder="$tests_folder/style"
tests_doc_folder="$tests_folder/doc"

style_exec="betty-style.pl"
doc_exec="betty-doc.pl"

errors=0

# # # # # # # # # # # # #
# Testing coding style  #
# # # # # # # # # # # # #

echo -e "Testing coding style specs..."

for dir in $tests_style_folder/*/
do
	dir=${dir%*/}
	echo -e "Found ${CYAN}${dir##*/}${NC} folder..."

	for file in ${dir}/*.{c,h}
	do

		if [ "${file}" == "${dir}/*.c" ] || [ "${file}" == "${dir}/*.h" ]
		then
			continue
		fi

		if [[ "${file}" == *.c ]]
		then
			current_test=${file%*.c}
		else
			current_test=${file%*.h}
		fi

		echo -e "\tTesting ${PURPLE}${current_test}${NC}..."

		src="${file}"
		expected="$current_test.expected"

		if [ ! -f $expected ]
		then
			echo -e "\t${RED}Missing expected output, ignored${NC}"
			echo
			continue
		fi

		output=$(./$style_exec $src)
		exp=$(cat $expected)

		if [ "$output" != "$exp" ]
		then
			echo -e "\t${RED}Error. The output is not the one expected:${NC}"
			echo "$output"
			let errors++
		else
			echo -e "\t${GREEN}Test passed successfully!${NC}"
		fi
		echo
	done
done

# # # # # # # # # # # # #
# Testing documentation #
# # # # # # # # # # # # #

echo -e "Testing documentation style specs..."

dir=${tests_doc_folder%*/}
echo -e "Found ${CYAN}${dir##*/}${NC} folder..."

for file in ${dir}/*.{c,h}
do

	if [ "${file}" == "${dir}/*.c" ] || [ "${file}" == "${dir}/*.h" ]
	then
		continue
	fi

	if [[ "${file}" == *.c ]]
	then
		current_test=${file%*.c}
	else
		current_test=${file%*.h}
	fi

	echo -e "\tTesting ${PURPLE}${current_test}${NC}..."

	src="${file}"
	expected_stdout="$current_test.expected.stdout"
	expected_stderr="$current_test.expected.stderr"

	if [ ! -f $expected_stdout ]
	then
		echo -e "\t${RED}Missing expected_stdout, ignored${NC}"
		echo
		continue
	fi

	if [ ! -f $expected_stderr ]
	then
		echo -e "\t${RED}Missing expected_stderr, ignored${NC}"
		echo
		continue
	fi

	rm -f "/tmp/stderr"
	output=$(./$doc_exec $src 2> /tmp/stderr)
	status=$(echo $?)
	err=$(cat /tmp/stderr)
	exp_stdout=$(cat $expected_stdout)
	exp_stderr=$(cat $expected_stderr)

	if [ "$output" != "$exp_stdout" ]
	then
		echo -e "\t${RED}Error. The output (stdout) is not the one expected:${NC}"
		echo "$output"
		let errors++
	else
		echo -e "\t${GREEN}Test passed successfully!${NC}"
	fi
	if [ "$err" != "$exp_stderr" ]
	then
		echo -e "\t${RED}Error. The error output (stderr) is not the one expected:${NC}"
		echo "$err"
		let errors++
	else
		echo -e "\t${GREEN}Test passed successfully!${NC}"
	fi

	if [ "$status" == "0" ]
	then
		if [[ $err = *[!\ ]* ]]
		then
			echo -e "\t${RED}Error. The error output (stderr) should be empty if the program successed:${NC}"
			echo $err
			let errors++
		else
			echo -e "\t${GREEN}Test passed successfully!${NC}"
		fi
	else
		if [[ $err = *[!\ ]* ]]
		then
			echo -e "\t${GREEN}Test passed successfully!${NC}"
		else
			echo -e "\t${RED}Error. The error output (stderr) should be empty if the program successed:${NC}"
			echo $err
			let errors++
		fi
	fi
	echo
done

# # # # # # # # # # # #
# Count total errors  #
# # # # # # # # # # # #

if [ $errors -gt 0 ]
then
	echo -e "${RED}${errors} test(s) didn't passed...${NC}"
	exit 1
fi

echo -e "${GREEN}All tests passed successfully!${NC}"
exit 0
