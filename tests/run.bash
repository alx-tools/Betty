#!/bin/bash

if [[ $# -eq 0 ]] ; then
	echo "Usage: $0 test_folder"
	exit 1
fi

if [ ! -d "style/$1" ]; then
	echo "style/$1: No such directory"
	exit 1
fi

for f in $(ls style/$1/*.{c,h} 2> /dev/null)
do
	# [[ "${f}" == *.c ]] && base=${f%*.c} || base=${f%*.h}

	if [ ! -f "${f}.normal" ]; then
		betty s $f > "${f}.normal"
		echo "Wrote ${f}.normal"
	else
		echo "${f}.normal already exists"
	fi

	if [ ! -f "${f}.brief" ]; then
		betty s -b $f > "${f}.brief"
		echo "Wrote ${f}.brief"
	else
		echo "${f}.brief already exists"
	fi

	if [ ! -f "${f}.context" ]; then
		betty s -c $f > "${f}.context"
		echo "Wrote ${f}.context"
	else
		echo "${f}.context already exists"
	fi

done
