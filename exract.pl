#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

my $file = "betty-style.pl";

my $FILE;
if (!open($FILE,"<$file")) {
	print STDERR "Error: Cannot open file $file\n";
	exit(1);
}

my $n = 0;

while(<$FILE>) {
	my $line = $_;
	chomp $line;

	$n++;

	if ($line =~ /(ERROR|WARN|CHK)\s*\(\"/ &&
	    $line !~ /^\s*#/) {
		$line =~ s/^\s+//;
		print $n . ": " . $line;
		while ($_ !~ /;\s*(?:#.*)?$/) {
			$_ = <$FILE>;
			$n++;
			chomp $_;
			$_ =~ s/^\s+//;
			print $_;
		}
		print "\n";
	}
}

close($FILE);
exit(0);
