#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;
use Cwd;

# Retrieves path to betty script
my $betty = $ENV{'BETTY_SCRIPT'} || die "$0: Error: Couldn't find Betty script\n";
if (! -f "$betty") {
	die "$0: Error: $betty: No such file\n";
}

# Lists all C source/header files in current directory
my @files = <*.{c,h}>;
if (scalar @files == 0) {
	die "$0: Error: Couldn't find any C source/header file to test\n";
}

foreach my $file (sort @files) {
	my @errors = ();
	my $spec = "$file.stdout";

	if (! -f $spec) {
		push(@errors, "Error: $spec does not exist\n");
	} else {
		my $output = `$betty -b $file`;
		my $expected_output = `cat $spec`;
		if ($output ne $expected_output) {
			push(@errors, "Mismatch output for $file\n\n");
			push(@errors, "Output:\n");
			push(@errors, "$output\n");
			push(@errors, "Expected:\n");
			push(@errors, $expected_output);
		}
	}

	if (scalar @errors > 0) {
		my $report_file = "$file.report";

		unlink $report_file if (-f $report_file);
		open(my $rp, '>', $report_file) || die "Couldn't open file '$report_file' $!";

		foreach my $error (@errors) {
			print $rp $error;
		}

		close $rp;
	} else {
		print "All good\n";
	}
}
