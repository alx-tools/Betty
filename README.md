# Betty

[![Build Status](https://travis-ci.org/holbertonschool/Betty.svg?branch=master)](https://travis-ci.org/holbertonschool/Betty)

### Installation

First clone the gitub repository on your local machine.  Then, run the script `install.sh` with **sudo privileges** to install `betty-style` and `betty-code` on your computer.  If using vagrant, run `$ sudo ./install.sh`.  Now, you will have the Betty installation along with the  following manuals:

 * _betty(1)_
 * _betty-style(1)_
 * _betty-doc(1)_

To verify the installation run `$man betty`.

### Documentation

Please visit the [Betty Wiki](https://github.com/holbertonschool/Betty/wiki) for the full specifications of Betty coding and documentation styles.

You'll also find some references and some tools for common text editors such as Emacs and Atom.

### Usage

Run the following command to check if your code/doc fits the Betty Style (mostly inspired from the Linux Kernel style):

```ShellSession
./betty-style.pl file1 [file2 [file3 [...]]]
```

```ShellSession
./betty-doc.pl file1 [file2 [file3 [...]]]
```
