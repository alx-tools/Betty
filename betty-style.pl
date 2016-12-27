#!/usr/bin/perl -w
# (c) 2001, Dave Jones. (the file handling bit)
# (c) 2005, Joel Schopp <jschopp@austin.ibm.com> (the ugly bit)
# (c) 2007,2008, Andy Whitcroft <apw@uk.ibm.com> (new conditions, test suite)
# (c) 2008-2010 Andy Whitcroft <apw@canonical.com>
# Licensed under the terms of the GNU GPL License version 2

use strict;
use warnings;
use diagnostics;

use File::Basename;
use Cwd 'abs_path';
use Term::ANSIColor qw(:constants);
use Getopt::Long qw(:config no_auto_abbrev);

my $P = $0;
my $D = dirname(abs_path($P));
my $V = '2.0';
my $minimum_perl_version = 5.10.0;

my $verbose = 0;
my $help = 0;
my $printVersion = 0;
my $color = 1;

my $max_line_length = 80;
my $max_func_length = 40;
my $max_funcs = 5;
my $safe_guard = 1;

sub printVersion {
	my $exitcode = shift @_ || 0;

	print "Version: $V\n";
	exit($exitcode);
}

sub help {
	my $exitcode = shift @_ || 0;

	print << "EOM";
Usage: $P [OPTION]... [FILE]...
Version: $V

Options:
  -q, --quiet                Quiet mode
  --no-color                 Use colors when output is STDOUT (default: on)

  --max-line-length=n        Set the maximum length of a line (default: 80)
  --max-func-length=n        Set the maximum length of a function (default: 40)
  --max-funcs=n              Set the maximum declared functions per source file
                             (default: 5)
                             Set it to -1 for infinite
  --no-safe-guard            Don't check for header files protection

  -h, --help                 Display this help and exit
  -v, --version              Display the version of the srcipt
EOM

	exit($exitcode);
}

sub uniq {
	my %seen;
	return grep { !$seen{$_}++ } @_;
}

GetOptions(
	'verbose'	=> \$verbose,
	'color!'	=> \$color,
	'h|help'	=> \$help,
	'v|version'	=> \$printVersion,
	'max-line-length=i' => \$max_line_length,
	'max-func-length=i' => \$max_func_length,
	'max-funcs=i'	=> \$max_funcs,
	'safe-guard!'	=> \$safe_guard
) or help(1);

help(0) if ($help);
printVersion(0) if ($printVersion);

my $exit = 0;

if ($^V && $^V lt $minimum_perl_version) {
	printf "$P: requires at least perl version %vd\n", $minimum_perl_version;
	exit(1);
}

if ($#ARGV < 0) {
	my $exec_name = basename($P);
	print "$exec_name: no input files\n";
	exit(1);
}

my $rpt_cleaners = 0;

my $emitted_corrupt = 0;

our $Ident	= qr{
			[A-Za-z_][A-Za-z\d_]*
			(?:\s*\#\#\s*[A-Za-z_][A-Za-z\d_]*)*
		}x;
our $Storage	= qr{extern|static|asmlinkage};
our $Sparse	= qr{
			__user|
			__kernel|
			__force|
			__iomem|
			__pmem|
			__must_check|
			__init_refok|
			__kprobes|
			__ref|
			__rcu|
			__private
		}x;
our $InitAttributePrefix = qr{__(?:mem|cpu|dev|net_|)};
our $InitAttributeData = qr{$InitAttributePrefix(?:initdata\b)};
our $InitAttributeConst = qr{$InitAttributePrefix(?:initconst\b)};
our $InitAttributeInit = qr{$InitAttributePrefix(?:init\b)};
our $InitAttribute = qr{$InitAttributeData|$InitAttributeConst|$InitAttributeInit};

# Notes to $Attribute:
# We need \b after 'init' otherwise 'initconst' will cause a false positive in a check
our $Attribute	= qr{
			const|
			__percpu|
			__nocast|
			__safe|
			__bitwise__|
			__packed__|
			__packed2__|
			__naked|
			__maybe_unused|
			__always_unused|
			__noreturn|
			__used|
			__cold|
			__pure|
			__noclone|
			__deprecated|
			__read_mostly|
			__kprobes|
			$InitAttribute|
			____cacheline_aligned|
			____cacheline_aligned_in_smp|
			____cacheline_internodealigned_in_smp|
			__weak
		  }x;
our $Modifier;
our $Inline	= qr{inline|__always_inline|noinline|__inline|__inline__};
our $Member	= qr{->$Ident|\.$Ident|\[[^]]*\]};
our $Lval	= qr{$Ident(?:$Member)*};

our $Int_type	= qr{(?i)llu|ull|ll|lu|ul|l|u};
our $Binary	= qr{(?i)0b[01]+$Int_type?};
our $Hex	= qr{(?i)0x[0-9a-f]+$Int_type?};
our $Int	= qr{[0-9]+$Int_type?};
our $Octal	= qr{0[0-7]+$Int_type?};
our $String	= qr{"[X\t]*"};
our $Float_hex	= qr{(?i)0x[0-9a-f]+p-?[0-9]+[fl]?};
our $Float_dec	= qr{(?i)(?:[0-9]+\.[0-9]*|[0-9]*\.[0-9]+)(?:e-?[0-9]+)?[fl]?};
our $Float_int	= qr{(?i)[0-9]+e-?[0-9]+[fl]?};
our $Float	= qr{$Float_hex|$Float_dec|$Float_int};
our $Constant	= qr{$Float|$Binary|$Octal|$Hex|$Int};
our $Assignment	= qr{\*\=|/=|%=|\+=|-=|<<=|>>=|&=|\^=|\|=|=};
our $Compare    = qr{<=|>=|==|!=|<|(?<!-)>};
our $Arithmetic = qr{\+|-|\*|\/|%};
our $Operators	= qr{
			<=|>=|==|!=|
			=>|->|<<|>>|<|>|!|~|
			&&|\|\||,|\^|\+\+|--|&|\||$Arithmetic
		  }x;

our $c90_Keywords = qr{do|for|while|if|else|return|goto|continue|switch|default|case|break}x;

our $BasicType;
our $NonptrType;
our $NonptrTypeMisordered;
our $NonptrTypeWithAttr;
our $Type;
our $TypeMisordered;
our $Declare;
our $DeclareMisordered;

our $NON_ASCII_UTF8	= qr{
	[\xC2-\xDF][\x80-\xBF]               # non-overlong 2-byte
	|  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
	| [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
	|  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
	|  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
	| [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
	|  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
}x;

our $UTF8	= qr{
	[\x09\x0A\x0D\x20-\x7E]              # ASCII
	| $NON_ASCII_UTF8
}x;

our $typeC99Typedefs = qr{(?:__)?(?:[us]_?)?int_?(?:8|16|32|64)_t};
our $typeOtherOSTypedefs = qr{(?x:
	u_(?:char|short|int|long) |          # bsd
	u(?:nchar|short|int|long)            # sysv
)};
our $typeKernelTypedefs = qr{(?x:
	(?:__)?(?:u|s|be|le)(?:8|16|32|64)|
	atomic_t
)};
our $typeTypedefs = qr{(?x:
	$typeC99Typedefs\b|
	$typeOtherOSTypedefs\b|
	$typeKernelTypedefs\b
)};

our $zero_initializer = qr{(?:(?:0[xX])?0+$Int_type?|NULL|false)\b};

our $logFunctions = qr{(?x:
	printk(?:_ratelimited|_once|)|
	(?:[a-z0-9]+_){1,2}(?:printk|emerg|alert|crit|err|warning|warn|notice|info|debug|dbg|vdbg|devel|cont|WARN)(?:_ratelimited|_once|)|
	WARN(?:_RATELIMIT|_ONCE|)|
	panic|
	MODULE_[A-Z_]+|
	seq_vprintf|seq_printf|seq_puts
)};

our $signature_tags = qr{(?xi:
	Signed-off-by:|
	Acked-by:|
	Tested-by:|
	Reviewed-by:|
	Reported-by:|
	Suggested-by:|
	To:|
	Cc:
)};

our @typeListMisordered = (
	qr{char\s+(?:un)?signed},
	qr{int\s+(?:(?:un)?signed\s+)?short\s},
	qr{int\s+short(?:\s+(?:un)?signed)},
	qr{short\s+int(?:\s+(?:un)?signed)},
	qr{(?:un)?signed\s+int\s+short},
	qr{short\s+(?:un)?signed},
	qr{long\s+int\s+(?:un)?signed},
	qr{int\s+long\s+(?:un)?signed},
	qr{long\s+(?:un)?signed\s+int},
	qr{int\s+(?:un)?signed\s+long},
	qr{int\s+(?:un)?signed},
	qr{int\s+long\s+long\s+(?:un)?signed},
	qr{long\s+long\s+int\s+(?:un)?signed},
	qr{long\s+long\s+(?:un)?signed\s+int},
	qr{long\s+long\s+(?:un)?signed},
	qr{long\s+(?:un)?signed},
);

our @typeList = (
	qr{void},
	qr{(?:(?:un)?signed\s+)?char},
	qr{(?:(?:un)?signed\s+)?short\s+int},
	qr{(?:(?:un)?signed\s+)?short},
	qr{(?:(?:un)?signed\s+)?int},
	qr{(?:(?:un)?signed\s+)?long\s+int},
	qr{(?:(?:un)?signed\s+)?long\s+long\s+int},
	qr{(?:(?:un)?signed\s+)?long\s+long},
	qr{(?:(?:un)?signed\s+)?long},
	qr{(?:un)?signed},
	qr{float},
	qr{double},
	qr{bool},
	qr{struct\s+$Ident},
	qr{union\s+$Ident},
	qr{enum\s+$Ident},
	qr{${Ident}_t},
	qr{${Ident}_handler},
	qr{${Ident}_handler_fn},
	@typeListMisordered,
);

our $C90_int_types = qr{(?x:
	long\s+long\s+int\s+(?:un)?signed|
	long\s+long\s+(?:un)?signed\s+int|
	long\s+long\s+(?:un)?signed|
	(?:(?:un)?signed\s+)?long\s+long\s+int|
	(?:(?:un)?signed\s+)?long\s+long|
	int\s+long\s+long\s+(?:un)?signed|
	int\s+(?:(?:un)?signed\s+)?long\s+long|

	long\s+int\s+(?:un)?signed|
	long\s+(?:un)?signed\s+int|
	long\s+(?:un)?signed|
	(?:(?:un)?signed\s+)?long\s+int|
	(?:(?:un)?signed\s+)?long|
	int\s+long\s+(?:un)?signed|
	int\s+(?:(?:un)?signed\s+)?long|

	int\s+(?:un)?signed|
	(?:(?:un)?signed\s+)?int
)};

our @typeListFile = ();
our @typeListWithAttr = (
	@typeList,
	qr{struct\s+$InitAttribute\s+$Ident},
	qr{union\s+$InitAttribute\s+$Ident},
);

our @modifierList = (
	qr{fastcall},
);
our @modifierListFile = ();

our $mode_perms_world_writable = qr{
	S_IWUGO		|
	S_IWOTH		|
	S_IRWXUGO	|
	S_IALLUGO	|
	0[0-7][0-7][2367]
}x;

our $allowed_asm_includes = qr{(?x:
	irq|
	memory|
	time|
	reboot
)};
# memory.h: ARM has a custom one

sub build_types {
	my $mods = "(?x:  \n" . join("|\n  ", (@modifierList, @modifierListFile)) . "\n)";
	my $all = "(?x:  \n" . join("|\n  ", (@typeList, @typeListFile)) . "\n)";
	my $Misordered = "(?x:  \n" . join("|\n  ", @typeListMisordered) . "\n)";
	my $allWithAttr = "(?x:  \n" . join("|\n  ", @typeListWithAttr) . "\n)";
	$Modifier	= qr{(?:$Attribute|$Sparse|$mods)};
	$BasicType	= qr{
				(?:$typeTypedefs\b)|
				(?:${all}\b)
		}x;
	$NonptrType	= qr{
			(?:$Modifier\s+|const\s+)*
			(?:
				(?:typeof|__typeof__)\s*\([^\)]*\)|
				(?:$typeTypedefs\b)|
				(?:${all}\b)
			)
			(?:\s+$Modifier|\s+const)*
		  }x;
	$NonptrTypeMisordered	= qr{
			(?:$Modifier\s+|const\s+)*
			(?:
				(?:${Misordered}\b)
			)
			(?:\s+$Modifier|\s+const)*
		  }x;
	$NonptrTypeWithAttr	= qr{
			(?:$Modifier\s+|const\s+)*
			(?:
				(?:typeof|__typeof__)\s*\([^\)]*\)|
				(?:$typeTypedefs\b)|
				(?:${allWithAttr}\b)
			)
			(?:\s+$Modifier|\s+const)*
		  }x;
	$Type	= qr{
			$NonptrType
			(?:(?:\s|\*|\[\])+\s*const|(?:\s|\*\s*(?:const\s*)?|\[\])+|(?:\s*\[\s*\])+)?
			(?:\s+$Inline|\s+$Modifier)*
		  }x;
	$TypeMisordered	= qr{
			$NonptrTypeMisordered
			(?:(?:\s|\*|\[\])+\s*const|(?:\s|\*\s*(?:const\s*)?|\[\])+|(?:\s*\[\s*\])+)?
			(?:\s+$Inline|\s+$Modifier)*
		  }x;
	$Declare	= qr{(?:$Storage\s+(?:$Inline\s+)?)?$Type};
	$DeclareMisordered	= qr{(?:$Storage\s+(?:$Inline\s+)?)?$TypeMisordered};
}
build_types();

our $Typecast	= qr{\s*(\(\s*$NonptrType\s*\)){0,1}\s*};

# Using $balanced_parens, $LvalOrFunc, or $FuncArg
# requires at least perl version v5.10.0
# Any use must be runtime checked with $^V

our $balanced_parens = qr/(\((?:[^\(\)]++|(?-1))*\))/;
our $LvalOrFunc	= qr{((?:[\&\*]\s*)?$Lval)\s*($balanced_parens{0,1})\s*};
our $FuncArg = qr{$Typecast{0,1}($LvalOrFunc|$Constant|$String)};

our $declaration_macros = qr{(?x:
	(?:$Storage\s+)?(?:[A-Z_][A-Z0-9]*_){0,2}(?:DEFINE|DECLARE)(?:_[A-Z0-9]+){1,6}\s*\(|
	(?:$Storage\s+)?LIST_HEAD\s*\(|
	(?:$Storage\s+)?${Type}\s+uninitialized_var\s*\(
)};

sub deparenthesize {
	my ($string) = @_;
	return "" if (!defined($string));

	while ($string =~ /^\s*\(.*\)\s*$/) {
		$string =~ s@^\s*\(\s*@@;
		$string =~ s@\s*\)\s*$@@;
	}

	$string =~ s@\s+@ @g;
	return $string;
}

my @rawlines = ();
my @lines = ();

for my $filename (@ARGV) {
	my $FILE;
	open($FILE, '-|', "diff -u /dev/null $filename") ||
		die "$P: $filename: diff failed - $!\n";
	while (<$FILE>) {
		chomp;
		push(@rawlines, $_);
	}
	close($FILE);

	if (!process($filename)) {
		$exit = 1;
	}
	@rawlines = ();
	@lines = ();
	@modifierListFile = ();
	@typeListFile = ();
	build_types();
}

exit($exit);

sub expand_tabs {
	my ($str) = @_;

	my $res = '';
	my $n = 0;
	for my $c (split(//, $str)) {
		if ($c eq "\t") {
			$res .= ' ';
			$n++;
			for (; ($n % 8) != 0; $n++) {
				$res .= ' ';
			}
			next;
		}
		$res .= $c;
		$n++;
	}

	return $res;
}
sub copy_spacing {
	(my $res = shift) =~ tr/\t/ /c;
	return $res;
}

sub line_stats {
	my ($line) = @_;

	# Drop the diff line leader and expand tabs
	$line =~ s/^.//;
	$line = expand_tabs($line);

	# Pick the indent from the front of the line.
	my ($white) = ($line =~ /^(\s*)/);

	return (length($line), length($white));
}

sub real_length {
	my ($line) = @_;

	return (length($line));
}

my $sanitise_quote = '';

sub sanitise_line_reset {
	my ($in_comment) = @_;

	if ($in_comment) {
		$sanitise_quote = '*/';
	} else {
		$sanitise_quote = '';
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

	for ($off = 1; $off < length($line); $off++) {
		$c = substr($line, $off, 1);

		# Comments we are wacking completly including the begin
		# and end, all to $;.
		if ($sanitise_quote eq '' && substr($line, $off, 2) eq '/*') {
			$sanitise_quote = '*/';

			substr($res, $off, 2, "$;$;");
			$off++;
			next;
		}
		if ($sanitise_quote eq '*/' && substr($line, $off, 2) eq '*/') {
			$sanitise_quote = '';
			substr($res, $off, 2, "$;$;");
			$off++;
			next;
		}
		if ($sanitise_quote eq '' && substr($line, $off, 2) eq '//') {
			$sanitise_quote = '//';

			substr($res, $off, 2, $sanitise_quote);
			$off++;
			next;
		}

		# A \ in a string means ignore the next character.
		if (($sanitise_quote eq "'" || $sanitise_quote eq '"') &&
		    $c eq "\\") {
			substr($res, $off, 2, 'XX');
			$off++;
			next;
		}
		# Regular quotes.
		if ($c eq "'" || $c eq '"') {
			if ($sanitise_quote eq '') {
				$sanitise_quote = $c;

				substr($res, $off, 1, $c);
				next;
			} elsif ($sanitise_quote eq $c) {
				$sanitise_quote = '';
			}
		}

		#print "c<$c> SQ<$sanitise_quote>\n";
		if ($off != 0 && $sanitise_quote eq '*/' && $c ne "\t") {
			substr($res, $off, 1, $;);
		} elsif ($off != 0 && $sanitise_quote eq '//' && $c ne "\t") {
			substr($res, $off, 1, $;);
		} elsif ($off != 0 && $sanitise_quote && $c ne "\t") {
			substr($res, $off, 1, 'X');
		} else {
			substr($res, $off, 1, $c);
		}
	}

	if ($sanitise_quote eq '//') {
		$sanitise_quote = '';
	}

	# The pathname on a #include may be surrounded by '<' and '>'.
	if ($res =~ /^.\s*\#\s*include\s+\<(.*)\>/) {
		my $clean = 'X' x length($1);
		$res =~ s@\<.*\>@<$clean>@;

	# The whole of a #error is a string.
	} elsif ($res =~ /^.\s*\#\s*(?:error|warning)\s+(.*)\b/) {
		my $clean = 'X' x length($1);
		$res =~ s@(\#\s*(?:error|warning)\s+).*@$1$clean@;
	}

	return $res;
}

sub ctx_statement_block {
	my ($linenr, $remain, $off) = @_;
	my $line = $linenr - 1;
	my $blk = '';
	my $soff = $off;
	my $coff = $off - 1;
	my $coff_set = 0;

	my $loff = 0;

	my $type = '';
	my $level = 0;
	my @stack = ();
	my $p;
	my $c;
	my $len = 0;

	my $remainder;
	while (1) {
		@stack = (['', 0]) if ($#stack == -1);

		#warn "CSB: blk<$blk> remain<$remain>\n";
		# If we are about to drop off the end, pull in more
		# context.
		if ($off >= $len) {
			for (; $remain > 0; $line++) {
				last if (!defined $lines[$line]);
				next if ($lines[$line] =~ /^-/);
				$remain--;
				$loff = $len;
				$blk .= $lines[$line] . "\n";
				$len = length($blk);
				$line++;
				last;
			}
			# Bail if there is no further context.
			#warn "CSB: blk<$blk> off<$off> len<$len>\n";
			if ($off >= $len) {
				last;
			}
			if ($level == 0 && substr($blk, $off) =~ /^.\s*#\s*define/) {
				$level++;
				$type = '#';
			}
		}
		$p = $c;
		$c = substr($blk, $off, 1);
		$remainder = substr($blk, $off);

		#warn "CSB: c<$c> type<$type> level<$level> remainder<$remainder> coff_set<$coff_set>\n";

		# Handle nested #if/#else.
		if ($remainder =~ /^#\s*(?:ifndef|ifdef|if)\s/) {
			push(@stack, [ $type, $level ]);
		} elsif ($remainder =~ /^#\s*(?:else|elif)\b/) {
			($type, $level) = @{$stack[$#stack - 1]};
		} elsif ($remainder =~ /^#\s*endif\b/) {
			($type, $level) = @{pop(@stack)};
		}

		# Statement ends at the ';' or a close '}' at the
		# outermost level.
		if ($level == 0 && $c eq ';') {
			last;
		}

		# An else is really a conditional as long as its not else if
		if ($level == 0 && $coff_set == 0 &&
				(!defined($p) || $p =~ /(?:\s|\}|\+)/) &&
				$remainder =~ /^(else)(?:\s|{)/ &&
				$remainder !~ /^else\s+if\b/) {
			$coff = $off + length($1) - 1;
			$coff_set = 1;
			#warn "CSB: mark coff<$coff> soff<$soff> 1<$1>\n";
			#warn "[" . substr($blk, $soff, $coff - $soff + 1) . "]\n";
		}

		if (($type eq '' || $type eq '(') && $c eq '(') {
			$level++;
			$type = '(';
		}
		if ($type eq '(' && $c eq ')') {
			$level--;
			$type = ($level != 0)? '(' : '';

			if ($level == 0 && $coff < $soff) {
				$coff = $off;
				$coff_set = 1;
				#warn "CSB: mark coff<$coff>\n";
			}
		}
		if (($type eq '' || $type eq '{') && $c eq '{') {
			$level++;
			$type = '{';
		}
		if ($type eq '{' && $c eq '}') {
			$level--;
			$type = ($level != 0)? '{' : '';

			if ($level == 0) {
				if (substr($blk, $off + 1, 1) eq ';') {
					$off++;
				}
				last;
			}
		}
		# Preprocessor commands end at the newline unless escaped.
		if ($type eq '#' && $c eq "\n" && $p ne "\\") {
			$level--;
			$type = '';
			$off++;
			last;
		}
		$off++;
	}
	# We are truly at the end, so shuffle to the next line.
	if ($off == $len) {
		$loff = $len + 1;
		$line++;
		$remain--;
	}

	my $statement = substr($blk, $soff, $off - $soff + 1);
	my $condition = substr($blk, $soff, $coff - $soff + 1);

	#warn "STATEMENT<$statement>\n";
	#warn "CONDITION<$condition>\n";

	#print "coff<$coff> soff<$off> loff<$loff>\n";

	return ($statement, $condition,
			$line, $remain + 1, $off - $loff + 1, $level);
}

sub statement_lines {
	my ($stmt) = @_;

	# Strip the diff line prefixes and rip blank lines at start and end.
	$stmt =~ s/(^|\n)./$1/g;
	$stmt =~ s/^\s*//;
	$stmt =~ s/\s*$//;

	my @stmt_lines = ($stmt =~ /\n/g);

	return $#stmt_lines + 2;
}

sub statement_rawlines {
	my ($stmt) = @_;

	my @stmt_lines = ($stmt =~ /\n/g);

	return $#stmt_lines + 2;
}

sub statement_block_size {
	my ($stmt) = @_;

	$stmt =~ s/(^|\n)./$1/g;
	$stmt =~ s/^\s*{//;
	$stmt =~ s/}\s*$//;
	$stmt =~ s/^\s*//;
	$stmt =~ s/\s*$//;

	my @stmt_lines = ($stmt =~ /\n/g);
	my @stmt_statements = ($stmt =~ /;/g);

	my $stmt_lines = $#stmt_lines + 2;
	my $stmt_statements = $#stmt_statements + 1;

	if ($stmt_lines > $stmt_statements) {
		return $stmt_lines;
	} else {
		return $stmt_statements;
	}
}

sub ctx_statement_full {
	my ($linenr, $remain, $off) = @_;
	my ($statement, $condition, $level);

	my (@chunks);

	# Grab the first conditional/block pair.
	($statement, $condition, $linenr, $remain, $off, $level) =
				ctx_statement_block($linenr, $remain, $off);
	#print "F: c<$condition> s<$statement> remain<$remain>\n";
	push(@chunks, [ $condition, $statement ]);
	if (!($remain > 0 && $condition =~ /^\s*(?:\n[+-])?\s*(?:if|else|do)\b/s)) {
		return ($level, $linenr, @chunks);
	}

	# Pull in the following conditional/block pairs and see if they
	# could continue the statement.
	for (;;) {
		($statement, $condition, $linenr, $remain, $off, $level) =
				ctx_statement_block($linenr, $remain, $off);
		#print "C: c<$condition> s<$statement> remain<$remain>\n";
		last if (!($remain > 0 && $condition =~ /^(?:\s*\n[+-])*\s*(?:else|do)\b/s));
		#print "C: push\n";
		push(@chunks, [ $condition, $statement ]);
	}

	return ($level, $linenr, @chunks);
}

sub ctx_block_get {
	my ($linenr, $remain, $outer, $open, $close, $off) = @_;
	my $line;
	my $start = $linenr - 1;
	my $blk = '';
	my @o;
	my @c;
	my @res = ();

	my $level = 0;
	my @stack = ($level);
	for ($line = $start; $remain > 0; $line++) {
		next if ($rawlines[$line] =~ /^-/);
		$remain--;

		$blk .= $rawlines[$line];

		# Handle nested #if/#else.
		if ($lines[$line] =~ /^.\s*#\s*(?:ifndef|ifdef|if)\s/) {
			push(@stack, $level);
		} elsif ($lines[$line] =~ /^.\s*#\s*(?:else|elif)\b/) {
			$level = $stack[$#stack - 1];
		} elsif ($lines[$line] =~ /^.\s*#\s*endif\b/) {
			$level = pop(@stack);
		}

		foreach my $c (split(//, $lines[$line])) {
			##print "C<$c>L<$level><$open$close>O<$off>\n";
			if ($off > 0) {
				$off--;
				next;
			}

			if ($c eq $close && $level > 0) {
				$level--;
				last if ($level == 0);
			} elsif ($c eq $open) {
				$level++;
			}
		}

		if (!$outer || $level <= 1) {
			push(@res, $rawlines[$line]);
		}

		last if ($level == 0);
	}

	return ($level, @res);
}
sub ctx_block_outer {
	my ($linenr, $remain) = @_;

	my ($level, @r) = ctx_block_get($linenr, $remain, 1, '{', '}', 0);
	return @r;
}
sub ctx_block {
	my ($linenr, $remain) = @_;

	my ($level, @r) = ctx_block_get($linenr, $remain, 0, '{', '}', 0);
	return @r;
}
sub ctx_statement {
	my ($linenr, $remain, $off) = @_;

	my ($level, @r) = ctx_block_get($linenr, $remain, 0, '(', ')', $off);
	return @r;
}
sub ctx_block_level {
	my ($linenr, $remain) = @_;

	return ctx_block_get($linenr, $remain, 0, '{', '}', 0);
}
sub ctx_statement_level {
	my ($linenr, $remain, $off) = @_;

	return ctx_block_get($linenr, $remain, 0, '(', ')', $off);
}

sub ctx_locate_comment {
	my ($first_line, $end_line) = @_;

	# Catch a comment on the end of the line itself.
	my ($current_comment) = ($rawlines[$end_line - 1] =~ m@.*(/\*.*\*/)\s*(?:\\\s*)?$@);
	return $current_comment if (defined $current_comment);

	# Look through the context and try and figure out if there is a
	# comment.
	my $in_comment = 0;
	$current_comment = '';
	for (my $linenr = $first_line; $linenr < $end_line; $linenr++) {
		my $line = $rawlines[$linenr - 1];
		#warn "           $line\n";
		if ($linenr == $first_line and $line =~ m@^.\s*\*@) {
			$in_comment = 1;
		}
		if ($line =~ m@/\*@) {
			$in_comment = 1;
		}
		if (!$in_comment && $current_comment ne '') {
			$current_comment = '';
		}
		$current_comment .= $line . "\n" if ($in_comment);
		if ($line =~ m@\*/@) {
			$in_comment = 0;
		}
	}

	chomp($current_comment);
	return($current_comment);
}
sub ctx_has_comment {
	my ($first_line, $end_line) = @_;
	my $cmt = ctx_locate_comment($first_line, $end_line);

	##print "LINE: $rawlines[$end_line - 1 ]\n";
	##print "CMMT: $cmt\n";

	return ($cmt ne '');
}

sub raw_line {
	my ($linenr, $cnt) = @_;

	my $offset = $linenr - 1;
	$cnt++;

	my $line;
	while ($cnt) {
		$line = $rawlines[$offset++];
		next if (defined($line) && $line =~ /^-/);
		$cnt--;
	}

	return $line;
}

sub cat_vet {
	my ($vet) = @_;
	my ($res, $coded);

	$res = '';
	while ($vet =~ /([^[:cntrl:]]*)([[:cntrl:]]|$)/g) {
		$res .= $1;
		if ($2 ne '') {
			$coded = sprintf("^%c", unpack('C', $2) + 64);
			$res .= $coded;
		}
	}
	$res =~ s/$/\$/;

	return $res;
}

my $av_preprocessor = 0;
my $av_pending;
my @av_paren_type;
my $av_pend_colon;

sub annotate_reset {
	$av_preprocessor = 0;
	$av_pending = '_';
	@av_paren_type = ('E');
	$av_pend_colon = 'O';
}

sub annotate_values {
	my ($stream, $type) = @_;

	my $res;
	my $var = '_' x length($stream);
	my $cur = $stream;

	while (length($cur)) {
		@av_paren_type = ('E') if ($#av_paren_type < 0);

		if ($cur =~ /^(\s+)/o) {
			if ($1 =~ /\n/ && $av_preprocessor) {
				$type = pop(@av_paren_type);
				$av_preprocessor = 0;
			}

		} elsif ($cur =~ /^(\(\s*$Type\s*)\)/ && $av_pending eq '_') {
			push(@av_paren_type, $type);
			$type = 'c';

		} elsif ($cur =~ /^($Type)\s*(?:$Ident|,|\)|\(|\s*$)/) {
			$type = 'T';

		} elsif ($cur =~ /^($Modifier)\s*/) {
			$type = 'T';

		} elsif ($cur =~ /^(\#\s*define\s*$Ident)(\(?)/o) {
			$av_preprocessor = 1;
			push(@av_paren_type, $type);
			if ($2 ne '') {
				$av_pending = 'N';
			}
			$type = 'E';

		} elsif ($cur =~ /^(\#\s*(?:undef\s*$Ident|include\b))/o) {
			$av_preprocessor = 1;
			push(@av_paren_type, $type);

		} elsif ($cur =~ /^(\#\s*(?:ifdef|ifndef|if))/o) {
			$av_preprocessor = 1;

			push(@av_paren_type, $type);
			push(@av_paren_type, $type);
			$type = 'E';

		} elsif ($cur =~ /^(\#\s*(?:else|elif))/o) {
			$av_preprocessor = 1;

			push(@av_paren_type, $av_paren_type[$#av_paren_type]);

			$type = 'E';

		} elsif ($cur =~ /^(\#\s*(?:endif))/o) {
			$av_preprocessor = 1;

			# Assume all arms of the conditional end as this
			# one does, and continue as if the #endif was not here.
			pop(@av_paren_type);
			push(@av_paren_type, $type);
			$type = 'E';

		} elsif ($cur =~ /^(\\\n)/o) {

		} elsif ($cur =~ /^(__attribute__)\s*\(?/o) {
			$av_pending = $type;
			$type = 'N';

		} elsif ($cur =~ /^(sizeof)\s*(\()?/o) {
			if (defined $2) {
				$av_pending = 'V';
			}
			$type = 'N';

		} elsif ($cur =~ /^(if|while|for)\b/o) {
			$av_pending = 'E';
			$type = 'N';

		} elsif ($cur =~/^(case)/o) {
			$av_pend_colon = 'C';
			$type = 'N';

		} elsif ($cur =~/^(return|else|goto|typeof|__typeof__)\b/o) {
			$type = 'N';

		} elsif ($cur =~ /^(\()/o) {
			push(@av_paren_type, $av_pending);
			$av_pending = '_';
			$type = 'N';

		} elsif ($cur =~ /^(\))/o) {
			my $new_type = pop(@av_paren_type);
			if ($new_type ne '_') {
				$type = $new_type;
			}

		} elsif ($cur =~ /^($Ident)\s*\(/o) {
			$type = 'V';
			$av_pending = 'V';

		} elsif ($cur =~ /^($Ident\s*):(?:\s*\d+\s*(,|=|;))?/) {
			if (defined $2 && $type eq 'C' || $type eq 'T') {
				$av_pend_colon = 'B';
			} elsif ($type eq 'E') {
				$av_pend_colon = 'L';
			}
			$type = 'V';

		} elsif ($cur =~ /^($Ident|$Constant)/o) {
			$type = 'V';

		} elsif ($cur =~ /^($Assignment)/o) {
			$type = 'N';

		} elsif ($cur =~/^(;|{|})/) {
			$type = 'E';
			$av_pend_colon = 'O';

		} elsif ($cur =~/^(,)/) {
			$type = 'C';

		} elsif ($cur =~ /^(\?)/o) {
			$type = 'N';

		} elsif ($cur =~ /^(:)/o) {
			substr($var, length($res), 1, $av_pend_colon);
			if ($av_pend_colon eq 'C' || $av_pend_colon eq 'L') {
				$type = 'E';
			} else {
				$type = 'N';
			}
			$av_pend_colon = 'O';

		} elsif ($cur =~ /^(\[)/o) {
			$type = 'N';

		} elsif ($cur =~ /^(-(?![->])|\+(?!\+)|\*|\&\&|\&)/o) {
			my $variant;

			if ($type eq 'V') {
				$variant = 'B';
			} else {
				$variant = 'U';
			}

			substr($var, length($res), 1, $variant);
			$type = 'N';

		} elsif ($cur =~ /^($Operators)/o) {
			if ($1 ne '++' && $1 ne '--') {
				$type = 'N';
			}

		} elsif ($cur =~ /(^.)/o) {
		}
		if (defined $1) {
			$cur = substr($cur, length($1));
			$res .= $type x length($1);
		}
	}

	return ($res, $var);
}

sub possible {
	my ($possible, $line) = @_;
	my $notPermitted = qr{(?:
		^(?:
			$Modifier|
			$Storage|
			$Type|
			DEFINE_\S+
		)$|
		^(?:
			goto|
			return|
			case|
			else|
			asm|__asm__|
			do|
			\#|
			\#\#|
		)(?:\s|$)|
		^(?:typedef|struct|enum)\b
	    )}x;
	if ($possible !~ $notPermitted) {
		# Check for modifiers.
		$possible =~ s/\s*$Storage\s*//g;
		$possible =~ s/\s*$Sparse\s*//g;
		if ($possible =~ /^\s*$/) {

		} elsif ($possible =~ /\s/) {
			$possible =~ s/\s*$Type\s*//g;
			for my $modifier (split(' ', $possible)) {
				if ($modifier !~ $notPermitted) {
					push(@modifierListFile, $modifier);
				}
			}

		} else {
			push(@typeListFile, $possible);
		}
		build_types();
	}
}

my $prefix = '';

sub report {
	my ($level, $type, $msg) = @_;

	my $output = '';
	if (-t STDOUT && $color) {
		if ($level eq 'ERROR') {
			$output .= RED;
		} elsif ($level eq 'WARNING') {
			$output .= YELLOW;
		} else {
			$output .= GREEN;
		}
	}
	$output .= $prefix . $level . ':';
	$output .= RESET if (-t STDOUT && $color);
	$output .= ' ' . $msg . "\n";

	$output = (split('\n', $output))[0] . "\n";

	push(our @report, $output);

	return 1;
}

sub report_dump {
	our @report;
}

sub ERROR {
	my ($type, $msg) = @_;

	if (report("ERROR", $type, $msg)) {
		our $clean = 0;
		our $cnt_error++;
		return 1;
	}
	return 0;
}
sub WARN {
	my ($type, $msg) = @_;

	if (report("WARNING", $type, $msg)) {
		our $clean = 0;
		our $cnt_warn++;
		return 1;
	}
	return 0;
}
sub CHK {
	my ($type, $msg) = @_;

	my $check = 0;
	if ($check && report("CHECK", $type, $msg)) {
		our $clean = 0;
		our $cnt_chk++;
		return 1;
	}
	return 0;
}

sub trim {
	my ($string) = @_;

	$string =~ s/^\s+|\s+$//g;

	return $string;
}

sub ltrim {
	my ($string) = @_;

	$string =~ s/^\s+//;

	return $string;
}

sub rtrim {
	my ($string) = @_;

	$string =~ s/\s+$//;

	return $string;
}

sub pos_last_openparen {
	my ($line) = @_;

	my $pos = 0;

	my $opens = $line =~ tr/\(/\(/;
	my $closes = $line =~ tr/\)/\)/;

	my $last_openparen = 0;

	if (($opens == 0) || ($closes >= $opens)) {
		return -1;
	}

	my $len = length($line);

	for ($pos = 0; $pos < $len; $pos++) {
		my $string = substr($line, $pos);
		if ($string =~ /^($FuncArg|$balanced_parens)/) {
			$pos += length($1) - 1;
		} elsif (substr($line, $pos, 1) eq '(') {
			$last_openparen = $pos;
		} elsif (index($string, '(') == -1) {
			last;
		}
	}

	return length(expand_tabs(substr($line, 0, $last_openparen))) + 1;
}

sub process {
	my $filename = shift;

	my $linenr=0;
	my $prevline="";
	my $prevrawline="";
	my $stashline="";
	my $stashrawline="";

	my $length;
	my $real_length;
	my $indent;
	my $previndent=0;
	my $stashindent=0;

	# Header protection
	my $header_protected = 0;
	my $protection_name = '';
	my $header_if_depth = 0;

	our $clean = 1;
	my $signoff = 0;
       my $commit_log_possible_stack_dump = 0;
	my $commit_log_long_line = 0;
	my $commit_log_has_diff = 0;
	my $reported_maintainer_file = 0;
	my $non_utf8_charset = 0;

	my $last_blank_line = 0;
	my $last_coalesced_string_linenr = -1;

	our @report = ();
	our $cnt_lines = 0;
	our $cnt_error = 0;
	our $cnt_warn = 0;
	our $cnt_chk = 0;

	# Trace the real file/line as we go.
	my $realfile = '';
	my $realline = 0;
	my $realcnt = 0;
	my $here = '';
	my $in_comment = 0;
	my $comment_edge = 0;
	my $first_line = 0;
	my $p1_prefix = '';

	my $prev_values = 'E';

	# suppression flags
	my %suppress_ifbraces;
	my %suppress_whiletrailers;
	my %suppress_export;
	my $suppress_statement = 0;

	my %signatures = ();

	# Pre-scan the patch sanitizing the lines.
	# Pre-scan the patch looking for any __setup documentation.
	#
	my @setup_docs = ();
	my $setup_docs = 0;

	sanitise_line_reset();
	my $line;
	foreach my $rawline (@rawlines) {
		$linenr++;
		$line = $rawline;

		if ($rawline=~/^\+\+\+\s+(\S+)/) {
			$setup_docs = 0;
			if ($1 =~ m@Documentation/kernel-parameters.txt$@) {
				$setup_docs = 1;
			}
			#next;
		}
		if ($rawline=~/^\@\@ -\d+(?:,\d+)? \+(\d+)(,(\d+))? \@\@/) {
			$realline=$1-1;
			if (defined $2) {
				$realcnt=$3+1;
			} else {
				$realcnt=1+1;
			}
			$in_comment = 0;

			# Guestimate if this is a continuing comment.  Run
			# the context looking for a comment "edge".  If this
			# edge is a close comment then we must be in a comment
			# at context start.
			my $edge;
			my $cnt = $realcnt;
			for (my $ln = $linenr + 1; $cnt > 0; $ln++) {
				next if (defined $rawlines[$ln - 1] &&
					 $rawlines[$ln - 1] =~ /^-/);
				$cnt--;
				#print "RAW<$rawlines[$ln - 1]>\n";
				last if (!defined $rawlines[$ln - 1]);
				if ($rawlines[$ln - 1] =~ m@(/\*|\*/)@ &&
				    $rawlines[$ln - 1] !~ m@"[^"]*(?:/\*|\*/)[^"]*"@) {
					($edge) = $1;
					last;
				}
			}
			if (defined $edge && $edge eq '*/') {
				$in_comment = 1;
			}

			# Guestimate if this is a continuing comment.  If this
			# is the start of a diff block and this line starts
			# ' *' then it is very likely a comment.
			if (!defined $edge &&
			    $rawlines[$linenr] =~ m@^.\s*(?:\*\*+| \*)(?:\s|$)@)
			{
				$in_comment = 1;
			}

			##print "COMMENT:$in_comment edge<$edge> $rawline\n";
			sanitise_line_reset($in_comment);

		} elsif ($realcnt && $rawline =~ /^(?:\+| |$)/) {
			# Standardise the strings and chars within the input to
			# simplify matching -- only bother with positive lines.
			$line = sanitise_line($rawline);
		}
		push(@lines, $line);

		if ($realcnt > 1) {
			$realcnt-- if ($line =~ /^(?:\+| |$)/);
		} else {
			$realcnt = 0;
		}

		#print "==>$rawline\n";
		#print "-->$line\n";

		if ($setup_docs && $line =~ /^\+/) {
			push(@setup_docs, $line);
		}
	}

	$prefix = '';
	my %camelcase = ();

	$realcnt = 0;
	$linenr = 0;
	my $nbfunc = 0;
	my $inscope = 0;
	my $funclines = 0;

	foreach my $line (@lines) {
		$linenr++;
		my $sline = $line;	#copy of $line
		$sline =~ s/$;/ /g;	#with comments as spaces

		my $rawline = $rawlines[$linenr - 1];

#extract the line range in the file after the patch is applied
		if ($line =~ /^\@\@ -\d+(?:,\d+)? \+(\d+)(,(\d+))? \@\@/) {
			$first_line = $linenr + 1;
			$realline=$1-1;
			if (defined $2) {
				$realcnt=$3+1;
			} else {
				$realcnt=1+1;
			}
			annotate_reset();
			$prev_values = 'E';

			%suppress_ifbraces = ();
			%suppress_whiletrailers = ();
			%suppress_export = ();
			$suppress_statement = 0;
			next;

# track the line number as we move through the hunk, note that
# new versions of GNU diff omit the leading space on completely
# blank context lines so we need to count that too.
		} elsif ($line =~ /^( |\+|$)/) {
			$realline++;
			$realcnt-- if ($realcnt != 0);

			# Measure the line length and indent.
			($length, $indent) = line_stats($rawline);
			$real_length = real_length($rawline);

			# Track the previous line.
			($prevline, $stashline) = ($stashline, $line);
			($previndent, $stashindent) = ($stashindent, $indent);
			($prevrawline, $stashrawline) = ($stashrawline, $rawline);

			#warn "line<$line>\n";

		} elsif ($realcnt == 1) {
			$realcnt--;
		}

		my $hunk_line = ($realcnt != 0);

		$here = "#$realline: ";

		my $found_file = 0;
		# extract the filename as it passes
		if ($line =~ /^diff --git.*?(\S+)$/) {
			$realfile = $1;
			$found_file = 1;
		} elsif ($line =~ /^\+\+\+\s+(\S+)/) {
			$realfile = $1;

			if ($realfile =~ m@^include/asm/@) {
				ERROR("MODIFIED_INCLUDE_ASM",
				      "do not modify files in include/asm, change architecture specific files in include/asm-<architecture>\n" . "$here$rawline\n");
			}
			$found_file = 1;
		}

#make up the handle for any error we report on this line
		$prefix = "$filename:$realline: ";

		$here .= "FILE: $realfile:$realline:" if ($realcnt != 0);

		my $hereline = "$here\n$rawline\n";
		my $herecurr = "$here\n$rawline\n";
		my $hereprev = "$here\n$prevrawline\n$rawline\n";

		$cnt_lines++ if ($realcnt != 0);

# Check for incorrect file permissions
		if ($line =~ /^new (file )?mode.*[7531]\d{0,2}$/) {
			my $permhere = $here . "FILE: $realfile\n";
			if ($realfile !~ m@scripts/@ &&
			    $realfile !~ /\.(py|pl|awk|sh)$/) {
				ERROR("EXECUTE_PERMISSIONS",
				      "do not set execute permissions for source files\n" . $permhere);
			}
		}

# ignore non-hunk lines and lines being removed
		next if (!$hunk_line || $line =~ /^-/);

#trailing whitespace
		if ($line =~ /^\+.*\015/) {
			my $herevet = "$here\n" . cat_vet($rawline) . "\n";
			ERROR("DOS_LINE_ENDINGS", "DOS line endings\n" . $herevet);
		} elsif ($rawline =~ /^\+.*\S\s+$/ || $rawline =~ /^\+\s+$/) {
			my $herevet = "$here\n" . cat_vet($rawline) . "\n";
			ERROR("TRAILING_WHITESPACE", "trailing whitespace\n" . $herevet);

			$rpt_cleaners = 1;
		}

# check we are in a valid source file if not then ignore this hunk
		next if ($realfile !~ /\.(h|c|s|S|pl|sh|dtsi|dts)$/);

# line length limit (with some exclusions)
#
# There are a few types of lines that may extend beyond $max_line_length:
#	logging functions like pr_info that end in a string
#	lines with a single string
#	#defines that are a single string
#
# There are 3 different line length message types:
# LONG_LINE_COMMENT	a comment starts before but extends beyond $max_linelength
# LONG_LINE_STRING	a string starts before but extends beyond $max_line_length
# LONG_LINE		all other lines longer than $max_line_length
#
# if LONG_LINE is ignored, the other 2 types are also ignored
#

		if ($line =~ /^\+/ && $real_length > $max_line_length) {
			my $msg_type = "LONG_LINE";

			# Check the allowed long line types first

			# logging functions that end in a string that starts
			# before $max_line_length
			if ($line =~ /^\+\s*$logFunctions\s*\(\s*(?:(?:KERN_\S+\s*|[^"]*))?($String\s*(?:|,|\)\s*;)\s*)$/ &&
			    length(expand_tabs(substr($line, 1, length($line) - length($1) - 1))) <= $max_line_length) {
				$msg_type = "";

			# lines with only strings (w/ possible termination)
			# #defines with only strings
			} elsif ($line =~ /^\+\s*$String\s*(?:\s*|,|\)\s*;)\s*$/ ||
				 $line =~ /^\+\s*#\s*define\s+\w+\s+$String$/) {
				$msg_type = "";

			# Otherwise set the alternate message types

			# a comment starts before $max_line_length
			} elsif ($line =~ /($;[\s$;]*)$/ &&
				 length(expand_tabs(substr($line, 1, length($line) - length($1) - 1))) <= $max_line_length) {
				$msg_type = "LONG_LINE_COMMENT"

			# a quoted string starts before $max_line_length
			} elsif ($sline =~ /\s*($String(?:\s*(?:\\|,\s*|\)\s*;\s*))?)$/ &&
				 length(expand_tabs(substr($line, 1, length($line) - length($1) - 1))) <= $max_line_length) {
				$msg_type = "LONG_LINE_STRING"
			}

			if ($msg_type ne "") {
				WARN($msg_type,
				     "line over $max_line_length characters ($real_length)\n" . $herecurr);
			}
		}

# check for adding lines without a newline.
		if ($line =~ /^\+/ && defined $lines[$linenr] && $lines[$linenr] =~ /^\\ No newline at end of file/) {
			WARN("MISSING_EOF_NEWLINE",
			     "adding a line without newline at end of file\n" . $herecurr);
		}

# check we are in a valid source file C or perl if not then ignore this hunk
		next if ($realfile !~ /\.(h|c|pl|dtsi|dts)$/);

# at the beginning of a line any tabs must come first and anything
# more than 8 must use tabs.
		if ($rawline =~ /^\+\s* \t\s*\S/ ||
		    $rawline =~ /^\+\s*        \s*/) {
			my $herevet = "$here\n" . cat_vet($rawline) . "\n";
			$rpt_cleaners = 1;
			ERROR("CODE_INDENT",
			    "code indent should use tabs where possible\n" . $herevet);
		}

# check for space before tabs.
		if ($rawline =~ /^\+/ && $rawline =~ / \t/) {
			my $herevet = "$here\n" . cat_vet($rawline) . "\n";
			WARN("SPACE_BEFORE_TAB",
			    "please, no space before tabs\n" . $herevet);
		}

# check for && or || at the start of a line
		if ($rawline =~ /^\+\s*(&&|\|\|)/) {
			CHK("LOGICAL_CONTINUATIONS",
			    "Logical continuations should be on the previous line\n" . $hereprev);
		}

# check indentation starts on a tab stop
		if ($^V && $^V ge 5.10.0 &&
		    $sline =~ /^\+\t+( +)(?:$c90_Keywords\b|\{\s*$|\}\s*(?:else\b|while\b|\s*$))/) {
			my $indent = length($1);
			if ($indent % 8) {
				WARN("TABSTOP",
				    "Statements should start on a tabstop\n" . $herecurr);
			}
		}

# check multi-line statement indentation matches previous line
		if ($^V && $^V ge 5.10.0 &&
		    $prevline =~ /^\+([ \t]*)((?:$c90_Keywords(?:\s+if)\s*)|(?:$Declare\s*)?(?:$Ident|\(\s*\*\s*$Ident\s*\))\s*|$Ident\s*=\s*$Ident\s*)\(.*(\&\&|\|\||,)\s*$/) {
			$prevline =~ /^\+(\t*)(.*)$/;
			my $oldindent = $1;
			my $rest = $2;

			my $pos = pos_last_openparen($rest);
			if ($pos >= 0) {
				$line =~ /^(\+| )([ \t]*)/;
				my $newindent = $2;

				my $goodtabindent = $oldindent .
					"\t" x ($pos / 8) .
					" "  x ($pos % 8);
				my $goodspaceindent = $oldindent . " "  x $pos;

				if ($newindent ne $goodtabindent &&
				    $newindent ne $goodspaceindent) {

					CHK("PARENTHESIS_ALIGNMENT",
					    "Alignment should match open parenthesis\n" . $hereprev);
				}
			}
		}

# check for space after cast like "(int) foo" or "(struct foo) bar"
# avoid checking a few false positives:
#   "sizeof(<type>)" or "__alignof__(<type>)"
#   function pointer declarations like "(*foo)(int) = bar;"
#   structure definitions like "(struct foo) { 0 };"
#   multiline macros that define functions
#   known attributes or the __attribute__ keyword
		if ($line =~ /^\+(.*)\(\s*$Type\s*\)([ \t]++)((?![={]|\\$|$Attribute|__attribute__))/ &&
		    (!defined($1) || $1 !~ /\b(?:sizeof|__alignof__)\s*$/)) {
			CHK("SPACING",
			    "No space is necessary after a cast\n" . $herecurr);
		}

# Block comment styles
# Networking with an initial /*
		if ($realfile =~ m@^(drivers/net/|net/)@ &&
		    $prevrawline =~ /^\+[ \t]*\/\*[ \t]*$/ &&
		    $rawline =~ /^\+[ \t]*\*/ &&
		    $realline > 2) {
			WARN("NETWORKING_BLOCK_COMMENT_STYLE",
			     "networking block comments don't use an empty /* line, use /* Comment...\n" . $hereprev);
		}

# Block comments use * on subsequent lines
		if ($prevline =~ /$;[ \t]*$/ &&			#ends in comment
		    $prevrawline =~ /^\+.*?\/\*/ &&		#starting /*
		    $prevrawline !~ /\*\/[ \t]*$/ &&		#no trailing */
		    $rawline =~ /^\+/ &&			#line is new
		    $rawline !~ /^\+[ \t]*\*/) {		#no leading *
			WARN("BLOCK_COMMENT_STYLE",
			     "Block comments use * on subsequent lines\n" . $hereprev);
		}

# Block comments use */ on trailing lines
		if ($rawline !~ m@^\+[ \t]*\*/[ \t]*$@ &&	#trailing */
		    $rawline !~ m@^\+.*/\*.*\*/[ \t]*$@ &&	#inline /*...*/
		    $rawline !~ m@^\+.*\*{2,}/[ \t]*$@ &&	#trailing **/
		    $rawline =~ m@^\+[ \t]*.+\*\/[ \t]*$@) {	#non blank */
			WARN("BLOCK_COMMENT_STYLE",
			     "Block comments use a trailing */ on a separate line\n" . $herecurr);
		}

# check for missing blank lines after struct/union declarations
# with exceptions for various attributes and macros
		if ($prevline =~ /^[\+ ]};?\s*$/ &&
		    $line =~ /^\+/ &&
		    !($line =~ /^\+\s*$/ ||
		      $line =~ /^\+\s*EXPORT_SYMBOL/ ||
		      $line =~ /^\+\s*MODULE_/i ||
		      $line =~ /^\+\s*\#\s*(?:end|elif|else)/ ||
		      $line =~ /^\+[a-z_]*init/ ||
		      $line =~ /^\+\s*(?:static\s+)?[A-Z_]*ATTR/ ||
		      $line =~ /^\+\s*DECLARE/ ||
		      $line =~ /^\+\s*__setup/)) {
			CHK("LINE_SPACING",
				"Please use a blank line after function/struct/union/enum declarations\n" . $hereprev);
		}

# check for multiple consecutive blank lines
		if ($prevline =~ /^[\+ ]\s*$/ &&
		    $line =~ /^\+\s*$/ &&
		    $last_blank_line != ($linenr - 1)) {
			CHK("LINE_SPACING",
			    "Please don't use multiple blank lines\n" . $hereprev);

			$last_blank_line = $linenr;
		}

# check for missing blank lines after declarations
		if ($sline =~ /^\+\s+\S/ &&			#Not at char 1
			# actual declarations
		    ($prevline =~ /^\+\s+$Declare\s*$Ident\s*[=,;:\[]/ ||
			# function pointer declarations
		     $prevline =~ /^\+\s+$Declare\s*\(\s*\*\s*$Ident\s*\)\s*[=,;:\[\(]/ ||
			# foo bar; where foo is some local typedef or #define
		     $prevline =~ /^\+\s+$Ident(?:\s+|\s*\*\s*)$Ident\s*[=,;\[]/ ||
			# known declaration macros
		     $prevline =~ /^\+\s+$declaration_macros/) &&
			# for "else if" which can look like "$Ident $Ident"
		    !($prevline =~ /^\+\s+$c90_Keywords\b/ ||
			# other possible extensions of declaration lines
		      $prevline =~ /(?:$Compare|$Assignment|$Operators)\s*$/ ||
			# not starting a section or a macro "\" extended line
		      $prevline =~ /(?:\{\s*|\\)$/) &&
			# looks like a declaration
		    !($sline =~ /^\+\s+$Declare\s*$Ident\s*[=,;:\[]/ ||
			# function pointer declarations
		      $sline =~ /^\+\s+$Declare\s*\(\s*\*\s*$Ident\s*\)\s*[=,;:\[\(]/ ||
			# foo bar; where foo is some local typedef or #define
		      $sline =~ /^\+\s+$Ident(?:\s+|\s*\*\s*)$Ident\s*[=,;\[]/ ||
			# known declaration macros
		      $sline =~ /^\+\s+$declaration_macros/ ||
			# start of struct or union or enum
		      $sline =~ /^\+\s+(?:union|struct|enum|typedef)\b/ ||
			# start or end of block or continuation of declaration
		      $sline =~ /^\+\s+(?:$|[\{\}\.\#\"\?\:\(\[])/ ||
			# bitfield continuation
		      $sline =~ /^\+\s+$Ident\s*:\s*\d+\s*[,;]/ ||
			# other possible extensions of declaration lines
		      $sline =~ /^\+\s+\(?\s*(?:$Compare|$Assignment|$Operators)/) &&
			# indentation of previous and current line are the same
		    (($prevline =~ /\+(\s+)\S/) && $sline =~ /^\+$1\S/)) {
			WARN("LINE_SPACING",
			    "Missing a blank line after declarations\n" . $hereprev);
		}

# check for spaces at the beginning of a line.
# Exceptions:
#  1) within comments
#  2) indented preprocessor commands
#  3) hanging labels
		if ($rawline =~ /^\+ / && $line !~ /^\+ *(?:$;|#|$Ident:)/)  {
			my $herevet = "$here\n" . cat_vet($rawline) . "\n";
			WARN("LEADING_SPACE",
			    "please, no spaces at the start of a line\n" . $herevet);
		}

# check we are in a valid C source file if not then ignore this hunk
		next if ($realfile !~ /\.(h|c)$/);

# Check for header protection
		if ($realfile =~ /\.h$/ && $safe_guard == 1) {
			# The header is not protected yet
			if ($header_protected == 0) {
				if ($protection_name eq '') {
					if ($line =~ /^.#\s*ifndef\s*(\S*)\s*$/) {
						$protection_name = $1;
					}
				}
				if ($protection_name ne '' &&
				    $line =~ /^.#\s*define\s*(\S*)\s*.*$/) {
					if (defined $1 && $1 eq $protection_name) {
						$header_protected = 1;
					}
				}
				if ($header_protected == 0 &&
				    $line !~ /^.\s*$/ &&
				    $line !~ /^.#\s*(?:end)?if/) {
					WARN("HEADER_PROTECTION",
						"This line is not protected from double inclusion\n" . $hereprev);
				}
			}

			if ($line =~ /^.#\s*if/) {
				++$header_if_depth;
			}
			if ($line =~ /^.#\s*endif/) {
				--$header_if_depth;
				if ($header_if_depth == 0) {
					$header_protected = 0;
					$protection_name = '';
				}
			}
		}

# check indentation of any line with a bare else
# (but not if it is a multiple line "if (foo) return bar; else return baz;")
# if the previous line is a break or return and is indented 1 tab more...
		if ($sline =~ /^\+([\t]+)(?:}[ \t]*)?else(?:[ \t]*{)?\s*$/) {
			my $tabs = length($1) + 1;
			if ($prevline =~ /^\+\t{$tabs,$tabs}break\b/ ||
			    ($prevline =~ /^\+\t{$tabs,$tabs}return\b/ &&
			     defined $lines[$linenr] &&
			     $lines[$linenr] !~ /^[ \+]\t{$tabs,$tabs}return/)) {
				WARN("UNNECESSARY_ELSE",
				     "else is not generally useful after a break or return\n" . $hereprev);
			}
		}

# check indentation of a line with a break;
# if the previous line is a goto or return and is indented the same # of tabs
		if ($sline =~ /^\+([\t]+)break\s*;\s*$/) {
			my $tabs = $1;
			if ($prevline =~ /^\+$tabs(?:goto|return)\b/) {
				WARN("UNNECESSARY_BREAK",
				     "break is not useful after a goto or return\n" . $hereprev);
			}
		}

# Check for potential 'bare' types
		my ($stat, $cond, $line_nr_next, $remain_next, $off_next,
		    $realline_next);
#print "LINE<$line>\n";
		if ($linenr >= $suppress_statement &&
		    $realcnt && $sline =~ /.\s*\S/) {
			($stat, $cond, $line_nr_next, $remain_next, $off_next) =
				ctx_statement_block($linenr, $realcnt, 0);
			$stat =~ s/\n./\n /g;
			$cond =~ s/\n./\n /g;

#print "linenr<$linenr> <$stat>\n";
			# If this statement has no statement boundaries within
			# it there is no point in retrying a statement scan
			# until we hit end of it.
			my $frag = $stat; $frag =~ s/;+\s*$//;
			if ($frag !~ /(?:{|;)/) {
#print "skip<$line_nr_next>\n";
				$suppress_statement = $line_nr_next;
			}

			# Find the real next line.
			$realline_next = $line_nr_next;
			if (defined $realline_next &&
			    (!defined $lines[$realline_next - 1] ||
			     substr($lines[$realline_next - 1], $off_next) =~ /^\s*$/)) {
				$realline_next++;
			}

			my $s = $stat;
			$s =~ s/{.*$//s;

			# Ignore goto labels.
			if ($s =~ /$Ident:\*$/s) {

			# Ignore functions being called
			} elsif ($s =~ /^.\s*$Ident\s*\(/s) {

			} elsif ($s =~ /^.\s*else\b/s) {

			# declarations always start with types
			} elsif ($prev_values eq 'E' && $s =~ /^.\s*(?:$Storage\s+)?(?:$Inline\s+)?(?:const\s+)?((?:\s*$Ident)+?)\b(?:\s+$Sparse)?\s*\**\s*(?:$Ident|\(\*[^\)]*\))(?:\s*$Modifier)?\s*(?:;|=|,|\()/s) {
				my $type = $1;
				$type =~ s/\s+/ /g;
				possible($type, "A:" . $s);

			# definitions in global scope can only start with types
			} elsif ($s =~ /^.(?:$Storage\s+)?(?:$Inline\s+)?(?:const\s+)?($Ident)\b\s*(?!:)/s) {
				possible($1, "B:" . $s);
			}

			# any (foo ... *) is a pointer cast, and foo is a type
			while ($s =~ /\(($Ident)(?:\s+$Sparse)*[\s\*]+\s*\)/sg) {
				possible($1, "C:" . $s);
			}

			# Check for any sort of function declaration.
			# int foo(something bar, other baz);
			# void (*store_gdt)(x86_descr_ptr *);
			if ($prev_values eq 'E' && $s =~ /^(.(?:typedef\s*)?(?:(?:$Storage|$Inline)\s*)*\s*$Type\s*(?:\b$Ident|\(\*\s*$Ident\))\s*)\(/s) {
				my ($name_len) = length($1);

				my $ctx = $s;
				substr($ctx, 0, $name_len + 1, '');
				$ctx =~ s/\)[^\)]*$//;

				for my $arg (split(/\s*,\s*/, $ctx)) {
					if ($arg =~ /^(?:const\s+)?($Ident)(?:\s+$Sparse)*\s*\**\s*(:?\b$Ident)?$/s || $arg =~ /^($Ident)$/s) {

						possible($1, "D:" . $s);
					}
				}
			}

		}

#
# Checks which may be anchored in the context.
#

# Check for switch () and associated case and default
# statements should be at the same indent.
		if ($line=~/\bswitch\s*\(.*\)/) {
			my $err = '';
			my $sep = '';
			my @ctx = ctx_block_outer($linenr, $realcnt);
			shift(@ctx);
			for my $ctx (@ctx) {
				my ($clen, $cindent) = line_stats($ctx);
				if ($ctx =~ /^\+\s*(case\s+|default:)/ &&
							$indent != $cindent) {
					$err .= "$sep$ctx\n";
					$sep = '';
				} else {
					$sep = "[...]\n";
				}
			}
			if ($err ne '') {
				ERROR("SWITCH_CASE_INDENT_LEVEL",
				      "switch and case should be at the same indent\n$hereline$err");
			}
		}

# if/while/etc brace do not go on next line, unless defining a do while loop,
# or if that brace on the next line is for something else
		#if ($line =~ /(.*)\b((?:if|while|for|switch|(?:[a-z_]+|)for_each[a-z_]+)\s*\(|do\b|else\b)/ && $line !~ /^.\s*\#/) {
		if ($line =~ /(.*)\b((?:if|while|for|switch|(?:[a-z_]+|)for_each[a-z_]+)\s*\(|else\b)/ && $line !~ /^.\s*\#/) {
			my $pre_ctx = "$1$2";

			my ($level, @ctx) = ctx_statement_level($linenr, $realcnt, 0);

			if ($line =~ /^\+\t{6,}/) {
				WARN("DEEP_INDENTATION",
				     "Too many leading tabs - consider code refactoring\n" . $herecurr);
			}

			my $ctx_cnt = $realcnt - $#ctx - 1;
			my $ctx = join("\n", @ctx);

			my $ctx_ln = $linenr;
			my $ctx_skip = $realcnt;

			while ($ctx_skip > $ctx_cnt || ($ctx_skip == $ctx_cnt &&
					defined $lines[$ctx_ln - 1] &&
					$lines[$ctx_ln - 1] =~ /^-/)) {
				##print "SKIP<$ctx_skip> CNT<$ctx_cnt>\n";
				$ctx_skip-- if (!defined $lines[$ctx_ln - 1] || $lines[$ctx_ln - 1] !~ /^-/);
				$ctx_ln++;
			}

			#print "realcnt<$realcnt> ctx_cnt<$ctx_cnt>\n";
			#print "pre<$pre_ctx>\nline<$line>\nctx<$ctx>\nnext<$lines[$ctx_ln - 1]>\n";

			# if ($ctx !~ /{\s*/ && defined($lines[$ctx_ln - 1]) && $lines[$ctx_ln - 1] =~ /^\+\s*{/) {
			# 	ERROR("OPEN_BRACE",
			# 	      "that open brace { should be on the next line\n" .
			# 		"$here\n$ctx\n$rawlines[$ctx_ln - 1]\n");
			# }
			if ($line =~ /\s*{/) {
				ERROR("OPEN_BRACE",
				      "that open brace { should be on the next line\n" .
					"$here\n$ctx\n$rawlines[$ctx_ln - 1]\n");
			}
			if ($level == 0 && $pre_ctx !~ /}\s*while\s*\($/ &&
			    $ctx =~ /\)\s*\;\s*$/ &&
			    defined $lines[$ctx_ln - 1])
			{
				my ($nlength, $nindent) = line_stats($lines[$ctx_ln - 1]);
				if ($nindent > $indent) {
					WARN("TRAILING_SEMICOLON",
					     "trailing semicolon indicates no statements, indent implies otherwise\n" .
						"$here\n$ctx\n$rawlines[$ctx_ln - 1]\n");
				}
			}
		}

# Check relative indent for conditionals and blocks.
		if ($line =~ /\b(?:(?:if|while|for|(?:[a-z_]+|)for_each[a-z_]+)\s*\(|do\b)/ && $line !~ /^.\s*#/ && $line !~ /\}\s*while\s*/) {
			($stat, $cond, $line_nr_next, $remain_next, $off_next) =
				ctx_statement_block($linenr, $realcnt, 0)
					if (!defined $stat);
			my ($s, $c) = ($stat, $cond);

			substr($s, 0, length($c), '');

			# remove inline comments
			$s =~ s/$;/ /g;
			$c =~ s/$;/ /g;

			# Find out how long the conditional actually is.
			my @newlines = ($c =~ /\n/gs);
			my $cond_lines = 1 + $#newlines;

			# Make sure we remove the line prefixes as we have
			# none on the first line, and are going to readd them
			# where necessary.
			$s =~ s/\n./\n/gs;
			while ($s =~ /\n\s+\\\n/) {
				$cond_lines += $s =~ s/\n\s+\\\n/\n/g;
			}

			# We want to check the first line inside the block
			# starting at the end of the conditional, so remove:
			#  1) any blank line termination
			#  2) any opening brace { on end of the line
			#  3) any do (...) {
			my $continuation = 0;
			my $check = 0;
			$s =~ s/^.*\bdo\b//;
			$s =~ s/^\s*{//;
			if ($s =~ s/^\s*\\//) {
				$continuation = 1;
			}
			if ($s =~ s/^\s*?\n//) {
				$check = 1;
				$cond_lines++;
			}

			# Also ignore a loop construct at the end of a
			# preprocessor statement.
			if (($prevline =~ /^.\s*#\s*define\s/ ||
			    $prevline =~ /\\\s*$/) && $continuation == 0) {
				$check = 0;
			}

			my $cond_ptr = -1;
			$continuation = 0;
			while ($cond_ptr != $cond_lines) {
				$cond_ptr = $cond_lines;

				# If we see an #else/#elif then the code
				# is not linear.
				if ($s =~ /^\s*\#\s*(?:else|elif)/) {
					$check = 0;
				}

				# Ignore:
				#  1) blank lines, they should be at 0,
				#  2) preprocessor lines, and
				#  3) labels.
				if ($continuation ||
				    $s =~ /^\s*?\n/ ||
				    $s =~ /^\s*#\s*?/ ||
				    $s =~ /^\s*$Ident\s*:/) {
					$continuation = ($s =~ /^.*?\\\n/) ? 1 : 0;
					if ($s =~ s/^.*?\n//) {
						$cond_lines++;
					}
				}
			}

			my (undef, $sindent) = line_stats("+" . $s);
			my $stat_real = raw_line($linenr, $cond_lines);

			# Check if either of these lines are modified, else
			# this is not this patch's fault.
			if (!defined($stat_real) ||
			    $stat !~ /^\+/ && $stat_real !~ /^\+/) {
				$check = 0;
			}
			if (defined($stat_real) && $cond_lines > 1) {
				$stat_real = "[...]\n$stat_real";
			}

			#print "line<$line> prevline<$prevline> indent<$indent> sindent<$sindent> check<$check> continuation<$continuation> s<$s> cond_lines<$cond_lines> stat_real<$stat_real> stat<$stat>\n";

			if ($check && $s ne '' &&
			    (($sindent % 8) != 0 ||
			     ($sindent < $indent) ||
			     ($sindent > $indent + 8))) {
				WARN("SUSPECT_CODE_INDENT",
				     "suspect code indent for conditional statements ($indent, $sindent)\n" . $herecurr . "$stat_real\n");
			}
		}

		# Track the 'values' across context and added lines.
		my $opline = $line; $opline =~ s/^./ /;
		my ($curr_values, $curr_vars) =
				annotate_values($opline . "\n", $prev_values);
		$curr_values = $prev_values . $curr_values;
		$prev_values = substr($curr_values, -1);

#ignore lines not being added
		next if ($line =~ /^[^\+]/);

# check for declarations of signed or unsigned without int
		while ($line =~ m{($Declare)\s*(?!char\b|short\b|int\b|long\b)\s*($Ident)?\s*[=,;\[\)\(]}g) {
			my $type = $1;
			my $var = $2;
			$var = "" if (!defined $var);
			if ($type =~ /^(?:(?:$Storage|$Inline|$Attribute)\s+)*((?:un)?signed)((?:\s*\*)*)\s*$/) {
				my $sign = $1;
				my $pointer = $2;

				$pointer = "" if (!defined $pointer);

				WARN("UNSPECIFIED_INT",
				    "Prefer '" . trim($sign) . " int" . rtrim($pointer) . "' to bare use of '$sign" . rtrim($pointer) . "'\n" . $herecurr);
			}
		}

# check for initialisation to aggregates open brace on the next line
		if ($line =~ /^.\s*{/ &&
		    ($prevline =~ /(?:^|[^=])=\s*$/ ||
		    $prevline =~ /^.\s*\bdo\b\s*/)) {
			ERROR("OPEN_BRACE",
			    "that open brace { should be on the previous line\n" . $hereprev);
		}

#
# Checks which are anchored on the added line.
#

# check for malformed paths in #include statements (uses RAW line)
		if ($rawline =~ m{^.\s*\#\s*include\s+[<"](.*)[">]}) {
			my $path = $1;
			if ($path =~ m{//}) {
				ERROR("MALFORMED_INCLUDE",
				      "malformed #include filename\n" . $herecurr);
			}
		}

# no C99 // comments
		if ($line =~ m{//}) {
			ERROR("C99_COMMENTS",
			    "do not use C99 // comments\n" . $herecurr);
		}
		# Remove C99 comments.
		$line =~ s@//.*@@;
		$opline =~ s@//.*@@;

# EXPORT_SYMBOL should immediately follow the thing it is exporting, consider
# the whole statement.
#print "APW <$lines[$realline_next - 1]>\n";
		if (defined $realline_next &&
		    exists $lines[$realline_next - 1] &&
		    !defined $suppress_export{$realline_next} &&
		    ($lines[$realline_next - 1] =~ /EXPORT_SYMBOL.*\((.*)\)/ ||
		     $lines[$realline_next - 1] =~ /EXPORT_UNUSED_SYMBOL.*\((.*)\)/)) {
			# Handle definitions which produce identifiers with
			# a prefix:
			#   XXX(foo);
			#   EXPORT_SYMBOL(something_foo);
			my $name = $1;
			if ($stat =~ /^(?:.\s*}\s*\n)?.([A-Z_]+)\s*\(\s*($Ident)/ &&
			    $name =~ /^${Ident}_$2/) {
#print "FOO C name<$name>\n";
				$suppress_export{$realline_next} = 1;

			} elsif ($stat !~ /(?:
				\n.}\s*$|
				^.DEFINE_$Ident\(\Q$name\E\)|
				^.DECLARE_$Ident\(\Q$name\E\)|
				^.LIST_HEAD\(\Q$name\E\)|
				^.(?:$Storage\s+)?$Type\s*\(\s*\*\s*\Q$name\E\s*\)\s*\(|
				\b\Q$name\E(?:\s+$Attribute)*\s*(?:;|=|\[|\()
			    )/x) {
#print "FOO A<$lines[$realline_next - 1]> stat<$stat> name<$name>\n";
				$suppress_export{$realline_next} = 2;
			} else {
				$suppress_export{$realline_next} = 1;
			}
		}
		if (!defined $suppress_export{$linenr} &&
		    $prevline =~ /^.\s*$/ &&
		    ($line =~ /EXPORT_SYMBOL.*\((.*)\)/ ||
		     $line =~ /EXPORT_UNUSED_SYMBOL.*\((.*)\)/)) {
#print "FOO B <$lines[$linenr - 1]>\n";
			$suppress_export{$linenr} = 2;
		}
		if (defined $suppress_export{$linenr} &&
		    $suppress_export{$linenr} == 2) {
			WARN("EXPORT_SYMBOL",
			     "EXPORT_SYMBOL(foo); should immediately follow its function/variable\n" . $herecurr);
		}

# Check for global variables (not allowed).
		if ($line =~ /^\+$Type\s*$Ident(?:\s+$Modifier)*(?:\s*=\s*.*)?;/ ||
			$line =~ /^\+$Declare\s*\(\s*\*\s*$Ident\s*\)\s*[=,;:\[\(]/ ||
			$line =~ /^\+$Ident(?:\s+|\s*\*\s*)$Ident\s*[=,;\[]/ ||
			$line =~ /^\+$declaration_macros/) {
			ERROR("GLOBAL_DECLARATION",
				  "global variables are not allowed\n" . $herecurr);
		}

# check for global initialisers.
		# if ($line =~ /^\+$Type\s*$Ident(?:\s+$Modifier)*\s*=\s*($zero_initializer)\s*;/) {
		# 	ERROR("GLOBAL_INITIALISERS",
		# 		  "do not initialise globals to $1\n" . $herecurr);
		# }
# check for static initialisers.
		if ($line =~ /^\+.*\bstatic\s.*=\s*($zero_initializer)\s*;/) {
			ERROR("INITIALISED_STATIC",
			    "do not initialise statics to $1\n" .
			    $herecurr);
		}

# check for misordered declarations of char/short/int/long with signed/unsigned
		while ($sline =~ m{(\b$TypeMisordered\b)}g) {
			my $tmp = trim($1);
			WARN("MISORDERED_TYPE",
			     "type '$tmp' should be specified in [[un]signed] [short|int|long|long long] order\n" . $herecurr);
		}

# check for static const char * arrays.
		if ($line =~ /\bstatic\s+const\s+char\s*\*\s*(\w+)\s*\[\s*\]\s*=\s*/) {
			WARN("STATIC_CONST_CHAR_ARRAY",
			     "static const char * array should probably be static const char * const\n" .
				$herecurr);
               }

# check for static char foo[] = "bar" declarations.
		if ($line =~ /\bstatic\s+char\s+(\w+)\s*\[\s*\]\s*=\s*"/) {
			WARN("STATIC_CONST_CHAR_ARRAY",
			     "static char array declaration should probably be static const char\n" .
				$herecurr);
               }

# check for const <foo> const where <foo> is not a pointer or array type
		if ($sline =~ /\bconst\s+($BasicType)\s+const\b/) {
			my $found = $1;
			if ($sline =~ /\bconst\s+\Q$found\E\s+const\b\s*\*/) {
				WARN("CONST_CONST",
				     "'const $found const *' should probably be 'const $found * const'\n" . $herecurr);
			} elsif ($sline !~ /\bconst\s+\Q$found\E\s+const\s+\w+\s*\[/) {
				WARN("CONST_CONST",
				     "'const $found const' should probably be 'const $found'\n" . $herecurr);
			}
		}

# check for non-global char *foo[] = {"bar", ...} declarations.
		if ($line =~ /^.\s+(?:static\s+|const\s+)?char\s+\*\s*\w+\s*\[\s*\]\s*=\s*\{/) {
			WARN("STATIC_CONST_CHAR_ARRAY",
			     "char * array declaration might be better as static const\n" .
				$herecurr);
               }

# check for sizeof(foo)/sizeof(foo[0]) that could be ARRAY_SIZE(foo)
		if ($line =~ m@\bsizeof\s*\(\s*($Lval)\s*\)@) {
			my $array = $1;
			if ($line =~ m@\b(sizeof\s*\(\s*\Q$array\E\s*\)\s*/\s*sizeof\s*\(\s*\Q$array\E\s*\[\s*0\s*\]\s*\))@) {
				my $array_div = $1;
				WARN("ARRAY_SIZE",
				    "Prefer ARRAY_SIZE($array)\n" . $herecurr);
			}
		}

# check for function declarations without arguments like "int foo()"
		if ($line =~ /(\b$Type\s+$Ident)\s*\(\s*\)/) {
			ERROR("FUNCTION_WITHOUT_ARGS",
			    "Bad function definition - $1() should probably be $1(void)\n" . $herecurr);
		}

# check for new typedefs, only function parameters and sparse annotations
# make sense.
		# if ($line =~ /\btypedef\s/ &&
		#     $line !~ /\btypedef\s+$Type\s*\(\s*\*?$Ident\s*\)\s*\(/ &&
		#     $line !~ /\btypedef\s+$Type\s+$Ident\s*\(/ &&
		#     $line !~ /\b$typeTypedefs\b/ &&
		#     $line !~ /\b__bitwise(?:__|)\b/) {
		# 	WARN("NEW_TYPEDEFS",
		# 	     "do not add new typedefs\n" . $herecurr);
		# }

# * goes on variable not on type
		# (char*[ const])
		while ($line =~ m{(\($NonptrType(\s*(?:$Modifier\b\s*|\*\s*)+)\))}g) {
			#print "AA<$1>\n";
			my ($ident, $from, $to) = ($1, $2, $2);

			# Should start with a space.
			$to =~ s/^(\S)/ $1/;
			# Should not end with a space.
			$to =~ s/\s+$//;
			# '*'s should not have spaces between.
			while ($to =~ s/\*\s+\*/\*\*/) {
			}

##			print "1: from<$from> to<$to> ident<$ident>\n";
			if ($from ne $to) {
				ERROR("POINTER_LOCATION",
				    "\"(foo$from)\" should be \"(foo$to)\"\n" .  $herecurr);
			}
		}
		while ($line =~ m{(\b$NonptrType(\s*(?:$Modifier\b\s*|\*\s*)+)($Ident))}g) {
			#print "BB<$1>\n";
			my ($match, $from, $to, $ident) = ($1, $2, $2, $3);

			# Should start with a space.
			$to =~ s/^(\S)/ $1/;
			# Should not end with a space.
			$to =~ s/\s+$//;
			# '*'s should not have spaces between.
			while ($to =~ s/\*\s+\*/\*\*/) {
			}
			# Modifiers should have spaces.
			$to =~ s/(\b$Modifier$)/$1 /;

##			print "2: from<$from> to<$to> ident<$ident>\n";
			if ($from ne $to && $ident !~ /^$Modifier$/) {
				ERROR("POINTER_LOCATION",
				    "\"foo${from}bar\" should be \"foo${to}bar\"\n" .  $herecurr);
			}
		}

# function brace can't be on same line, except for #defines of do while,
# or if closed on same line
		if (($line=~/$Type\s*$Ident\(.*\).*\s*{/) and
		    !($line=~/\#\s*define.*do\s\{/) and !($line=~/}/)) {
			ERROR("OPEN_BRACE",
			    "open brace '{' following function declarations go on the next line\n" . $herecurr);
		}

# check number of functions
# and number of lines per function
		if ($line =~ /.*}.*/) {
			$inscope--;
			if ($inscope == 0) {
				$funclines = 0;
			}
		}

		if ($inscope >= 1) {
			$funclines++;
			if ($funclines > $max_func_length) {
				WARN("FUNCTIONS",
				  "More than $max_func_length lines in a function\n");
			}
		}

		if ($line =~ /.*{.*/) {
			$inscope++;
			if ($prevline =~ /^(.(?:typedef\s*)?(?:(?:$Storage|$Inline)\s*)*\s*$Type\s*(?:\b$Ident|\(\*\s*$Ident\))\s*)\(/s && $inscope == 1) {
				$nbfunc++;
				$funclines = 0;
				if ($max_funcs > 0 && $nbfunc > $max_funcs) {
					my $tmpline = $realline - 1;
					$prefix = "$realfile:$tmpline: ";
					ERROR("FUNCTIONS",
					  "More than $max_funcs functions in the file\n");
				}
			}
		}

# open braces for enum, union and struct go on the same line.
		# if ($line =~ /^.\s*{/ &&
		#     $prevline =~ /^.\s*(?:typedef\s+)?(enum|union|struct)(?:\s+$Ident)?\s*$/) {
		# 	ERROR("OPEN_BRACE",
		# 		  "open brace '{' following $1 go on the same line\n" . $hereprev);
		# }
		#
		if ($realfile =~ /\.c$/ &&
		    $line =~ /^.\s*(?:typedef\s+)?(enum|union|struct)(?:\s+$Ident)?\s*.*/ &&
		    $line !~ /;$/) {
					WARN("STRUCT_DEF",
						"$1 definition should be avoided in .c files\n");
		}

		if ($line =~ /^.\s*(?:typedef\s+)?(enum|union|struct)(?:\s+$Ident)?\s*{/) {
			ERROR("OPEN_BRACE",
			    "open brace '{' following $1 go on the next line\n" . $hereprev);
		}

# missing space after union, struct or enum definition
		# if ($line =~ /^.\s*(?:typedef\s+)?(enum|union|struct)(?:\s+$Ident){1,2}[=\{]/) {
		# 	WARN("SPACING",
		# 		 "missing space after $1 definition\n" . $herecurr);
		# }

# Function pointer declarations
# check spacing between type, funcptr, and args
# canonical declaration is "type (*funcptr)(args...)"
		if ($line =~ /^.\s*($Declare)\((\s*)\*(\s*)($Ident)(\s*)\)(\s*)\(/) {
			my $declare = $1;
			my $pre_pointer_space = $2;
			my $post_pointer_space = $3;
			my $funcname = $4;
			my $post_funcname_space = $5;
			my $pre_args_space = $6;

# the $Declare variable will capture all spaces after the type
# so check it for a missing trailing missing space but pointer return types
# don't need a space so don't warn for those.
			my $post_declare_space = "";
			if ($declare =~ /(\s+)$/) {
				$post_declare_space = $1;
				$declare = rtrim($declare);
			}
			if ($declare !~ /\*$/ && $post_declare_space =~ /^$/) {
				WARN("SPACING",
				     "missing space after return type\n" . $herecurr);
				$post_declare_space = " ";
			}

# unnecessary space "type  (*funcptr)(args...)"
# This test is not currently implemented because these declarations are
# equivalent to
#	int  foo(int bar, ...)
# and this is form shouldn't/doesn't generate a checkpatch warning.
#
#			elsif ($declare =~ /\s{2,}$/) {
#				WARN("SPACING",
#				     "Multiple spaces after return type\n" . $herecurr);
#			}

# unnecessary space "type ( *funcptr)(args...)"
			if (defined $pre_pointer_space &&
			    $pre_pointer_space =~ /^\s/) {
				WARN("SPACING",
				     "Unnecessary space after function pointer open parenthesis\n" . $herecurr);
			}

# unnecessary space "type (* funcptr)(args...)"
			if (defined $post_pointer_space &&
			    $post_pointer_space =~ /^\s/) {
				WARN("SPACING",
				     "Unnecessary space before function pointer name\n" . $herecurr);
			}

# unnecessary space "type (*funcptr )(args...)"
			if (defined $post_funcname_space &&
			    $post_funcname_space =~ /^\s/) {
				WARN("SPACING",
				     "Unnecessary space after function pointer name\n" . $herecurr);
			}

# unnecessary space "type (*funcptr) (args...)"
			if (defined $pre_args_space &&
			    $pre_args_space =~ /^\s/) {
				WARN("SPACING",
				     "Unnecessary space before function pointer arguments\n" . $herecurr);
			}
		}

# check for spacing round square brackets; allowed:
#  1. with a type on the left -- int [] a;
#  2. at the beginning of a line for slice initialisers -- [0...10] = 5,
#  3. inside a curly brace -- = { [0...10] = 5 }
		while ($line =~ /(.*?\s)\[/g) {
			my ($where, $prefix) = ($-[1], $1);
			if ($prefix !~ /$Type\s+$/ &&
			    ($where != 0 || $prefix !~ /^.\s+$/) &&
			    $prefix !~ /[{,]\s+$/) {
				ERROR("BRACKET_SPACE",
				    "space prohibited before open square bracket '['\n" . $herecurr);
			}
		}

# check for spaces between functions and their parentheses.
		while ($line =~ /($Ident)\s+\(/g) {
			my $name = $1;
			my $ctx_before = substr($line, 0, $-[1]);
			my $ctx = "$ctx_before$name";

			# Ignore those directives where spaces _are_ permitted.
			if ($name =~ /^(?:
				if|for|while|switch|return|case|
				volatile|__volatile__|
				__attribute__|format|__extension__|
				asm|__asm__)$/x)
			{
			# cpp #define statements have non-optional spaces, ie
			# if there is a space between the name and the open
			# parenthesis it is simply not a parameter group.
			} elsif ($ctx_before =~ /^.\s*\#\s*define\s*$/) {

			# cpp #elif statement condition may start with a (
			} elsif ($ctx =~ /^.\s*\#\s*elif\s*$/) {

			# If this whole things ends with a type its most
			# likely a typedef for a function.
			} elsif ($ctx =~ /$Type$/) {

			} else {
				WARN("SPACING",
				    "space prohibited between function name and open parenthesis '('\n" . $herecurr);
			}
		}

# Check operator spacing.
		if (!($line=~/\#\s*include/)) {
			my $line_fixed = 0;

			my $ops = qr{
				<<=|>>=|<=|>=|==|!=|
				\+=|-=|\*=|\/=|%=|\^=|\|=|&=|
				=>|->|<<|>>|<|>|=|!|~|
				&&|\|\||,|\^|\+\+|--|&|\||\+|-|\*|\/|%|
				\?:|\?|:
			}x;
			my @elements = split(/($ops|;)/, $opline);

##			print("element count: <" . $#elements . ">\n");
##			foreach my $el (@elements) {
##				print("el: <$el>\n");
##			}

			my @fix_elements = ();
			my $off = 0;

			foreach my $el (@elements) {
				push(@fix_elements, substr($rawline, $off, length($el)));
				$off += length($el);
			}

			$off = 0;

			my $blank = copy_spacing($opline);
			my $last_after = -1;

			for (my $n = 0; $n < $#elements; $n += 2) {

				$off += length($elements[$n]);

				# Pick up the preceding and succeeding characters.
				my $ca = substr($opline, 0, $off);
				my $cc = '';
				if (length($opline) >= ($off + length($elements[$n + 1]))) {
					$cc = substr($opline, $off + length($elements[$n + 1]));
				}
				my $cb = "$ca$;$cc";

				my $a = '';
				$a = 'V' if ($elements[$n] ne '');
				$a = 'W' if ($elements[$n] =~ /\s$/);
				$a = 'C' if ($elements[$n] =~ /$;$/);
				$a = 'B' if ($elements[$n] =~ /(\[|\()$/);
				$a = 'O' if ($elements[$n] eq '');
				$a = 'E' if ($ca =~ /^\s*$/);

				my $op = $elements[$n + 1];

				my $c = '';
				if (defined $elements[$n + 2]) {
					$c = 'V' if ($elements[$n + 2] ne '');
					$c = 'W' if ($elements[$n + 2] =~ /^\s/);
					$c = 'C' if ($elements[$n + 2] =~ /^$;/);
					$c = 'B' if ($elements[$n + 2] =~ /^(\)|\]|;)/);
					$c = 'O' if ($elements[$n + 2] eq '');
					$c = 'E' if ($elements[$n + 2] =~ /^\s*\\$/);
				} else {
					$c = 'E';
				}

				my $ctx = "${a}x${c}";

				my $at = "(ctx:$ctx)";

				my $ptr = substr($blank, 0, $off) . "^";
				my $hereptr = "$hereline$ptr\n";

				# Pull out the value of this operator.
				my $op_type = substr($curr_values, $off + 1, 1);

				# Get the full operator variant.
				my $opv = $op . substr($curr_vars, $off, 1);

				# Ignore operators passed as parameters.
				if ($op_type ne 'V' &&
				    $ca =~ /\s$/ && $cc =~ /^\s*[,\)]/) {

#				# Ignore comments
#				} elsif ($op =~ /^$;+$/) {

				# ; should have either the end of line or a space or \ after it
				} elsif ($op eq ';') {
					if ($ctx !~ /.x[WEBC]/ &&
					    $cc !~ /^\\/ && $cc !~ /^;/) {
						ERROR("SPACING",
						    "space required after that '$op' $at\n" . $hereptr);
					}

				# // is a comment
				} elsif ($op eq '//') {

				#   :   when part of a bitfield
				} elsif ($opv eq ':B') {
					# skip the bitfield test for now

				# No spaces for:
				#   ->
				} elsif ($op eq '->') {
					if ($ctx =~ /Wx.|.xW/) {
						if (ERROR("SPACING",
						    "spaces prohibited around that '$op' $at\n" . $hereptr)) {
							if (defined $fix_elements[$n + 2]) {
    								$fix_elements[$n + 2] =~ s/^\s+//;
    							}
						}
					}

				# , must not have a space before and must have a space on the right.
				} elsif ($op eq ',') {
					if ($ctx =~ /Wx./) {
						ERROR("SPACING",
						    "space prohibited before that '$op' $at\n" . $hereptr);
					}
					if ($ctx !~ /.x[WEC]/ && $cc !~ /^}/) {
						ERROR("SPACING",
						    "space required after that '$op' $at\n" . $hereptr);
					}

				# '*' as part of a type definition -- reported already.
				} elsif ($opv eq '*_') {
					#warn "'*' is part of type\n";

				# unary operators should have a space before and
				# none after.  May be left adjacent to another
				# unary operator, or a cast
				} elsif ($op eq '!' || $op eq '~' ||
					 $opv eq '*U' || $opv eq '-U' || $opv eq '+U' ||
					 $opv eq '&U' || $opv eq '&&U') {
					if ($ctx !~ /[WEBC]x./ && $ca !~ /(?:\)|!|~|\*|-|\+|\&|\||\+\+|\-\-|\{)$/) {
						ERROR("SPACING",
						    "space required before that '$op' $at\n" . $hereptr);
					}
					if ($op eq '*' && $cc =~/\s*$Modifier\b/) {
						# A unary '*' may be const

					} elsif ($ctx =~ /.xW/) {
						if (ERROR("SPACING",
						    "space prohibited after that '$op' $at\n" . $hereptr)) {
							if (defined $fix_elements[$n + 2]) {
    								$fix_elements[$n + 2] =~ s/^\s+//;
    							}
						}
					}

				# unary ++ and unary -- are allowed no space on one side.
				} elsif ($op eq '++' or $op eq '--') {
					if ($ctx !~ /[WEOBC]x[^W]/ && $ctx !~ /[^W]x[WOBEC]/) {
						ERROR("SPACING",
						    "space required one side of that '$op' $at\n" . $hereptr);
					}
					if ($ctx =~ /Wx[BE]/ ||
					    ($ctx =~ /Wx./ && $cc =~ /^;/)) {
						ERROR("SPACING",
						    "space prohibited before that '$op' $at\n" . $hereptr);
					}
					if ($ctx =~ /ExW/) {
						if (ERROR("SPACING",
						    "space prohibited after that '$op' $at\n" . $hereptr)) {
							if (defined $fix_elements[$n + 2]) {
    								$fix_elements[$n + 2] =~ s/^\s+//;
    							}
						}
					}

				# << and >> may either have or not have spaces both sides
				} elsif ($op eq '<<' or $op eq '>>' or
					 $op eq '&' or $op eq '^' or $op eq '|' or
					 $op eq '+' or $op eq '-' or
					 $op eq '*' or $op eq '/' or
					 $op eq '%')
				{
					my $force_check = 1;
					if ($force_check) {
						if (defined $fix_elements[$n + 2] && $ctx !~ /[EW]x[EW]/) {
							if (ERROR("SPACING",
							    "spaces preferred around that '$op' $at\n" . $hereptr)) {
								$fix_elements[$n + 2] =~ s/^\s+//;
							}
						} elsif (!defined $fix_elements[$n + 2] && $ctx !~ /Wx[OE]/) {
							ERROR("SPACING",
							    "space preferred before that '$op' $at\n" . $hereptr);
						}
					} elsif ($ctx =~ /Wx[^WCE]|[^WCE]xW/) {
						if (ERROR("SPACING",
						    "need consistent spacing around '$op' $at\n" . $hereptr)) {
							if (defined $fix_elements[$n + 2]) {
    								$fix_elements[$n + 2] =~ s/^\s+//;
    							}
						}
					}

				# A colon needs no spaces before when it is
				# terminating a case value or a label.
				} elsif ($opv eq ':C' || $opv eq ':L') {
					if ($ctx =~ /Wx./) {
						ERROR("SPACING",
						    "space prohibited before that '$op' $at\n" . $hereptr);
					}

				# All the others need spaces both sides.
				} elsif ($ctx !~ /[EWC]x[CWE]/) {
					my $ok = 0;

					# Ignore email addresses <foo@bar>
					if (($op eq '<' &&
					     $cc =~ /^\S+\@\S+>/) ||
					    ($op eq '>' &&
					     $ca =~ /<\S+\@\S+$/))
					{
					    	$ok = 1;
					}

					# for asm volatile statements
					# ignore a colon with another
					# colon immediately before or after
					if (($op eq ':') &&
					    ($ca =~ /:$/ || $cc =~ /^:/)) {
						$ok = 1;
					}

					# messages are ERROR, but ?: are CHK
					if ($ok == 0) {
						my $msg_type = \&ERROR;
						$msg_type = \&ERROR if (($op eq '?:' || $op eq '?' || $op eq ':') && $ctx =~ /VxV/);

						if (&{$msg_type}("SPACING",
						    "spaces required around that '$op' $at\n" . $hereptr)) {
							if (defined $fix_elements[$n + 2]) {
    								$fix_elements[$n + 2] =~ s/^\s+//;
    							}
						}
					}
				}
				$off += length($elements[$n + 1]);
			}
		}

# check for whitespace before a non-naked semicolon
		if ($line =~ /^\+.*\S\s+;\s*$/) {
			WARN("SPACING",
			    "space prohibited before semicolon\n" . $herecurr);
		}

# check for multiple assignments
		if ($line =~ /^.\s*$Lval\s*=\s*$Lval\s*=(?!=)/) {
			CHK("MULTIPLE_ASSIGNMENTS",
			    "multiple assignments should be avoided\n" . $herecurr);
		}

## # check for multiple declarations, allowing for a function declaration
## # continuation.
## 		if ($line =~ /^.\s*$Type\s+$Ident(?:\s*=[^,{]*)?\s*,\s*$Ident.*/ &&
## 		    $line !~ /^.\s*$Type\s+$Ident(?:\s*=[^,{]*)?\s*,\s*$Type\s*$Ident.*/) {
##
## 			# Remove any bracketed sections to ensure we do not
## 			# falsly report the parameters of functions.
## 			my $ln = $line;
## 			while ($ln =~ s/\([^\(\)]*\)//g) {
## 			}
## 			if ($ln =~ /,/) {
## 				WARN("MULTIPLE_DECLARATION",
##				     "declaring multiple variables together should be avoided\n" . $herecurr);
## 			}
## 		}

#need space before brace following if, while, etc
		if (($line =~ /\(.*\)\{/ && $line !~ /\($Type\)\{/) ||
		    $line =~ /do\{/) {
			ERROR("SPACING",
			    "space required before the open brace '{'\n" . $herecurr);
		}

## # check for blank lines before declarations
##		if ($line =~ /^.\t+$Type\s+$Ident(?:\s*=.*)?;/ &&
##		    $prevrawline =~ /^.\s*$/) {
##			WARN("SPACING",
##			     "No blank lines before declarations\n" . $hereprev);
##		}
##

# closing brace should have a space following it when it has anything
# on the line
		if ($line =~ /}(?!(?:,|;|\)))\S/) {
			ERROR("SPACING",
			    "space required after that close brace '}'\n" . $herecurr);;
		}

# check spacing on square brackets
		if ($line =~ /\[\s/ && $line !~ /\[\s*$/) {
			ERROR("SPACING",
			    "space prohibited after that open square bracket '['\n" . $herecurr);
		}
		if ($line =~ /\s\]/) {
			ERROR("SPACING",
			    "space prohibited before that close square bracket ']'\n" . $herecurr);
		}

# check spacing on parentheses
		if ($line =~ /\(\s/ && $line !~ /\(\s*(?:\\)?$/ &&
		    $line !~ /for\s*\(\s+;/) {
			ERROR("SPACING",
			    "space prohibited after that open parenthesis '('\n" . $herecurr);
		}
		if ($line =~ /(\s+)\)/ && $line !~ /^.\s*\)/ &&
		    $line !~ /for\s*\(.*;\s+\)/ &&
		    $line !~ /:\s+\)/) {
			ERROR("SPACING",
			    "space prohibited before that close parenthesis ')'\n" . $herecurr);
		}

# check unnecessary parentheses around addressof/dereference single $Lvals
# ie: &(foo->bar) should be &foo->bar and *(foo->bar) should be *foo->bar

		while ($line =~ /(?:[^&]&\s*|\*)\(\s*($Ident\s*(?:$Member\s*)+)\s*\)/g) {
			my $var = $1;
			CHK("UNNECESSARY_PARENTHESES",
			    "Unnecessary parentheses around $var\n" . $herecurr);
		}

# check for unnecessary parentheses around function pointer uses
# ie: (foo->bar)(); should be foo->bar();
# but not "if (foo->bar) (" to avoid some false positives
		if ($line =~ /(\bif\s*|)(\(\s*$Ident\s*(?:$Member\s*)+\))[ \t]*\(/ && $1 !~ /^if/) {
			my $var = $2;
			CHK("UNNECESSARY_PARENTHESES",
			    "Unnecessary parentheses around function pointer $var\n" . $herecurr);
		}

#goto labels aren't indented, allow a single space however
		if ($line=~/^.\s+[A-Za-z\d_]+:(?![0-9]+)/ and
		   !($line=~/^. [A-Za-z\d_]+:/) and !($line=~/^.\s+default:/)) {
			WARN("INDENTED_LABEL",
			    "labels should not be indented\n" . $herecurr);
		}

# return needs parentheses
		if (defined($stat) && $stat !~ /^.\s*return\s*;\s*$/ && $stat =~ /^.\s*return(\s*).*/s) {
			my $spacing = $1;
			if ($^V && $^V ge 5.10.0 &&
			    $stat !~ /^.\s*return\s*($balanced_parens)\s*;\s*$/) {
				my $value = $1;
				$value = deparenthesize($value);
				if ($value =~ m/^\s*$FuncArg\s*(?:\?)|$/) {
					ERROR("RETURN_PARENTHESES",
					      "parentheses are required on a return statement\n" . $herecurr);
				}
			} elsif ($spacing !~ /\s+/) {
				ERROR("SPACING",
				      "space required before the open parenthesis '('\n" . $herecurr);
			}
		}

# unnecessary return in a void function
# at end-of-function, with the previous line a single leading tab, then return;
# and the line before that not a goto label target like "out:"
		if ($sline =~ /^[ \+]}\s*$/ &&
		    $prevline =~ /^\+\treturn\s*;\s*$/ &&
		    $linenr >= 3 &&
		    $lines[$linenr - 3] =~ /^[ +]/ &&
		    $lines[$linenr - 3] !~ /^[ +]\s*$Ident\s*:/) {
					my $tmpline = $realline - 1;
					$prefix = "$realfile:$tmpline: ";
					WARN("RETURN_VOID",
						"void function return statements are not generally useful\n" . $hereprev);
					}

# if statements using unnecessary parentheses - ie: if ((foo == bar))
		if ($^V && $^V ge 5.10.0 &&
		    $line =~ /\bif\s*((?:\(\s*){2,})/) {
			my $openparens = $1;
			my $count = $openparens =~ tr@\(@\(@;
			my $msg = "";
			if ($line =~ /\bif\s*(?:\(\s*){$count,$count}$LvalOrFunc\s*($Compare)\s*$LvalOrFunc(?:\s*\)){$count,$count}/) {
				my $comp = $4;	#Not $1 because of $LvalOrFunc
				$msg = " - maybe == should be = ?" if ($comp eq "==");
				WARN("UNNECESSARY_PARENTHESES",
				     "Unnecessary parentheses$msg\n" . $herecurr);
			}
		}

# comparisons with a constant or upper case identifier on the left
#	avoid cases like "foo + BAR < baz"
#	only fix matches surrounded by parentheses to avoid incorrect
#	conversions like "FOO < baz() + 5" being "misfixed" to "baz() > FOO + 5"
		if ($^V && $^V ge 5.10.0 &&
		    $line =~ /^\+(.*)\b($Constant|[A-Z_][A-Z0-9_]*)\s*($Compare)\s*($LvalOrFunc)/) {
			my $lead = $1;
			my $const = $2;
			my $comp = $3;
			my $to = $4;
			if ($lead !~ /(?:$Operators|\.)\s*$/ &&
			    $to !~ /^(?:Constant|[A-Z_][A-Z0-9_]*)$/) {
				WARN("CONSTANT_COMPARISON",
				    "Comparisons should place the constant on the right side of the test\n" . $herecurr);
			}
		}

# Return of what appears to be an errno should normally be negative
		if ($sline =~ /\breturn(?:\s*\(+\s*|\s+)(E[A-Z]+)(?:\s*\)+\s*|\s*)[;:,]/) {
			my $name = $1;
			if ($name ne 'EOF' && $name ne 'ERROR') {
				WARN("USE_NEGATIVE_ERRNO",
				     "return of an errno should typically be negative (ie: return -$1)\n" . $herecurr);
			}
		}

# Need a space before open parenthesis after if, while etc
		if ($line =~ /\b(if|while|for|switch)\(/) {
			ERROR("SPACING",
			    "space required before the open parenthesis '('\n" . $herecurr);
		}

# Check for illegal assignment in if conditional -- and check for trailing
# statements after the conditional.
		if ($line =~ /do\s*(?!{)/) {
			($stat, $cond, $line_nr_next, $remain_next, $off_next) =
				ctx_statement_block($linenr, $realcnt, 0)
					if (!defined $stat);
			my ($stat_next) = ctx_statement_block($line_nr_next,
						$remain_next, $off_next);
			$stat_next =~ s/\n./\n /g;
			##print "stat<$stat> stat_next<$stat_next>\n";

			if ($stat_next =~ /^\s*while\b/) {
				# If the statement carries leading newlines,
				# then count those as offsets.
				my ($whitespace) =
					($stat_next =~ /^((?:\s*\n[+-])*\s*)/s);
				my $offset =
					statement_rawlines($whitespace) - 1;

				$suppress_whiletrailers{$line_nr_next +
								$offset} = 1;
			}
		}
		if (!defined $suppress_whiletrailers{$linenr} &&
		    defined($stat) && defined($cond) &&
		    $line =~ /\b(?:if|while|for)\s*\(/ && $line !~ /^.\s*#/) {
			my ($s, $c) = ($stat, $cond);

			if ($c =~ /\bif\s*\(.*[^<>!=]=[^=].*/s) {
				ERROR("ASSIGN_IN_IF",
				      "do not use assignment in if condition\n" . $herecurr);
			}

			# Find out what is on the end of the line after the
			# conditional.
			substr($s, 0, length($c), '');
			$s =~ s/\n.*//g;
			$s =~ s/$;//g; 	# Remove any comments
			if (length($c) && $s !~ /^\s*{?\s*\\*\s*$/ &&
			    $c !~ /}\s*while\s*/)
			{
				# Find out how long the conditional actually is.
				my @newlines = ($c =~ /\n/gs);
				my $cond_lines = 1 + $#newlines;
				my $stat_real = '';

				$stat_real = raw_line($linenr, $cond_lines)
							. "\n" if ($cond_lines);
				if (defined($stat_real) && $cond_lines > 1) {
					$stat_real = "[...]\n$stat_real";
				}

				ERROR("TRAILING_STATEMENTS",
				      "trailing statements should be on next line\n" . $herecurr . $stat_real);
			}
		}

# Check for bitwise tests written as boolean
		if ($line =~ /
			(?:
				(?:\[|\(|\&\&|\|\|)
				\s*0[xX][0-9]+\s*
				(?:\&\&|\|\|)
			|
				(?:\&\&|\|\|)
				\s*0[xX][0-9]+\s*
				(?:\&\&|\|\||\)|\])
			)/x)
		{
			WARN("HEXADECIMAL_BOOLEAN_TEST",
			     "boolean test with hexadecimal, perhaps just 1 \& or \|?\n" . $herecurr);
		}

# if and else should not have general statements after it
		if ($line =~ /^.\s*(?:}\s*)?else\b(.*)/) {
			my $s = $1;
			$s =~ s/$;//g; 	# Remove any comments
			if ($s !~ /^\s*(?:\sif|(?:{|)\s*\\?\s*$)/) {
				ERROR("TRAILING_STATEMENTS",
				      "trailing statements should be on next line\n" . $herecurr);
			}
		}
# if should not continue a brace
		if ($line =~ /}\s*if\b/) {
			ERROR("TRAILING_STATEMENTS",
			      "trailing statements should be on next line (or did you mean 'else if'?)\n" .
				$herecurr);
		}
# case and default should not have general statements after them
		if ($line =~ /^.\s*(?:case\s*.*|default\s*):/g &&
		    $line !~ /\G(?:
			(?:\s*$;*)(?:\s*{)?(?:\s*$;*)(?:\s*\\)?\s*$|
			\s*return\s+
		    )/xg)
		{
			ERROR("TRAILING_STATEMENTS",
			      "trailing statements should be on next line\n" . $herecurr);
		}

		# Check for }<nl>else {, these must be at the same
		# indent level to be relevant to each other.
		# if ($prevline=~/}\s*$/ and $line=~/^.\s*else\s*/ &&
		#     $previndent == $indent) {
		# 	ERROR("ELSE_AFTER_BRACE",
		# 		  "else should follow close brace '}'\n" . $hereprev);
		# }
		if ($line=~/^.\s*}\s*else\s*/ &&
		    $previndent == $indent) {
			ERROR("ELSE_AFTER_BRACE",
			    "else statement following close brace '}' sould be on the next line\n" . $hereprev);
		}

		if ($prevline=~/}\s*$/ and $line=~/^.\s*while\s*/ &&
		    $previndent == $indent) {
			my ($s, $c) = ctx_statement_block($linenr, $realcnt, 0);

			# Find out what is on the end of the line after the
			# conditional.
			substr($s, 0, length($c), '');
			$s =~ s/\n.*//g;

			if ($s =~ /^\s*;/) {
				ERROR("WHILE_AFTER_BRACE",
				    "while should follow close brace '}'\n" . $hereprev);
			}
		}

#Specific variable tests
		while ($line =~ m{($Constant|$Lval)}g) {
			my $var = $1;
#CamelCase
			if ($var !~ /^$Constant$/ &&
			    $var =~ /[A-Z][a-z]|[a-z][A-Z]/ &&
#Ignore Page<foo> variants
			    $var !~ /^(?:Clear|Set|TestClear|TestSet|)Page[A-Z]/ &&
#Ignore SI style variants like nS, mV and dB (ie: max_uV, regulator_min_uA_show)
			    $var !~ /^(?:[a-z_]*?)_?[a-z][A-Z](?:_[a-z_]+)?$/ &&
#Ignore some three character SI units explicitly, like MiB and KHz
			    $var !~ /^(?:[a-z_]*?)_?(?:[KMGT]iB|[KMGT]?Hz)(?:_[a-z_]+)?$/) {
				while ($var =~ m{($Ident)}g) {
					my $word = $1;
					next if ($word !~ /[A-Z][a-z]|[a-z][A-Z]/);
					# TODO
					if (!defined $camelcase{$word}) {
						$camelcase{$word} = 1;
						CHK("CAMELCASE",
						    "Avoid CamelCase: <$word>\n" . $herecurr);
					}
				}
			}
		}

#no spaces allowed after \ in define
		if ($line =~ /\#\s*define.*\\\s+$/) {
			WARN("WHITESPACE_AFTER_LINE_CONTINUATION",
			    "Whitespace after \\ makes next lines useless\n" . $herecurr);
		}

# multi-statement macros should be enclosed in a do while loop, grab the
# first statement and ensure its the whole macro if its not enclosed
# in a known good container
		if ($realfile !~ m@/vmlinux.lds.h$@ &&
		    $line =~ /^.\s*\#\s*define\s*$Ident(\()?/) {
			my $ln = $linenr;
			my $cnt = $realcnt;
			my ($off, $dstat, $dcond, $rest);
			my $ctx = '';
			my $has_flow_statement = 0;
			my $has_arg_concat = 0;
			($dstat, $dcond, $ln, $cnt, $off) =
				ctx_statement_block($linenr, $realcnt, 0);
			$ctx = $dstat;
			#print "dstat<$dstat> dcond<$dcond> cnt<$cnt> off<$off>\n";
			#print "LINE<$lines[$ln-1]> len<" . length($lines[$ln-1]) . "\n";

			$has_flow_statement = 1 if ($ctx =~ /\b(goto|return)\b/);
			$has_arg_concat = 1 if ($ctx =~ /\#\#/ && $ctx !~ /\#\#\s*(?:__VA_ARGS__|args)\b/);

			$dstat =~ s/^.\s*\#\s*define\s+$Ident(?:\([^\)]*\))?\s*//;
			$dstat =~ s/$;//g;
			$dstat =~ s/\\\n.//g;
			$dstat =~ s/^\s*//s;
			$dstat =~ s/\s*$//s;

			# Flatten any parentheses and braces
			while ($dstat =~ s/\([^\(\)]*\)/1/ ||
			       $dstat =~ s/\{[^\{\}]*\}/1/ ||
			       $dstat =~ s/.\[[^\[\]]*\]/1/)
			{
			}

			# Flatten any obvious string concatentation.
			while ($dstat =~ s/($String)\s*$Ident/$1/ ||
			       $dstat =~ s/$Ident\s*($String)/$1/)
			{
			}

			# Make asm volatile uses seem like a generic function
			$dstat =~ s/\b_*asm_*\s+_*volatile_*\b/asm_volatile/g;

			my $exceptions = qr{
				$Declare|
				module_param_named|
				MODULE_PARM_DESC|
				DECLARE_PER_CPU|
				DEFINE_PER_CPU|
				__typeof__\(|
				union|
				struct|
				\.$Ident\s*=\s*|
				^\"|\"$|
				^\[
			}x;
			#print "REST<$rest> dstat<$dstat> ctx<$ctx>\n";
			if ($dstat ne '' &&
			    $dstat !~ /^(?:$Ident|-?$Constant),$/ &&			# 10, // foo(),
			    $dstat !~ /^(?:$Ident|-?$Constant);$/ &&			# foo();
			    $dstat !~ /^[!~-]?(?:$Lval|$Constant)$/ &&		# 10 // foo() // !foo // ~foo // -foo // foo->bar // foo.bar->baz
			    $dstat !~ /^'X'$/ && $dstat !~ /^'XX'$/ &&			# character constants
			    $dstat !~ /$exceptions/ &&
			    $dstat !~ /^\.$Ident\s*=/ &&				# .foo =
			    $dstat !~ /^(?:\#\s*$Ident|\#\s*$Constant)\s*$/ &&		# stringification #foo
			    $dstat !~ /^do\s*$Constant\s*while\s*$Constant;?$/ &&	# do {...} while (...); // do {...} while (...)
			    $dstat !~ /^for\s*$Constant$/ &&				# for (...)
			    $dstat !~ /^for\s*$Constant\s+(?:$Ident|-?$Constant)$/ &&	# for (...) bar()
			    $dstat !~ /^do\s*{/ &&					# do {...
			    $dstat !~ /^\(\{/ &&						# ({...
			    $ctx !~ /^.\s*#\s*define\s+TRACE_(?:SYSTEM|INCLUDE_FILE|INCLUDE_PATH)\b/)
			{
				$ctx =~ s/\n*$//;
				my $herectx = $here . "\n";
				my $cnt = statement_rawlines($ctx);

				for (my $n = 0; $n < $cnt; $n++) {
					$herectx .= raw_line($linenr, $n) . "\n";
				}

				if ($dstat =~ /;/) {
					ERROR("MULTISTATEMENT_MACRO_USE_DO_WHILE",
					      "Macros with multiple statements should be enclosed in a do - while loop\n" . "$herectx");
				} else {
					ERROR("COMPLEX_MACRO",
					      "Macros with complex values should be enclosed in parentheses\n" . "$herectx");
				}
			}

# check for macros with flow control, but without ## concatenation
# ## concatenation is commonly a macro that defines a function so ignore those
			if ($has_flow_statement && !$has_arg_concat) {
				my $herectx = $here . "\n";
				my $cnt = statement_rawlines($ctx);

				for (my $n = 0; $n < $cnt; $n++) {
					$herectx .= raw_line($linenr, $n) . "\n";
				}
				WARN("MACRO_WITH_FLOW_CONTROL",
				     "Macros with flow control statements should be avoided\n" . "$herectx");
			}

# check for line continuations outside of #defines, preprocessor #, and asm

		} else {
			if ($prevline !~ /^..*\\$/ &&
			    $line !~ /^\+\s*\#.*\\$/ &&		# preprocessor
			    $line !~ /^\+.*\b(__asm__|asm)\b.*\\$/ &&	# asm
			    $line =~ /^\+.*\\$/) {
				WARN("LINE_CONTINUATIONS",
				     "Avoid unnecessary line continuations\n" . $herecurr);
			}
		}

# do {} while (0) macro tests:
# single-statement macros do not need to be enclosed in do while (0) loop,
# macro should not end with a semicolon
		if ($^V && $^V ge 5.10.0 &&
		    $realfile !~ m@/vmlinux.lds.h$@ &&
		    $line =~ /^.\s*\#\s*define\s+$Ident(\()?/) {
			my $ln = $linenr;
			my $cnt = $realcnt;
			my ($off, $dstat, $dcond, $rest);
			my $ctx = '';
			($dstat, $dcond, $ln, $cnt, $off) =
				ctx_statement_block($linenr, $realcnt, 0);
			$ctx = $dstat;

			$dstat =~ s/\\\n.//g;
			$dstat =~ s/$;/ /g;

			if ($dstat =~ /^\+\s*#\s*define\s+$Ident\s*${balanced_parens}\s*do\s*{(.*)\s*}\s*while\s*\(\s*0\s*\)\s*([;\s]*)\s*$/) {
				my $stmts = $2;
				my $semis = $3;

				$ctx =~ s/\n*$//;
				my $cnt = statement_rawlines($ctx);
				my $herectx = $here . "\n";

				for (my $n = 0; $n < $cnt; $n++) {
					$herectx .= raw_line($linenr, $n) . "\n";
				}

				if (($stmts =~ tr/;/;/) == 1 &&
				    $stmts !~ /^\s*(if|while|for|switch)\b/) {
					WARN("SINGLE_STATEMENT_DO_WHILE_MACRO",
					     "Single statement macros should not use a do {} while (0) loop\n" . "$herectx");
				}
				if (defined $semis && $semis ne "") {
					WARN("DO_WHILE_MACRO_WITH_TRAILING_SEMICOLON",
					     "do {} while (0) macros should not be semicolon terminated\n" . "$herectx");
				}
			} elsif ($dstat =~ /^\+\s*#\s*define\s+$Ident.*;\s*$/) {
				$ctx =~ s/\n*$//;
				my $cnt = statement_rawlines($ctx);
				my $herectx = $here . "\n";

				for (my $n = 0; $n < $cnt; $n++) {
					$herectx .= raw_line($linenr, $n) . "\n";
				}

				WARN("TRAILING_SEMICOLON",
				     "macros should not use a trailing semicolon\n" . "$herectx");
			}
		}

# check for redundant bracing round if etc
		if ($line =~ /(^.*)\bif\b/ && $1 !~ /else\s*$/) {
			my ($level, $endln, @chunks) =
				ctx_statement_full($linenr, $realcnt, 1);
			#print "chunks<$#chunks> linenr<$linenr> endln<$endln> level<$level>\n";
			#print "APW: <<$chunks[1][0]>><<$chunks[1][1]>>\n";
			if ($#chunks > 0 && $level == 0) {
				my @allowed = ();
				my $allow = 0;
				my $seen = 0;
				my $herectx = $here . "\n";
				my $ln = $linenr - 1;
				for my $chunk (@chunks) {
					my ($cond, $block) = @{$chunk};

					# If the condition carries leading newlines, then count those as offsets.
					my ($whitespace) = ($cond =~ /^((?:\s*\n[+-])*\s*)/s);
					my $offset = statement_rawlines($whitespace) - 1;

					$allowed[$allow] = 0;
					#print "COND<$cond> whitespace<$whitespace> offset<$offset>\n";

					# We have looked at and allowed this specific line.
					$suppress_ifbraces{$ln + $offset} = 1;

					$herectx .= "$rawlines[$ln + $offset]\n[...]\n";
					$ln += statement_rawlines($block) - 1;

					substr($block, 0, length($cond), '');

					$seen++ if ($block =~ /^\s*{/);

					#print "cond<$cond> block<$block> allowed<$allowed[$allow]>\n";
					if (statement_lines($cond) > 1) {
						#print "APW: ALLOWED: cond<$cond>\n";
						$allowed[$allow] = 1;
					}
					if ($block =~/\b(?:if|for|while)\b/) {
						#print "APW: ALLOWED: block<$block>\n";
						$allowed[$allow] = 1;
					}
					if (statement_block_size($block) > 1) {
						#print "APW: ALLOWED: lines block<$block>\n";
						$allowed[$allow] = 1;
					}
					$allow++;
				}
				if ($seen) {
					my $sum_allowed = 0;
					foreach (@allowed) {
						$sum_allowed += $_;
					}
					# TODO: Make this chech work: Detect open brace on next line
					if ($sum_allowed == 0) {
						WARN("BRACES",
						     "braces {} are not necessary for any arm of this statement\n" . $herectx);
					} elsif ($sum_allowed != $allow &&
						 $seen != $allow) {
						CHK("BRACES",
						    "braces {} should be used on all arms of this statement\n" . $herectx);
					}
				}
			}
		}
		if (!defined $suppress_ifbraces{$linenr - 1} &&
					$line =~ /\b(if|while|for|else)\b/) {
			my $allowed = 0;

			# Check the pre-context.
			if (substr($line, 0, $-[0]) =~ /(\}\s*)$/) {
				#print "APW: ALLOWED: pre<$1>\n";
				$allowed = 1;
			}

			my ($level, $endln, @chunks) =
				ctx_statement_full($linenr, $realcnt, $-[0]);

			# Check the condition.
			my ($cond, $block) = @{$chunks[0]};
			#print "CHECKING<$linenr> cond<$cond> block<$block>\n";
			if (defined $cond) {
				substr($block, 0, length($cond), '');
			}
			if (statement_lines($cond) > 1) {
				#print "APW: ALLOWED: cond<$cond>\n";
				$allowed = 1;
			}
			if ($block =~/\b(?:if|for|while)\b/) {
				#print "APW: ALLOWED: block<$block>\n";
				$allowed = 1;
			}
			if (statement_block_size($block) > 1) {
				#print "APW: ALLOWED: lines block<$block>\n";
				$allowed = 1;
			}
			# Check the post-context.
			if (defined $chunks[1]) {
				my ($cond, $block) = @{$chunks[1]};
				if (defined $cond) {
					substr($block, 0, length($cond), '');
				}
				if ($block =~ /^\s*\{/) {
					#print "APW: ALLOWED: chunk-1 block<$block>\n";
					$allowed = 1;
				}
			}
			if ($level == 0 && $block =~ /^\s*\{/ && !$allowed) {
				my $herectx = $here . "\n";
				my $cnt = statement_rawlines($block);

				for (my $n = 0; $n < $cnt; $n++) {
					$herectx .= raw_line($linenr, $n) . "\n";
				}

				WARN("BRACES",
				     "braces {} are not necessary for single statement blocks\n" . $herectx);
			}
		}

# check for unnecessary blank lines around braces
		if (($line =~ /^.\s*}\s*$/ && $prevrawline =~ /^.\s*$/)) {
			CHK("BRACES",
			    "Blank lines aren't necessary before a close brace '}'\n" . $hereprev);
		}
		if (($rawline =~ /^.\s*$/ && $prevline =~ /^..*{\s*$/)) {
			CHK("BRACES",
			    "Blank lines aren't necessary after an open brace '{'\n" . $hereprev);
		}

# no volatiles please
		my $asm_volatile = qr{\b(__asm__|asm)\s+(__volatile__|volatile)\b};
		if ($line =~ /\bvolatile\b/ && $line !~ /$asm_volatile/) {
			WARN("VOLATILE",
			     "Use of volatile is usually wrong: see Documentation/volatile-considered-harmful.txt\n" . $herecurr);
		}

# Check for user-visible strings broken across lines, which breaks the ability
# to grep for the string.  Make exceptions when the previous string ends in a
# newline (multiple lines in one string constant) or '\t', '\r', ';', or '{'
# (common in inline assembly) or is a octal \123 or hexadecimal \xaf value
		if ($line =~ /^\+\s*$String/ &&
		    $prevline =~ /"\s*$/ &&
		    $prevrawline !~ /(?:\\(?:[ntr]|[0-7]{1,3}|x[0-9a-fA-F]{1,2})|;\s*|\{\s*)"\s*$/) {
			WARN("SPLIT_STRING",
			    "quoted string split across lines\n" . $hereprev);
		}

# check for missing a space in a string concatenation
		if ($prevrawline =~ /[^\\]\w"$/ && $rawline =~ /^\+[\t ]+"\w/) {
			WARN('MISSING_SPACE',
			     "break quoted strings at a space character\n" . $hereprev);
		}

# check for spaces before a quoted newline
		if ($rawline =~ /^.*\".*\s\\n/) {
			WARN("QUOTED_WHITESPACE_BEFORE_NEWLINE",
			    "unnecessary whitespace before a quoted newline\n" . $herecurr);
		}

# concatenated string without spaces between elements
		if ($line =~ /$String[A-Z_]/ || $line =~ /[A-Za-z0-9_]$String/) {
			CHK("CONCATENATED_STRING",
			    "Concatenated strings should use spaces between elements\n" . $herecurr);
		}

# uncoalesced string fragments
		if ($line =~ /$String\s*"/) {
			WARN("STRING_FRAGMENTS",
			     "Consecutive strings are generally better as a single string\n" . $herecurr);
		}

# check for %L{u,d,i} and 0x%[udi] in strings
		my $string;
		while ($line =~ /(?:^|")([X\t]*)(?:"|$)/g) {
			$string = substr($rawline, $-[1], $+[1] - $-[1]);
			$string =~ s/%%/__/g;
			if ($string =~ /(?<!%)%[\*\d\.\$]*L[udi]/) {
				WARN("PRINTF_L",
				     "\%Ld/%Lu are not-standard C, use %lld/%llu\n" . $herecurr);
				last;
			}
			if ($string =~ /0x%[\*\d\.\$\Llzth]*[udi]/) {
				ERROR("PRINTF_0xDECIMAL",
				      "Prefixing 0x with decimal output is defective\n" . $herecurr);
			}
		}

# check for line continuations in quoted strings with odd counts of "
		if ($rawline =~ /\\$/ && $rawline =~ tr/"/"/ % 2) {
			WARN("LINE_CONTINUATIONS",
			     "Avoid line continuations in quoted strings\n" . $herecurr);
		}

# warn about #if 0
		if ($line =~ /^.\s*\#\s*if\s+0\b/) {
			CHK("REDUNDANT_CODE",
			    "if this code is redundant consider removing it\n" .
				$herecurr);
		}

# check for needless "if (<foo>) fn(<foo>)" uses
		if ($prevline =~ /\bif\s*\(\s*($Lval)\s*\)/) {
			my $tested = quotemeta($1);
			my $expr = '\s*\(\s*' . $tested . '\s*\)\s*;';
			if ($line =~ /\b(kfree|usb_free_urb|debugfs_remove(?:_recursive)?|(?:kmem_cache|mempool|dma_pool)_destroy)$expr/) {
				my $func = $1;
				WARN('NEEDLESS_IF',
				    "$func(NULL) is safe and this check is probably not required\n" . $hereprev);
			}
		}

# check for mask then right shift without a parentheses
		if ($^V && $^V ge 5.10.0 &&
		    $line =~ /$LvalOrFunc\s*\&\s*($LvalOrFunc)\s*>>/ &&
		    $4 !~ /^\&/) { # $LvalOrFunc may be &foo, ignore if so
			WARN("MASK_THEN_SHIFT",
			     "Possible precedence defect with mask then right shift - may need parentheses\n" . $herecurr);
		}

# check for pointer comparisons to NULL
		if ($^V && $^V ge 5.10.0) {
			while ($line =~ /\b$LvalOrFunc\s*(==|\!=)\s*NULL\b/g) {
				my $val = $1;
				my $equal = "!";
				$equal = "" if ($4 eq "!=");
				CHK("COMPARISON_TO_NULL",
				    "Comparison to NULL could be written \"${equal}${val}\"\n" . $herecurr);
			}
		}

# warn about #ifdefs in C files
#		if ($line =~ /^.\s*\#\s*if(|n)def/ && ($realfile =~ /\.c$/)) {
#			print "#ifdef in C files should be avoided\n";
#			print "$herecurr";
#			$clean = 0;
#		}

# warn about spacing in #ifdefs
		if ($line =~ /^.\s*\#\s*(ifdef|ifndef|elif)\s\s+/) {
			ERROR("SPACING",
			    "exactly one space required after that #$1\n" . $herecurr);
		}

# check of hardware specific defines
		if ($line =~ m@^.\s*\#\s*if.*\b(__i386__|__powerpc64__|__sun__|__s390x__)\b@ && $realfile !~ m@include/asm-@) {
			CHK("ARCH_DEFINES",
			    "architecture specific defines should be avoided\n" .  $herecurr);
		}

# Check that the storage class is at the beginning of a declaration
		if ($line =~ /\b$Storage\b/ && $line !~ /^.\s*$Storage\b/) {
			WARN("STORAGE_CLASS",
			     "storage class should be at the beginning of the declaration\n" . $herecurr)
		}

# check the location of the inline attribute, that it is between
# storage class and type.
		if ($line =~ /\b$Type\s+$Inline\b/ ||
		    $line =~ /\b$Inline\s+$Storage\b/) {
			ERROR("INLINE_LOCATION",
			      "inline keyword should sit between storage class and type\n" . $herecurr);
		}

# Check for __inline__ and __inline, prefer inline
		if ($realfile !~ m@\binclude/uapi/@ &&
		    $line =~ /\b(__inline__|__inline)\b/) {
			WARN("INLINE",
			    "plain inline is preferred over $1\n" . $herecurr);
		}

# Check for __attribute__ packed, prefer __packed
		if ($realfile !~ m@\binclude/uapi/@ &&
		    $line =~ /\b__attribute__\s*\(\s*\(.*\bpacked\b/) {
			WARN("PREFER_PACKED",
			     "__packed is preferred over __attribute__((packed))\n" . $herecurr);
		}

# Check for __attribute__ aligned, prefer __aligned
		if ($realfile !~ m@\binclude/uapi/@ &&
		    $line =~ /\b__attribute__\s*\(\s*\(.*aligned/) {
			WARN("PREFER_ALIGNED",
			     "__aligned(size) is preferred over __attribute__((aligned(size)))\n" . $herecurr);
		}

# Check for __attribute__ format(printf, prefer __printf
		if ($realfile !~ m@\binclude/uapi/@ &&
		    $line =~ /\b__attribute__\s*\(\s*\(\s*format\s*\(\s*printf/) {
			WARN("PREFER_PRINTF",
			    "__printf(string-index, first-to-check) is preferred over __attribute__((format(printf, string-index, first-to-check)))\n" . $herecurr);
		}

# Check for __attribute__ format(scanf, prefer __scanf
		if ($realfile !~ m@\binclude/uapi/@ &&
		    $line =~ /\b__attribute__\s*\(\s*\(\s*format\s*\(\s*scanf\b/) {
			WARN("PREFER_SCANF",
			    "__scanf(string-index, first-to-check) is preferred over __attribute__((format(scanf, string-index, first-to-check)))\n" . $herecurr);
		}

# Check for __attribute__ weak, or __weak declarations (may have link issues)
		if ($^V && $^V ge 5.10.0 &&
		    $line =~ /(?:$Declare|$DeclareMisordered)\s*$Ident\s*$balanced_parens\s*(?:$Attribute)?\s*;/ &&
		    ($line =~ /\b__attribute__\s*\(\s*\(.*\bweak\b/ ||
		     $line =~ /\b__weak\b/)) {
			ERROR("WEAK_DECLARATION",
			      "Using weak declarations can have unintended link defects\n" . $herecurr);
		}

# check for cast of C90 native int or longer types constants
		if ($line =~ /(\(\s*$C90_int_types\s*\)\s*)($Constant)\b/) {
			WARN("TYPECAST_INT_CONSTANT",
			    "Unnecessary typecast of c90 int constant\n" . $herecurr);
		}

# check for sizeof(&)
		if ($line =~ /\bsizeof\s*\(\s*\&/) {
			WARN("SIZEOF_ADDRESS",
			     "sizeof(& should be avoided\n" . $herecurr);
		}

# check for sizeof without parenthesis
		if ($line =~ /\bsizeof\s+((?:\*\s*|)$Lval|$Type(?:\s+$Lval|))/) {
			WARN("SIZEOF_PARENTHESIS",
			    "sizeof $1 should be sizeof($1)\n" . $herecurr);
		}

# Check for misused memsets
		if ($^V && $^V ge 5.10.0 &&
		    defined $stat &&
		    $stat =~ /^\+(?:.*?)\bmemset\s*\(\s*$FuncArg\s*,\s*$FuncArg\s*\,\s*$FuncArg\s*\)/) {

			my $ms_addr = $2;
			my $ms_val = $7;
			my $ms_size = $12;

			if ($ms_size =~ /^(0x|)0$/i) {
				ERROR("MEMSET",
				      "memset to 0's uses 0 as the 2nd argument, not the 3rd\n" . "$here\n$stat\n");
			} elsif ($ms_size =~ /^(0x|)1$/i) {
				WARN("MEMSET",
				     "single byte memset is suspicious. Swapped 2nd/3rd argument?\n" . "$here\n$stat\n");
			}
		}

# check for new externs in .h files.
		if ($realfile =~ /\.h$/ &&
		    $line =~ /^\+\s*(extern\s+)$Type\s*$Ident\s*\(/s) {
			CHK("AVOID_EXTERNS",
			    "extern prototypes should be avoided in .h files\n" . $herecurr);
		}

# check for new externs in .c files.
		if ($realfile =~ /\.c$/ && defined $stat &&
		    ($stat =~ /^.\s*(?:extern\s+)?$Type\s+($Ident)(\s*)\(/s ||
		    $stat =~ /^.\s*(?:extern\s+)?$Type\s+(?:\**)?($Ident)(\s*)\(/))
		{
			my $function_name = $1;
			my $paren_space = $2;

			my $s = $stat;
			if (defined $cond) {
				substr($s, 0, length($cond), '');
			}
			if ($s =~ /^\s*;/ &&
			    $function_name ne 'uninitialized_var')
			{
				WARN("AVOID_EXTERNS",
				     "externs should be avoided in .c files\n" .  $herecurr);
			}

			if ($paren_space =~ /\n/) {
				WARN("FUNCTION_ARGUMENTS",
				     "arguments for function declarations should follow identifier\n" . $herecurr);
			}

		} elsif ($realfile =~ /\.c$/ && defined $stat &&
		    $stat =~ /^.\s*extern\s+/)
		{
			WARN("AVOID_EXTERNS",
			     "externs should be avoided in .c files\n" .  $herecurr);
		}

		# check for new typedefs in source files
		if ($realfile =~ /\.c$/ &&
		    $line =~ /\btypedef\s/ &&
		    $line !~ /\btypedef\s+$Type\s*\(\s*\*?$Ident\s*\)\s*\(/ &&
		    $line !~ /\btypedef\s+$Type\s+$Ident\s*\(/ &&
		    $line !~ /\b$typeTypedefs\b/ &&
		    $line !~ /\b__bitwise(?:__|)\b/) {
			WARN("NEW_TYPEDEFS",
			     "typedefs should be avoided in .c files\n" . $herecurr);
		}

# check for multiple semicolons
		if ($line =~ /;\s*;\s*$/) {
			WARN("ONE_SEMICOLON",
			    "Statements terminations use 1 semicolon\n" . $herecurr);
		}

# check for case / default statements not preceded by break/fallthrough/switch
		if ($line =~ /^.\s*(?:case\s+(?:$Ident|$Constant)\s*|default):/) {
			my $has_break = 0;
			my $has_statement = 0;
			my $count = 0;
			my $prevline = $linenr;
			while ($prevline > 1 && !$has_break) {
				$prevline--;
				my $rline = $rawlines[$prevline - 1];
				my $fline = $lines[$prevline - 1];
				last if ($fline =~ /^\@\@/);
				next if ($fline =~ /^\-/);
				next if ($fline =~ /^.(?:\s*(?:case\s+(?:$Ident|$Constant)[\s$;]*|default):[\s$;]*)*$/);
				$has_break = 1 if ($rline =~ /fall[\s_-]*(through|thru)/i);
				next if ($fline =~ /^.[\s$;]*$/);
				$has_statement = 1;
				$count++;
				$has_break = 1 if ($fline =~ /\bswitch\b|\b(?:break\s*;[\s$;]*$|return\b|goto\b|continue\b)/);
			}
			if (!$has_break && $has_statement) {
				WARN("MISSING_BREAK",
				     "Possible switch case/default not preceeded by break or fallthrough comment\n" . $herecurr);
			}
		}

# check for switch/default statements without a break;
		if ($^V && $^V ge 5.10.0 &&
		    defined $stat &&
		    $stat =~ /^\+[$;\s]*(?:case[$;\s]+\w+[$;\s]*:[$;\s]*|)*[$;\s]*\bdefault[$;\s]*:[$;\s]*;/g) {
			my $ctx = '';
			my $herectx = $here . "\n";
			my $cnt = statement_rawlines($stat);
			for (my $n = 0; $n < $cnt; $n++) {
				$herectx .= raw_line($linenr, $n) . "\n";
			}
			WARN("DEFAULT_NO_BREAK",
			     "switch default: should use break\n" . $herectx);
		}

# check for comparisons against true and false
		if ($line =~ /\+\s*(.*?)\b(true|false|$Lval)\s*(==|\!=)\s*(true|false|$Lval)\b(.*)$/i) {
			my $lead = $1;
			my $arg = $2;
			my $test = $3;
			my $otype = $4;
			my $trail = $5;
			my $op = "!";

			($arg, $otype) = ($otype, $arg) if ($arg =~ /^(?:true|false)$/i);

			my $type = lc($otype);
			if ($type =~ /^(?:true|false)$/) {
				if (("$test" eq "==" && "$type" eq "true") ||
				    ("$test" eq "!=" && "$type" eq "false")) {
					$op = "";
				}

				CHK("BOOL_COMPARISON",
				    "Using comparison to $otype is error prone\n" . $herecurr);

## maybe suggesting a correct construct would better
##				    "Using comparison to $otype is error prone.  Perhaps use '${lead}${op}${arg}${trail}'\n" . $herecurr);

			}
		}
	}

	# If we have no input at all, then there is nothing to report on
	# so just keep quiet.
	if ($#rawlines == -1) {
		exit(0);
	}

	print report_dump();
	if (!($clean == 1 && $verbose == 0)) {
		print "total: $cnt_error errors, $cnt_warn warnings, " .
			"$cnt_lines lines checked\n";
	}

	if ($verbose == 1) {
		print "\n";
		if ($clean == 1) {
			print "$filename has no obvious style problems.\n";
		} else {
			print "$filename has style problems, please review.\n";
		}
	}
	return $clean;
}
