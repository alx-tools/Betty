#!/usr/bin/perl -w

## Copyright (c) 1998 Michael Zucchi, All Rights Reserved        ##
## Copyright (C) 2000, 1  Tim Waugh <twaugh@redhat.com>          ##
## Copyright (C) 2001  Simon Huggins                             ##
## Copyright (C) 2005-2012  Randy Dunlap                         ##
## Copyright (C) 2012  Dan Luedtke                               ##
## 								 ##
## #define enhancements by Armin Kuster <akuster@mvista.com>	 ##
## Copyright (c) 2000 MontaVista Software, Inc.			 ##
## 								 ##
## This software falls under the GNU General Public License.     ##
## Please read the COPYING file for more information             ##

# 18/01/2001 - 	Cleanups
# 		Functions prototyped as foo(void) same as foo()
# 		Stop eval'ing where we don't need to.
# -- huggie@earth.li

# 27/06/2001 -  Allowed whitespace after initial "/**" and
#               allowed comments before function declarations.
# -- Christian Kreibich <ck@whoop.org>

# Still to do:
# 	- add perldoc documentation
# 	- Look more closely at some of the scarier bits :)

# 26/05/2001 - 	Support for separate source and object trees.
#		Return error code.
# 		Keith Owens <kaos@ocs.com.au>

# 23/09/2001 - Added support for typedefs, structs, enums and unions
#              Support for Context section; can be terminated using empty line
#              Small fixes (like spaces vs. \s in regex)
# -- Tim Jansen <tim@tjansen.de>

# 25/07/2012 - Added support for HTML5
# -- Dan Luedtke <mail@danrl.de>

use strict;
use File::Basename;
use Term::ANSIColor qw(:constants);
use Getopt::Long qw(:config no_auto_abbrev);

my $P = $0;
my $exec_name = basename($P);
my $V = '2.0';

my $color = 1;
my $verbose = 0;
my $help = 0;
my $printVersion = 0;

my $errors = 0;
my $warnings = 0;

sub printVersion($) {
	my ($exitcode) = @_;

	print "Version: $V\n";
	exit($exitcode);
}

sub help($) {
	my ($exitcode) = @_;

	print <<"EOM";
Usage: $exec_name [options] file [file2...]

Read C language source or header files and extract embedded documentation
comments.

The documentation comments are identified by "/**" opening comment mark. See
Betty man page about Documentation for the documentation comment syntax.

Options:
  --color, --no-color   Usese colors when output is STDOUT (default: on)
  -v                    Verbose output, more warnings and other information.
  --version             Display the version number and exit
  -h, --help            Display this help and exit

EOM
    exit ($exitcode);
}

GetOptions(
	'color!'		=> \$color,
	'v'			=> \$verbose,
	'version'		=> \$printVersion,
	'h|help'		=> \$help
) or help(1);

help(0) if ($help);
printVersion(0) if ($printVersion);

##
# dumps section contents to arrays/hashes intended for that purpose
##
# sub dump_section {
# 	my $file = shift;
# 	my $name = shift;
# 	my $contents = join "\n", @_;
#
# 	if ($name =~ m/$type_constant/) {
# 		$name = $1;
# 		$constants{$name} = $contents;
# 	}
# 	elsif ($name =~ m/$type_param/) {
# 		$name = $1;
# 		$parameterdescs{$name} = $contents;
# 		$sectcheck = $sectcheck . $name . " ";
# 	}
# 	elsif ($name eq "@\.\.\.") {
# 		$name = "...";
# 		$parameterdescs{$name} = $contents;
# 		$sectcheck = $sectcheck . $name . " ";
# 	}
# 	else {
# 		if (defined($sections{$name}) && ($sections{$name} ne "")) {
# 			print STDERR "${file}:$.: error: duplicate section name '$name'\n";
# 			++$errors;
# 		}
# 		$sections{$name} = $contents;
# 		push @sectionlist, $name;
# 	}
# }

# Regexps
my $doc_start = qr{^/\*\*\s*$};
my $doc_end = qr{\*/};
my $doc_com = qr{^\s*\*\s*};
my $doc_special = qr{\@\%\$\&};
my $doc_sect = qr{$doc_com([$doc_special]?[\w\s]+):\s*(.*)};
# my $doc_block = qr{${doc_com}DOC:\s*(.*)?};
my $doc_decl = qr{$doc_com(\w+)};
my $doc_content = qr{$doc_com(.*)};
my $doc_split_start = qr{^\s*/\*\*\s*$};

my $declaration_purpose;

# Sections
my $contents = "";
my $section_default = "Description"; # default section
my $section_intro = "Introduction";
my $section = $section_default;
my $section_context = "Context";
my $section_return = "Return";

# States
# 0: normal code, looking for '/**' line
# 1: looking for function name
# 2: scanning field start.
# 3: scanning prototype.
# 4: documentation block
# 5: gathering documentation outside main block
my $state;
my $in_doc_sect;
my $prototype;
my $brcount;

sub reset_state {
	$state = 0;
	$prototype = "";
}

reset_state();

sub process_file($) {
	my ($file) = @_;

	my $identifier;

	if ($verbose) {
		print STDOUT "Processing file: ${file}\n";
	}

	if (!open(IN,"<$file")) {
		print STDERR "Error: Cannot open file: ${file}\n";
		++$errors;
		return;
	}

	$. = 1;
	while (<IN>) {
		while (s/\\\s*$//) {
			$_ .= <IN>;
		}

		my $line = $_;
		my $in_purpose = 0;

		# DEBUG
		# print "($.)STATE:$state\t$line\n";

		if ($state == 0) {
			if ($line =~ /$doc_start/o) {
				# next line is always the function name
				$state = 1;
				$in_doc_sect = 0;
			}
		}
		elsif ($state == 1) { # this line is the function name (always)
			# if ($line =~ /$doc_block/o) {
			# 	$state = 4;
			# 	$contents = "";
			# 	$section = $1;
			# 	if ($section eq "") {
			# 		$section = $section_intro;
			# 	}
			# }
			# elsif ($line =~ /$doc_decl/o) {
			if ($line =~ /$doc_decl/o) {
				$identifier = $1;
				if ($line =~ /\s*([\w\s]+?)\s*-/) {
					$identifier = $1;
				}

				$state = 2;
				$declaration_purpose = "";
				if ($line =~ /-\s*(.*)/) {
					# strip trailing/multiple spaces
					$declaration_purpose = $1;
					$declaration_purpose =~ s/\s*$//;
					$declaration_purpose =~ s/\s+/ /g;
					$in_purpose = 1;
				}

				if ($declaration_purpose eq "") {
					print STDERR "${file}:$.: warning: missing initial short description\n";
					++$warnings;
				}

				# if ($identifier =~ m/^struct/) {
				# 	$decl_type = 'struct';
				# }
				# elsif ($identifier =~ m/^union/) {
				# 	$decl_type = 'union';
				# }
				# elsif ($identifier =~ m/^enum/) {
				# 	$decl_type = 'enum';
				# }
				# elsif ($identifier =~ m/^typedef/) {
				# 	$decl_type = 'typedef';
				# }
				# else {
				# 	$decl_type = 'function';
				# }

				if ($verbose) {
					print STDOUT "${file}:$.: info: ",
						"Scanning doc for $identifier\n";
						# "Scanning doc for $decl_type $identifier\n";
				}
			}
			else {
				print STDERR "${file}:$.: warning: Cannot understand $line ",
					"- I thought it was a doc line\n";
				++$warnings;
				$state = 0;
			}
		}
		elsif ($state == 2) { # look for head: lines, and include content
			if ($line =~ /$doc_sect/o) {
				my $newsection = $1;
				my $newcontents = $2;

				if (($contents ne "") && ($contents ne "\n")) {
					if (!$in_doc_sect && $verbose) {
						print STDERR "${file}:$.: warning: contents before sections\n";
						++$warnings;
					}
					# dump_section($file, $section, xml_escape($contents));
				}
				$section = $newsection;

				$in_doc_sect = 1;
				$in_purpose = 0;
				$contents = $newcontents;
				if ($contents ne "") {
					$contents =~ s/^\s+//;
					$contents .= "\n";
				}
			}
			elsif ($line =~ /$doc_end/) {
				if (($contents ne "") && ($contents ne "\n")) {
					# dump_section($file, $section, xml_escape($contents));
					$section = $section_default;
					$contents = "";
				}

				if ($line =~ m/\s*\*\s*[a-zA-Z_0-9:\.]+\s*\*\//) {
					print STDERR "${file}:$.: warning: suspicious ending line\n";
					++$warnings;
				}

				$prototype = "";
				$state = 3;
				$brcount = 0;
				if ($verbose) {
					print STDOUT "end of doc comment, looking for prototype\n";
				}
			}
			elsif ($line =~ /$doc_content/) {
				if ($1 eq "") {
					$contents .= "\n";
					if ($section =~ m/^@/ || $section eq $section_context) {
						# dump_section($file, $section, xml_escape($contents));
						$section = $section_default;
						$contents = "";
					}
					$in_purpose = 0;
				}
				elsif ($in_purpose == 1) {
					# Continued declaration purpose
					chomp($declaration_purpose);
					$declaration_purpose .= " $1";
					$declaration_purpose =~ s/\s+/ /g;
				}
				else {
					$contents .= "$1\n";
				}
			}
			else {
				print STDERR "${file}:$.: warning: bad line\n";
				++$warnings;
			}
		}
		elsif ($state == 3) {	# scanning for function '{' (end of prototype)
			if ($line =~ /$doc_split_start/) {
				$state = 5;
				$split_doc_state = 1;
			}
			elsif ($decl_type eq 'function' && $_ !~ /(?:struct|enum|union)+/) {
				process_state3_function($_, $file);
			}
			else {
				process_state3_type($_, $file);
			}
		}
		# elsif ($state == 5) { # scanning for split parameters
		# 	# First line (state 1) needs to be a @parameter
		# 	if ($split_doc_state == 1 && $line =~ /$doc_split_sect/o) {
		# 		$section = $1;
		# 		$contents = $2;
		# 		if ($contents ne "") {
		# 			while ((substr($contents, 0, 1) eq " ") ||
		# 			    substr($contents, 0, 1) eq "\t") {
		# 				$contents = substr($contents, 1);
		# 			}
		# 			$contents .= "\n";
		# 		}
		# 		$split_doc_state = 2;
		# 		# Documentation block end */
		# 	}
		# 	elsif (/$doc_split_end/) {
		# 		if (($contents ne "") && ($contents ne "\n")) {
		# 			dump_section($file, $section, xml_escape($contents));
		# 			$section = $section_default;
		# 			$contents = "";
		# 		}
		# 		$state = 3;
		# 		$split_doc_state = 0;
		# 		# Regular text
		# 	}
		# 	elsif (/$doc_content/) {
		# 		if ($split_doc_state == 2) {
		# 			$contents .= $1 . "\n";
		# 		}
		# 		elsif ($split_doc_state == 1) {
		# 			$split_doc_state = 4;
		# 			print STDERR "Warning(${file}:$.): ";
		# 			print STDERR "Incorrect use of kernel-doc format: $_";
		# 			++$warnings;
		# 		}
		# 	}
		# }
	}
}

foreach (@ARGV) {
	chomp;
	process_file($_);
}
if ($verbose && $errors) {
	print STDERR "$errors errors\n";
}
if ($verbose && $warnings) {
	print STDERR "$warnings warnings\n";
}

exit(($errors > 0 || $warnings > 0));
