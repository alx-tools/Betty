#! /bin/bash

list="./tests"

samples_dir="samples"
output_path="/tmp/Betty_tests"
output_file="$output_path/output"

mkdir $output_path

while read check; do
  echo -e "Start check: \033[0;36m$check\033[0m"
  #echo "Test 25 lines checker:"
  c_suffix=".c"
  result_suffix="_result"
  ../Betty.py $samples_dir/$check$c_suffix > $output_file
  diff $samples_dir/$check$result_suffix $output_file > /dev/null
  if [ $? -ne 0 ]; then
    echo -e "\033[0;31mFail\033[0m"
    echo -e "\033[0;36mOutput should be:\033[0m"
    cat $samples_dir/$check$result_suffix
    echo -e "\033[0;36mCurrent output:\033[0m"
    cat $output_file
    exit
  else
    echo -e "\033[0;32mSuccess\033[0m"
  fi
done <$list

rm -fr $output_path
