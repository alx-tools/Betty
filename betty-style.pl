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
my $V = '1.0';
my $minimum_perl_version = 5.10.0;

my $verbose = 0;
my $help = 0;
my $printVersion = 0;
my $color = 1;

# Options
my $trailing_whitespace = 1;
my $long_line = 1;
my $long_line_max = 80;
my $eof_newline = 1;
my $code_indent = 1;
my $space_before_tab = 1;
my $logical_continuations = 1;
my $tabstop = 1;
my $parenthesis_alignment = 1;
my $space_after_cast = 1;
my $block_comment_subsequent = 1;
my $block_comment_leading = 1;
my $block_comment_trailing = 1;
my $line_spacing = 1;
my $single_line_spacing = 1;
my $leading_space = 1;
my $safe_guard = 1;
my $unnecessary_else = 1;
my $unnecessary_break = 1;
my $switch_indent = 1;
my $deep_indent = 1;
my $loop_open_brace = 1;
my $loop_trailing_semicolon = 1;
my $suspect_indent = 1;
my $unspecified_int = 1;
my $init_open_brace = 1;
my $do_while_open_brace = 1;
my $malformed_include = 1;
my $c99_comments = 1;
my $global_declaration = 1;
my $global_init = 1;
my $static_init = 1;
my $misordered_type = 1;
my $func_without_args = 1;
my $pointer_location = 1;
my $func_open_brace = 1;
my $long_func = 1;
my $long_func_max = 40;
my $count_func = 1;
my $count_func_max = 5;
my $struct_open_brace = 1;
my $struct_def = 1;
my $func_ptr_space = 1;
my $bracket_space = 1;
my $func_parenthesis_space = 1;
my $op_spacing = 1;
my $semicolon_space = 1;
my $multiple_assignments = 1;
my $space_open_brace = 1;
my $blank_before_decl = 1;
my $close_brace_space = 1;
my $bracket_space_in = 1;
my $parenthesis_space_in = 1;
my $unnecessary_parentheses = 1;
my $indented_label = 1;
my $ret_parentheses = 1;
my $ret_space = 1;
my $return_void = 1;
my $const_comp = 1;
my $ctrl_space = 1;
my $assign_in_if = 1;
my $trailing_statements = 1;
my $hexa_bool_test = 1;
my $if_after_brace = 1;
my $else_after_brace = 1;
my $while_after_brace = 1;
my $camelcase = 1;
my $whitespace_continuation = 1;
my $multistatement_macro = 1;
my $complex_macro = 1;
my $macro_flow_control = 1;
my $line_continuation = 1;
my $single_statement_macro = 1;
my $macro_semicolon = 1;
my $unnecessary_braces = 1;
my $necessary_braces = 1;
my $blank_line_brace = 1;
my $volatile = 0;
my $string_split = 0;
my $string_missing_space = 0;
my $string_space_new_line = 0;
my $string_concat = 0;
my $string_fragments = 0;
my $printf_l = 1;
my $printf_0xdecimal = 1;
my $string_line_continuation = 0;
my $redundant_code = 1;
my $mask_then_shift = 1;
my $null_comparison = 1;
my $preproc_if_space = 1;
my $storage_class = 1;
my $inline_location = 1;
my $prefer_inline = 1;
my $prefer_packed = 1;
my $prefer_aligned = 1;
my $weak_declaration = 0;
my $cast_int_const = 1;
my $sizeof_address = 1;
my $sizeof_parenthesis = 1;
my $header_externs = 0;
my $avoid_externs = 1;
my $func_args = 1;
my $typedefs = 1;
my $single_semicolon = 1;
my $missing_break = 1;
my $default_no_break = 1;

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
  --verbose                       Verbose mode
  --[no-]color                    Use colors when output is STDOUT (default: on)

  --[no-]trailing-whitespace      Check for trailing whitespaces (default: on)
  --[no-]long-line                Check for long lines (default: on)
  --long-line-max=n               When --long-line is enale, set the maximum length of a line (default: 80)
  --[no-]eof-newline              Check for new line at end of file (default: on)
  --[no-]code-indent              Check if spaces are using instead of tabs (default: on)
  --[no-]space-before-tab         Check if spaces are used before a tab (default: on)
  --[no-]logical-continuations    Check for logical operators at the beginning of a line (default: on)
  --[no-]tabstop                  Check for indentation after tabstop (default: on)
  --[no-]parenthesis-alignment    Check for alignment with open parenthesis (default: on)
  --[no-]space-after-cast         Check for space after a cast (default: on)
  --[no-]block-comment-subsequent Check for block comment subsequent line style (default: on)
  --[no-]block-comment-leading    Check for block comment leading line style (default: on)
  --[no-]block-comment-trailing   Check for block comment trailing line style (default: on)
  --[no-]line-spacing             Check for blank line after declaration (default: on)
  --[no-]single-line-spacing      Check for multiple blank lines after declaration (default: on)
  --[no-]leading-space            Check for spaces at the beginning of a line (default: on)
  --[no-]safe-guard               Check for header file protection (default: on)
  --[no-]unnecessary-else         Check for unnecessary else after return or break (default: on)
  --[no-]unnecessary-break        Check for unnecessary break after return or goto (default: on)
  --[no-]switch-indent            Check for switch and case alignment (default: on)
  --[no-]deep-indent              Check for deep indentation (default: on)
  --[no-]loop-open-brace          Check for loop open brace on next line (default: on)
  --[no-]loop-trailing-semicolon  Check for bad indentation after loop trailing semicolon (default: on)
  --[no-]suspect-indent           Check for suspect indentation in conditional statement (default: on)
  --[no-]unspecified-int          Check for unspecified int after [un]signed declaration (default: on)
  --[no-]init-open-brace          Check for initialisation open brace on the same line (default: on)
  --[no-]do-while-open-brace      Check for do/while loop open brace on the same line (default: on)
  --[no-]malformed-include        Check for malformed include filename (default: on)
  --[no-]c99-comments             Check for usage of C99 comments (default: on)
  --[no-]global_declaration       Check for global variables declarations (default: on)
  --[no-]global-init              Check for global zero-initialisation (default: on)
  --[no-]static-init              Check for static zero-initialisation (default: on)
  --[no-]misordered-type          Check for misordered type in declaration (default: on)
  --[no-]func-without-args        Check for function declaration without arguments (default: on)
  --[no-]pointer-location         Check for bad pointer location (default: on)
  --[no-]func-open-brace          Check for function open brace on the next line (default: on)
  --[no-]long-func                Check for long functions (default: on)
  --long-func-max=n               When --long-func is enable, set the maximum number of lines per function (default: 40)
  --[no-]count-func               Check for too many functions declared in a single file (default: on)
  --max-funcs=n                   When --count-func is enable, set the maximum number of functions declared in a single file (default: 5)
  --[no-]struct-open-brace        Check for struct/union/enum open brace on the next line (default: on)
  --[no-]struct-def               Check for struct/union/enum definition in .c files (default: on)
  --[no-]func-ptr-space           Check for a space errors when declaring a pointer to function (default: on)
  --[no-]bracket-space            Check for prohibited space before open square bracket (default: on)
  --[no-]func-parenthesis-space   Check for space between function name and open parenthesis (default: on)
  --[no-]op-spacing               Check for operators spacing (default: on)
  --[no-]semicolon-space          Check for space before semicolon (default: on)
  --[no-]multiple-assignments     Check for multiple assignments (default: on)
  --[no-]space-open-brace         Check for space before opening brace (default: on)
  --[no-]blank-before-decl        Check for blank line before declaration (default: on)
  --[no-]close-brace-space        Check for missed space after closing brace (default: on)
  --[no-]bracket-space-in         Check for prohibited space inside square brackets (default: on)
  --[no-]parenthesis-space-in     Check for prohibited space inside parenthesis (default: on)
  --[no-]unnecessary-parentheses  Check for unnecessary parentheses (default: on)
  --[no-]indented-label           Check for indented label (default: on)
  --[no-]ret-parentheses          Check for missing parentheses around return value (default: on)
  --[no-]ret-space                Check for missing space after return keyword (default: on)
  --[no-]return-void              Check for useless void return (default: on)
  --[no-]const-comp               Check for operands order when comparing with a constant (default: on)
  --[no-]ctrl-space               Check for space after control statement keyword (default: on)
  --[no-]assign-in-if             Check for assignment in if condition (default: on)
  --[no-]trailing-statements      Check for trailing statements on a single line (default: on)
  --[no-]hexa-bool-test           Check for bitwise test written as boolean (default: on)
  --[no-]if-after-brace           Check for if just after a closing brace (default: on)
  --[no-]else-after-brace         Check for else just after a closing brace (default: on)
  --[no-]while-after-brace        Check for while not following close brace in do/while statement (default: on)
  --[no-]camelcase                Check for camelcase variable naming (default: off)
  --[no-]whitespace-continuation  Check for whitespace after a line continuation '\\' (default: on)
  --[no-]multistatement-macro     Check for multistatement macro not enclose in a do/while (default: on)
  --[no-]complex-macro            Check for complex macro not enclosed in parentheses (default: on)
  --[no-]macro-flow-control       Check for macro containing flow control statement (default: on)
  --[no-]line-continuation        Check for line continuation outside a define (default: on)
  --[no-]single-statement-macro   Check for single statement macro enclosed in do/while (default: on)
  --[no-]macro-semicolon          Check for semicolon terminated macros (default: on)
  --[no-]unnecessary-braces       Check for unnecessary braces (default: on)
  --[no-]necessary-braces         Check for necessary braces (default: on)
  --[no-]blank-line-brace         Check for unnecessary blank line around braces (default: on)
  --[no-]volatile                 Check for volatile usage (default: off)
  --[no-]string-split             Check for split quoted string across lines (default: off)
  --[no-]string-missing-space     Check for missing space in quoted string concatenation (default: off)
  --[no-]string_space_new_line    Check for spaces before wuoted new line (default: off)
  --[no-]string-concat            Check for space between elements when concatenating quoted strings (default: off)
  --[no-]string-fragments         Check for quoted string fragments instead of a single one (default: off)
  --[no-]printf-l                 Check for not standard \%Lu/\%Ld in printf (default: on)
  --[no-]printf-0xdecimal         Check for deficient use of `0x\%d` in printf (default: on)
  --[no-]string-line-continuation Check for line continuation inside a quoted string (default: off)
  --[no-]redundant-code           Check for redundant code (default: on)
  --[no-]mask-then-shift          Check for mask followed by right shift without parentheses (default: on)
  --[no-]null-comparison          Check for comparison with NULL (default: on)
  --[no-]preproc-if-space         Check for spaces after preprocessor condition (default: on)
  --[no-]storage-class            Check for storage class not at the beginning of a declaration (default: on)
  --[no-]inline-location          Check for bad location of the inline attribute (default: on)
  --[no-]prefer-inline            Check for inline attribute style (default: on)
  --[no-]prefer-packed            Check for packed attribute style (default: on)
  --[no-]prefer-aligned           Check for aligned attribute style (default: on)
  --[no-]weak-declaration         Check for weak declaration (default: off)
  --[no-]cast-int-const           Check for unnecessary cast of C90 int constant (default: on)
  --[no-]sizeof-address           Check for usage of 'sizeof(&' (default: on)
  --[no-]sizeof-parenthesis       Check for sizeof without parenthesis (default: on)
  --[no-]header-externs           Check for externs in header files (default: on)
  --[no-]avoid-externs            Check for externs in C source files (default: on)
  --[no-]func-args                Check for misplaced function arguments (default: on)
  --[no-]typedefs                 Check for new typedefs in C source files (default: on)
  --[no-]single-semicolon         Check termination with only one semicolon (default: on)
  --[no-]missing-break            Check for missing break in switch/case statement (default: on)
  --[no-]default-no-break         Check for missing break in switch/default statement (default: on)

  -h, --help                      Display this help and exit
  -v, --version                   Display the version of the srcipt
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

	'trailing-whitespace!' => \$trailing_whitespace,
	'long-line!' => \$long_line,
	'long-line-max=i' => \$long_line_max,
	'eof-newline!' => \$eof_newline,
	'code-indent!' => \$code_indent,
	'space-before-tab!' => \$space_before_tab,
	'logical-continuations!' => \$logical_continuations,
	'tabstop!' => \$tabstop,
	'parenthesis-alignment!' => \$parenthesis_alignment,
	'space-after-cast!' => \$space_after_cast,
	'block-comment-subsequent!' => \$block_comment_subsequent,
	'block-comment-leading!' => \$block_comment_leading,
	'block-comment-trailing!' => \$block_comment_trailing,
	'line-spacing!' => \$line_spacing,
	'single-line-spacing!' => \$single_line_spacing,
	'leading-space!' => \$leading_space,
	'safe-guard!'	=> \$safe_guard,
	'unnecessary-else!' => \$unnecessary_else,
	'unnecessary-break!' => \$unnecessary_break,
	'switch-indent!' => \$switch_indent,
	'deep-indent!' => \$deep_indent,
	'loop-open-brace!' => \$loop_open_brace,
	'loop-trailing-semicolon!' => \$loop_trailing_semicolon,
	'suspect-indent!' => \$suspect_indent,
	'unspecified-int!' => \$unspecified_int,
	'init-open-brace!' => \$init_open_brace,
	'do-while-open-brace!' => \$do_while_open_brace,
	'malformed-include!' => \$malformed_include,
	'c99-comments!' => \$c99_comments,
	'global-declaration!' => \$global_declaration,
	'global-init!' => \$global_init,
	'static-init!' => \$static_init,
	'misordered-type!' => \$misordered_type,
	'func-without-args!' => \$func_without_args,
	'pointer-location!' => \$pointer_location,
	'func-open-brace!' => \$func_open_brace,
	'long-func!' => \$long_func,
	'long-func-func=i' => \$long_func_max,
	'count-func!' => \$count_func,
	'count-func-max=i' => \$count_func_max,
	'struct-open-brace!' => \$struct_open_brace,
	'struct-def!' => \$struct_def,
	'func-ptr-space!' => \$func_ptr_space,
	'bracket-space!' => \$bracket_space,
	'func-parenthesis-space!' => \$func_parenthesis_space,
	'op-spacing!' => \$op_spacing,
	'semicolon-space!' => \$semicolon_space,
	'multiple-assignments!' => \$multiple_assignments,
	'space-open-brace!' => \$space_open_brace,
	'blank-before-decl!' => \$blank_before_decl,
	'close-brace-space!' => \$close_brace_space,
	'bracket-space-in!' => \$bracket_space_in,
	'parenthesis-space-in!' => \$parenthesis_space_in,
	'unnecessary-parentheses!' => \$unnecessary_parentheses,
	'indented-label!' => \$indented_label,
	'ret-parentheses!' => \$ret_parentheses,
	'ret-space!' => \$ret_space,
	'return-void!' => \$return_void,
	'const-comp!' => \$const_comp,
	'ctrl-space!' => \$ctrl_space,
	'assign-in-if!' => \$assign_in_if,
	'trailing-statements!' => \$trailing_statements,
	'hexa-bool-test!' => \$hexa_bool_test,
	'if-after-brace!' => \$if_after_brace,
	'else-after-brace!' => \$else_after_brace,
	'while-after-brace!' => \$while_after_brace,
	'camelcase!' => \$camelcase,
	'whitespace-continuation!' => \$whitespace_continuation,
	'multistatement-macro!' => \$multistatement_macro,
	'complex-macro!' => \$complex_macro,
	'macro-flow-control!' => \$macro_flow_control,
	'line-continuation!' => \$line_continuation,
	'single-statement-macro!' => \$single_statement_macro,
	'macro-semicolon!' => \$macro_semicolon,
	'unnecessary-braces!' => \$unnecessary_braces,
	'necessary-braces!' => \$necessary_braces,
	'blank-line-brace!' => \$blank_line_brace,
	'volatile!' => \$volatile,
	'string-split!' => \$string_split,
	'string-missing-space!' => \$string_missing_space,
	'string-space-new-line!' => \$string_space_new_line,
	'string-concat!' => \$string_concat,
	'string-fragments!' => \$string_fragments,
	'printf-l!' => \$printf_l,
	'printf-0xdecimal!' => \$printf_0xdecimal,
	'string-line-continuation!' => \$string_line_continuation,
	'redundant-code!' => \$redundant_code,
	'mask-then-shift!' => \$mask_then_shift,
	'null-comparison!' => \$null_comparison,
	'preproc-if-space!' => \$preproc_if_space,
	'storage-class!' => \$storage_class,
	'inline-location!' => \$inline_location,
	'prefer-inline!' => \$prefer_inline,
	'prefer-packed!' => \$prefer_packed,
	'prefer-aligned!' => \$prefer_aligned,
	'weak-declaration!' => \$weak_declaration,
	'cast-int-const!' => \$cast_int_const,
	'sizeof-address!' => \$sizeof_address,
	'sizeof-parenthesis!' => \$sizeof_parenthesis,
	'header-externs!' => \$header_externs,
	'avoid_externs!' => \$avoid_externs,
	'func-args!' => \$func_args,
	'typedefs!' => \$typedefs,
	'single-semicolon!' => \$single_semicolon,
	'missing-break!' => \$missing_break,
	'default-no-break!' => \$default_no_break
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

my $emitted_corrupt = 0;

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

my $total_errors = 0;
my $total_warns = 0;
my $total_lines = 0;
my $total_files = 0;

for my $filename (@ARGV) {
	my $FILE;
	open($FILE, '-|', "diff -u /dev/null $filename") ||
		die "$P: $filename: diff failed - $!\n";
	while (<$FILE>) {
		chomp;
		push(@rawlines, $_);
	}
	close($FILE);

	$total_files++;
	if (!process($filename)) {
		$exit = 1;
	}
	@rawlines = ();
	@lines = ();
	@modifierListFile = ();
	@typeListFile = ();
	build_types();
}

if ($exit != 0) {
	print "Total: ";
	print "$total_errors errors, ";
	print "$total_warns warnings, ";

	my $line_plural = "s";
	$line_plural = "" if ($total_lines < 2);
	my $file_plural = "s";
	$file_plural = "" if ($total_files < 2);

	print "$total_lines line$line_plural checked in $total_files file$file_plural\n";
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

sub line_stats {
	my ($line) = @_;

	# Drop the diff line leader and expand tabs
	$line =~ s/^.//;
	$line = expand_tabs($line);

	# Pick the indent from the front of the line.
	my ($white) = ($line =~ /^(\s*)/);

	return (length($line), length($white));
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

sub ctx_statement_level {
	my ($linenr, $remain, $off) = @_;

	return ctx_block_get($linenr, $remain, 0, '(', ')', $off);
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

	$msg = (split('\n', $msg))[0];

	my $output = '';
	if (-t STDOUT && $color) {
		if ($level eq 'error') {
			$output .= RED;
		} elsif ($level eq 'warning') {
			$output .= YELLOW;
		} else {
			$output .= GREEN;
		}
	}
	# $output .= $prefix . $level . ':';
	my $line = (split(":", $prefix))[1]; # Line number only
	$output .= "$level line $line:";
	$output .= RESET if (-t STDOUT && $color);
	$output .= ' ' . $msg;
	$output .= " [--$type]";
	$output .= "\n";

	$output = (split('\n', $output))[0] . "\n";

	push(our @report, $output);

	return 1;
}

sub report_dump {
	our @report;
}

sub ERROR {
	my ($type, $msg) = @_;

	if (report("error", $type, $msg)) {
		our $clean = 0;
		$total_errors++;
		return 1;
	}
	return 0;
}

sub WARN {
	my ($type, $msg) = @_;

	if (report("warning", $type, $msg)) {
		our $clean = 0;
		$total_warns++;
		return 1;
	}
	return 0;
}

sub trim {
	my ($string) = @_;

	$string =~ s/^\s+|\s+$//g;
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

	my $linenr = 0;
	my $prevline = "";
	my $prevrawline = "";
	my $stashline = "";
	my $stashrawline = "";

	my $length;
	my $real_length;
	my $indent;
	my $previndent = 0;
	my $stashindent = 0;

	# Header protection
	my $header_protected = 0;
	my $protection_name = '';
	my $header_if_depth = 0;

	our $clean = 1;

	my $last_blank_line = 0;

	our @report = ();

	# Trace the real file/line as we go.
	my $realfile = '';
	my $realline = 0;
	my $realcnt = 0;
	my $in_comment = 0;
	my $first_line = 0;

	my $prev_values = 'E';

	# suppression flags
	my %suppress_ifbraces;
	my %suppress_whiletrailers;
	my $suppress_statement = 0;

	sanitise_line_reset();
	my $line;
	foreach my $rawline (@rawlines) {
		$linenr++;
		$line = $rawline;

		if ($rawline=~/^\@\@ -\d+(?:,\d+)? \+(\d+)(,(\d+))? \@\@/) {
			$realline = $1 - 1;
			if (defined $2) {
				$realcnt = $3 + 1;
			} else {
				$realcnt= 1 + 1;
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
			    $rawlines[$linenr] =~ m@^.\s*(?:\*\*+| \*)(?:\s|$)@) {
				$in_comment = 1;
			}

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
	}

	$prefix = '';
	my %camelcase_hash = ();

	$realcnt = 0;
	$linenr = 0;
	my $nbfunc = 0;
	my $inscope = 0;
	my $funclines = 0;

	foreach my $line (@lines) {
		$linenr++;
		my $sline = $line; #copy of $line
		$sline =~ s/$;/ /g; #with comments as spaces

		my $rawline = $rawlines[$linenr - 1];

#extract the line range in the file after the patch is applied
		if ($line =~ /^\@\@ -\d+(?:,\d+)? \+(\d+)(,(\d+))? \@\@/) {
			$first_line = $linenr + 1;
			$realline = $1 - 1;
			if (defined $2) {
				$realcnt = $3 + 1;
			} else {
				$realcnt = 1 + 1;
			}
			annotate_reset();
			$prev_values = 'E';

			%suppress_ifbraces = ();
			%suppress_whiletrailers = ();
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
			$real_length = length($rawline);

			# Track the previous line.
			($prevline, $stashline) = ($stashline, $line);
			($previndent, $stashindent) = ($stashindent, $indent);
			($prevrawline, $stashrawline) = ($stashrawline, $rawline);
		} elsif ($realcnt == 1) {
			$realcnt--;
		}

		my $hunk_line = ($realcnt != 0);

		# extract the filename as it passes
		if ($line =~ /^\+\+\+\s+(\S+)/) {
			$realfile = $1;
		}

#make up the handle for any error we report on this line
		$prefix = "$filename:$realline: ";

		$total_lines++ if ($realcnt != 0);

# ignore non-hunk lines and lines being removed
		next if (!$hunk_line || $line =~ /^-/);

#trailing whitespace
		if ($trailing_whitespace &&
		    ($rawline =~ /^\+.*\S\s+$/ ||
		     $rawline =~ /^\+\s+$/)) {
			ERROR("trailing-whitespace", "trailing whitespace\n");
		}

# check we are in a valid source file if not then ignore this hunk
		next if ($realfile !~ /\.(h|c|s|S|pl|sh|dtsi|dts)$/);

# line length limit (with some exclusions)
#
# There are a few types of lines that may extend beyond $long_line_max:
#	logging functions like pr_info that end in a string
#	lines with a single string
#	#defines that are a single string
#
# There are 3 different line length message types:
# LONG_LINE_COMMENT	a comment starts before but extends beyond $long_line_max
# LONG_LINE_STRING	a string starts before but extends beyond $long_line_max
# LONG_LINE		all other lines longer than $long_line_max
#
# if LONG_LINE is ignored, the other 2 types are also ignored
#

		if ($long_line &&
		    $line =~ /^\+/ &&
		    $real_length > $long_line_max) {
			my $ignore = 0;

			# Check the allowed long line types first

			# logging functions that end in a string that starts
			# before $long_line_max
			if ($line =~ /^\+\s*$logFunctions\s*\(\s*(?:(?:KERN_\S+\s*|[^"]*))?($String\s*(?:|,|\)\s*;)\s*)$/ &&
			    length(expand_tabs(substr($line, 1, length($line) - length($1) - 1))) <= $long_line_max) {
				$ignore = 1;

			# lines with only strings (w/ possible termination)
			# #defines with only strings
			} elsif ($line =~ /^\+\s*$String\s*(?:\s*|,|\)\s*;)\s*$/ ||
			    $line =~ /^\+\s*#\s*define\s+\w+\s+$String$/) {
				$ignore = 1;
			}

			if (!$ignore) {
				WARN("long-line",
				    "line over $long_line_max characters ($real_length)\n");
			}
		}

# check for adding lines without a newline.
		if ($eof_newline &&
		    $line =~ /^\+/ &&
		    defined $lines[$linenr] &&
		    $lines[$linenr] =~ /^\\ No newline at end of file/) {
			WARN("eof-newline",
			    "no newline at end of file\n");
		}

# check we are in a valid source file C or perl if not then ignore this hunk
		next if ($realfile !~ /\.(h|c|pl|dtsi|dts)$/);

# at the beginning of a line any tabs must come first and anything
# more than 8 must use tabs.
		if ($code_indent &&
		    ($rawline =~ /^\+\s* \t\s*\S/ ||
		     $rawline =~ /^\+\s*        \s*/)) {
			ERROR("code-indent",
			    "code indent should use tabs where possible\n");
		}

# check for space before tabs.
		if ($space_before_tab &&
		    $rawline =~ /^\+/ && $rawline =~ / \t/) {
			WARN("space-before-tab",
			    "please, no space before tabs\n");
		}

# check for && or || at the start of a line
		if ($logical_continuations &&
		    $rawline =~ /^\+\s*(&&|\|\|)/) {
			WARN("logical-continuations",
			    "Logical continuations should be on the previous line\n");
		}

# check indentation starts on a tab stop
		if ($tabstop &&
		    $^V && $^V ge 5.10.0 &&
		    $sline =~ /^\+\t+( +)(?:$c90_Keywords\b|\{\s*$|\}\s*(?:else\b|while\b|\s*$))/) {
			my $indent = length($1);
			if ($indent % 8) {
				WARN("tabstop",
				    "Statements should start on a tabstop\n");
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

				if ($parenthesis_alignment &&
				    $newindent ne $goodtabindent &&
				    $newindent ne $goodspaceindent) {
					WARN("parenthesis-alignment",
					    "Alignment should match open parenthesis\n");
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
		if ($space_after_cast &&
		    $line =~ /^\+(.*)\(\s*$Type\s*\)([ \t]++)((?![={]|\\$|$Attribute|__attribute__))/ &&
		    (!defined($1) || $1 !~ /\b(?:sizeof|__alignof__)\s*$/)) {
			WARN("space-after-cast",
			    "No space is necessary after a cast\n");
		}

# Block comment styles

# Block comments use * on subsequent lines
		if ($block_comment_subsequent &&
		    $prevline =~ /$;[ \t]*$/ &&			#ends in comment
		    $prevrawline =~ /^\+.*?\/\*/ &&		#starting /*
		    $prevrawline !~ /\*\/[ \t]*$/ &&		#no trailing */
		    $rawline =~ /^\+/ &&			#line is new
		    $rawline !~ /^\+[ \t]*\*/) {		#no leading *
			WARN("block-comment-sub",
			    "Block comments start with * on subsequent lines\n");
		}

# Block comments use /* on leading line
		if ($rawline !~ m@^.\s*/\*\s*$@ &&		#leading /*
		    $rawline !~ m@^.*/\*.*\*/\s*$@ &&		#inline /*...*/
		    $rawline !~ m@^.*/\*{2,}\s*$@ &&		#leading /**
		    $rawline =~ m@^.\s*/\*+.+\s*$@) {		#/* non blank
			WARN("block-comment-leading",
			    "Block comments use a leading /* on a separate line\n" . $herecurr);
		}

# Block comments use */ on trailing lines
		if ($block_comment_trailing &&
		    $rawline !~ m@^\+[ \t]*\*/[ \t]*$@ &&	#trailing */
		    $rawline !~ m@^\+.*/\*.*\*/[ \t]*$@ &&	#inline /*...*/
		    $rawline !~ m@^\+.*\*{2,}/[ \t]*$@ &&	#trailing **/
		    $rawline =~ m@^\+[ \t]*.+\*\/[ \t]*$@) {	#non blank */
			WARN("block-comment-trailing",
			    "Block comments use a trailing */ on a separate line\n");
		}

# check for missing blank lines after struct/union declarations
# with exceptions for various attributes and macros
		if ($line_spacing &&
		    $prevline =~ /^[\+ ]};?\s*$/ &&
		    $line =~ /^\+/ &&
		    !($line =~ /^\+\s*$/ ||
		      $line =~ /^\+\s*EXPORT_SYMBOL/ ||
		      $line =~ /^\+\s*MODULE_/i ||
		      $line =~ /^\+\s*\#\s*(?:end|elif|else)/ ||
		      $line =~ /^\+[a-z_]*init/ ||
		      $line =~ /^\+\s*(?:static\s+)?[A-Z_]*ATTR/ ||
		      $line =~ /^\+\s*DECLARE/ ||
		      $line =~ /^\+\s*__setup/)) {
			WARN("line-spacing",
			    "Please use a blank line after function/struct/union/enum declarations\n");
		}

# check for multiple consecutive blank lines
		if ($prevline =~ /^[\+ ]\s*$/ &&
		    $line =~ /^\+\s*$/ &&
		    $last_blank_line != ($linenr - 1)) {
			$last_blank_line = $linenr;
			if ($single_line_spacing) {
				WARN("single-line-spacing",
				    "Please don't use multiple blank lines\n");
			}
		}

# check for missing blank lines after declarations
		if ($line_spacing &&
		    $sline =~ /^\+\s+\S/ &&			#Not at char 1
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
			WARN("line-spacing",
			    "Missing a blank line after declarations\n");
		}

# check for spaces at the beginning of a line.
# Exceptions:
#  1) within comments
#  2) indented preprocessor commands
#  3) hanging labels
		if ($leading_space &&
		    $rawline =~ /^\+ / && $line !~ /^\+ *(?:$;|#|$Ident:)/)  {
			WARN("leading-space",
			    "please, no spaces at the start of a line\n");
		}

# check we are in a valid C source file if not then ignore this hunk
		next if ($realfile !~ /\.(h|c)$/);

# Check for header protection
		if ($realfile =~ /\.h$/) {
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
				if ($safe_guard &&
				    $header_protected == 0 &&
				    $line !~ /^.\s*$/ &&
				    $line !~ /^.#\s*(?:end)?if/) {
					WARN("safe-guard",
					    "This line is not protected from double inclusion\n");
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
		if ($unnecessary_else &&
		    $sline =~ /^\+([\t]+)(?:}[ \t]*)?else(?:[ \t]*{)?\s*$/) {
			my $tabs = length($1) + 1;
			if ($prevline =~ /^\+\t{$tabs,$tabs}break\b/ ||
			    ($prevline =~ /^\+\t{$tabs,$tabs}return\b/ &&
			     defined $lines[$linenr] &&
			     $lines[$linenr] !~ /^[ \+]\t{$tabs,$tabs}return/)) {
				WARN("unnecessary-else",
				    "else is not generally useful after a break or return\n");
			}
		}

# check indentation of a line with a break;
# if the previous line is a goto or return and is indented the same # of tabs
		if ($unnecessary_break &&
		    $sline =~ /^\+([\t]+)break\s*;\s*$/) {
			my $tabs = $1;
			if ($prevline =~ /^\+$tabs(?:goto|return)\b/) {
				WARN("unnecessary-break",
				    "break is not useful after a goto or return\n");
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
			if ($prev_values eq 'E' &&
			    $s =~ /^(.(?:typedef\s*)?(?:(?:$Storage|$Inline)\s*)*\s*$Type\s*(?:\b$Ident|\(\*\s*$Ident\))\s*)\(/s) {
				my ($name_len) = length($1);

				my $ctx = $s;
				substr($ctx, 0, $name_len + 1, '');
				$ctx =~ s/\)[^\)]*$//;

				for my $arg (split(/\s*,\s*/, $ctx)) {
					if ($arg =~ /^(?:const\s+)?($Ident)(?:\s+$Sparse)*\s*\**\s*(:?\b$Ident)?$/s ||
					    $arg =~ /^($Ident)$/s) {
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
			if ($switch_indent &&
			    $err ne '') {
				ERROR("switch-indent",
				    "switch and case should be at the same indent\n$err");
			}
		}

# if/while/etc brace go on next line, unless defining a do while loop,
# or if that brace on the next line is for something else
		#if ($line =~ /(.*)\b((?:if|while|for|switch|(?:[a-z_]+|)for_each[a-z_]+)\s*\(|do\b|else\b)/ && $line !~ /^.\s*\#/) {
		if ($line =~ /(.*)\b((?:if|while|for|switch|(?:[a-z_]+|)for_each[a-z_]+)\s*\(|else\b)/ &&
		    $line !~ /^.\s*\#/) {
			my $pre_ctx = "$1$2";

			my ($level, @ctx) = ctx_statement_level($linenr, $realcnt, 0);

			if ($deep_indent &&
			    $line =~ /^\+\t{6,}/) {
				WARN("deep-indent",
				    "Too many leading tabs - consider code refactoring\n");
			}

			my $ctx_cnt = $realcnt - $#ctx - 1;
			my $ctx = join("\n", @ctx);

			my $ctx_ln = $linenr;
			my $ctx_skip = $realcnt;

			while ($ctx_skip > $ctx_cnt || ($ctx_skip == $ctx_cnt &&
			    defined $lines[$ctx_ln - 1] &&
			    $lines[$ctx_ln - 1] =~ /^-/)) {
				$ctx_skip-- if (!defined $lines[$ctx_ln - 1] || $lines[$ctx_ln - 1] !~ /^-/);
				$ctx_ln++;
			}

			# if ($ctx !~ /{\s*/ && defined($lines[$ctx_ln - 1]) && $lines[$ctx_ln - 1] =~ /^\+\s*{/) {
			# 	ERROR("op-brace-to-rename",
			# 	      "that open brace should be on the next line\n");
			# }
			if ($loop_open_brace &&
			    $line =~ /\s*{/) {
				ERROR("loop-open-brace",
				    "that open brace should be on the next line\n");
			}
			if ($level == 0 &&
			    $pre_ctx !~ /}\s*while\s*\($/ &&
			    $ctx =~ /\)\s*\;\s*$/ &&
			    defined $lines[$ctx_ln - 1]) {
				my ($nlength, $nindent) = line_stats($lines[$ctx_ln - 1]);
				if ($loop_trailing_semicolon &&
				    $nindent > $indent) {
					WARN("loop-trailing-semicolon",
					    "trailing semicolon indicates no statements, indent implies otherwise\n");
				}
			}
		}

# Check relative indent for conditionals and blocks.
		if ($line =~ /\b(?:(?:if|while|for|(?:[a-z_]+|)for_each[a-z_]+)\s*\(|do\b)/ &&
		    $line !~ /^.\s*#/ &&
		    $line !~ /\}\s*while\s*/) {
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
			     $prevline =~ /\\\s*$/) &&
			    $continuation == 0) {
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

			# print "line<$line> prevline<$prevline> indent<$indent> sindent<$sindent> check<$check> continuation<$continuation> s<$s> cond_lines<$cond_lines> stat_real<$stat_real> stat<$stat>\n";

			if ($suspect_indent &&
			    $check && $s ne '' &&
			    (($sindent % 8) != 0 ||
			     ($sindent < $indent) ||
			     ($sindent > $indent + 8))) {
				WARN("suspect-indent",
				     "suspect code indent for conditional statements ($indent, $sindent)\n" . "$stat_real\n");
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

				if ($unspecified_int) {
					WARN("unspecified-int",
					    "Prefer '" . trim($sign) . " int" . rtrim($pointer) .
					    "' to bare use of '$sign" . rtrim($pointer) . "'\n");
				}
			}
		}

# check for initialisation to aggregates open brace on the same line
		if ($init_open_brace &&
		    $line =~ /^.\s*{/ &&
		    $prevline =~ /(?:^|[^=])=\s*$/) {
			ERROR("init-open-brace",
			    "that open brace { should be on the previous line\n");
		}

# Check for do/while loop open brace on the same line
		if ($do_while_open_brace &&
		    $line =~ /^.\s*{/ &&
		    $prevline =~ /^.\s*\bdo\b\s*/) {
			ERROR("do-while-open-brace",
			    "that open brace { should be on the previous line\n");
		}

#
# Checks which are anchored on the added line.
#

# check for malformed paths in #include statements (uses RAW line)
		if ($rawline =~ m{^.\s*\#\s*include\s+[<"](.*)[">]}) {
			my $path = $1;
			if ($malformed_include &&
			    $path =~ m{//}) {
				ERROR("malformed-include",
				    "malformed #include filename\n");
			}
		}

# no C99 // comments
		if ($c99_comments &&
		    $line =~ m{//}) {
			ERROR("c99-comments",
			    "do not use C99 // comments\n");
		}
		# Remove C99 comments.
		$line =~ s@//.*@@;
		$opline =~ s@//.*@@;

# Check for global variables (not allowed).
		if ($global_declaration &&
		    $inscope == 0 &&
		    ($line =~ /^\+\s*$Type\s*$Ident(?:\s+$Modifier)*(?:\s*=\s*.*)?;/ ||
		     $line =~ /^\+\s*$Declare\s*\(\s*\*\s*$Ident\s*\)\s*[=,;:\[\(].*;/ ||
		     $line =~ /^\+\s*$Ident(?:\s+|\s*\*\s*)$Ident\s*[=,;\[]/ ||
		     $line =~ /^\+\s*$declaration_macros/)) {
			ERROR("global-declaration",
			    "do not declare global variables\n");
		}

# check for global initialisers.
		if ($global_init &&
		    $line =~ /^\+$Type\s*$Ident(?:\s+$Modifier)*\s*=\s*($zero_initializer)\s*;/) {
			ERROR("global-init",
				  "do not initialise globals to $1\n");
		}
# check for static initialisers.
		if ($static_init &&
		    $line =~ /^\+.*\bstatic\s.*=\s*($zero_initializer)\s*;/) {
			ERROR("static-init",
			    "do not initialise statics to $1\n");
		}

# check for misordered declarations of char/short/int/long with signed/unsigned
		while ($misordered_type &&
		    $sline =~ m{(\b$TypeMisordered\b)}g) {
			my $tmp = trim($1);
			WARN("misordered-type",
			    "type '$tmp' should be specified in [[un]signed] [short|int|long|long long] order\n");
		}

# check for function declarations without arguments like "int foo()"
		if ($func_without_args &&
		    $line =~ /(\b$Type\s+$Ident)\s*\(\s*\)/) {
			ERROR("func-without-args",
			    "$1() should probably be $1(void)\n");
		}

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
			while ($to =~ s/\*\s+\*/\*\*/) {}

##			print "1: from<$from> to<$to> ident<$ident>\n";
			if ($pointer_location &&
			    $from ne $to) {
				ERROR("pointer-location",
				    "\"(foo$from)\" should be \"(foo$to)\"\n");
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
			while ($to =~ s/\*\s+\*/\*\*/) {}
			# Modifiers should have spaces.
			$to =~ s/(\b$Modifier$)/$1 /;

##			print "2: from<$from> to<$to> ident<$ident>\n";
			if ($pointer_location &&
			    $from ne $to && $ident !~ /^$Modifier$/) {
				ERROR("pointer-location",
				    "\"foo${from}bar\" should be \"foo${to}bar\"\n");
			}
		}

# function brace can't be on same line, except for #defines of do while,
# or if closed on same line
		if ($func_open_brace &&
		    $line=~/$Type\s*$Ident\(.*\).*\s*{/ &&
		    !($line=~/\#\s*define.*do\s\{/) &&
		    !($line=~/}/)) {
			ERROR("func-open-brace",
			    "open brace following function declarations go on the next line\n");
		}

# check number of functions
# and number of lines per function
		if ($line =~ /(})/g) {
			$inscope -= $#-;
			if ($inscope == 0) {
				$funclines = 0;
			}
		}

		if ($inscope >= 1) {
			$funclines++;
			if ($long_func &&
			    $funclines > $long_func_max) {
				WARN("long-func",
				    "More than $long_func_max lines in a function\n");
			}
		}

		if ($line =~ /({)/g) {
			$inscope += $#-;
			if ($prevline =~ /^(.(?:typedef\s*)?(?:(?:$Storage|$Inline)\s*)*\s*$Type\s*(?:\b$Ident|\(\*\s*$Ident\))\s*)\(/s &&
			    $inscope == 1) {
				$nbfunc++;
				$funclines = 0;
				if ($count_func &&
				    $nbfunc > $count_func_max) {
					my $tmpline = $realline - 1;
					$prefix = "$realfile:$tmpline: ";
					ERROR("count-func",
					    "More than $count_func_max functions declared\n");
				}
			}
		}

# open braces for enum, union and struct go on the next line.
		if ($struct_open_brace &&
		    $line =~ /^.\s*(?:typedef\s+)?(enum|union|struct)(?:\s+$Ident)?\s*{/) {
			ERROR("struct-open-brace",
			    "open brace following $1 go on the next line\n");
		}

		if ($struct_def &&
		    $realfile =~ /\.c$/ &&
		    $line =~ /^.\s*(?:typedef\s+)?(enum|union|struct)(?:\s+$Ident)?\s*.*/ &&
		    $line !~ /;$/) {
			WARN("struct-def",
			    "$1 definition should be avoided in .c files\n");
		}

# Function pointer declarations
# check spacing between type, funcptr, and args
# canonical declaration is "type (*funcptr)(args...)"
		if ($func_ptr_space &&
		    $line =~ /^.\s*($Declare)\((\s*)\*(\s*)($Ident)(\s*)\)(\s*)\(/) {
			my $declare = $1;
			my $pre_pointer_space = $2;
			my $post_pointer_space = $3;
			my $funcname = $4;
			my $post_funcname_space = $5;
			my $pre_args_space = $6;

# the $declare variable will capture all spaces after the type
# so check it for a missing trailing missing space but pointer return types
# don't need a space so don't warn for those.
			my $post_declare_space = "";
			if ($declare =~ /(\s+)$/) {
				$post_declare_space = $1;
				$declare = rtrim($declare);
			}
			if ($declare !~ /\*$/ && $post_declare_space =~ /^$/) {
				WARN("func-ptr-space",
				    "missing space after return type\n");
				$post_declare_space = " ";
			}

# unnecessary space "type ( *funcptr)(args...)"
			if (defined $pre_pointer_space &&
			    $pre_pointer_space =~ /^\s/) {
				WARN("func-ptr-space",
				    "Unnecessary space after function pointer open parenthesis\n");
			}

# unnecessary space "type (* funcptr)(args...)"
			if (defined $post_pointer_space &&
			    $post_pointer_space =~ /^\s/) {
				WARN("func-ptr-space",
				    "Unnecessary space before function pointer name\n");
			}

# unnecessary space "type (*funcptr )(args...)"
			if (defined $post_funcname_space &&
			    $post_funcname_space =~ /^\s/) {
				WARN("func-ptr-space",
				    "Unnecessary space after function pointer name\n");
			}

# unnecessary space "type (*funcptr) (args...)"
			if (defined $pre_args_space &&
			    $pre_args_space =~ /^\s/) {
				WARN("func-ptr-space",
				    "Unnecessary space before function pointer arguments\n");
			}
		}

# check for spacing round square brackets; allowed:
#  1. with a type on the left -- int [] a;
#  2. at the beginning of a line for slice initialisers -- [0...10] = 5,
#  3. inside a curly brace -- = { [0...10] = 5 }
		while ($bracket_space &&
		    $line =~ /(.*?\s)\[/g) {
			my ($where, $prefix) = ($-[1], $1);
			if ($prefix !~ /$Type\s+$/ &&
			    ($where != 0 || $prefix !~ /^.\s+$/) &&
			    $prefix !~ /[{,]\s+$/) {
				ERROR("bracket-space",
				    "space prohibited before open square bracket '['\n");
			}
		}

# check for spaces between functions and their parentheses.
		while ($func_parenthesis_space &&
		    $line =~ /($Ident)\s+\(/g) {
			my $name = $1;
			my $ctx_before = substr($line, 0, $-[1]);
			my $ctx = "$ctx_before$name";

			# Ignore those directives where spaces _are_ permitted.
			if ($name =~ /^(?:
				if|for|while|switch|return|case|
				volatile|__volatile__|
				__attribute__|format|__extension__|
				asm|__asm__)$/x) {
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
				WARN("func-parenthesis-space",
				    "space prohibited between function name and open parenthesis\n");
			}
		}

# Check operator spacing.
		if ($op_spacing &&
		    !($line=~/\#\s*include/)) {
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
						ERROR("op-spacing",
						    "space required after that '$op'\n");
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
						if (ERROR("op-spacing",
						    "spaces prohibited around that '$op'\n")) {
							if (defined $fix_elements[$n + 2]) {
    								$fix_elements[$n + 2] =~ s/^\s+//;
    							}
						}
					}

				# , must not have a space before and must have a space on the right.
				} elsif ($op eq ',') {
					if ($ctx =~ /Wx./) {
						ERROR("op-spacing",
						    "space prohibited before that '$op'\n");
					}
					if ($ctx !~ /.x[WEC]/ && $cc !~ /^}/) {
						ERROR("op-spacing",
						    "space required after that '$op'\n");
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
					if ($ctx !~ /[WEBC]x./ &&
					    $ca !~ /(?:\)|!|~|\*|-|\+|\&|\||\+\+|\-\-|\{)$/) {
						ERROR("op-spacing",
						    "space required before that '$op'\n");
					}
					if ($op eq '*' && $cc =~/\s*$Modifier\b/) {
						# A unary '*' may be const

					} elsif ($ctx =~ /.xW/) {
						if (ERROR("op-spacing",
						    "space prohibited after that '$op'\n")) {
							if (defined $fix_elements[$n + 2]) {
    								$fix_elements[$n + 2] =~ s/^\s+//;
    							}
						}
					}

				# unary ++ and unary -- are allowed no space on one side.
				} elsif ($op eq '++' or $op eq '--') {
					if ($ctx !~ /[WEOBC]x[^W]/ && $ctx !~ /[^W]x[WOBEC]/) {
						ERROR("op-spacing",
						    "space required one side of that '$op'\n");
					}
					if ($ctx =~ /Wx[BE]/ ||
					    ($ctx =~ /Wx./ && $cc =~ /^;/)) {
						ERROR("op-spacing",
						    "space prohibited before that '$op'\n");
					}
					if ($ctx =~ /ExW/) {
						if (ERROR("op-spacing",
						    "space prohibited after that '$op'\n")) {
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
				    $op eq '%') {
					my $force_check = 1;
					if ($force_check) {
						if (defined $fix_elements[$n + 2] && $ctx !~ /[EW]x[EW]/) {
							if (ERROR("op-spacing",
							    "spaces preferred around that '$op'\n")) {
								$fix_elements[$n + 2] =~ s/^\s+//;
							}
						} elsif (!defined $fix_elements[$n + 2] && $ctx !~ /Wx[OE]/) {
							ERROR("op-spacing",
							    "space preferred before that '$op'\n");
						}
					} elsif ($ctx =~ /Wx[^WCE]|[^WCE]xW/) {
						if (ERROR("op-spacing",
						    "need consistent spacing around '$op'\n")) {
							if (defined $fix_elements[$n + 2]) {
    								$fix_elements[$n + 2] =~ s/^\s+//;
    							}
						}
					}

				# A colon needs no spaces before when it is
				# terminating a case value or a label.
				} elsif ($opv eq ':C' || $opv eq ':L') {
					if ($ctx =~ /Wx./) {
						ERROR("op-spacing",
						    "space prohibited before that '$op'\n");
					}

				# All the others need spaces both sides.
				} elsif ($ctx !~ /[EWC]x[CWE]/) {
					my $ok = 0;

					# Ignore email addresses <foo@bar>
					if (($op eq '<' &&
					     $cc =~ /^\S+\@\S+>/) ||
					    ($op eq '>' &&
					     $ca =~ /<\S+\@\S+$/)) {
						$ok = 1;
					}

					# for asm volatile statements
					# ignore a colon with another
					# colon immediately before or after
					if (($op eq ':') &&
					    ($ca =~ /:$/ || $cc =~ /^:/)) {
						$ok = 1;
					}

					if (!$ok) {
						if (ERROR("op-spacing",
						    "spaces required around that '$op'\n")) {
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
		if ($semicolon_space &&
		    $line =~ /^\+.*\S\s+;\s*$/) {
			WARN("semicolon-space",
			    "space prohibited before semicolon\n");
		}

# check for multiple assignments
		if ($multiple_assignments &&
		    $line =~ /^.\s*$Lval\s*=\s*$Lval\s*=(?!=)/) {
			WARN("multiple-assignments",
			    "multiple assignments should be avoided\n");
		}

# NOTE: Can be useful
# check for multiple declarations, allowing for a function declaration
# continuation.
		# if ($line =~ /^.\s*$Type\s+$Ident(?:\s*=[^,{]*)?\s*,\s*$Ident.*/ &&
		#     $line !~ /^.\s*$Type\s+$Ident(?:\s*=[^,{]*)?\s*,\s*$Type\s*$Ident.*/) {
		#
		# 	# Remove any bracketed sections to ensure we do not
		# 	# falsly report the parameters of functions.
		# 	my $ln = $line;
		# 	while ($ln =~ s/\([^\(\)]*\)//g) {
		# 	}
		# 	if ($ln =~ /,/) {
		# 		WARN("multiple-declaration",
		# 		     "declaring multiple variables together should be avoided\n");
		# 	}
		# }

#need space before brace following if, while, etc
		if ($space_open_brace &&
		    ($line =~ /\(.*\)\{/ && $line !~ /\($Type\)\{/) ||
		    $line =~ /do\{/) {
			ERROR("space-open-brace",
			    "space required before the open brace\n");
		}

# check for blank lines before declarations
		if ($blank_before_decl &&
		    $line =~ /^.\t+$Type\s+$Ident(?:\s*=.*)?;/ &&
		    $prevrawline =~ /^.\s*$/) {
			WARN("blank-before-decl",
			     "No blank lines before declarations\n");
		}


# closing brace should have a space following it when it has anything
# on the line
		if ($close_brace_space &&
		    $line =~ /}(?!(?:,|;|\)))\S/) {
			ERROR("close-brace-space",
			    "space required after that close brace\n");;
		}

# check spacing on square brackets
		if ($bracket_space_in &&
		    $line =~ /\[\s/ && $line !~ /\[\s*$/) {
			ERROR("bracket-space-in",
			    "space prohibited after that open square bracket\n");
		}
		if ($bracket_space_in &&
		    $line =~ /\s\]/) {
			ERROR("bracket-space-in",
			    "space prohibited before that close square bracket\n");
		}

# check spacing on parentheses
		if ($parenthesis_space_in &&
		    $line =~ /\(\s/ && $line !~ /\(\s*(?:\\)?$/ &&
		    $line !~ /for\s*\(\s+;/) {
			ERROR("parenthesis-space-in",
			    "space prohibited after that open parenthesis\n");
		}
		if ($parenthesis_space_in &&
		    $line =~ /(\s+)\)/ && $line !~ /^.\s*\)/ &&
		    $line !~ /for\s*\(.*;\s+\)/ &&
		    $line !~ /:\s+\)/) {
			ERROR("parenthesis-space-in",
			    "space prohibited before that close parenthesis\n");
		}

# check unnecessary parentheses around addressof/dereference single $Lvals
# ie: &(foo->bar) should be &foo->bar and *(foo->bar) should be *foo->bar

		while ($unnecessary_parentheses &&
		    $line =~ /(?:[^&]&\s*|\*)\(\s*($Ident\s*(?:$Member\s*)+)\s*\)/g) {
			my $var = $1;
			WARN("unnecessary-parentheses",
			    "Unnecessary parentheses around $var\n");
		}

# check for unnecessary parentheses around function pointer uses
# ie: (foo->bar)(); should be foo->bar();
# but not "if (foo->bar) (" to avoid some false positives
		if ($unnecessary_parentheses &&
		    $line =~ /(\bif\s*|)(\(\s*$Ident\s*(?:$Member\s*)+\))[ \t]*\(/ &&
		    $1 !~ /^if/) {
			my $var = $2;
			WARN("unnecessary-parentheses",
			    "Unnecessary parentheses around function pointer $var\n");
		}

#goto labels aren't indented, allow a single space however
		if ($indented_label &&
		    $line=~/^.\s+[A-Za-z\d_]+:(?![0-9]+)/ &&
		    !($line=~/^. [A-Za-z\d_]+:/) &&
		    !($line=~/^.\s+(?:default|case):/)) {
			WARN("indented-label",
			    "labels should not be indented\n");
		}

# return needs parentheses
		if (defined($stat) && $stat !~ /^.\s*return\s*;\s*$/ && $stat =~ /^.\s*return(\s*).*/s) {
			my $spacing = $1;
			if ($^V && $^V ge 5.10.0 &&
			    $stat !~ /^.\s*return\s*($balanced_parens)\s*;\s*$/) {
				my $value = $1;
				$value = deparenthesize($value);
				if ($ret_parentheses &&
				    $value =~ m/^\s*$FuncArg\s*(?:\?)|$/) {
					ERROR("ret-parentheses",
					      "parentheses are required on a return statement\n");
				}
			} elsif ($ret_space && $spacing !~ /\s+/) {
				ERROR("ret-space",
				      "space required before the open parenthesis\n");
			}
		}

# unnecessary return in a void function
# at end-of-function, with the previous line a single leading tab, then return;
# and the line before that not a goto label target like "out:"
		if ($return_void &&
		    $sline =~ /^[ \+]}\s*$/ &&
		    $prevline =~ /^\+\treturn\s*;\s*$/ &&
		    $linenr >= 3 &&
		    $lines[$linenr - 3] =~ /^[ +]/ &&
		    $lines[$linenr - 3] !~ /^[ +]\s*$Ident\s*:/) {
			my $tmpline = $realline - 1;
			$prefix = "$realfile:$tmpline: ";
			WARN("return-void",
			    "void function return statements are not generally useful\n");
		}

# if statements using unnecessary parentheses - ie: if ((foo == bar))
		if ($unnecessary_parentheses &&
		    $^V && $^V ge 5.10.0 &&
		    $line =~ /\bif\s*((?:\(\s*){2,})/) {
			my $openparens = $1;
			my $count = $openparens =~ tr@\(@\(@;
			my $msg = "";
			if ($line =~ /\bif\s*(?:\(\s*){$count,$count}$LvalOrFunc\s*($Compare)\s*$LvalOrFunc(?:\s*\)){$count,$count}/) {
				my $comp = $4;	#Not $1 because of $LvalOrFunc
				$msg = " - maybe == should be = ?" if ($comp eq "==");
				WARN("unnecessary-parentheses",
				    "Unnecessary parentheses$msg\n");
			}
		}

# comparisons with a constant or upper case identifier on the left
#	avoid cases like "foo + BAR < baz"
#	only fix matches surrounded by parentheses to avoid incorrect
#	conversions like "FOO < baz() + 5" being "misfixed" to "baz() > FOO + 5"
		if ($const_comp &&
		    $^V && $^V ge 5.10.0 &&
		    $line =~ /^\+(.*)\b($Constant|[A-Z_][A-Z0-9_]*)\s*($Compare)\s*($LvalOrFunc)/) {
			my $lead = $1;
			my $const = $2;
			my $comp = $3;
			my $to = $4;
			if ($lead !~ /(?:$Operators|\.)\s*$/ &&
			    $to !~ /^(?:Constant|[A-Z_][A-Z0-9_]*)$/) {
				WARN("const-comp",
				    "Comparisons should place the constant on the right side of the test\n");
			}
		}

# Need a space before open parenthesis after if, while etc
		if ($ctrl_space &&
		    $line =~ /\b(if|while|for|switch)\(/) {
			ERROR("ctrl-space",
			    "space required before the open parenthesis\n");
		}

# Check for illegal assignment in if conditional -- and check for trailing
# statements after the conditional.
		if ($line =~ /do\s*(?!{)/) {
			($stat, $cond, $line_nr_next, $remain_next, $off_next) =
			    ctx_statement_block($linenr, $realcnt, 0)
			    if (!defined $stat);
			my ($stat_next) = ctx_statement_block($line_nr_next, $remain_next, $off_next);
			$stat_next =~ s/\n./\n /g;

			if ($stat_next =~ /^\s*while\b/) {
				# If the statement carries leading newlines,
				# then count those as offsets.
				my ($whitespace) = ($stat_next =~ /^((?:\s*\n[+-])*\s*)/s);
				my $offset = statement_rawlines($whitespace) - 1;

				$suppress_whiletrailers{$line_nr_next + $offset} = 1;
			}
		}
		if (!defined $suppress_whiletrailers{$linenr} &&
		    defined($stat) && defined($cond) &&
		    $line =~ /\b(?:if|while|for)\s*\(/ && $line !~ /^.\s*#/) {
			my ($s, $c) = ($stat, $cond);

			if ($assign_in_if &&
			    $c =~ /\bif\s*\(.*[^<>!=]=[^=].*/s) {
				ERROR("assign-in-if",
				    "do not use assignment in if condition\n");
			}

			# Find out what is on the end of the line after the
			# conditional.
			substr($s, 0, length($c), '');
			$s =~ s/\n.*//g;
			$s =~ s/$;//g; 	# Remove any comments
			if (length($c) &&
			    length($s) > 1 &&
			    $s !~ /^\s*{?\s*\\*\s*$/ &&
			    $c !~ /}\s*while\s*/) {
				# Find out how long the conditional actually is.
				my @newlines = ($c =~ /\n/gs);
				my $cond_lines = 1 + $#newlines;
				my $stat_real = '';

				$stat_real = raw_line($linenr, $cond_lines)
							. "\n" if ($cond_lines);
				if (defined($stat_real) && $cond_lines > 1) {
					$stat_real = "[...]\n$stat_real";
				}

				if ($trailing_statements) {
					ERROR("trailing-statements",
					    "trailing statements should be on next line\n" .
					    $stat_real);
				}
			}
		}

# Check for bitwise tests written as boolean
		if ($hexa_bool_test &&
		    $line =~ /(?:
				(?:\[|\(|\&\&|\|\|)
				\s*0[xX][0-9]+\s*
				(?:\&\&|\|\|)
			|
				(?:\&\&|\|\|)
				\s*0[xX][0-9]+\s*
				(?:\&\&|\|\||\)|\])
			)/x) {
			WARN("hexa-bool-test",
			    "boolean test with hexadecimal, perhaps just 1 \& or \|?\n");
		}

# if and else should not have general statements after it
		if ($trailing_statements &&
		    $line =~ /^.\s*(?:}\s*)?else\b(.*)/) {
			my $s = $1;
			$s =~ s/$;//g; # Remove any comments
			if ($s !~ /^\s*(?:\sif|(?:{|)\s*\\?\s*$)/) {
				ERROR("trailing-statements",
				    "trailing statements should be on next line\n");
			}
		}
# if should not continue a brace
		if ($if_after_brace &&
		    $line =~ /}\s*if\b/) {
			ERROR("if-after-brace",
			    "'if' should not follow a closing brace\n");
		}
# case and default should not have general statements after them
		if ($trailing_statements &&
		    $line =~ /^.\s*(?:case\s*.*|default\s*):/g &&
		    $line !~ /\G(?:
			(?:\s*$;*)(?:\s*{)?(?:\s*$;*)(?:\s*\\)?\s*$|
			\s*return\s+
		    )/xg) {
			ERROR("trailing-statements",
			    "trailing statements should be on next line\n");
		}

		if ($else_after_brace &&
		    $line=~/^.\s*}\s*else\s*/ &&
		    $previndent == $indent) {
			ERROR("else-after-brace",
			    "else statement following close brace should be on the next line\n");
		}

		if ($while_after_brace &&
		    $prevline=~/}\s*$/ &&
		    $line=~/^.\s*while\s*/ &&
		    $previndent == $indent) {
			my ($s, $c) = ctx_statement_block($linenr, $realcnt, 0);

			# Find out what is on the end of the line after the
			# conditional.
			substr($s, 0, length($c), '');
			$s =~ s/\n.*//g;

			if ($s =~ /^\s*;/) {
				ERROR("while-after-brace",
				    "while should follow close brace '}'\n");
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
					if (!defined $camelcase_hash{$word}) {
						$camelcase_hash{$word} = 1;
						if ($camelcase) {
							WARN("camelcase",
							    "Avoid CamelCase: <$word>\n");
						}
					}
				}
			}
		}

#no spaces allowed after \ in define
		if ($whitespace_continuation &&
		    $line =~ /\#\s*define.*\\\s+$/) {
			WARN("whitespace-continuation",
			    "Whitespace after \\ makes next lines useless\n");
		}

# multi-statement macros should be enclosed in a do while loop, grab the
# first statement and ensure its the whole macro if its not enclosed
# in a known good container
		if ($line =~ /^.\s*\#\s*define\s*$Ident(\()?/) {
			my $ln = $linenr;
			my $cnt = $realcnt;
			my ($off, $dstat, $dcond, $rest);
			my $ctx = '';
			my $has_flow_statement = 0;
			my $has_arg_concat = 0;
			($dstat, $dcond, $ln, $cnt, $off) = ctx_statement_block($linenr, $realcnt, 0);
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
			       $dstat =~ s/.\[[^\[\]]*\]/1/) {}

			# Flatten any obvious string concatentation.
			while ($dstat =~ s/($String)\s*$Ident/$1/ ||
			       $dstat =~ s/$Ident\s*($String)/$1/) {}

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
			    $ctx !~ /^.\s*#\s*define\s+TRACE_(?:SYSTEM|INCLUDE_FILE|INCLUDE_PATH)\b/) {
				$ctx =~ s/\n*$//;

				if ($dstat =~ /;/) {
					if ($multistatement_macro) {
						ERROR("multistatement-macro",
						    "Macros with multiple statements should be enclosed in a do/while loop\n");
					}
				} else {
					if ($complex_macro) {
						ERROR("complex-macro",
						    "Macros with complex values should be enclosed in parentheses\n");
					}
				}
			}

# check for macros with flow control, but without ## concatenation
# ## concatenation is commonly a macro that defines a function so ignore those
			if ($macro_flow_control &&
			    $has_flow_statement &&
			    !$has_arg_concat) {
				WARN("macro-flow-control",
				    "Macros with flow control statements should be avoided\n");
			}

# check for line continuations outside of #defines, preprocessor #, and asm

		} else {
			if ($line_continuation &&
			    $prevline !~ /^..*\\$/ &&
			    $line !~ /^\+\s*\#.*\\$/ && # preprocessor
			    $line !~ /^\+.*\b(__asm__|asm)\b.*\\$/ && # asm
			    $line =~ /^\+.*\\$/) {
				WARN("line-continuation",
				    "Avoid unnecessary line continuations\n");
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
			($dstat, $dcond, $ln, $cnt, $off) = ctx_statement_block($linenr, $realcnt, 0);
			$ctx = $dstat;

			$dstat =~ s/\\\n.//g;
			$dstat =~ s/$;/ /g;

			if ($dstat =~ /^\+\s*#\s*define\s+$Ident\s*${balanced_parens}\s*do\s*{(.*)\s*}\s*while\s*\(\s*0\s*\)\s*([;\s]*)\s*$/) {
				my $stmts = $2;
				my $semis = $3;

				$ctx =~ s/\n*$//;

				if ($single_statement_macro &&
				    ($stmts =~ tr/;/;/) == 1 &&
				    $stmts !~ /^\s*(if|while|for|switch)\b/) {
					WARN("single-statement-macro",
					    "Single statement macros should not use a do/while loop\n");
				}
				if ($macro_semicolon &&
				    defined $semis &&
				    $semis ne "") {
					WARN("macro-semicolon",
					    "macros should not be semicolon terminated\n");
				}
			} elsif ($dstat =~ /^\+\s*#\s*define\s+$Ident.*;\s*$/) {
				$ctx =~ s/\n*$//;

				if ($macro_semicolon) {
					WARN("macro-semicolon",
					    "macros should not be semicolon terminated\n");
				}
			}
		}

# check for redundant bracing round if etc
		if ($line =~ /(^.*)\bif\b/ && $1 !~ /else\s*$/) {
			my ($level, $endln, @chunks) = ctx_statement_full($linenr, $realcnt, 1);
			if ($#chunks > 0 && $level == 0) {
				my @allowed = ();
				my $allow = 0;
				my $seen = 0;
				my $ln = $linenr - 1;
				for my $chunk (@chunks) {
					my ($cond, $block) = @{$chunk};

					# If the condition carries leading newlines, then count those as offsets.
					my ($whitespace) = ($cond =~ /^((?:\s*\n[+-])*\s*)/s);
					my $offset = statement_rawlines($whitespace) - 1;

					$allowed[$allow] = 0;

					# We have looked at and allowed this specific line.
					$suppress_ifbraces{$ln + $offset} = 1;

					$ln += statement_rawlines($block) - 1;

					substr($block, 0, length($cond), '');

					$seen++ if ($block =~ /^\s*{/);

					if (statement_lines($cond) > 1) {
						$allowed[$allow] = 1;
					}
					if ($block =~/\b(?:if|for|while)\b/) {
						$allowed[$allow] = 1;
					}
					if (statement_block_size($block) > 1) {
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
						if ($unnecessary_braces) {
							WARN("unnecessary-braces",
							    "braces are not necessary for any arm of this statement\n");
						}
					} elsif ($sum_allowed != $allow &&
						 $seen != $allow) {
						if ($necessary_braces) {
							WARN("necessary-braces",
							    "braces should be used on all arms of this statement\n");
						}
					}
				}
			}
		}
		if (!defined $suppress_ifbraces{$linenr - 1} &&
		    $line =~ /\b(if|while|for|else)\b/) {
			my $allowed = 0;

			# Check the pre-context.
			if (substr($line, 0, $-[0]) =~ /(\}\s*)$/) {
				$allowed = 1;
			}

			my ($level, $endln, @chunks) = ctx_statement_full($linenr, $realcnt, $-[0]);

			# Check the condition.
			my ($cond, $block) = @{$chunks[0]};
			if (defined $cond) {
				substr($block, 0, length($cond), '');
			}
			if (statement_lines($cond) > 1) {
				$allowed = 1;
			}
			if ($block =~/\b(?:if|for|while)\b/) {
				$allowed = 1;
			}
			if (statement_block_size($block) > 1) {
				$allowed = 1;
			}
			# Check the post-context.
			if (defined $chunks[1]) {
				my ($cond, $block) = @{$chunks[1]};
				if (defined $cond) {
					substr($block, 0, length($cond), '');
				}
				if ($block =~ /^\s*\{/) {
					$allowed = 1;
				}
			}
			if (!$level && $block =~ /^\s*\{/ && !$allowed) {
				if ($unnecessary_braces) {
					WARN("unnecessary-braces",
					    "braces are not necessary for single statement blocks\n");
				}
			}
		}

# check for unnecessary blank lines around braces
		if ($blank_line_brace &&
		    $line =~ /^.\s*}\s*$/ &&
		    $prevrawline =~ /^.\s*$/) {
			WARN("blank-line-brace",
			    "Blank lines aren't necessary before a close brace\n");
		}
		if ($blank_line_brace &&
		    $rawline =~ /^.\s*$/ &&
		    $prevline =~ /^..*{\s*$/) {
			WARN("blank-line-brace",
			    "Blank lines aren't necessary after an open brace\n");
		}

# no volatiles please
		my $asm_volatile = qr{\b(__asm__|asm)\s+(__volatile__|volatile)\b};
		if ($volatile &&
		    $line =~ /\bvolatile\b/ &&
		    $line !~ /$asm_volatile/) {
			WARN("volatile",
			    "Use of volatile is usually wrong\n");
		}

# Check for user-visible strings broken across lines, which breaks the ability
# to grep for the string.  Make exceptions when the previous string ends in a
# newline (multiple lines in one string constant) or '\t', '\r', ';', or '{'
# (common in inline assembly) or is a octal \123 or hexadecimal \xaf value
		if ($string_split &&
		    $line =~ /^\+\s*$String/ &&
		    $prevline =~ /"\s*$/ &&
		    $prevrawline !~ /(?:\\(?:[ntr]|[0-7]{1,3}|x[0-9a-fA-F]{1,2})|;\s*|\{\s*)"\s*$/) {
			WARN("string-split",
			    "quoted string split across lines\n");
		}

# check for missing a space in a string concatenation
		if ($string_missing_space &&
		    $prevrawline =~ /[^\\]\w"$/ &&
		    $rawline =~ /^\+[\t ]+"\w/) {
			WARN('string-missing-space',
			    "break quoted strings at a space character\n");
		}

# check for spaces before a quoted newline
		if ($string_space_new_line &&
		    $rawline =~ /^.*\".*\s\\n/) {
			WARN("string-space-new-line",
			    "unnecessary whitespace before a quoted newline\n");
		}

# concatenated string without spaces between elements
		if ($string_concat &&
		    ($line =~ /$String[A-Z_]/ || $line =~ /[A-Za-z0-9_]$String/)) {
			WARN("string-concat",
			    "Concatenated strings should use spaces between elements\n");
		}

# uncoalesced string fragments
		if ($string_fragments &&
		    $line =~ /$String\s*"/) {
			WARN("string-fragments",
			    "Consecutive strings are generally better as a single string\n");
		}

# check for %L{u,d,i} and 0x%[udi] in strings
		my $string;
		while ($line =~ /(?:^|")([X\t]*)(?:"|$)/g) {
			$string = substr($rawline, $-[1], $+[1] - $-[1]);
			$string =~ s/%%/__/g;
			if ($printf_l &&
			    $string =~ /(?<!%)%[\*\d\.\$]*L[udi]/) {
				WARN("printf-l",
				    "\%Ld/\%Lu are not-standard C, use \%lld/\%llu\n");
				last;
			}
			if ($printf_0xdecimal &&
			    $string =~ /0x%[\*\d\.\$\Llzth]*[udi]/) {
				ERROR("printf-0xdecimal",
				    "Prefixing 0x with decimal output is defective\n");
			}
		}

# check for line continuations in quoted strings with odd counts of "
		if ($string_line_continuation &&
		    $rawline =~ /\\$/ &&
		    $rawline =~ tr/"/"/ % 2) {
			WARN("string-line-continuation",
			    "Avoid line continuations in quoted strings\n");
		}

# warn about #if 0
		if ($redundant_code &&
		    $line =~ /^.\s*\#\s*if\s+0\b/) {
			WARN("redundant-code",
			    "if this code is redundant consider removing it\n");
		}

# check for mask then right shift without a parentheses
		if ($mask_then_shift &&
		    $^V && $^V ge 5.10.0 &&
		    $line =~ /$LvalOrFunc\s*\&\s*($LvalOrFunc)\s*>>/ &&
		    $4 !~ /^\&/) { # $LvalOrFunc may be &foo, ignore if so
			WARN("mask-then-shift",
			    "Possible precedence defect with mask then right shift - may need parentheses\n");
		}

# check for pointer comparisons to NULL
		if ($null_comparison &&
		    $^V && $^V ge 5.10.0) {
			while ($line =~ /\b$LvalOrFunc\s*(==|\!=)\s*NULL\b/g) {
				my $val = $1;
				my $equal = "!";
				$equal = "" if ($4 eq "!=");
				WARN("null-comparison",
				    "Comparison to NULL could be written \"${equal}${val}\"\n");
			}
		}

# warn about spacing in #ifdefs
		if ($preproc_if_space &&
		    $line =~ /^.\s*\#\s*(ifdef|ifndef|elif)\s\s+/) {
			ERROR("preproc-if-space",
			    "exactly one space required after that #$1\n");
		}

# Check that the storage class is at the beginning of a declaration
		if ($storage_class &&
		    $line =~ /\b$Storage\b/ &&
		    $line !~ /^.\s*$Storage\b/) {
			WARN("storage-class",
			    "storage class should be at the beginning of the declaration\n");
		}

# check the location of the inline attribute, that it is between
# storage class and type.
		if ($inline_location &&
		    ($line =~ /\b$Type\s+$Inline\b/ ||
		     $line =~ /\b$Inline\s+$Storage\b/)) {
			ERROR("inline-location",
			    "inline keyword should sit between storage class and type\n");
		}

# Check for __inline__ and __inline, prefer inline
		if ($prefer_inline &&
		    $line =~ /\b(__inline__|__inline)\b/) {
			WARN("prefer-inline",
			    "plain inline is preferred over $1\n");
		}

# Check for __attribute__ packed, prefer __packed
		if ($prefer_packed &&
		    $line =~ /\b__attribute__\s*\(\s*\(.*\bpacked\b/) {
			WARN("prefer-packed",
			    "__packed is preferred over __attribute__((packed))\n");
		}

# Check for __attribute__ aligned, prefer __aligned
		if ($prefer_aligned &&
		    $line =~ /\b__attribute__\s*\(\s*\(.*aligned/) {
			WARN("prefer-aligned",
			    "__aligned(size) is preferred over __attribute__((aligned(size)))\n");
		}

# Check for __attribute__ weak, or __weak declarations (may have link issues)
		if ($weak_declaration &&
		    $^V && $^V ge 5.10.0 &&
		    $line =~ /(?:$Declare|$DeclareMisordered)\s*$Ident\s*$balanced_parens\s*(?:$Attribute)?\s*;/ &&
		    ($line =~ /\b__attribute__\s*\(\s*\(.*\bweak\b/ ||
		     $line =~ /\b__weak\b/)) {
			ERROR("weak-declaration",
			    "Using weak declarations can have unintended link defects\n");
		}

# check for cast of C90 native int or longer types constants
		if ($cast_int_const &&
		    $line =~ /(\(\s*$C90_int_types\s*\)\s*)($Constant)\b/) {
			WARN("cast-int-const",
			    "Unnecessary typecast of c90 int constant\n");
		}

# check for sizeof(&)
		if ($sizeof_address &&
		    $line =~ /\bsizeof\s*\(\s*\&/) {
			WARN("sizeof-address",
			    "sizeof(& should be avoided\n");
		}

# check for sizeof without parenthesis
		if ($sizeof_parenthesis &&
		    $line =~ /\bsizeof\s+((?:\*\s*|)$Lval|$Type(?:\s+$Lval|))/) {
			WARN("sizeof-parenthesis",
			    "sizeof $1 should be sizeof($1)\n");
		}

# check for new externs in .h files.
		if ($header_externs &&
		    $realfile =~ /\.h$/ &&
		    $line =~ /^\+\s*(extern\s+)$Type\s*$Ident\s*\(/s) {
			WARN("header-externs",
			    "extern prototypes should be avoided in .h files\n");
		}

# check for new externs in .c files.
		if ($realfile =~ /\.c$/ && defined $stat &&
		    ($stat =~ /^.\s*(?:extern\s+)?$Type\s+($Ident)(\s*)\(/s ||
		    $stat =~ /^.\s*(?:extern\s+)?$Type\s+(?:\**)?($Ident)(\s*)\(/)) {
			my $function_name = $1;
			my $paren_space = $2;

			my $s = $stat;
			if (defined $cond) {
				substr($s, 0, length($cond), '');
			}
			if ($avoid_externs &&
			    $s =~ /^\s*;/ &&
			    $function_name ne 'uninitialized_var') {
				WARN("avoid-externs",
				    "externs should be avoided in .c files\n");
			}

			if ($func_args &&
			    $paren_space =~ /\n/) {
				WARN("func-args",
				    "arguments for function declarations should follow identifier\n");
			}

		} elsif ($avoid_externs &&
		    $realfile =~ /\.c$/ &&
		    defined $stat &&
		    $stat =~ /^.\s*extern\s+/) {
			WARN("avoid-externs",
			    "externs should be avoided in .c files\n");
		}

		# check for new typedefs in source files
		if ($typedefs &&
		    $realfile =~ /\.c$/ &&
		    $line =~ /\btypedef\s/ &&
		    $line !~ /\btypedef\s+$Type\s*\(\s*\*?$Ident\s*\)\s*\(/ &&
		    $line !~ /\btypedef\s+$Type\s+$Ident\s*\(/ &&
		    $line !~ /\b$typeTypedefs\b/ &&
		    $line !~ /\b__bitwise(?:__|)\b/) {
			WARN("typedefs",
			    "typedefs should be avoided in .c files\n");
		}

# check for multiple semicolons
		if ($single_semicolon &&
		    $line =~ /;\s*;\s*$/) {
			WARN("single-semicolon",
			    "Statements terminations use 1 semicolon\n");
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
			if ($missing_break &&
			    !$has_break && $has_statement) {
				WARN("missing-break",
				    "Possible switch case/default not preceeded by break or fallthrough comment\n");
			}
		}

# check for switch/default statements without a break;
		if ($^V && $^V ge 5.10.0 &&
		    defined $stat &&
		    $stat =~ /^\+[$;\s]*(?:case[$;\s]+\w+[$;\s]*:[$;\s]*|)*[$;\s]*\bdefault[$;\s]*:[$;\s]*;/g) {
			if ($default_no_break) {
				WARN("default-no-break",
				    "switch default: should use break\n");
			}
		}
	}

	# If we have no input at all, then there is nothing to report on
	# so just keep quiet.
	exit(0) if ($#rawlines == -1);

	if (!$clean) {
		print "$realfile:\n";
		print " " x 4, join(" " x 4, report_dump());
	}

	if ($verbose) {
		if ($clean) {
			print "$realfile has no obvious style problems.\n";
		} else {
			print "$realfile has style problems, please review.\n";
		}
	}
	return $clean;
}
