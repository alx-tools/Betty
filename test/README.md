#Test

##How to create a new test ?

You can simply create a new test by creating two files in the `samples` folder:
* A source file name `<name>.c`:
  * In this source file, put some C code that does or does not respect the Kernel-style
  * This code will not be compiled, so you can put any variable name, or call any variable function.
  * Comment your file to describe exactly what you want to be tested
* A file named `<name>_result`:
  * In this file, put the output that `Betty` should print with this file as a parameter

Then, you just have to add a new line in the file `tests` containing `<name>`.
