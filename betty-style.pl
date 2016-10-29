#!/usr/bin/perl -w
# (c) 2001, Dave Jones. (the file handling bit)
# (c) 2005, Joel Schopp <jschopp@austin.ibm.com> (the ugly bit)
# (c) 2007,2008, Andy Whitcroft <apw@uk.ibm.com> (new conditions, test suite)
# (c) 2008-2010 Andy Whitcroft <apw@canonical.com>
# (c) 2016, Alexandre Gautier <alexandre@holbertonschool.com>
# Licensed under the terms of the GNU GPL License version 3

use strict;
use POSIX;
use File::Basename;
use Cwd 'abs_path';
use Term::ANSIColor qw(:constants);
use Getopt::Long qw(:config no_auto_abbrev);

my $P = $0;
my $exec_name = basename($P);
my $V = '0.32';

my $show_types = 0;
my $list_types = 0;
my $help = 0;
my $printVersion = 0;
my $max_line_length = 80;
my $max_func_length = 40;
my $max_funcs = 5;
my $color = 1;

sub printVersion
{
	my ($exitcode) = @_;

	print "Version: $V\n";
	exit($exitcode);
}

sub help
{
	my ($exitcode) = @_;

	print << "EOM";
Usage: $exec_name [OPTION]... [FILE]...
Version: $V

Options:
  --list-types               List the possible message types
  --show-types               Show the specific message type in the output
  --max-line-length=n        Set the maximum line length, if exceeded, warn
  --max-func-length=n        Set the maximum function length, if exceeded, warn
  --max-funcs=n              Set the maximum functions per file, if exceeded, warn
  --no-color                 Don't use colors when output is STDOUT
  -h, --help                 Display this help and exit
  --version                  Display the version number and exit

When FILE is - read standard input.
EOM

	exit($exitcode);
}

sub uniq
{
	my %seen;
	return grep { !$seen{$_}++ } @_;
}

sub list_types
{
	my ($exitcode) = @_;
	my $count = 0;
	local $/ = undef;

	my $script;
	if (!open($script, '<', abs_path($P)))
	{
		print "$exec_name: Can't read '$exec_name' $!\n";
		exit(1);
	}

	my $text = <$script>;
	close($script);

	my @types = ();
	for ($text =~ /\b(?:(?:CHK|WARN|ERROR)\s*\(\s*"([^"]+)")/g)
	{
		push (@types, $_);
	}
	@types = sort(uniq(@types));
	print("#\tMessage type\n\n");
	foreach my $type (@types)
	{
		print(++$count . "\t" . $type . "\n");
	}

	exit($exitcode);
}

GetOptions(
	'show-types!'		=> \$show_types,
	'list-types!'		=> \$list_types,
	'max-line-length=i'	=> \$max_line_length,
	'max-func-length=i' 	=> \$max_func_length,
	'max-funcs=i'		=> \$max_funcs,
	'color!'		=> \$color,
	'h|help'		=> \$help,
	'version'		=> \$printVersion
) or help(1);

help(0) if ($help);
printVersion(0) if ($printVersion);
list_types(0) if ($list_types);

my $exit = 0;

if ($#ARGV < 0)
{
	print "$exec_name: no input files\n";
	exit(1);
}

my @rawlines = ();
my @lines = ();

for my $filename (@ARGV)
{
	my $FILE;
	if (!open($FILE, '-|', "diff -u /dev/null $filename"))
	{
		print "$exec_name: $filename: diff failed - $!\n";
		exit(1);
	}
	while (<$FILE>)
	{
		chomp;
		push(@rawlines, $_);
	}
	close($FILE);

	if (!process($filename))
	{
		$exit = 1;
	}
	@rawlines = ();
	@lines = ();
	# @fixed = ();
	# @fixed_inserted = ();
	# @fixed_deleted = ();
	# $fixlinenr = -1;
	# @modifierListFile = ();
	# @typeListFile = ();
	# build_types();
}

exit($exit);

my $sanitise_quote = '';

sub sanitise_line_reset
{
	my ($in_comment) = @_;

	$sanitise_quote = '';
	if ($in_comment)
	{
		$sanitise_quote = '*/';
	}
}

sub sanitise_line {
	my ($line) = @_;

	my $res = '';
	my $l = '';

	my $qlen = 0;
	my $off = 0;
	my $c;

	# Always copy over the diff marker.
	$res = substr($line, 0, 1);

	for ($off = 1; $off < length($line); $off++)
	{
		$c = substr($line, $off, 1);

		# Comments we are wacking completly including the begin
		# and end, all to $;.
		if ($sanitise_quote eq '' && substr($line, $off, 2) eq '/*')
		{
			$sanitise_quote = '*/';
			substr($res, $off, 2, "$;$;");
			$off++;
			next;
		}
		if ($sanitise_quote eq '*/' && substr($line, $off, 2) eq '*/')
		{
			$sanitise_quote = '';
			substr($res, $off, 2, "$;$;");
			$off++;
			next;
		}
		if ($sanitise_quote eq '' && substr($line, $off, 2) eq '//')
		{
			$sanitise_quote = '//';
			substr($res, $off, 2, $sanitise_quote);
			$off++;
			next;
		}

		# A \ in a string means ignore the next character.
		if (($sanitise_quote eq "'" || $sanitise_quote eq '"') &&
		    $c eq "\\")
		{
			substr($res, $off, 2, 'XX');
			$off++;
			next;
		}
		# Regular quotes.
		if ($c eq "'" || $c eq '"')
		{
			if ($sanitise_quote eq '')
			{
				$sanitise_quote = $c;
				substr($res, $off, 1, $c);
				next;
			}
			elsif ($sanitise_quote eq $c)
			{
				$sanitise_quote = '';
			}
		}

		#print "c<$c> SQ<$sanitise_quote>\n";
		if ($off != 0 && $sanitise_quote eq '*/' && $c ne "\t")
		{
			substr($res, $off, 1, $;);
		}
		elsif ($off != 0 && $sanitise_quote eq '//' && $c ne "\t")
		{
			substr($res, $off, 1, $;);
		}
		elsif ($off != 0 && $sanitise_quote && $c ne "\t")
		{
			substr($res, $off, 1, 'X');
		}
		else
		{
			substr($res, $off, 1, $c);
		}
	}

	if ($sanitise_quote eq '//')
	{
		$sanitise_quote = '';
	}

	# The pathname on a #include may be surrounded by '<' and '>'.
	if ($res =~ /^.\s*\#\s*include\s+\<(.*)\>/)
	{
		my $clean = 'X' x length($1);
		$res =~ s@\<.*\>@<$clean>@;

	}
	# The whole of a #error is a string.
	elsif ($res =~ /^.\s*\#\s*(?:error|warning)\s+(.*)\b/)
	{
		my $clean = 'X' x length($1);
		$res =~ s@(\#\s*(?:error|warning)\s+).*@$1$clean@;
	}

	return $res;
}

sub process
{
	my $filename = shift;

	my $linenr = 0;

	# Trace the real file/line as we go.
	# my $realfile = '';
	my $realline = 0;
	my $realcnt = 0;
	my $in_comment = 0;

	sanitise_line_reset();
	my $line;
	foreach my $rawline (@rawlines)
	{
		$linenr++;
		$line = $rawline;

		if ($rawline =~ /^\@\@ -\d+(?:,\d+)? \+(\d+)(,(\d+))? \@\@/)
		{
			$realline = $1 - 1;
			if (defined $2)
			{
				$realcnt = $3 + 1;
			}
			else
			{
				$realcnt = 1 + 1;
			}
			$in_comment = 0;

			# Guestimate if this is a continuing comment.  Run
			# the context looking for a comment "edge".  If this
			# edge is a close comment then we must be in a comment
			# at context start.
			my $edge;
			my $cnt = $realcnt;
			for (my $ln = $linenr + 1; $cnt > 0; $ln++)
			{
				next if (defined $rawlines[$ln - 1] &&
				    $rawlines[$ln - 1] =~ /^-/);
				$cnt--;
				# print "RAW<$rawlines[$ln - 1]>\n";
				last if (!defined $rawlines[$ln - 1]);
				if ($rawlines[$ln - 1] =~ m@(/\*|\*/)@ &&
				    $rawlines[$ln - 1] !~ m@"[^"]*(?:/\*|\*/)[^"]*"@)
				{
					$edge = $1;
					last;
				}
			}
			$in_comment = 1 if (defined $edge && $edge eq '*/');

			# Guestimate if this is a continuing comment.  If this
			# is the start of a diff block and this line starts
			# ' *' then it is very likely a comment.
			$in_comment = 1 if (!defined $edge &&
			    $rawlines[$linenr] =~ m@^.\s*(?:\*\*+| \*)(?:\s|$)@);

			# print "COMMENT:$in_comment edge<$edge> $rawline\n";
			sanitise_line_reset($in_comment);

		}
		elsif ($realcnt && $rawline =~ /^(?:\+| |$)/)
		{
			# Standardise the strings and chars within the input to
			# simplify matching -- only bother with positive lines.
			$line = sanitise_line($rawline);
		}
		push(@lines, $line);

		if ($realcnt > 1)
		{
			$realcnt-- if ($line =~ /^(?:\+| |$)/);
		}
		else
		{
			$realcnt = 0;
		}

		# print "==>$rawline\n";
		# print "-->$line\n";
	}
}
