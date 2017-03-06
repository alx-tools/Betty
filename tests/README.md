# Betty test suites

### Description

This folder contains all the tests for Betty.

### Organization

This folder is divided in two subfolders:

 * The `style` folder contains all the tests for the `betty-style` script
 * The `doc` folder contains all the tests for the `betty-doc` script

Both `style` and `doc` folders contain subfolders.  
Each subfolder corresponds to a specific test suite, and thus contains one or many test files.  
Since each test suite can have different requirements, each subfolder contains a script file.  
This script file will be in charge of running the specs for each test suite and output the result.  
These scripts can differ from one test suite to another, but their structure will roughly be the same.

### Tests manager

The `tests-manager.pl`script can be used to parse the Betty scripts and look for untested stuff.  
Please refer to the `tests-manager.pl` script for more details about how to manage/create test suites.
