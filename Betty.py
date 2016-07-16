#!/usr/bin/python
#
# Betty Kernel-style C code checker
# Version: 0.0.1
#

'''
Betty takes in the name of a file from command line and scans the given file for the number of functions
and number of lines per function.
If the number of functions exceeds 5, an error is printed.
An error is also printed if the number of lines in a function exceeds 25.
A mark is assigned and printed for the conformity of the file to kernel-style: 0 for True, 1 for False.
'''

import sys,re

version = '0.0.1'

class Betty:
    def __init__(self):
        self.user = []
        self.verbose = 0
        self.score = 1
        self.printline = 0
        self.mark = 0

    def new_file(self):
        self.nb_line = 1
        self.nb_funcline = 0
        self.nb_func = 0
        self.is_func = 0
        if self.verbose == 1:
            print "Scan",self.file

    def check_nbline(self):
        '''
        check_nbline checks the number of functions in the file and the number of lines in each function.
        if the number of functions exceeds 5, check_nbline prints an error.
        if the number of lines in a function exceeds 25, check_nbline prints an error.
        '''
        if self.file[-2:] == ".c":
            if self.line[:1] == '}' and self.is_func == 1:
                self.is_func = 0
                self.nb_funcline = 0
            elif self.line[:1] == '{' and self.is_func == 0:
                self.is_func = 1
                self.nb_funcline = 0
                self.nb_func += 1
                if self.nb_func > 5:
                    self.mark += 1
                    self.print_error('more than 5 functions in file')
            else:
                if self.nb_func >= 1 and self.is_func:
                    self.nb_funcline += 1
                    if self.nb_funcline > 25:
                        self.mark += 1
                        self.print_error('more than 25 lines in function')

    def print_error(self, msg):
        print "Error in",self.file,"in line",self.nb_line,":",msg
        if self.printline:
            print self.line

    def cant_open(self, file):
        if (self.verbose or file == sys.argv[1]):
            print "Can't open file",file

    def scan_files(self, files):
        for file_name in files:
            self.file = file_name
            self.new_file()
            try:
                fd = open(file_name, 'r')
            except IOError:
                self.cant_open(file)
            else:
                for self.line in fd.readlines():
                    self.check_nbline()
                    self.nb_line += 1
                    fd.close()

def get_files(argv):
    li = []
    pattern = re.compile('[.]c$|[.]h$')
    for arg in sys.argv:
        test = re.search(pattern, arg)
        if test:
            li.append(arg)
    return li

def help():
    print "Help"
    print "Betty version " + str(version)
    print "Usage: Betty.py <files_to_scan>"
    sys.exit()

def main():
    if '-help' in sys.argv[1:]:
        help()
    if len(sys.argv) == 1:
        print "Usage: Betty.py <files_to_scan>"
        sys.exit()
    checker = Betty()
    files = get_files(sys.argv)
    try:
        checker.scan_files(files)
    except NameError:
        print "Usage: Betty.py <files_to_scan>"
    if checker.score:
        print "Mark:",-checker.mark
        print ( "No limits exceeded for number of functions per file or number of lines per function." if checker.mark==0
                else "You have corrections to make.")

if __name__ == "__main__":
    main()
