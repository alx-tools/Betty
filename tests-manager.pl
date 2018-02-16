#!/usr/bin/perl -w

# Tests manager
# Manages the test suites fot Betty
#
# This script read the betty-style.pl scripts and finds all the the warnings
# that can be triggered
# For each warning, it will check that a corresponfing folder exists in the
# test folder and contains at least a test suite.
# If a warning happens N times in the script, then at least N tests must be
# written in the test suite.
#
# In addidition to the warnings. This script will find all the possible
# command-line options in betty-style.pl.
# A warning type (C.f. betty-style.pl `WARN` and `report` subroutines)
# has the same name as its corresponding command-line option, but some options
# may not trigger a warning. (i.e. --max-funcs=n).
# These command-line options also need to be tested.

use strict;
use warnings;
use diagnostics;
use Term::ANSIColor qw(:constants);
use Getopt::Long qw(:config no_auto_abbrev);
use File::Copy qw(copy);
use File::Spec;
use File::Basename;

my $V = "1.0.0";
my $P = dirname(File::Spec->rel2abs( __FILE__ ));

# Path to the old Betty-Style script
my $old_betty_style = "$P/betty-style.pl";
die "$old_betty_style is missing!\n" if (! -f $old_betty_style);

# Path to the folder containing the test suites for bett-style
my $base_folder = "$P/tests/style";
die "$base_folder is missing!\n" if (! -e $base_folder);

# Path to the new Betty script (the one that will be tested)
my $betty_cli = "$P/betty-cli.pl";
die "$betty_cli is missing!\n" if (! -f $betty_cli);

# Debug mode.
# Outputs more informations about the tests anylisis
my $debug = 0;
# Create mode.
# When a test folder doesn't exist, create it and fill it with templates
my $create = 0;
my $help = 0;
my $version = 0;

sub version {
	my $exitcode = shift @_ || 0;

	print "Betty tests manager\n";
	print "Version: $V\n";
	exit($exitcode);
}

sub help {
	my $exitcode = shift @_ || 0;

	print << "EOT";
Usage: $0 [OPTION]...
Options:
  -d, --debug               Outputs more informations about the tests analysis
  -c, --create              When a test folder is missing, it will be created,
                            along with additional templates

  -h, --help                Display this help and exit
  -v, --version             Display the version of the srcipt and exit
EOT

	exit($exitcode);
}

# Retrieves the command-line arguments
GetOptions(
	'd|debug'	=> \$debug,
	'c|create'	=> \$create,
	'h|help'	=> \$help,
	'v|version'	=> \$version
) or help(1);
help(0) if ($help);
version(0) if ($version);

# Options hash
# This hash will contain all the command-line options along with all the
# warning types declared in betty-style.pl
# Structure:
# $options = {
#	'type' => {
#		prefix => string,
#		suffix => string,
#		desc => string,
#		count => int,
#		lines => [int]
#	},
#	...
# };
# This hash will be filled during the parsing of betty-style.pl
# It will be used to detect if a test folder is missing, and eventually
# to genarate it.
my $options;

# read_script subroutine
#
# This subroutine will open and read entirely the betty-style script.
# It will look for:
#  - The command-line options description (C.f. betty-style `help` subroutine)
#  - Every single call to the `WARN` subroutine
sub read_script {
	my $count = 0;

	open(IN, '<', "$old_betty_style") ||
		die "Error: Cannot open file $old_betty_style\n";
	my $i = 0;
	while (<IN>)
	{
		my $line = $_;
		++$i;

		# command-line options section
		# Retrive the prefix, the suffix, and the description
		if ($line =~ /^\s*(--(?:\[no\])?)([^\s=]+)((?:=\S+)?)\s+(.*)$/ &&
		    $line !~ /;\s*$/ &&
		    $line !~ /(?:color|verbose)/) {
			$options->{$2}->{prefix} = $1;
			$options->{$2}->{suffix} = $3;
			$options->{$2}->{desc} = $4;
			$options->{$2}->{count} = 0;
		}

		# call to the `WARN` subroutine
		# Increment the counter for the warning type
		if ($line =~ /WARN\("([^"]+)",/ &&
		    $line !~ /^\s*#/) {
			$options->{$1}->{count} += 1;
			push(@{$options->{$1}->{lines}}, $i);
			++$count;
		}
	}
	close(IN);

	if ($debug) {
		foreach my $warn (sort keys $options) {
			printf "[%02d] -> %s\n", $options->{$warn}->{count}, $warn;
		}
		print "Total: $count\n";
	}
}

# write_todo subroutine
# $path: Path to the file to write in
# $type: Warning type / option name
#
# Writes a Markdown to-do template in the test folder corresponding to $type
# This file will contain a reminder of:
#  - What is to be tested
#  - How many different test are needed
#  - Where to find the different references to it type in the bett-style script
sub write_todo {
	my ($path, $type) = @_;

	open(my $fh, '>', $path) || die "Couldn't open file '$path' $!";

	# Prints the title (warning type / command-line option name)
	print $fh "# $type\n\n";

	if (!exists($options->{$type})) {
		print STDERR "Couldn't find option $type\n";
		return;
	}

	my $prefix = $options->{$type}->{prefix};
	my $suffix = $options->{$type}->{suffix};

	# Prints the corresponding command-line option
	print $fh "### Option\n\n";
	print $fh "```\n";
	print $fh $prefix, $type, $suffix, "\n";
	print $fh "```\n\n";

	# Prints the command-line description
	print $fh "### Description\n\n";
	print $fh $options->{$type}->{desc}, "\n\n";

	# Prints
	print $fh "### TODO\n\n";
	my $plural = "";
	$plural = "s" if ($options->{$type}->{count} > 1);
	print $fh $options->{$type}->{count}, " check$plural to write\n\n";

	# Prints the lines in betty-style where the type is referenced
	for (my $i = 0; $i < $options->{$type}->{count}; ++$i) {
		print $fh " - betty-style.pl: ";
		print $fh @{$options->{$type}->{lines}}[$i], "\n";
	}

	close $fh;
}

read_script();

my $total_good = 0;
my $total_warn = 0;
my $total_err = 0;
my $exit = 0;

# check the test folder corresponding to each type found in betty-style script
foreach my $type (sort keys $options) {
	my $type_folder = "$base_folder/$type";

	# The corresponding test folder does not exist
	if (! -e $type_folder) {
		print RED, $type, RESET, ": No test suite found\n";
		$total_err++;
		mkdir $type_folder if ($create);
		next if (!$create);
	}

	# Lists all the C source and header files in the test folder
	my @test_files = <$type_folder/*.{c,h}>;
	if (scalar @test_files == 0) {
		print RED, $type, RESET, ": No test in folder\n";
		my $filename = "TODO.md";
		write_todo("$type_folder/$filename", $type);
		$total_err++;
		next;
	} elsif (scalar @test_files < $options->{$type}->{count}) {
		print YELLOW, $type, RESET, ": You should have at least ", $options->{$type}->{count},
			" tests, you currently have ", scalar @test_files, "\n";
		my $filename = "TODO.md";
		write_todo("$type_folder/$filename", $type);
		$total_warn++;
	} else {
		print GREEN, $type, RESET, ": Found\n";
		$total_good++;
	}
	if (run_tests($base_folder, @test_files)) {
		print GREEN, "\tPassed ", scalar @test_files * 3, " tests!\n", RESET;
	} else {
		$exit = 1;
	}
}

print "\n";
print GREEN, $total_good, RESET, ", ";
print YELLOW, $total_warn, RESET, ", ";
print RED, $total_err, RESET, "\n";

exit ($exit);

##
## run_tests()
##
## Params:
##   $cmd: Betty command (style or doc)
##   @files: List of files to be tested (C source files)
##
## Returns: 1 when clean, 0 on failure
##
sub run_tests {

	my ($cmd, @files) = @_;
	my $clean = 1;

	my @c = split("/", $cmd);
	$cmd = pop @c;
	my $path = join("/", @c);

	foreach my $file (sort @files) {
		$file =~ s/^.*\/style\//style\//;
		$file =~ s/^.*\/doc\//doc\//;
		my @errors = ();

		my $expected = "$path/$file.normal";
		if (! -f $expected) {
			push(@errors, "Error: $expected does not exist\n");
		} else {
			my $output = `cd $P/tests ; $betty_cli $cmd $file`;
			my $expected_output = `cat $expected`;
			if ($output ne $expected_output) {
				push(@errors, "Mismatch output for $file\n\n");
				push(@errors, "Output:\n");
				push(@errors, "$output\n");
				push(@errors, "Expected:\n");
				push(@errors, $expected_output);
			}
		}

		$expected = "$path/$file.brief";
		if (! -f $expected) {
			push(@errors, "Error: $expected does not exist\n");
		} else {
			my $output = `cd $P/tests ; $betty_cli $cmd -b $file`;
			my $expected_output = `cat $expected`;
			if ($output ne $expected_output) {
				push(@errors, "Mismatch output for $file\n\n");
				push(@errors, "Output:\n");
				push(@errors, "$output\n");
				push(@errors, "Expected:\n");
				push(@errors, $expected_output);
			}
		}

		$expected = "$path/$file.context";
		if (! -f $expected) {
			push(@errors, "Error: $expected does not exist\n");
		} else {
			my $output = `cd $P/tests ; $betty_cli $cmd -c $file`;
			my $expected_output = `cat $expected`;
			if ($output ne $expected_output) {
				push(@errors, "Mismatch output for $file\n\n");
				push(@errors, "Output:\n");
				push(@errors, "$output\n");
				push(@errors, "Expected:\n");
				push(@errors, $expected_output);
			}
		}

		my $report_file = "$path/$file.report";
		unlink $report_file if (-f $report_file);
		if (scalar @errors > 0) {
			open(my $rp, '>', $report_file) || die "Couldn't open file '$report_file' $!";

			print $rp join('', @errors);
			print STDERR "\t", join("\t", @errors);

			close $rp;
			$clean = 0;
		}
	}

	return $clean
}
