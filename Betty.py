#!/usr/bin/python
#
# Betty Kernel-style C code checker
# Version: 0.1.1
#

import sys,re

version = '0.1.1'

# This class represents the checker
class Betty:
    def __init__(self):
        self.mark = 0

    # This function reset all the variables relatives to a file
    # it is called when we start to check a new file
    def new_file(self):
        self.nb_line = 1
        self.nb_funcline = 0
        self.nb_func = 0
        self.in_scope = 0
        print "Scan",self.file

    # This function count the number of functions in a file
    # and the number of lines in each function
    def check_nbline(self):
        # If the checked file is a C source file
        if self.file[-2:] == ".c":
            # If the current checked line starts with an opening brace
            # it means that we are entering a scope
            if self.line[:1] == '{':
                self.in_scope += 1
                # If the scope depth is one
                # we are in a new function scope
                if self.in_scope == 1:
                    self.nb_funcline = 0
                    self.nb_func += 1
                # Check if the function counter is greater than 5
                if self.nb_func > 5:
                    self.mark += 1
                    self.print_error('more than 5 functions in file')
            # If the current checked line starts with a closing brace
            # it means that we are going out of a scope
            elif self.line[:1] == '}':
                self.in_scope -= 1
            else:
                # If the current checked line is in the scope of a function
                # or in a nested one (still in the scope of a function)
                # We check the number of line counted inside this function
                if self.in_scope >= 1:
                    self.nb_funcline += 1
                    if self.nb_funcline > 25:
                        self.mark += 1
                        self.print_error('more than 25 lines in function')

    # This function check if a line
    # in the scope of a function
    # is more than 80 colums long
    def check_nbcol(self):
        line = self.line.replace('\t', '    ')
        if self.in_scope >= 1 and line[80:]:
            self.mark += 1
            self.print_error('more than 80 columns in a line')

    # This function will be called for each line of a file
    def check_line(self):
        self.check_nbline()
        self.check_nbcol()

    # Print an error found in a file
    # and print the line itself
    def print_error(self, msg):
        print "Error in",self.file,"in line",self.nb_line,":",msg
        print self.line

    # Open each file of 'files' one by one
    # For each file, we will proceed for check line by line
    def scan_files(self, files):
        for self.file in files:
            self.new_file()
            try:
                fd = open(self.file, 'r')
            except IOError:
                print "Can't open file",self.file
            else:
                for self.line in fd.readlines():
                    self.check_line()
                    self.nb_line += 1
                fd.close()

# This function returns a list
# that contains all the files in @argv
# that ends with extensions '.c' or '.h'
def get_files(argv):
    li = []
    pattern = re.compile('[.]c$|[.]h$')
    for arg in argv:
        test = re.search(pattern, arg)
        if test:
            li.append(arg)
    return li

# Prints informations and indications
# about the script
def help():
    print "Help"
    print "Betty version " + str(version)
    print "Usage: Betty.py <files_to_scan>"
    sys.exit()

def main():
    if '-help' in sys.argv[1:]:
        help()
    # No parameter...
    if len(sys.argv) == 1:
        print "Usage: Betty.py <files_to_scan>"
        sys.exit()
    # Create a new Betty instance
    checker = Betty()
    # Get the list of all '.c' and '.h' files
    files = get_files(sys.argv)
    try:
        checker.scan_files(files)
    except NameError:
        print "Usage: Betty.py <files_to_scan>"
    print "Mark:",-checker.mark,

if __name__ == "__main__":
    main()
