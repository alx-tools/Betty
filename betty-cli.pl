#!/usr/bin/env perl

use v5.18;

use strict;
use warnings;
use diagnostics;

use feature 'say';

use Term::ANSIColor qw(:constants);
local $Term::ANSIColor::AUTORESET = 1;
use Getopt::Long qw(:config no_auto_abbrev);

## Hash containing the different commands that can be executed,
## and their options.
##
## 'name' => {
##   desc => 'String',
##   alias => ['String', ...],,
##   handler => sub()
##   arg => 'String',
##   options => {
##     'name' => {
##       desc => 'String',
##       alias => 'String',
##       type => 'String',
##       value => ANY
##     }
##   }
## }
my $options = {
	'help' => {
		desc => 'Shows a help message',
		alias => 'h',
		handler => \&help
	},
	'style' => {
		desc => 'Checks coding style',
		alias => 's',
		handler => \&betty_style,
		arg => 'file...',
		options => {
			'brief' => {
				desc => 'Brief mode. One line per error. No summary',
				alias => 'b',
				type => 'Switch',
				value => 0
			},
			'color' => {
				desc => 'Use colors when output is STDOUT',
				type => 'Switch',
				value => 1
			},
			'context' => {
				desc => [
					'For each error, print the line and',
					'point out the error',
					'Not compatible with --brief'
				],
				alias => 'c',
				type => 'Switch',
				value => 0
			},
			'assign-in-cond' => {
				desc => 'Check for assignment in condition',
				type => 'Switch',
				value => 1
			},
			'avoid-externs' => {
				desc => 'Check for externs in C source files',
				type => 'Switch',
				value => 1
			},
			'blank-before-decl' => {
				desc => 'Check for blank line before declaration',
				type => 'Switch',
				value => 1
			},
			'blank-line-brace' => {
				desc => 'Check for unnecessary blank line around braces',
				type => 'Switch',
				value => 1
			},
			'block-comment-leading' => {
				desc => 'Check for block comment leading line style',
				type => 'Switch',
				value => 1
			},
			'block-comment-subsequent' => {
				desc => 'Check for block comment subsequent line style',
				type => 'Switch',
				value => 1
			},
			'block-comment-trailing' => {
				desc => 'Check for block comment trailing line style',
				type => 'Switch',
				value => 1
			},
			'bracket-space' => {
				desc => 'Check for prohibited space before open square bracket',
				type => 'Switch',
				value => 1
			},
			'bracket-space-in' => {
				desc => 'Check for prohibited space inside square brackets',
				type => 'Switch',
				value => 1
			},
			'c99-comments' => {
				desc => 'Check for usage of C99 comments',
				type => 'Switch',
				value => 1
			},
			'camelcase' => {
				desc => 'Check for camelcase variable naming',
				type => 'Switch',
				value => 1
			},
			'cast-int-const' => {
				desc => 'Check for unnecessary cast of C90 int constant',
				type => 'Switch',
				value => 1
			},
			'close-brace-space' => {
				desc => 'Check for missed space after closing brace',
				type => 'Switch',
				value => 1
			},
			'code-indent' => {
				desc => 'Check if spaces are used instead of tabs',
				type => 'Switch',
				value => 1
			},
			'complex-macro' => {
				desc => 'Check for complex macro not enclosed in parentheses',
				type => 'Switch',
				value => 1
			}
		}
	},
	'doc' => {
		desc => 'Checks documentation style',
		alias => 'd',
		arg => 'file...',
		options => {
			'test' => {
				desc => 'This is a test option',
				value => 0,
				alias => 't'
			}
		}
	}
};

##
## help()
##
## Params:
##  ? $exitcode: Exit status after help subroutine is done
##
## Returns: None
##
## Prints a help message and exit de program
##
sub help {
	my $exitcode = (@_) or 0;

	for my $key (sort keys %{$options}) {
		my $cmd = $options->{$key};
		print "betty $key ";

		if (exists($cmd->{options})) {
			print CYAN "[options...] ";
		}
		if (exists($cmd->{arg})) {
			print YELLOW "<", $cmd->{arg}, ">";
		}
		print "\n";

		# Print command description
		say "  ", $cmd->{desc};

		# Print command alias
		if (exists($cmd->{alias})) {
			say BRIGHT_BLACK "  alias: ", $cmd->{alias};
		}

		# Print command options
		if (exists($cmd->{options})) {
			for my $opt_key (sort keys %{$cmd->{options}}) {
				my $option = $cmd->{options}->{$opt_key};

				my $real_option = "--";
				if (exists($option->{type}) &&
				    $option->{type} eq 'Switch' &&
				    $option->{value} == 1) {
					$real_option .= "no";
				}
				$real_option = "${real_option}${opt_key}";

				print "    ", CYAN "$real_option ";
				if (exists($option->{type}) &&
				    $option->{type} ne 'Switch') {
					print CYAN "(", $option->{type}, ") ";
					if (exists($option->{value}) &&
						defined($option->{value})) {
						print GREEN "(Default: ", $option->{value}, ")";
					}
				}
				print "\n";

				if (ref($option->{desc}) eq 'ARRAY') {
					my @desc_lines = @{$option->{desc}};
					for my $desc (@desc_lines) {
						say "      ", $desc;
					}
				} else {
					say "      ", $option->{desc};
				}

				if (exists($option->{alias})) {
					my $alias = $option->{alias};
					my $real_alias = "-";
					if (!exists($option->{type}) &&
					    $option->{value} == 1) {
						$real_alias = "--no";
					}
					$real_alias = "$real_alias$alias";
					say BRIGHT_BLACK "      alias: $real_alias";
				}
			}
		}
		print "\n";
	}
	exit($exitcode);
}

help(0) if ($#ARGV == -1);

# Analyse ARGV to determine command
my $cmd = shift @ARGV;
my $found = 0;
for my $key (sort keys %{$options}) {
	last if ($found == 1);
	$found = 1 if ($key eq $cmd);

	if (exists($options->{$key}{alias}) &&
	    $options->{$key}{alias} eq $cmd) {
		$cmd = $key;
		$found = 1;
	}
}
if ($found == 0) {
	say RED "`$cmd` is not a valid command.";
	say RED "Please run `betty help` for the list of available commands";
	exit(1);
}

# Prepare to call GetOptions()
my %get_opts = ();
my $cmd_hash = $options->{$cmd};
if (exists($cmd_hash->{options})) {
	my $options = $cmd_hash->{options};
	for my $opt_key (sort keys %{$options}) {
		my $option = $options->{$opt_key};

		my @elements = ();
		push @elements, $opt_key;

		if (exists($option->{alias})) {
			my $alias = $option->{alias};
			push @elements, $alias;
		}
		my $final = join('|', @elements);

		if (!exists($option->{type})) {
			$final = "$final!";
		} else {
			$final = "$final=s" if ($option->{type} eq 'String');
			$final = "$final=i" if ($option->{type} eq 'Integer');
			$final = "$final+" if ($option->{type} eq 'Counter');
			$final = "$final!" if ($option->{type} eq 'Switch');
		}

		$get_opts{$final} = \$option->{value};
	}
}

# Parse options
GetOptions(%get_opts) or help(1);

################################################################################
# REGEX DECLARATIONS / INITIALIZATION
################################################################################
our $Ident = qr{
	[A-Za-z_][A-Za-z\d_]*
	(?:\s*\#\#\s*[A-Za-z_][A-Za-z\d_]*)*
}x;
our $Storage = qr{extern|static|asmlinkage};
our $Sparse = qr{
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
our $Attribute = qr{
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
our $Inline = qr{inline|__always_inline|noinline|__inline|__inline__};
our $Member = qr{->$Ident|\.$Ident|\[[^]]*\]};
our $Lval = qr{$Ident(?:$Member)*};

our $Int_type = qr{(?i)llu|ull|ll|lu|ul|l|u};
our $Binary = qr{(?i)0b[01]+$Int_type?};
our $Hex = qr{(?i)0x[0-9a-f]+$Int_type?};
our $Int = qr{[0-9]+$Int_type?};
our $Octal = qr{0[0-7]+$Int_type?};
our $String = qr{"[X\t]*"};
our $Float_hex = qr{(?i)0x[0-9a-f]+p-?[0-9]+[fl]?};
our $Float_dec = qr{(?i)(?:[0-9]+\.[0-9]*|[0-9]*\.[0-9]+)(?:e-?[0-9]+)?[fl]?};
our $Float_int = qr{(?i)[0-9]+e-?[0-9]+[fl]?};
our $Float = qr{$Float_hex|$Float_dec|$Float_int};
our $Constant = qr{$Float|$Binary|$Octal|$Hex|$Int};
our $Assignment = qr{\*\=|/=|%=|\+=|-=|<<=|>>=|&=|\^=|\|=|=};
our $Compare = qr{<=|>=|==|!=|<|(?<!-)>};
our $Arithmetic = qr{\+|-|\*|\/|%};
our $Operators = qr{
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

our $NON_ASCII_UTF8 = qr{
	[\xC2-\xDF][\x80-\xBF]               # non-overlong 2-byte
	|  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
	| [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
	|  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
	|  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
	| [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
	|  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
}x;

our $UTF8 = qr{
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

sub build_types {
	my $mods = "(?x:  \n" . join("|\n  ", (@modifierList, @modifierListFile)) . "\n)";
	my $all = "(?x:  \n" . join("|\n  ", (@typeList, @typeListFile)) . "\n)";
	my $Misordered = "(?x:  \n" . join("|\n  ", @typeListMisordered) . "\n)";
	my $allWithAttr = "(?x:  \n" . join("|\n  ", @typeListWithAttr) . "\n)";
	$Modifier = qr{(?:$Attribute|$Sparse|$mods)};
	$BasicType = qr{
		(?:$typeTypedefs\b)|
		(?:${all}\b)
	}x;
	$NonptrType = qr{
		(?:$Modifier\s+|const\s+)*
		(?:
			(?:typeof|__typeof__)\s*\([^\)]*\)|
			(?:$typeTypedefs\b)|
			(?:${all}\b)
		)
		(?:\s+$Modifier|\s+const)*
	}x;
	$NonptrTypeMisordered = qr{
		(?:$Modifier\s+|const\s+)*
		(?:
			(?:${Misordered}\b)
		)
		(?:\s+$Modifier|\s+const)*
	}x;
	$NonptrTypeWithAttr = qr{
		(?:$Modifier\s+|const\s+)*
		(?:
			(?:typeof|__typeof__)\s*\([^\)]*\)|
			(?:$typeTypedefs\b)|
			(?:${allWithAttr}\b)
		)
		(?:\s+$Modifier|\s+const)*
	}x;
	$Type = qr{
		$NonptrType
		(?:(?:\s|\*|\[\])+\s*const|(?:\s|\*\s*(?:const\s*)?|\[\])+|(?:\s*\[\s*\])+)?
		(?:\s+$Inline|\s+$Modifier)*
	}x;
	$TypeMisordered = qr{
		$NonptrTypeMisordered
		(?:(?:\s|\*|\[\])+\s*const|(?:\s|\*\s*(?:const\s*)?|\[\])+|(?:\s*\[\s*\])+)?
		(?:\s+$Inline|\s+$Modifier)*
	}x;
	$Declare = qr{(?:$Storage\s+(?:$Inline\s+)?)?$Type};
	$DeclareMisordered = qr{(?:$Storage\s+(?:$Inline\s+)?)?$TypeMisordered};
}
build_types();

our $Typecast = qr{\s*(\(\s*$NonptrType\s*\)){0,1}\s*};

# Using $balanced_parens, $LvalOrFunc, or $FuncArg
# requires at least perl version v5.10.0
# Any use must be runtime checked with $^V
our $balanced_parens = qr/(\((?:[^\(\)]++|(?-1))*\))/;
our $LvalOrFunc = qr{((?:[\&\*]\s*)?$Lval)\s*($balanced_parens{0,1})\s*};
our $FuncArg = qr{$Typecast{0,1}($LvalOrFunc|$Constant|$String)};

our $declaration_macros = qr{(?x:
	(?:$Storage\s+)?(?:[A-Z_][A-Z0-9]*_){0,2}(?:DEFINE|DECLARE)(?:_[A-Z0-9]+){1,6}\s*\(|
	(?:$Storage\s+)?LIST_HEAD\s*\(|
	(?:$Storage\s+)?${Type}\s+uninitialized_var\s*\(
)};

################################################################################
################################################################################
################################## BETTY STYLE #################################
################################################################################
################################################################################

my $style_opt = $options->{'style'}->{options};

##
## s_option()
##
## Params:
##   $option_name: Name of the option to retrieve the value of
##
## Returns: Option value
##
sub s_option {
	my ($option_name) = @_;

	return $style_opt->{$option_name}->{value};
}

my @lines = ();

my $total_errs = 0;
my $total_lines = 0;
my $total_files = 0;

##
## betty_style()
##
## Params:
##
## Returns: None
##
## Runs betty-style
##
sub betty_style {

	my $exit = 0;

	foreach my $filename (@ARGV) {
		my $FILE;

		if (! -f $filename) {
			print STDERR "$filename: No such file\n";
			next;
		}
		if ($filename !~ /\.(h|c)$/) {
			print STDERR "$filename: Not a C source file\n";
			next;
		}
		next if (!open($FILE, '<', $filename));

		while (<$FILE>) {
			chomp;
			push(@lines, $_);
		}
		close($FILE);

		$total_files++;
		if (!process_style($filename)) {
			$exit = 1;
		}
		@lines = ();
		build_types();
	}

	if ($exit != 0 && !s_option('brief')) {
		my $errs_plural = "";
		$errs_plural = "s" if ($total_errs > 1);
		my $line_plural = "";
		$line_plural = "s" if ($total_lines > 1);
		my $file_plural = "";
		$file_plural = "s" if ($total_files > 1);

		print "Total: ";
		print "$total_errs error$errs_plural, ";
		print "$total_lines line$line_plural checked in $total_files file$file_plural\n";
	}
}

our $prefix = '';
sub WARN {
	my ($type, $msg, $line, $region, $r_begin, $r_end) = @_;

	$msg = (split('\n', $msg))[0];

	my $output = '';
	my $line_no = (split(":", $prefix))[1]; # Line number only
	$line =~ s/\t/        /g if (defined $line);
	$r_begin = index($line, $region) if (!defined $r_begin && defined $line && defined $region);
	$r_end = $r_begin + length($region) if (!defined $r_end && defined $line && defined $region);

	$output .= RED if (-t STDOUT && s_option('color'));
	$output .= "line " if (!s_option('brief'));
	$output .= "$line_no";
	$output .= "[$r_begin,$r_end]" if (defined($r_begin) && defined($r_end) && s_option('brief'));
	$output .= RESET if (-t STDOUT && s_option('color'));
	$output .= ': ' . $msg;
	$output .= " [$type]";
	$output = (split('\n', $output))[0] . "\n";
	push(our @report, $output);

	$output = '';
	# Print context
	if (defined $line && !s_option('brief') && s_option('context')) {
		my $leading = 0;
		if ($line =~ /^(\s+)/) {
			$leading = length $1;
		}
		$line =~ s/^\s+//g;
		$line =~ s/\s+$//g;

		if (!defined $region) {
			$output .= BRIGHT_BLACK if (-t STDOUT && s_option('color'));
			$output .= "    $line\n";
			$output .= RESET if (-t STDOUT && s_option('color'));
			push(@report, $output);
			our $clean = 0;
			$total_errs++;
			return 1;
		}

		my $l1 = substr($line, 0, $r_begin - $leading);
		my $l2 = substr($line, ($r_begin - $leading) + length $region);

		$output .= BRIGHT_BLACK if (-t STDOUT && s_option('color'));
		$output .= "    $l1";
		$output .= RESET if (-t STDOUT && s_option('color'));
		$output .= "$region";
		$output .= BRIGHT_BLACK if (-t STDOUT && s_option('color'));
		$output .= "$l2\n";
		$output .= RESET if (-t STDOUT && s_option('color'));
		push(@report, $output);

		$output = "    ";
		$output .= " " x ($r_begin - $leading);
		$output .= "^";
		$output .= "-" x ((length $region) - 2) if (length $region > 2);
		$output .= "^" if ((length $region) >= 2);
		$output .= "\n";
		push(@report, $output);
	}

	our $clean = 0;
	$total_errs++;
	return 1;
}

##
## process_style()
##
## Params:
##   $filename: Path to the C source file to be checked
##
## Returns: None
##
## Runs betty-style
##
sub process_style {

	my $filename = shift;

	our @report = ();
	our $clean = 1;

	my $linenr = 0;
	my $prevline = "";
	my $stashline = "";
	my %camelcase_hash = ();

	my $in_comment = 0;

	foreach my $line (@lines) {
		$linenr++;
		$total_lines++;
		$prefix = "$filename:$linenr: ";

		($prevline, $stashline) = ($stashline, $line);

		$in_comment = 1 if ($line =~ /\/\*+/);
		$in_comment = 0 if ($line =~ /\*+\//);


		################################################################
		# CHECKS
		################################################################

		# assign-in-cond
		# check fro assignment in condition
		my $assign_r = qr{[^=!<>](?:\*|\/|%|\+|-|&|\||^|<<|>>)?=[^=]};
		if (s_option('assign-in-cond') &&
		    $line =~ /\b(if|while|switch)\s*\(.*([a-zA-Z0-9_]+\s*$assign_r\s*[a-zA-Z0-9_]+)/ ||
		    $line =~ /\b(for)\s*\([^;]*;[^;]*([a-zA-Z0-9_]+\s*$assign_r\s*[a-zA-Z0-9_]+)/) {
			my ($cond, $region) = ($1, $2);
			WARN("assign-in-cond",
			    "Do not use assignment in '$cond' condition",
			    $line, $region);
		}

		# avoid-externs
		# check for new externs in .c files
		if (s_option('avoid-externs') &&
		    $filename =~ /\.c$/ &&
		    $line =~ /^\s*(extern\s+.*)\s*$/g) {
			WARN("avoid-externs",
			    "externs should be avoided in '.c' files",
			    $line);
		}

		# blank-before-decl
		# check for blank lines before declarations
		if (s_option('blank-before-decl') &&
		    $line =~ /^\t+$Type\s*$Ident\s*(?:=.*|;)?/ &&
		    $prevline =~ /^\s*$/) {
			WARN("blank-before-decl",
			     "No blank lines before declarations",
			     $line);
		}

		# blank-line-brace
		# check for unnecessary blank lines around braces
		if (s_option('blank-line-brace')) {
			if ($line =~ /^\s*}\s*(?:;\s*)?$/ &&
			    $prevline =~ /^\s*$/) {
				$prefix = "$filename:". ($linenr - 1) . ": ";
				WARN("blank-line-brace",
				    "Blank lines aren't necessary before a close brace");
			} elsif ($line =~ /^\s*$/ &&
			    $prevline =~ /^.*{\s*$/) {
				WARN("blank-line-brace",
				    "Blank lines aren't necessary after an open brace");
			}
		}

		# block-comment-leading
		# Block comments use /* on leading line
		if (s_option('block-comment-leading') &&
		    $line !~ /^[ \t]*\/\*[ \t]*$/ &&		#leading /*
		    $line !~ /^.*\/\*.*\*\/[ \t]*$/ &&		#inline /*...*/
		    $line !~ /^.*\/\*{2,}[ \t]*$/ &&		#leading /**
		    $line =~ /^[ \t]*(\/\*+).+[ \t]*$/) {	#/* non blank
			WARN("block-comment-leading",
			    "Block comments use a leading '/*' on a separate line",
			    $line, $1);
		}

		# block-comment-subsequent
		# Block comments use * on subsequent lines
		if (s_option('block-comment-subsequent') &&
		    $in_comment == 1 &&
		    $line !~ /^[ \t]*\/\*+.*$/ &&		#leading /*
		    $line !~ /^[ \t]*\*/) {			#no leading *
			WARN("block-comment-subsequent",
			    "Block comments start with '*' on subsequent lines",
			    $line);
		}

		# block-comment-trailing
		# Block comments use */ on trailing lines
		if (s_option('block-comment-trailing') &&
		    $line !~ /^[ \t]*\*\/[ \t]*$/ &&		#trailing */
		    $line !~ /^.*\/\*.*\*\/[ \t]*$/ &&		#inline /*...*/
		    $line !~ /^[ \t]*\*{2,}\/[ \t]*$/ &&	#trailing **/
		    $line =~ /^[ \t]*.+[^\*](\*+\/)[ \t]*$/) {	#non blank */
			WARN("block-comment-trailing",
			    "Block comments use a trailing '*/' on a separate line",
			    $line, $1);
		}

		# bracket-space
		# check for spacing round square brackets
		while (s_option('bracket-space') &&
		    $line =~ /(\s+)\[/g) {
			my ($lead, $where, $prefix) = (0, $-[1], $1);
			if ($line =~ /^(\s+)/) {
				$lead = $1;
				$lead =~ s/\t/        /g;
			}
			WARN("bracket-space",
			    "Space prohibited before open square bracket '['",
			    $line, $prefix, $where - 1 + length $lead);
		}

		# bracket-space-in
		# check spacing on square brackets
		if (s_option('bracket-space-in')) {
			while ($line =~ /\[(\s+)\S/g) {
				my ($lead, $where, $prefix) = (0, $-[1], $1);
				if ($line =~ /^(\s+)/) {
					$lead = $1;
					$lead =~ s/\t/        /g;
				}
				WARN("bracket-space-in",
				    "Space prohibited after that open square bracket",
				    $line, $prefix, $where - 1 + length $lead);
			}
			while ($line =~ /(\s+)\]/g) {
				my ($lead, $where, $prefix) = (0, $-[1], $1);
				if ($line =~ /^(\s+)/) {
					$lead = $1;
					$lead =~ s/\t/        /g;
				}
				WARN("bracket-space-in",
				    "Space prohibited before that close square bracket",
				    $line, $prefix, $where - 1 + length $lead);
			}
		}

		# c99-comments
		# no C99 '//' comments
		if (s_option('c99-comments') &&
		    $line =~ m{(//.*)}) {
			WARN("c99-comments",
			    "Do not use C99 '//' comments",
			    $line, $1);
		}

		$line =~ s/\/\/.*//g;

		# camelcase
		# Specific variable tests
		while ($line =~ m{($Constant|$Lval)}g) {
			my $var = $1;
			my $v = $var;
			$v =~ s/(\[|\]|\(|\))/\\$1/g;
			# print "VAR: [$var] --> [$v]\n";
			next if ($line =~ /\/\*.*$v/ || $in_comment || $line =~ /"[^"]*$v/);
			if ($var !~ /^$Constant$/ &&
			    $var =~ /[A-Z][a-z]|[a-z][A-Z]/ &&
			    # Ignore Page<foo> variants
			    $var !~ /^(?:Clear|Set|TestClear|TestSet|)Page[A-Z]/ &&
			    # Ignore SI style variants like nS, mV and dB
			    # (ie: max_uV, regulator_min_uA_show)
			    $var !~ /^(?:[a-z_]*?)_?[a-z][A-Z](?:_[a-z_]+)?$/ &&
			    # Ignore some three character SI units explicitly,
			    # like MiB and KHz
			    $var !~ /^(?:[a-z_]*?)_?(?:[KMGT]iB|[KMGT]?Hz)(?:_[a-z_]+)?$/) {
				while ($var =~ m{($Ident)}g) {
					my $word = $1;
					next if ($word !~ /[A-Z][a-z]|[a-z][A-Z]/);
					if (!defined $camelcase_hash{$word}) {
						$camelcase_hash{$word} = 1;
						if (s_option('camelcase')) {
							WARN("camelcase",
							    "Avoid CamelCase: '$word'",
							    $line, $word);
						}
					}
				}
			}
		}

		# cast-int-const
		# check for cast of C90 native int or longer types constants
		if (s_option('cast-int-const') &&
		    $line =~ /(\(\s*$C90_int_types\s*\))\s*($Constant)\b/) {
			WARN("cast-int-const",
			    "Unnecessary typecast of c90 int constant",
			    $line, $1);
		}

		# close-brace-space
		# closing brace should have a space following it when it has
		# anything on the line
		if (s_option('close-brace-space') &&
		    $line =~ /(}(?!(?:}|,|;|\)))\S)/) {
			WARN("close-brace-space",
			    "Space required after that close brace",
			    $line, $1);;
		}

		# code-indent
		# at the beginning of a line any tabs must come first and
		# anything more than 8 must use tabs.
		if (s_option('code-indent') &&
		    ($line =~ /^\s* \t\s*\S/ ||
		     $line =~ /^\s*        \s*/)) {
			WARN("code-indent",
			    "code indent should use tabs where possible",
			    $line);
		}

		################################################################
		# CHECKS DONE
		################################################################
	}

	# Report errors after a file has been analyzed
	if (!$clean) {
		if (s_option('brief')) {
			foreach my $rep (@report) {
				print "$filename:$rep";
			}
		} else {
			print "$filename:\n";
			print " " x 4, join(" " x 4, @report);
		}
	}

	return $clean;
}


################################################################################
################################################################################
################################## BETTY DOC ###################################
################################################################################
################################################################################

# Execute command
$options->{$cmd}->{handler}() if (exists($options->{$cmd}->{handler}));
exit(0);
