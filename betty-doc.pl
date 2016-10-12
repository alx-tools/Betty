#!/usr/bin/perl -w

use strict;

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

my $V = '1.0';

sub printVersion {

	print STDOUT << "EOM";
Version: $V
EOM
	exit(0);
}

sub usage {
    my $message = <<"EOF";
Usage: $0 [OPTION ...] FILE ...

Read C language source or header FILEs, extract embedded documentation comments,
and print STDOUT formatted documentation to standard output.

The documentation comments are identified by "/**" opening comment mark. See
Documentation/kernel-doc-nano-HOWTO.txt for the documentation comment syntax.

Output format selection (mutually exclusive):
  -docbook		Output DocBook format.
  -html			Output HTML format.
  -html5		Output HTML5 format.
  -list			Output symbol list format. This is for use by docproc. This is the default.
  -man			Output troff manual page format.
  -rst			Output reStructuredText format.
  -text			Output plain text format.

Output selection (mutually exclusive):
  -function NAME	Only output documentation for the given function(s)
			or DOC: section title(s). All other functions and DOC:
			sections are ignored. May be specified multiple times.
  -nofunction NAME	Do NOT output documentation for the given function(s);
			only output documentation for the other functions and
			DOC: sections. May be specified multiple times.

Output selection modifiers:
  -no-doc-sections	Do not output DOC: sections.

Other parameters:
  -v			Verbose output, more warnings and other information.
  -h			print STDOUT this help.

EOF
    print STDOUT $message;
    exit 1;
}

#
# format of comments.
# In the following table, (...)? signifies optional structure.
#                         (...)* signifies 0 or more structure elements
# /**
#  * function_name(:)? (- short description)?
# (* @parameterx: (description of parameter x)?)*
# (* a blank line)?
#  * (Description:)? (Description of function)?
#  * (section header: (section description)? )*
#  (*)?*/
#
# So .. the trivial example would be:
#
# /**
#  * my_function
#  */
#
# If the Description: header tag is omitted, then there must be a blank line
# after the last parameter specification.
# e.g.
# /**
#  * my_function - does my stuff
#  * @my_arg: its mine damnit
#  *
#  * Does my stuff explained.
#  */
#
#  or, could also use:
# /**
#  * my_function - does my stuff
#  * @my_arg: its mine damnit
#  * Description: Does my stuff explained.
#  */
# etc.
#
# Besides functions you can also write documentation for structs, unions,
# enums and typedefs. Instead of the function name you must write the name
# of the declaration;  the struct/union/enum/typedef must always precede
# the name. Nesting of declarations is not supported.
# Use the argument mechanism to document members or constants.
# e.g.
# /**
#  * struct my_struct - short description
#  * @a: first member
#  * @b: second member
#  *
#  * Longer description
#  */
# struct my_struct {
#     int a;
#     int b;
# /* private: */
#     int c;
# };
#
# All descriptions can be multiline, except the short function description.
#
# For really longs structs, you can also describe arguments inside the
# body of the struct.
# eg.
# /**
#  * struct my_struct - short description
#  * @a: first member
#  * @b: second member
#  *
#  * Longer description
#  */
# struct my_struct {
#     int a;
#     int b;
#     /**
#      * @c: This is longer description of C
#      *
#      * You can use paragraphs to describe arguments
#      * using this method.
#      */
#     int c;
# };
#
# This should be use only for struct/enum members.
#
# You can also add additional sections. When documenting kernel functions you
# should document the "Context:" of the function, e.g. whether the functions
# can be called form interrupts. Unlike other sections you can end it with an
# empty line.
# A non-void function should have a "Return:" section describing the return
# value(s).
# Example-sections should contain the string EXAMPLE so that they are marked
# appropriately in DocBook.
#
# Example:
# /**
#  * user_function - function that can only be called in user context
#  * @a: some argument
#  * Context: !in_interrupt()
#  *
#  * Some description
#  * Example:
#  *    user_function(22);
#  */
# ...
#
#
# All descriptive text is further processed, scanning for the following special
# patterns, which are highlighted appropriately.
#
# 'funcname()' - function
# '$ENVVAR' - environmental variable
# '&struct_name' - name of a structure (up to two words including 'struct')
# '@parameter' - name of a parameter
# '%CONST' - name of a constant.

## init lots of data

my $errors = 0;
my $warnings = 0;
my $anon_struct_union = 0;

# match expressions used to find embedded type information
my $type_constant = '\%([-_\w]+)';
my $type_func = '(\w+)\(\)';
my $type_param = '\@(\w+)';
my $type_struct = '\&((struct\s*)*[_\w]+)';
my $type_struct_xml = '\\&amp;((struct\s*)*[_\w]+)';
my $type_env = '(\$\w+)';
my $type_enum_full = '\&(enum)\s*([_\w]+)';
my $type_struct_full = '\&(struct)\s*([_\w]+)';

# Output conversion substitutions.
#  One for each output format

# these work fairly well
my @highlights_html = (
                       [$type_constant, "<i>\$1</i>"],
                       [$type_func, "<b>\$1</b>"],
                       [$type_struct_xml, "<i>\$1</i>"],
                       [$type_env, "<b><i>\$1</i></b>"],
                       [$type_param, "<tt><b>\$1</b></tt>"]
                      );
my $local_lt = "\\\\\\\\lt:";
my $local_gt = "\\\\\\\\gt:";
my $blankline_html = $local_lt . "p" . $local_gt;	# was "<p>"

# html version 5
my @highlights_html5 = (
                        [$type_constant, "<span class=\"const\">\$1</span>"],
                        [$type_func, "<span class=\"func\">\$1</span>"],
                        [$type_struct_xml, "<span class=\"struct\">\$1</span>"],
                        [$type_env, "<span class=\"env\">\$1</span>"],
                        [$type_param, "<span class=\"param\">\$1</span>]"]
		       );
my $blankline_html5 = $local_lt . "br /" . $local_gt;

# XML, docbook format
my @highlights_xml = (
                      ["([^=])\\\"([^\\\"<]+)\\\"", "\$1<quote>\$2</quote>"],
                      [$type_constant, "<constant>\$1</constant>"],
                      [$type_struct_xml, "<structname>\$1</structname>"],
                      [$type_param, "<parameter>\$1</parameter>"],
                      [$type_func, "<function>\$1</function>"],
                      [$type_env, "<envar>\$1</envar>"]
		     );
my $blankline_xml = $local_lt . "/para" . $local_gt . $local_lt . "para" . $local_gt . "\n";

# gnome, docbook format
my @highlights_gnome = (
                        [$type_constant, "<replaceable class=\"option\">\$1</replaceable>"],
                        [$type_func, "<function>\$1</function>"],
                        [$type_struct, "<structname>\$1</structname>"],
                        [$type_env, "<envar>\$1</envar>"],
                        [$type_param, "<parameter>\$1</parameter>" ]
		       );
my $blankline_gnome = "</para><para>\n";

# these are pretty rough
my @highlights_man = (
                      [$type_constant, "\$1"],
                      [$type_func, "\\\\fB\$1\\\\fP"],
                      [$type_struct, "\\\\fI\$1\\\\fP"],
                      [$type_param, "\\\\fI\$1\\\\fP"]
		     );
my $blankline_man = "";

# text-mode
my @highlights_text = (
                       [$type_constant, "\$1"],
                       [$type_func, "\$1"],
                       [$type_struct, "\$1"],
                       [$type_param, "\$1"]
		      );
my $blankline_text = "";

# rst-mode
my @highlights_rst = (
                       [$type_constant, "``\$1``"],
                       [$type_func, "\\:c\\:func\\:`\$1`"],
                       [$type_struct_full, "\\:c\\:type\\:`\$1 \$2 <\$2>`"],
                       [$type_enum_full, "\\:c\\:type\\:`\$1 \$2 <\$2>`"],
                       [$type_struct, "\\:c\\:type\\:`struct \$1 <\$1>`"],
                       [$type_param, "**\$1**"]
		      );
my $blankline_rst = "\n";

# list mode
my @highlights_list = (
                       [$type_constant, "\$1"],
                       [$type_func, "\$1"],
                       [$type_struct, "\$1"],
                       [$type_param, "\$1"]
		      );
my $blankline_list = "";

# read arguments
if ($#ARGV == -1) {
    usage();
}

my $kernelversion;
my $dohighlight = "";

my $verbose = 0;
my $output_mode = "list";
my $output_preformatted = 0;
my $no_doc_sections = 0;
my @highlights = @highlights_list;
my $blankline = $blankline_list;
my $modulename = "Kernel API";
my $function_only = 0;
my $show_not_found = 0;

my @build_time;
if (defined($ENV{'KBUILD_BUILD_TIMESTAMP'}) &&
    (my $seconds = `date -d"${ENV{'KBUILD_BUILD_TIMESTAMP'}}" +%s`) ne '') {
    @build_time = gmtime($seconds);
} else {
    @build_time = localtime;
}

my $man_date = ('January', 'February', 'March', 'April', 'May', 'June',
		'July', 'August', 'September', 'October',
		'November', 'December')[$build_time[4]] .
  " " . ($build_time[5]+1900);

# Essentially these are globals.
# They probably want to be tidied up, made more localised or something.
# CAVEAT EMPTOR!  Some of the others I localised may not want to be, which
# could cause "use of undefined value" or other bugs.
my ($function, %function_table, %parametertypes, $declaration_purpose);
my ($type, $declaration_name, $return_type);
my ($newsection, $newcontents, $prototype, $brcount, %source_map);

if (defined($ENV{'KBUILD_VERBOSE'})) {
	$verbose = "$ENV{'KBUILD_VERBOSE'}";
}

# Generated docbook code is inserted in a template at a point where
# docbook v3.1 requires a non-zero sequence of RefEntry's; see:
# http://www.oasis-open.org/docbook/documentation/reference/html/refentry.html
# We keep track of number of generated entries and generate a dummy
# if needs be to ensure the expanded template can be postprocessed
# into html.
my $section_counter = 0;

my $lineprefix="";

# states
# 0 - normal code
# 1 - looking for function name
# 2 - scanning field start.
# 3 - scanning prototype.
# 4 - documentation block
# 5 - gathering documentation outside main block
my $state;
my $in_doc_sect;

# Split Doc State
# 0 - Invalid (Before start or after finish)
# 1 - Is started (the /** was found inside a struct)
# 2 - The @parameter header was found, start accepting multi paragraph text.
# 3 - Finished (the */ was found)
# 4 - Error - Comment without header was found. Spit a warning as it's not
#     proper kernel-doc and ignore the rest.
my $split_doc_state;

#declaration types: can be
# 'function', 'struct', 'union', 'enum', 'typedef'
my $decl_type;

my $doc_special = "\@\%\$\&";

my $doc_start = '^/\*\*\s*$'; # Allow whitespace at end of comment start.
my $doc_end = '\*/';
my $doc_com = '\s*\*\s*';
my $doc_com_body = '\s*\* ?';
my $doc_decl = $doc_com . '(\w+)';
my $doc_sect = $doc_com . '([' . $doc_special . ']?[\w\s]+):(.*)';
my $doc_content = $doc_com_body . '(.*)';
my $doc_block = $doc_com . 'DOC:\s*(.*)?';
my $doc_split_start = '^\s*/\*\*\s*$';
my $doc_split_sect = '\s*\*\s*(@[\w\s]+):(.*)';
my $doc_split_end = '^\s*\*/\s*$';

my %constants;
my %parameterdescs;
my @parameterlist;
my %sections;
my @sectionlist;
my $sectcheck;
my $struct_actual;

my $contents = "";
my $section_default = "Description";	# default section
my $section_intro = "Introduction";
my $section = $section_default;
my $section_context = "Context";
my $section_return = "Return";

my $undescribed = "-- undescribed --";

reset_state();

while ($ARGV[0] =~ m/^-(.*)/) {
    my $cmd = shift @ARGV;
		if ($cmd eq "--version") {
			printVersion();
    } elsif ($cmd eq "-html") {
	$output_mode = "html";
	@highlights = @highlights_html;
	$blankline = $blankline_html;
    } elsif ($cmd eq "-html5") {
	$output_mode = "html5";
	@highlights = @highlights_html5;
	$blankline = $blankline_html5;
    } elsif ($cmd eq "-man") {
	$output_mode = "man";
	@highlights = @highlights_man;
	$blankline = $blankline_man;
    } elsif ($cmd eq "-text") {
	$output_mode = "text";
	@highlights = @highlights_text;
	$blankline = $blankline_text;
    } elsif ($cmd eq "-rst") {
	$output_mode = "rst";
	@highlights = @highlights_rst;
	$blankline = $blankline_rst;
    } elsif ($cmd eq "-docbook") {
	$output_mode = "xml";
	@highlights = @highlights_xml;
	$blankline = $blankline_xml;
    } elsif ($cmd eq "-list") {
	$output_mode = "list";
	@highlights = @highlights_list;
	$blankline = $blankline_list;
    } elsif ($cmd eq "-gnome") {
	$output_mode = "gnome";
	@highlights = @highlights_gnome;
	$blankline = $blankline_gnome;
    } elsif ($cmd eq "-module") { # not needed for XML, inherits from calling document
	$modulename = shift @ARGV;
    } elsif ($cmd eq "-function") { # to only output specific functions
	$function_only = 1;
	$function = shift @ARGV;
	$function_table{$function} = 1;
    } elsif ($cmd eq "-nofunction") { # to only output specific functions
	$function_only = 2;
	$function = shift @ARGV;
	$function_table{$function} = 1;
    } elsif ($cmd eq "-v") {
	$verbose = 1;
    } elsif (($cmd eq "-h") || ($cmd eq "--help")) {
	usage();
    } elsif ($cmd eq '-no-doc-sections') {
	    $no_doc_sections = 1;
    } elsif ($cmd eq '-show-not-found') {
	$show_not_found = 1;
    }
}

# continue execution near EOF;

# get kernel version from env
sub get_kernel_version() {
    my $version = 'unknown kernel version';

    if (defined($ENV{'KERNELVERSION'})) {
	$version = $ENV{'KERNELVERSION'};
    }
    return $version;
}

##
# dumps section contents to arrays/hashes intended for that purpose.
#
sub dump_section {
    my $file = shift;
    my $name = shift;
    my $contents = join "\n", @_;

    if ($name =~ m/$type_constant/) {
	$name = $1;
#	print STDERR "constant section '$1' = '$contents'\n";
	$constants{$name} = $contents;
    } elsif ($name =~ m/$type_param/) {
#	print STDERR "parameter def '$1' = '$contents'\n";
	$name = $1;
	$parameterdescs{$name} = $contents;
	$sectcheck = $sectcheck . $name . " ";
    } elsif ($name eq "@\.\.\.") {
#	print STDERR "parameter def '...' = '$contents'\n";
	$name = "...";
	$parameterdescs{$name} = $contents;
	$sectcheck = $sectcheck . $name . " ";
    } else {
#	print STDERR "other section '$name' = '$contents'\n";
	if (defined($sections{$name}) && ($sections{$name} ne "")) {
		print STDERR "${file}:$.: error: duplicate section name '$name'\n";
		++$errors;
	}
	$sections{$name} = $contents;
	push @sectionlist, $name;
    }
}

##
# dump DOC: section after checking that it should go out
#
sub dump_doc_section {
    my $file = shift;
    my $name = shift;
    my $contents = join "\n", @_;

    if ($no_doc_sections) {
        return;
    }

    if (($function_only == 0) ||
	( $function_only == 1 && defined($function_table{$name})) ||
	( $function_only == 2 && !defined($function_table{$name})))
    {
	dump_section($file, $name, $contents);
	output_blockhead({'sectionlist' => \@sectionlist,
			  'sections' => \%sections,
			  'module' => $modulename,
			  'content-only' => ($function_only != 0), });
    }
}

##
# output function
#
# parameterdescs, a hash.
#  function => "function name"
#  parameterlist => @list of parameters
#  parameterdescs => %parameter descriptions
#  sectionlist => @list of sections
#  sections => %section descriptions
#

sub output_highlight {
    my $contents = join "\n",@_;
    my $line;

#   DEBUG
#   if (!defined $contents) {
#	use Carp;
#	confess "output_highlight got called with no args?\n";
#   }

    if ($output_mode eq "html" || $output_mode eq "html5" ||
	$output_mode eq "xml") {
	$contents = local_unescape($contents);
	# convert data read & converted thru xml_escape() into &xyz; format:
	$contents =~ s/\\\\\\/\&/g;
    }
#   print STDERR "contents b4:$contents\n";
    eval $dohighlight;
    die $@ if $@;
#   print STDERR "contents af:$contents\n";

#   strip whitespaces when generating html5
    if ($output_mode eq "html5") {
	$contents =~ s/^\s+//;
	$contents =~ s/\s+$//;
    }
    foreach $line (split "\n", $contents) {
	if (! $output_preformatted) {
	    $line =~ s/^\s*//;
	}
	if ($line eq ""){
	    if (! $output_preformatted) {
		print STDOUT $lineprefix, local_unescape($blankline);
	    }
	} else {
	    $line =~ s/\\\\\\/\&/g;
	    if ($output_mode eq "man" && substr($line, 0, 1) eq ".") {
		print STDOUT "\\&$line";
	    } else {
		print STDOUT $lineprefix, $line;
	    }
	}
	print STDOUT "\n";
    }
}

# output sections in html
sub output_section_html(%) {
    my %args = %{$_[0]};
    my $section;

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT "<h3>$section</h3>\n";
	print STDOUT "<blockquote>\n";
	output_highlight($args{'sections'}{$section});
	print STDOUT "</blockquote>\n";
    }
}

# output enum in html
sub output_enum_html(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $count;
    print STDOUT "<h2>enum " . $args{'enum'} . "</h2>\n";

    print STDOUT "<b>enum " . $args{'enum'} . "</b> {<br>\n";
    $count = 0;
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT " <b>" . $parameter . "</b>";
	if ($count != $#{$args{'parameterlist'}}) {
	    $count++;
	    print STDOUT ",\n";
	}
	print STDOUT "<br>";
    }
    print STDOUT "};<br>\n";

    print STDOUT "<h3>Constants</h3>\n";
    print STDOUT "<dl>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "<dt><b>" . $parameter . "</b>\n";
	print STDOUT "<dd>";
	output_highlight($args{'parameterdescs'}{$parameter});
    }
    print STDOUT "</dl>\n";
    output_section_html(@_);
    print STDOUT "<hr>\n";
}

# output typedef in html
sub output_typedef_html(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $count;
    print STDOUT "<h2>typedef " . $args{'typedef'} . "</h2>\n";

    print STDOUT "<b>typedef " . $args{'typedef'} . "</b>\n";
    output_section_html(@_);
    print STDOUT "<hr>\n";
}

# output struct in html
sub output_struct_html(%) {
    my %args = %{$_[0]};
    my ($parameter);

    print STDOUT "<h2>" . $args{'type'} . " " . $args{'struct'} . " - " . $args{'purpose'} . "</h2>\n";
    print STDOUT "<b>" . $args{'type'} . " " . $args{'struct'} . "</b> {<br>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	if ($parameter =~ /^#/) {
		print STDOUT "$parameter<br>\n";
		next;
	}
	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT "&nbsp; &nbsp; <i>$1</i><b>$parameter</b>) <i>($2)</i>;<br>\n";
	} elsif ($type =~ m/^(.*?)\s*(:.*)/) {
	    # bitfield
	    print STDOUT "&nbsp; &nbsp; <i>$1</i> <b>$parameter</b>$2;<br>\n";
	} else {
	    print STDOUT "&nbsp; &nbsp; <i>$type</i> <b>$parameter</b>;<br>\n";
	}
    }
    print STDOUT "};<br>\n";

    print STDOUT "<h3>Members</h3>\n";
    print STDOUT "<dl>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	($parameter =~ /^#/) && next;

	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	print STDOUT "<dt><b>" . $parameter . "</b>\n";
	print STDOUT "<dd>";
	output_highlight($args{'parameterdescs'}{$parameter_name});
    }
    print STDOUT "</dl>\n";
    output_section_html(@_);
    print STDOUT "<hr>\n";
}

# output function in html
sub output_function_html(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;

    print STDOUT "<h2>" . $args{'function'} . " - " . $args{'purpose'} . "</h2>\n";
    print STDOUT "<i>" . $args{'functiontype'} . "</i>\n";
    print STDOUT "<b>" . $args{'function'} . "</b>\n";
    print STDOUT "(";
    $count = 0;
    foreach $parameter (@{$args{'parameterlist'}}) {
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT "<i>$1</i><b>$parameter</b>) <i>($2)</i>";
	} else {
	    print STDOUT "<i>" . $type . "</i> <b>" . $parameter . "</b>";
	}
	if ($count != $#{$args{'parameterlist'}}) {
	    $count++;
	    print STDOUT ",\n";
	}
    }
    print STDOUT ")\n";

    print STDOUT "<h3>Arguments</h3>\n";
    print STDOUT "<dl>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	print STDOUT "<dt><b>" . $parameter . "</b>\n";
	print STDOUT "<dd>";
	output_highlight($args{'parameterdescs'}{$parameter_name});
    }
    print STDOUT "</dl>\n";
    output_section_html(@_);
    print STDOUT "<hr>\n";
}

# output DOC: block header in html
sub output_blockhead_html(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT "<h3>$section</h3>\n";
	print STDOUT "<ul>\n";
	output_highlight($args{'sections'}{$section});
	print STDOUT "</ul>\n";
    }
    print STDOUT "<hr>\n";
}

# output sections in html5
sub output_section_html5(%) {
    my %args = %{$_[0]};
    my $section;

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT "<section>\n";
	print STDOUT "<h1>$section</h1>\n";
	print STDOUT "<p>\n";
	output_highlight($args{'sections'}{$section});
	print STDOUT "</p>\n";
	print STDOUT "</section>\n";
    }
}

# output enum in html5
sub output_enum_html5(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $count;
    my $html5id;

    $html5id = $args{'enum'};
    $html5id =~ s/[^a-zA-Z0-9\-]+/_/g;
    print STDOUT "<article class=\"enum\" id=\"enum:". $html5id . "\">";
    print STDOUT "<h1>enum " . $args{'enum'} . "</h1>\n";
    print STDOUT "<ol class=\"code\">\n";
    print STDOUT "<li>";
    print STDOUT "<span class=\"keyword\">enum</span> ";
    print STDOUT "<span class=\"identifier\">" . $args{'enum'} . "</span> {";
    print STDOUT "</li>\n";
    $count = 0;
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "<li class=\"indent\">";
	print STDOUT "<span class=\"param\">" . $parameter . "</span>";
	if ($count != $#{$args{'parameterlist'}}) {
	    $count++;
	    print STDOUT ",";
	}
	print STDOUT "</li>\n";
    }
    print STDOUT "<li>};</li>\n";
    print STDOUT "</ol>\n";

    print STDOUT "<section>\n";
    print STDOUT "<h1>Constants</h1>\n";
    print STDOUT "<dl>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "<dt>" . $parameter . "</dt>\n";
	print STDOUT "<dd>";
	output_highlight($args{'parameterdescs'}{$parameter});
	print STDOUT "</dd>\n";
    }
    print STDOUT "</dl>\n";
    print STDOUT "</section>\n";
    output_section_html5(@_);
    print STDOUT "</article>\n";
}

# output typedef in html5
sub output_typedef_html5(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $count;
    my $html5id;

    $html5id = $args{'typedef'};
    $html5id =~ s/[^a-zA-Z0-9\-]+/_/g;
    print STDOUT "<article class=\"typedef\" id=\"typedef:" . $html5id . "\">\n";
    print STDOUT "<h1>typedef " . $args{'typedef'} . "</h1>\n";

    print STDOUT "<ol class=\"code\">\n";
    print STDOUT "<li>";
    print STDOUT "<span class=\"keyword\">typedef</span> ";
    print STDOUT "<span class=\"identifier\">" . $args{'typedef'} . "</span>";
    print STDOUT "</li>\n";
    print STDOUT "</ol>\n";
    output_section_html5(@_);
    print STDOUT "</article>\n";
}

# output struct in html5
sub output_struct_html5(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $html5id;

    $html5id = $args{'struct'};
    $html5id =~ s/[^a-zA-Z0-9\-]+/_/g;
    print STDOUT "<article class=\"struct\" id=\"struct:" . $html5id . "\">\n";
    print STDOUT "<hgroup>\n";
    print STDOUT "<h1>" . $args{'type'} . " " . $args{'struct'} . "</h1>";
    print STDOUT "<h2>". $args{'purpose'} . "</h2>\n";
    print STDOUT "</hgroup>\n";
    print STDOUT "<ol class=\"code\">\n";
    print STDOUT "<li>";
    print STDOUT "<span class=\"type\">" . $args{'type'} . "</span> ";
    print STDOUT "<span class=\"identifier\">" . $args{'struct'} . "</span> {";
    print STDOUT "</li>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "<li class=\"indent\">";
	if ($parameter =~ /^#/) {
		print STDOUT "<span class=\"param\">" . $parameter ."</span>\n";
		print STDOUT "</li>\n";
		next;
	}
	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT "<span class=\"type\">$1</span> ";
	    print STDOUT "<span class=\"param\">$parameter</span>";
	    print STDOUT "<span class=\"type\">)</span> ";
	    print STDOUT "(<span class=\"args\">$2</span>);";
	} elsif ($type =~ m/^(.*?)\s*(:.*)/) {
	    # bitfield
	    print STDOUT "<span class=\"type\">$1</span> ";
	    print STDOUT "<span class=\"param\">$parameter</span>";
	    print STDOUT "<span class=\"bits\">$2</span>;";
	} else {
	    print STDOUT "<span class=\"type\">$type</span> ";
	    print STDOUT "<span class=\"param\">$parameter</span>;";
	}
	print STDOUT "</li>\n";
    }
    print STDOUT "<li>};</li>\n";
    print STDOUT "</ol>\n";

    print STDOUT "<section>\n";
    print STDOUT "<h1>Members</h1>\n";
    print STDOUT "<dl>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	($parameter =~ /^#/) && next;

	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	print STDOUT "<dt>" . $parameter . "</dt>\n";
	print STDOUT "<dd>";
	output_highlight($args{'parameterdescs'}{$parameter_name});
	print STDOUT "</dd>\n";
    }
    print STDOUT "</dl>\n";
    print STDOUT "</section>\n";
    output_section_html5(@_);
    print STDOUT "</article>\n";
}

# output function in html5
sub output_function_html5(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;
    my $html5id;

    $html5id = $args{'function'};
    $html5id =~ s/[^a-zA-Z0-9\-]+/_/g;
    print STDOUT "<article class=\"function\" id=\"func:". $html5id . "\">\n";
    print STDOUT "<hgroup>\n";
    print STDOUT "<h1>" . $args{'function'} . "</h1>";
    print STDOUT "<h2>" . $args{'purpose'} . "</h2>\n";
    print STDOUT "</hgroup>\n";
    print STDOUT "<ol class=\"code\">\n";
    print STDOUT "<li>";
    print STDOUT "<span class=\"type\">" . $args{'functiontype'} . "</span> ";
    print STDOUT "<span class=\"identifier\">" . $args{'function'} . "</span> (";
    print STDOUT "</li>";
    $count = 0;
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "<li class=\"indent\">";
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT "<span class=\"type\">$1</span> ";
	    print STDOUT "<span class=\"param\">$parameter</span>";
	    print STDOUT "<span class=\"type\">)</span> ";
	    print STDOUT "(<span class=\"args\">$2</span>)";
	} else {
	    print STDOUT "<span class=\"type\">$type</span> ";
	    print STDOUT "<span class=\"param\">$parameter</span>";
	}
	if ($count != $#{$args{'parameterlist'}}) {
	    $count++;
	    print STDOUT ",";
	}
	print STDOUT "</li>\n";
    }
    print STDOUT "<li>)</li>\n";
    print STDOUT "</ol>\n";

    print STDOUT "<section>\n";
    print STDOUT "<h1>Arguments</h1>\n";
    print STDOUT "<p>\n";
    print STDOUT "<dl>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	print STDOUT "<dt>" . $parameter . "</dt>\n";
	print STDOUT "<dd>";
	output_highlight($args{'parameterdescs'}{$parameter_name});
	print STDOUT "</dd>\n";
    }
    print STDOUT "</dl>\n";
    print STDOUT "</section>\n";
    output_section_html5(@_);
    print STDOUT "</article>\n";
}

# output DOC: block header in html5
sub output_blockhead_html5(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;
    my $html5id;

    foreach $section (@{$args{'sectionlist'}}) {
	$html5id = $section;
	$html5id =~ s/[^a-zA-Z0-9\-]+/_/g;
	print STDOUT "<article class=\"doc\" id=\"doc:". $html5id . "\">\n";
	print STDOUT "<h1>$section</h1>\n";
	print STDOUT "<p>\n";
	output_highlight($args{'sections'}{$section});
	print STDOUT "</p>\n";
    }
    print STDOUT "</article>\n";
}

sub output_section_xml(%) {
    my %args = %{$_[0]};
    my $section;
    # print STDOUT out each section
    $lineprefix="   ";
    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT "<refsect1>\n";
	print STDOUT "<title>$section</title>\n";
	if ($section =~ m/EXAMPLE/i) {
	    print STDOUT "<informalexample><programlisting>\n";
	    $output_preformatted = 1;
	} else {
	    print STDOUT "<para>\n";
	}
	output_highlight($args{'sections'}{$section});
	$output_preformatted = 0;
	if ($section =~ m/EXAMPLE/i) {
	    print STDOUT "</programlisting></informalexample>\n";
	} else {
	    print STDOUT "</para>\n";
	}
	print STDOUT "</refsect1>\n";
    }
}

# output function in XML DocBook
sub output_function_xml(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;
    my $id;

    $id = "API-" . $args{'function'};
    $id =~ s/[^A-Za-z0-9]/-/g;

    print STDOUT "<refentry id=\"$id\">\n";
    print STDOUT "<refentryinfo>\n";
    print STDOUT " <title>LINUX</title>\n";
    print STDOUT " <productname>Kernel Hackers Manual</productname>\n";
    print STDOUT " <date>$man_date</date>\n";
    print STDOUT "</refentryinfo>\n";
    print STDOUT "<refmeta>\n";
    print STDOUT " <refentrytitle><phrase>" . $args{'function'} . "</phrase></refentrytitle>\n";
    print STDOUT " <manvolnum>9</manvolnum>\n";
    print STDOUT " <refmiscinfo class=\"version\">" . $kernelversion . "</refmiscinfo>\n";
    print STDOUT "</refmeta>\n";
    print STDOUT "<refnamediv>\n";
    print STDOUT " <refname>" . $args{'function'} . "</refname>\n";
    print STDOUT " <refpurpose>\n";
    print STDOUT "  ";
    output_highlight ($args{'purpose'});
    print STDOUT " </refpurpose>\n";
    print STDOUT "</refnamediv>\n";

    print STDOUT "<refsynopsisdiv>\n";
    print STDOUT " <title>Synopsis</title>\n";
    print STDOUT "  <funcsynopsis><funcprototype>\n";
    print STDOUT "   <funcdef>" . $args{'functiontype'} . " ";
    print STDOUT "<function>" . $args{'function'} . " </function></funcdef>\n";

    $count = 0;
    if ($#{$args{'parameterlist'}} >= 0) {
	foreach $parameter (@{$args{'parameterlist'}}) {
	    $type = $args{'parametertypes'}{$parameter};
	    if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
		# pointer-to-function
		print STDOUT "   <paramdef>$1<parameter>$parameter</parameter>)\n";
		print STDOUT "     <funcparams>$2</funcparams></paramdef>\n";
	    } else {
		print STDOUT "   <paramdef>" . $type;
		print STDOUT " <parameter>$parameter</parameter></paramdef>\n";
	    }
	}
    } else {
	print STDOUT "  <void/>\n";
    }
    print STDOUT "  </funcprototype></funcsynopsis>\n";
    print STDOUT "</refsynopsisdiv>\n";

    # print STDOUT parameters
    print STDOUT "<refsect1>\n <title>Arguments</title>\n";
    if ($#{$args{'parameterlist'}} >= 0) {
	print STDOUT " <variablelist>\n";
	foreach $parameter (@{$args{'parameterlist'}}) {
	    my $parameter_name = $parameter;
	    $parameter_name =~ s/\[.*//;

	    print STDOUT "  <varlistentry>\n   <term><parameter>$parameter</parameter></term>\n";
	    print STDOUT "   <listitem>\n    <para>\n";
	    $lineprefix="     ";
	    output_highlight($args{'parameterdescs'}{$parameter_name});
	    print STDOUT "    </para>\n   </listitem>\n  </varlistentry>\n";
	}
	print STDOUT " </variablelist>\n";
    } else {
	print STDOUT " <para>\n  None\n </para>\n";
    }
    print STDOUT "</refsect1>\n";

    output_section_xml(@_);
    print STDOUT "</refentry>\n\n";
}

# output struct in XML DocBook
sub output_struct_xml(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $id;

    $id = "API-struct-" . $args{'struct'};
    $id =~ s/[^A-Za-z0-9]/-/g;

    print STDOUT "<refentry id=\"$id\">\n";
    print STDOUT "<refentryinfo>\n";
    print STDOUT " <title>LINUX</title>\n";
    print STDOUT " <productname>Kernel Hackers Manual</productname>\n";
    print STDOUT " <date>$man_date</date>\n";
    print STDOUT "</refentryinfo>\n";
    print STDOUT "<refmeta>\n";
    print STDOUT " <refentrytitle><phrase>" . $args{'type'} . " " . $args{'struct'} . "</phrase></refentrytitle>\n";
    print STDOUT " <manvolnum>9</manvolnum>\n";
    print STDOUT " <refmiscinfo class=\"version\">" . $kernelversion . "</refmiscinfo>\n";
    print STDOUT "</refmeta>\n";
    print STDOUT "<refnamediv>\n";
    print STDOUT " <refname>" . $args{'type'} . " " . $args{'struct'} . "</refname>\n";
    print STDOUT " <refpurpose>\n";
    print STDOUT "  ";
    output_highlight ($args{'purpose'});
    print STDOUT " </refpurpose>\n";
    print STDOUT "</refnamediv>\n";

    print STDOUT "<refsynopsisdiv>\n";
    print STDOUT " <title>Synopsis</title>\n";
    print STDOUT "  <programlisting>\n";
    print STDOUT $args{'type'} . " " . $args{'struct'} . " {\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	if ($parameter =~ /^#/) {
	    my $prm = $parameter;
	    # convert data read & converted thru xml_escape() into &xyz; format:
	    # This allows us to have #define macros interspersed in a struct.
	    $prm =~ s/\\\\\\/\&/g;
	    print STDOUT "$prm\n";
	    next;
	}

	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	defined($args{'parameterdescs'}{$parameter_name}) || next;
	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT "  $1 $parameter) ($2);\n";
	} elsif ($type =~ m/^(.*?)\s*(:.*)/) {
	    # bitfield
	    print STDOUT "  $1 $parameter$2;\n";
	} else {
	    print STDOUT "  " . $type . " " . $parameter . ";\n";
	}
    }
    print STDOUT "};";
    print STDOUT "  </programlisting>\n";
    print STDOUT "</refsynopsisdiv>\n";

    print STDOUT " <refsect1>\n";
    print STDOUT "  <title>Members</title>\n";

    if ($#{$args{'parameterlist'}} >= 0) {
    print STDOUT "  <variablelist>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
      ($parameter =~ /^#/) && next;

      my $parameter_name = $parameter;
      $parameter_name =~ s/\[.*//;

      defined($args{'parameterdescs'}{$parameter_name}) || next;
      ($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
      print STDOUT "    <varlistentry>";
      print STDOUT "      <term>$parameter</term>\n";
      print STDOUT "      <listitem><para>\n";
      output_highlight($args{'parameterdescs'}{$parameter_name});
      print STDOUT "      </para></listitem>\n";
      print STDOUT "    </varlistentry>\n";
    }
    print STDOUT "  </variablelist>\n";
    } else {
	print STDOUT " <para>\n  None\n </para>\n";
    }
    print STDOUT " </refsect1>\n";

    output_section_xml(@_);

    print STDOUT "</refentry>\n\n";
}

# output enum in XML DocBook
sub output_enum_xml(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;
    my $id;

    $id = "API-enum-" . $args{'enum'};
    $id =~ s/[^A-Za-z0-9]/-/g;

    print STDOUT "<refentry id=\"$id\">\n";
    print STDOUT "<refentryinfo>\n";
    print STDOUT " <title>LINUX</title>\n";
    print STDOUT " <productname>Kernel Hackers Manual</productname>\n";
    print STDOUT " <date>$man_date</date>\n";
    print STDOUT "</refentryinfo>\n";
    print STDOUT "<refmeta>\n";
    print STDOUT " <refentrytitle><phrase>enum " . $args{'enum'} . "</phrase></refentrytitle>\n";
    print STDOUT " <manvolnum>9</manvolnum>\n";
    print STDOUT " <refmiscinfo class=\"version\">" . $kernelversion . "</refmiscinfo>\n";
    print STDOUT "</refmeta>\n";
    print STDOUT "<refnamediv>\n";
    print STDOUT " <refname>enum " . $args{'enum'} . "</refname>\n";
    print STDOUT " <refpurpose>\n";
    print STDOUT "  ";
    output_highlight ($args{'purpose'});
    print STDOUT " </refpurpose>\n";
    print STDOUT "</refnamediv>\n";

    print STDOUT "<refsynopsisdiv>\n";
    print STDOUT " <title>Synopsis</title>\n";
    print STDOUT "  <programlisting>\n";
    print STDOUT "enum " . $args{'enum'} . " {\n";
    $count = 0;
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "  $parameter";
	if ($count != $#{$args{'parameterlist'}}) {
	    $count++;
	    print STDOUT ",";
	}
	print STDOUT "\n";
    }
    print STDOUT "};";
    print STDOUT "  </programlisting>\n";
    print STDOUT "</refsynopsisdiv>\n";

    print STDOUT "<refsect1>\n";
    print STDOUT " <title>Constants</title>\n";
    print STDOUT "  <variablelist>\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
      my $parameter_name = $parameter;
      $parameter_name =~ s/\[.*//;

      print STDOUT "    <varlistentry>";
      print STDOUT "      <term>$parameter</term>\n";
      print STDOUT "      <listitem><para>\n";
      output_highlight($args{'parameterdescs'}{$parameter_name});
      print STDOUT "      </para></listitem>\n";
      print STDOUT "    </varlistentry>\n";
    }
    print STDOUT "  </variablelist>\n";
    print STDOUT "</refsect1>\n";

    output_section_xml(@_);

    print STDOUT "</refentry>\n\n";
}

# output typedef in XML DocBook
sub output_typedef_xml(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $id;

    $id = "API-typedef-" . $args{'typedef'};
    $id =~ s/[^A-Za-z0-9]/-/g;

    print STDOUT "<refentry id=\"$id\">\n";
    print STDOUT "<refentryinfo>\n";
    print STDOUT " <title>LINUX</title>\n";
    print STDOUT " <productname>Kernel Hackers Manual</productname>\n";
    print STDOUT " <date>$man_date</date>\n";
    print STDOUT "</refentryinfo>\n";
    print STDOUT "<refmeta>\n";
    print STDOUT " <refentrytitle><phrase>typedef " . $args{'typedef'} . "</phrase></refentrytitle>\n";
    print STDOUT " <manvolnum>9</manvolnum>\n";
    print STDOUT "</refmeta>\n";
    print STDOUT "<refnamediv>\n";
    print STDOUT " <refname>typedef " . $args{'typedef'} . "</refname>\n";
    print STDOUT " <refpurpose>\n";
    print STDOUT "  ";
    output_highlight ($args{'purpose'});
    print STDOUT " </refpurpose>\n";
    print STDOUT "</refnamediv>\n";

    print STDOUT "<refsynopsisdiv>\n";
    print STDOUT " <title>Synopsis</title>\n";
    print STDOUT "  <synopsis>typedef " . $args{'typedef'} . ";</synopsis>\n";
    print STDOUT "</refsynopsisdiv>\n";

    output_section_xml(@_);

    print STDOUT "</refentry>\n\n";
}

# output in XML DocBook
sub output_blockhead_xml(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;

    my $id = $args{'module'};
    $id =~ s/[^A-Za-z0-9]/-/g;

    # print STDOUT out each section
    $lineprefix="   ";
    foreach $section (@{$args{'sectionlist'}}) {
	if (!$args{'content-only'}) {
		print STDOUT "<refsect1>\n <title>$section</title>\n";
	}
	if ($section =~ m/EXAMPLE/i) {
	    print STDOUT "<example><para>\n";
	    $output_preformatted = 1;
	} else {
	    print STDOUT "<para>\n";
	}
	output_highlight($args{'sections'}{$section});
	$output_preformatted = 0;
	if ($section =~ m/EXAMPLE/i) {
	    print STDOUT "</para></example>\n";
	} else {
	    print STDOUT "</para>";
	}
	if (!$args{'content-only'}) {
		print STDOUT "\n</refsect1>\n";
	}
    }

    print STDOUT "\n\n";
}

# output in XML DocBook
sub output_function_gnome {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;
    my $id;

    $id = $args{'module'} . "-" . $args{'function'};
    $id =~ s/[^A-Za-z0-9]/-/g;

    print STDOUT "<sect2>\n";
    print STDOUT " <title id=\"$id\">" . $args{'function'} . "</title>\n";

    print STDOUT "  <funcsynopsis>\n";
    print STDOUT "   <funcdef>" . $args{'functiontype'} . " ";
    print STDOUT "<function>" . $args{'function'} . " ";
    print STDOUT "</function></funcdef>\n";

    $count = 0;
    if ($#{$args{'parameterlist'}} >= 0) {
	foreach $parameter (@{$args{'parameterlist'}}) {
	    $type = $args{'parametertypes'}{$parameter};
	    if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
		# pointer-to-function
		print STDOUT "   <paramdef>$1 <parameter>$parameter</parameter>)\n";
		print STDOUT "     <funcparams>$2</funcparams></paramdef>\n";
	    } else {
		print STDOUT "   <paramdef>" . $type;
		print STDOUT " <parameter>$parameter</parameter></paramdef>\n";
	    }
	}
    } else {
	print STDOUT "  <void>\n";
    }
    print STDOUT "  </funcsynopsis>\n";
    if ($#{$args{'parameterlist'}} >= 0) {
	print STDOUT " <informaltable pgwide=\"1\" frame=\"none\" role=\"params\">\n";
	print STDOUT "<tgroup cols=\"2\">\n";
	print STDOUT "<colspec colwidth=\"2*\">\n";
	print STDOUT "<colspec colwidth=\"8*\">\n";
	print STDOUT "<tbody>\n";
	foreach $parameter (@{$args{'parameterlist'}}) {
	    my $parameter_name = $parameter;
	    $parameter_name =~ s/\[.*//;

	    print STDOUT "  <row><entry align=\"right\"><parameter>$parameter</parameter></entry>\n";
	    print STDOUT "   <entry>\n";
	    $lineprefix="     ";
	    output_highlight($args{'parameterdescs'}{$parameter_name});
	    print STDOUT "    </entry></row>\n";
	}
	print STDOUT " </tbody></tgroup></informaltable>\n";
    } else {
	print STDOUT " <para>\n  None\n </para>\n";
    }

    # print STDOUT out each section
    $lineprefix="   ";
    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT "<simplesect>\n <title>$section</title>\n";
	if ($section =~ m/EXAMPLE/i) {
	    print STDOUT "<example><programlisting>\n";
	    $output_preformatted = 1;
	} else {
	}
	print STDOUT "<para>\n";
	output_highlight($args{'sections'}{$section});
	$output_preformatted = 0;
	print STDOUT "</para>\n";
	if ($section =~ m/EXAMPLE/i) {
	    print STDOUT "</programlisting></example>\n";
	} else {
	}
	print STDOUT " </simplesect>\n";
    }

    print STDOUT "</sect2>\n\n";
}

##
# output function in man
sub output_function_man(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;

    print STDOUT ".TH \"$args{'function'}\" 9 \"$args{'function'}\" \"$man_date\" \"Kernel Hacker's Manual\" LINUX\n";

    print STDOUT ".SH NAME\n";
    print STDOUT $args{'function'} . " \\- " . $args{'purpose'} . "\n";

    print STDOUT ".SH SYNOPSIS\n";
    if ($args{'functiontype'} ne "") {
	print STDOUT ".B \"" . $args{'functiontype'} . "\" " . $args{'function'} . "\n";
    } else {
	print STDOUT ".B \"" . $args{'function'} . "\n";
    }
    $count = 0;
    my $parenth = "(";
    my $post = ",";
    foreach my $parameter (@{$args{'parameterlist'}}) {
	if ($count == $#{$args{'parameterlist'}}) {
	    $post = ");";
	}
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT ".BI \"" . $parenth . $1 . "\" " . $parameter . " \") (" . $2 . ")" . $post . "\"\n";
	} else {
	    $type =~ s/([^\*])$/$1 /;
	    print STDOUT ".BI \"" . $parenth . $type . "\" " . $parameter . " \"" . $post . "\"\n";
	}
	$count++;
	$parenth = "";
    }

    print STDOUT ".SH ARGUMENTS\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	print STDOUT ".IP \"" . $parameter . "\" 12\n";
	output_highlight($args{'parameterdescs'}{$parameter_name});
    }
    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT ".SH \"", uc $section, "\"\n";
	output_highlight($args{'sections'}{$section});
    }
}

##
# output enum in man
sub output_enum_man(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;

    print STDOUT ".TH \"$args{'module'}\" 9 \"enum $args{'enum'}\" \"$man_date\" \"API Manual\" LINUX\n";

    print STDOUT ".SH NAME\n";
    print STDOUT "enum " . $args{'enum'} . " \\- " . $args{'purpose'} . "\n";

    print STDOUT ".SH SYNOPSIS\n";
    print STDOUT "enum " . $args{'enum'} . " {\n";
    $count = 0;
    foreach my $parameter (@{$args{'parameterlist'}}) {
	print STDOUT ".br\n.BI \"    $parameter\"\n";
	if ($count == $#{$args{'parameterlist'}}) {
	    print STDOUT "\n};\n";
	    last;
	}
	else {
	    print STDOUT ", \n.br\n";
	}
	$count++;
    }

    print STDOUT ".SH Constants\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	print STDOUT ".IP \"" . $parameter . "\" 12\n";
	output_highlight($args{'parameterdescs'}{$parameter_name});
    }
    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT ".SH \"$section\"\n";
	output_highlight($args{'sections'}{$section});
    }
}

##
# output struct in man
sub output_struct_man(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);

    print STDOUT ".TH \"$args{'module'}\" 9 \"" . $args{'type'} . " " . $args{'struct'} . "\" \"$man_date\" \"API Manual\" LINUX\n";

    print STDOUT ".SH NAME\n";
    print STDOUT $args{'type'} . " " . $args{'struct'} . " \\- " . $args{'purpose'} . "\n";

    print STDOUT ".SH SYNOPSIS\n";
    print STDOUT $args{'type'} . " " . $args{'struct'} . " {\n.br\n";

    foreach my $parameter (@{$args{'parameterlist'}}) {
	if ($parameter =~ /^#/) {
	    print STDOUT ".BI \"$parameter\"\n.br\n";
	    next;
	}
	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT ".BI \"    " . $1 . "\" " . $parameter . " \") (" . $2 . ")" . "\"\n;\n";
	} elsif ($type =~ m/^(.*?)\s*(:.*)/) {
	    # bitfield
	    print STDOUT ".BI \"    " . $1 . "\ \" " . $parameter . $2 . " \"" . "\"\n;\n";
	} else {
	    $type =~ s/([^\*])$/$1 /;
	    print STDOUT ".BI \"    " . $type . "\" " . $parameter . " \"" . "\"\n;\n";
	}
	print STDOUT "\n.br\n";
    }
    print STDOUT "};\n.br\n";

    print STDOUT ".SH Members\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	($parameter =~ /^#/) && next;

	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	print STDOUT ".IP \"" . $parameter . "\" 12\n";
	output_highlight($args{'parameterdescs'}{$parameter_name});
    }
    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT ".SH \"$section\"\n";
	output_highlight($args{'sections'}{$section});
    }
}

##
# output typedef in man
sub output_typedef_man(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);

    print STDOUT ".TH \"$args{'module'}\" 9 \"$args{'typedef'}\" \"$man_date\" \"API Manual\" LINUX\n";

    print STDOUT ".SH NAME\n";
    print STDOUT "typedef " . $args{'typedef'} . " \\- " . $args{'purpose'} . "\n";

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT ".SH \"$section\"\n";
	output_highlight($args{'sections'}{$section});
    }
}

sub output_blockhead_man(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $count;

    print STDOUT ".TH \"$args{'module'}\" 9 \"$args{'module'}\" \"$man_date\" \"API Manual\" LINUX\n";

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT ".SH \"$section\"\n";
	output_highlight($args{'sections'}{$section});
    }
}

##
# output in text
sub output_function_text(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $start;

    print STDOUT "Name:\n\n";
    print STDOUT $args{'function'} . " - " . $args{'purpose'} . "\n";

    print STDOUT "\nSynopsis:\n\n";
    if ($args{'functiontype'} ne "") {
	$start = $args{'functiontype'} . " " . $args{'function'} . " (";
    } else {
	$start = $args{'function'} . " (";
    }
    print STDOUT $start;

    my $count = 0;
    foreach my $parameter (@{$args{'parameterlist'}}) {
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT $1 . $parameter . ") (" . $2;
	} else {
	    print STDOUT $type . " " . $parameter;
	}
	if ($count != $#{$args{'parameterlist'}}) {
	    $count++;
	    print STDOUT ",\n";
	    print STDOUT " " x length($start);
	} else {
	    print STDOUT ");\n\n";
	}
    }

    print STDOUT "Arguments:\n\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	print STDOUT $parameter . "\n\t" . $args{'parameterdescs'}{$parameter_name} . "\n";
    }
    output_section_text(@_);
}

#output sections in text
sub output_section_text(%) {
    my %args = %{$_[0]};
    my $section;

    print STDOUT "\n";
    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT "$section:\n\n";
	output_highlight($args{'sections'}{$section});
    }
    print STDOUT "\n\n";
}

# output enum in text
sub output_enum_text(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $count;
    print STDOUT "Enum:\n\n";

    print STDOUT "enum " . $args{'enum'} . " - " . $args{'purpose'} . "\n\n";
    print STDOUT "enum " . $args{'enum'} . " {\n";
    $count = 0;
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "\t$parameter";
	if ($count != $#{$args{'parameterlist'}}) {
	    $count++;
	    print STDOUT ",";
	}
	print STDOUT "\n";
    }
    print STDOUT "};\n\n";

    print STDOUT "Constants:\n\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "$parameter\n\t";
	print STDOUT $args{'parameterdescs'}{$parameter} . "\n";
    }

    output_section_text(@_);
}

# output typedef in text
sub output_typedef_text(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $count;
    print STDOUT "Typedef:\n\n";

    print STDOUT "typedef " . $args{'typedef'} . " - " . $args{'purpose'} . "\n";
    output_section_text(@_);
}

# output struct as text
sub output_struct_text(%) {
    my %args = %{$_[0]};
    my ($parameter);

    print STDOUT $args{'type'} . " " . $args{'struct'} . " - " . $args{'purpose'} . "\n\n";
    print STDOUT $args{'type'} . " " . $args{'struct'} . " {\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	if ($parameter =~ /^#/) {
	    print STDOUT "$parameter\n";
	    next;
	}

	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT "\t$1 $parameter) ($2);\n";
	} elsif ($type =~ m/^(.*?)\s*(:.*)/) {
	    # bitfield
	    print STDOUT "\t$1 $parameter$2;\n";
	} else {
	    print STDOUT "\t" . $type . " " . $parameter . ";\n";
	}
    }
    print STDOUT "};\n\n";

    print STDOUT "Members:\n\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	($parameter =~ /^#/) && next;

	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	print STDOUT "$parameter\n\t";
	print STDOUT $args{'parameterdescs'}{$parameter_name} . "\n";
    }
    print STDOUT "\n";
    output_section_text(@_);
}

sub output_blockhead_text(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT " $section:\n";
	print STDOUT "    -> ";
	output_highlight($args{'sections'}{$section});
    }
}

##
# output in restructured text
#

#
# This could use some work; it's used to output the DOC: sections, and
# starts by putting out the name of the doc section itself, but that tends
# to duplicate a header already in the template file.
#
sub output_blockhead_rst(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT "**$section**\n\n";
	output_highlight_rst($args{'sections'}{$section});
	print STDOUT "\n";
    }
}

sub output_highlight_rst {
    my $contents = join "\n",@_;
    my $line;

    # undo the evil effects of xml_escape() earlier
    $contents = xml_unescape($contents);

    eval $dohighlight;
    die $@ if $@;

    foreach $line (split "\n", $contents) {
	if ($line eq "") {
	    print STDOUT $lineprefix, $blankline;
	} else {
	    $line =~ s/\\\\\\/\&/g;
	    print STDOUT $lineprefix, $line;
	}
	print STDOUT "\n";
    }
}

sub output_function_rst(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);
    my $start;

    print STDOUT ".. c:function:: ";
    if ($args{'functiontype'} ne "") {
	$start = $args{'functiontype'} . " " . $args{'function'} . " (";
    } else {
	$start = $args{'function'} . " (";
    }
    print STDOUT $start;

    my $count = 0;
    foreach my $parameter (@{$args{'parameterlist'}}) {
	if ($count ne 0) {
	    print STDOUT ", ";
	}
	$count++;
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT $1 . $parameter . ") (" . $2;
	} else {
	    print STDOUT $type . " " . $parameter;
	}
    }
    print STDOUT ")\n\n    " . $args{'purpose'} . "\n\n";

    print STDOUT ":Parameters:\n\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	my $parameter_name = $parameter;
	#$parameter_name =~ s/\[.*//;
	$type = $args{'parametertypes'}{$parameter};

	if ($type ne "") {
	    print STDOUT "      ``$type $parameter``\n";
	} else {
	    print STDOUT "      ``$parameter``\n";
	}
	if ($args{'parameterdescs'}{$parameter_name} ne $undescribed) {
	    my $oldprefix = $lineprefix;
	    $lineprefix = "        ";
	    output_highlight_rst($args{'parameterdescs'}{$parameter_name});
	    $lineprefix = $oldprefix;
	} else {
	    print STDOUT "\n        _undescribed_\n";
	}
	print STDOUT "\n";
    }
    output_section_rst(@_);
}

sub output_section_rst(%) {
    my %args = %{$_[0]};
    my $section;
    my $oldprefix = $lineprefix;
    $lineprefix = "        ";

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT ":$section:\n\n";
	output_highlight_rst($args{'sections'}{$section});
	print STDOUT "\n";
    }
    print STDOUT "\n";
    $lineprefix = $oldprefix;
}

sub output_enum_rst(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $count;
    my $name = "enum " . $args{'enum'};

    print STDOUT "\n\n.. c:type:: " . $name . "\n\n";
    print STDOUT "    " . $args{'purpose'} . "\n\n";

    print STDOUT "..\n\n:Constants:\n\n";
    my $oldprefix = $lineprefix;
    $lineprefix = "    ";
    foreach $parameter (@{$args{'parameterlist'}}) {
	print STDOUT "  `$parameter`\n";
	if ($args{'parameterdescs'}{$parameter} ne $undescribed) {
	    output_highlight_rst($args{'parameterdescs'}{$parameter});
	} else {
	    print STDOUT "    undescribed\n";
	}
	print STDOUT "\n";
    }
    $lineprefix = $oldprefix;
    output_section_rst(@_);
}

sub output_typedef_rst(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $count;
    my $name = "typedef " . $args{'typedef'};

    ### FIXME: should the name below contain "typedef" or not?
    print STDOUT "\n\n.. c:type:: " . $name . "\n\n";
    print STDOUT "    " . $args{'purpose'} . "\n\n";

    output_section_rst(@_);
}

sub output_struct_rst(%) {
    my %args = %{$_[0]};
    my ($parameter);
    my $name = $args{'type'} . " " . $args{'struct'};

    print STDOUT "\n\n.. c:type:: " . $name . "\n\n";
    print STDOUT "    " . $args{'purpose'} . "\n\n";

    print STDOUT ":Definition:\n\n";
    print STDOUT " ::\n\n";
    print STDOUT "  " . $args{'type'} . " " . $args{'struct'} . " {\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	if ($parameter =~ /^#/) {
	    print STDOUT "    " . "$parameter\n";
	    next;
	}

	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	$type = $args{'parametertypes'}{$parameter};
	if ($type =~ m/([^\(]*\(\*)\s*\)\s*\(([^\)]*)\)/) {
	    # pointer-to-function
	    print STDOUT "    $1 $parameter) ($2);\n";
	} elsif ($type =~ m/^(.*?)\s*(:.*)/) {
	    # bitfield
	    print STDOUT "    $1 $parameter$2;\n";
	} else {
	    print STDOUT "    " . $type . " " . $parameter . ";\n";
	}
    }
    print STDOUT "  };\n\n";

    print STDOUT ":Members:\n\n";
    foreach $parameter (@{$args{'parameterlist'}}) {
	($parameter =~ /^#/) && next;

	my $parameter_name = $parameter;
	$parameter_name =~ s/\[.*//;

	($args{'parameterdescs'}{$parameter_name} ne $undescribed) || next;
	$type = $args{'parametertypes'}{$parameter};
	print STDOUT "      `$type $parameter`" . "\n";
	my $oldprefix = $lineprefix;
	$lineprefix = "        ";
	output_highlight_rst($args{'parameterdescs'}{$parameter_name});
	$lineprefix = $oldprefix;
	print STDOUT "\n";
    }
    print STDOUT "\n";
    output_section_rst(@_);
}


## list mode output functions

sub output_function_list(%) {
    my %args = %{$_[0]};

    print STDOUT $args{'function'} . "\n";
}

# output enum in list
sub output_enum_list(%) {
    my %args = %{$_[0]};
    print STDOUT $args{'enum'} . "\n";
}

# output typedef in list
sub output_typedef_list(%) {
    my %args = %{$_[0]};
    print STDOUT $args{'typedef'} . "\n";
}

# output struct as list
sub output_struct_list(%) {
    my %args = %{$_[0]};

    print STDOUT $args{'struct'} . "\n";
}

sub output_blockhead_list(%) {
    my %args = %{$_[0]};
    my ($parameter, $section);

    foreach $section (@{$args{'sectionlist'}}) {
	print STDOUT "DOC: $section\n";
    }
}

##
# generic output function for all types (function, struct/union, typedef, enum);
# calls the generated, variable output_ function name based on
# functype and output_mode
sub output_declaration {
    no strict 'refs';
    my $name = shift;
    my $functype = shift;
    my $func = "output_${functype}_$output_mode";
    if (($function_only==0) ||
	( $function_only == 1 && defined($function_table{$name})) ||
	( $function_only == 2 && !($functype eq "function" && defined($function_table{$name}))))
    {
	&$func(@_);
	$section_counter++;
    }
}

##
# generic output function - calls the right one based on current output mode.
sub output_blockhead {
    no strict 'refs';
    my $func = "output_blockhead_" . $output_mode;
    &$func(@_);
    $section_counter++;
}

##
# takes a declaration (struct, union, enum, typedef) and
# invokes the right handler. NOT called for functions.
sub dump_declaration($$) {
    no strict 'refs';
    my ($prototype, $file) = @_;
    my $func = "dump_" . $decl_type;
    &$func(@_);
}

sub dump_union($$) {
    dump_struct(@_);
}

sub dump_struct($$) {
    my $x = shift;
    my $file = shift;
    my $nested;

    if ($x =~ /(struct|union)\s+(\w+)\s*{(.*)}/) {
	#my $decl_type = $1;
	$declaration_name = $2;
	my $members = $3;

	# ignore embedded structs or unions
	$members =~ s/({.*})//g;
	$nested = $1;

	# ignore members marked private:
	$members =~ s/\/\*\s*private:.*?\/\*\s*public:.*?\*\///gosi;
	$members =~ s/\/\*\s*private:.*//gosi;
	# strip comments:
	$members =~ s/\/\*.*?\*\///gos;
	$nested =~ s/\/\*.*?\*\///gos;
	# strip kmemcheck_bitfield_{begin,end}.*;
	$members =~ s/kmemcheck_bitfield_.*?;//gos;
	# strip attributes
	$members =~ s/__attribute__\s*\(\([a-z,_\*\s\(\)]*\)\)//i;
	$members =~ s/__aligned\s*\([^;]*\)//gos;
	$members =~ s/\s*CRYPTO_MINALIGN_ATTR//gos;
	# replace DECLARE_BITMAP
	$members =~ s/DECLARE_BITMAP\s*\(([^,)]+), ([^,)]+)\)/unsigned long $1\[BITS_TO_LONGS($2)\]/gos;

	create_parameterlist($members, ';', $file);
	check_sections($file, $declaration_name, "struct", $sectcheck, $struct_actual, $nested);

	output_declaration($declaration_name,
			   'struct',
			   {'struct' => $declaration_name,
			    'module' => $modulename,
			    'parameterlist' => \@parameterlist,
			    'parameterdescs' => \%parameterdescs,
			    'parametertypes' => \%parametertypes,
			    'sectionlist' => \@sectionlist,
			    'sections' => \%sections,
			    'purpose' => $declaration_purpose,
			    'type' => $decl_type
			   });
    }
    else {
	print STDERR "${file}:$.: error: Cannot parse struct or union!\n";
	++$errors;
    }
}

sub dump_enum($$) {
    my $x = shift;
    my $file = shift;

    $x =~ s@/\*.*?\*/@@gos;	# strip comments.
    # strip #define macros inside enums
    $x =~ s@#\s*((define|ifdef)\s+|endif)[^;]*;@@gos;

    if ($x =~ /enum\s+(\w+)\s*{(.*)}/) {
	$declaration_name = $1;
	my $members = $2;

	foreach my $arg (split ',', $members) {
	    $arg =~ s/^\s*(\w+).*/$1/;
	    push @parameterlist, $arg;
	    if (!$parameterdescs{$arg}) {
		$parameterdescs{$arg} = $undescribed;
		print STDERR "${file}:$.: warning: Enum value '$arg' ".
		    "not described in enum '$declaration_name'\n";
	    }
		++$warnings;
	}

	output_declaration($declaration_name,
			   'enum',
			   {'enum' => $declaration_name,
			    'module' => $modulename,
			    'parameterlist' => \@parameterlist,
			    'parameterdescs' => \%parameterdescs,
			    'sectionlist' => \@sectionlist,
			    'sections' => \%sections,
			    'purpose' => $declaration_purpose
			   });
    }
    else {
	print STDERR "${file}:$.: error: Cannot parse enum!\n";
	++$errors;
    }
}

sub dump_typedef($$) {
    my $x = shift;
    my $file = shift;

    $x =~ s@/\*.*?\*/@@gos;	# strip comments.

    # Parse function prototypes
    if ($x =~ /typedef\s+(\w+)\s*\(\*\s*(\w\S+)\s*\)\s*\((.*)\);/) {
	# Function typedefs
	$return_type = $1;
	$declaration_name = $2;
	my $args = $3;

	create_parameterlist($args, ',', $file);

	output_declaration($declaration_name,
			   'function',
			   {'function' => $declaration_name,
			    'module' => $modulename,
			    'functiontype' => $return_type,
			    'parameterlist' => \@parameterlist,
			    'parameterdescs' => \%parameterdescs,
			    'parametertypes' => \%parametertypes,
			    'sectionlist' => \@sectionlist,
			    'sections' => \%sections,
			    'purpose' => $declaration_purpose
			   });
	return;
    }

    while (($x =~ /\(*.\)\s*;$/) || ($x =~ /\[*.\]\s*;$/)) {
	$x =~ s/\(*.\)\s*;$/;/;
	$x =~ s/\[*.\]\s*;$/;/;
    }

    if ($x =~ /typedef.*\s+(\w+)\s*;/) {
	$declaration_name = $1;

	output_declaration($declaration_name,
			   'typedef',
			   {'typedef' => $declaration_name,
			    'module' => $modulename,
			    'sectionlist' => \@sectionlist,
			    'sections' => \%sections,
			    'purpose' => $declaration_purpose
			   });
    }
    else {
	print STDERR "${file}:$.: error: Cannot parse typedef!\n";
	++$errors;
    }
}

sub save_struct_actual($) {
    my $actual = shift;

    # strip all spaces from the actual param so that it looks like one string item
    $actual =~ s/\s*//g;
    $struct_actual = $struct_actual . $actual . " ";
}

sub create_parameterlist($$$) {
    my $args = shift;
    my $splitter = shift;
    my $file = shift;
    my $type;
    my $param;

    # temporarily replace commas inside function pointer definition
    while ($args =~ /(\([^\),]+),/) {
	$args =~ s/(\([^\),]+),/$1#/g;
    }

    foreach my $arg (split($splitter, $args)) {
	# strip comments
	$arg =~ s/\/\*.*\*\///;
	# strip leading/trailing spaces
	$arg =~ s/^\s*//;
	$arg =~ s/\s*$//;
	$arg =~ s/\s+/ /;

	if ($arg =~ /^#/) {
	    # Treat preprocessor directive as a typeless variable just to fill
	    # corresponding data structures "correctly". Catch it later in
	    # output_* subs.
	    push_parameter($arg, "", $file);
	} elsif ($arg =~ m/\(.+\)\s*\(/) {
	    # pointer-to-function
	    $arg =~ tr/#/,/;
	    $arg =~ m/[^\(]+\(\*?\s*(\w*)\s*\)/;
	    $param = $1;
	    $type = $arg;
	    $type =~ s/([^\(]+\(\*?)\s*$param/$1/;
	    save_struct_actual($param);
	    push_parameter($param, $type, $file);
	} elsif ($arg) {
	    $arg =~ s/\s*:\s*/:/g;
	    $arg =~ s/\s*\[/\[/g;

	    my @args = split('\s*,\s*', $arg);
	    if ($args[0] =~ m/\*/) {
		$args[0] =~ s/(\*+)\s*/ $1/;
	    }

	    my @first_arg;
	    if ($args[0] =~ /^(.*\s+)(.*?\[.*\].*)$/) {
		    shift @args;
		    push(@first_arg, split('\s+', $1));
		    push(@first_arg, $2);
	    } else {
		    @first_arg = split('\s+', shift @args);
	    }

	    unshift(@args, pop @first_arg);
	    $type = join " ", @first_arg;

	    foreach $param (@args) {
		if ($param =~ m/^(\*+)\s*(.*)/) {
		    save_struct_actual($2);
		    push_parameter($2, "$type $1", $file);
		}
		elsif ($param =~ m/(.*?):(\d+)/) {
		    if ($type ne "") { # skip unnamed bit-fields
			save_struct_actual($1);
			push_parameter($1, "$type:$2", $file)
		    }
		}
		else {
		    save_struct_actual($param);
		    push_parameter($param, $type, $file);
		}
	    }
	}
    }
}

sub push_parameter($$$) {
	my $param = shift;
	my $type = shift;
	my $file = shift;

	if (($anon_struct_union == 1) && ($type eq "") &&
	    ($param eq "}")) {
		return;		# ignore the ending }; from anon. struct/union
	}

	$anon_struct_union = 0;
	my $param_name = $param;
	$param_name =~ s/\[.*//;

	if ($type eq "" && $param =~ /\.\.\.$/)
	{
	    if (!defined $parameterdescs{$param} || $parameterdescs{$param} eq "") {
		$parameterdescs{$param} = "variable arguments";
	    }
	}
	elsif ($type eq "" && ($param eq "" or $param eq "void"))
	{
	    $param="void";
	    $parameterdescs{void} = "no arguments";
	}
	elsif ($type eq "" && ($param eq "struct" or $param eq "union"))
	# handle unnamed (anonymous) union or struct:
	{
		$type = $param;
		$param = "{unnamed_" . $param . "}";
		$parameterdescs{$param} = "anonymous\n";
		$anon_struct_union = 1;
	}

	# warn if parameter has no description
	# (but ignore ones starting with # as these are not parameters
	# but inline preprocessor statements);
	# also ignore unnamed structs/unions;
	if (!$anon_struct_union) {
	if (!defined $parameterdescs{$param_name} && $param_name !~ /^#/) {

	    $parameterdescs{$param_name} = $undescribed;

	    if (($type eq 'function') || ($type eq 'enum')) {
		print STDERR "${file}:$.: warning: Function parameter ".
		    "or member '$param' not " .
		    "described in '$declaration_name'\n";
	    }
			my $tmpLine = $. - 1;
	    print STDERR "${file}:$tmpLine: warning:" .
			 " No description found for parameter '$param'\n";
	    ++$warnings;
	}
	}

	$param = xml_escape($param);

	# strip spaces from $param so that it is one continuous string
	# on @parameterlist;
	# this fixes a problem where check_sections() cannot find
	# a parameter like "addr[6 + 2]" because it actually appears
	# as "addr[6", "+", "2]" on the parameter list;
	# but it's better to maintain the param string unchanged for output,
	# so just weaken the string compare in check_sections() to ignore
	# "[blah" in a parameter string;
	###$param =~ s/\s*//g;
	push @parameterlist, $param;
	$parametertypes{$param} = $type;
}

sub check_sections($$$$$$) {
	my ($file, $decl_name, $decl_type, $sectcheck, $prmscheck, $nested) = @_;
	my @sects = split ' ', $sectcheck;
	my @prms = split ' ', $prmscheck;
	my $err;
	my ($px, $sx);
	my $prm_clean;		# strip trailing "[array size]" and/or beginning "*"

	foreach $sx (0 .. $#sects) {
		$err = 1;
		foreach $px (0 .. $#prms) {
			$prm_clean = $prms[$px];
			$prm_clean =~ s/\[.*\]//;
			$prm_clean =~ s/__attribute__\s*\(\([a-z,_\*\s\(\)]*\)\)//i;
			# ignore array size in a parameter string;
			# however, the original param string may contain
			# spaces, e.g.:  addr[6 + 2]
			# and this appears in @prms as "addr[6" since the
			# parameter list is split at spaces;
			# hence just ignore "[..." for the sections check;
			$prm_clean =~ s/\[.*//;

			##$prm_clean =~ s/^\**//;
			if ($prm_clean eq $sects[$sx]) {
				$err = 0;
				last;
			}
		}
		if ($err) {
			if ($decl_type eq "function") {
				print STDERR "${file}:$.: warning: " .
					"Excess function parameter " .
					"'$sects[$sx]' " .
					"description in '$decl_name'\n";
				++$warnings;
			} else {
				if ($nested !~ m/\Q$sects[$sx]\E/) {
				    print STDERR "${file}:$.: warning: " .
					"Excess struct/union/enum/typedef member " .
					"'$sects[$sx]' " .
					"description in '$decl_name'\n";
				    ++$warnings;
				}
			}
		}
	}
}

##
# Checks the section describing the return value of a function.
sub check_return_section {
        my $file = shift;
        my $declaration_name = shift;
        my $return_type = shift;
	my $real_line = $. - 1;

        # Ignore an empty return type (It's a macro)
        # Ignore functions with a "void" return type. (But don't ignore "void *")
        if (($return_type eq "") || ($return_type =~ /void\s*\w*\s*$/)) {
                return;
        }

        if (!defined($sections{$section_return}) ||
            $sections{$section_return} eq "") {
                print STDERR "${file}:$real_line: warning: " .
                        "No description found for return value of " .
                        "'$declaration_name'\n";
                ++$warnings;
        }
}

##
# takes a function prototype and the name of the current file being
# processed and spits out all the details stored in the global
# arrays/hashes.
sub dump_function($$) {
    my $prototype = shift;
    my $file = shift;
    my $noret = 0;

    $prototype =~ s/^static +//;
    $prototype =~ s/^extern +//;
    $prototype =~ s/^asmlinkage +//;
    $prototype =~ s/^inline +//;
    $prototype =~ s/^__inline__ +//;
    $prototype =~ s/^__inline +//;
    $prototype =~ s/^__always_inline +//;
    $prototype =~ s/^noinline +//;
    $prototype =~ s/__init +//;
    $prototype =~ s/__init_or_module +//;
    $prototype =~ s/__meminit +//;
    $prototype =~ s/__must_check +//;
    $prototype =~ s/__weak +//;
    my $define = $prototype =~ s/^#\s*define\s+//; #ak added
    $prototype =~ s/__attribute__\s*\(\([a-z,]*\)\)//;

    # Yes, this truly is vile.  We are looking for:
    # 1. Return type (may be nothing if we're looking at a macro)
    # 2. Function name
    # 3. Function parameters.
    #
    # All the while we have to watch out for function pointer parameters
    # (which IIRC is what the two sections are for), C types (these
    # regexps don't even start to express all the possibilities), and
    # so on.
    #
    # If you mess with these regexps, it's a good idea to check that
    # the following functions' documentation still comes out right:
    # - parport_register_device (function pointer parameters)
    # - atomic_set (macro)
    # - pci_match_device, __copy_to_user (long return type)

    if ($define && $prototype =~ m/^()([a-zA-Z0-9_~:]+)\s+/) {
        # This is an object-like macro, it has no return type and no parameter
        # list.
        # Function-like macros are not allowed to have spaces between
        # declaration_name and opening parenthesis (notice the \s+).
        $return_type = $1;
        $declaration_name = $2;
        $noret = 1;
    } elsif ($prototype =~ m/^()([a-zA-Z0-9_~:]+)\s*\(([^\(]*)\)/ ||
	$prototype =~ m/^(\w+)\s+([a-zA-Z0-9_~:]+)\s*\(([^\(]*)\)/ ||
	$prototype =~ m/^(\w+\s*\*)\s*([a-zA-Z0-9_~:]+)\s*\(([^\(]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+)\s+([a-zA-Z0-9_~:]+)\s*\(([^\(]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s*\*+)\s*([a-zA-Z0-9_~:]+)\s*\(([^\(]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s+\w+)\s+([a-zA-Z0-9_~:]+)\s*\(([^\(]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s+\w+\s*\*)\s*([a-zA-Z0-9_~:]+)\s*\(([^\(]*)\)/ ||
	$prototype =~ m/^()([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+)\s+([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+\s*\*)\s*([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+)\s+([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s*\*)\s*([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s+\w+)\s+([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s+\w+\s*\*)\s*([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s+\w+\s+\w+)\s+([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s+\w+\s+\w+\s*\*)\s*([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/ ||
	$prototype =~ m/^(\w+\s+\w+\s*\*\s*\w+\s*\*\s*)\s*([a-zA-Z0-9_~:]+)\s*\(([^\{]*)\)/)  {
	$return_type = $1;
	$declaration_name = $2;
	my $args = $3;

	create_parameterlist($args, ',', $file);
    } else {
	print STDERR "${file}:$.: fatal: cannot understand function prototype: '$prototype'\n";
	++$errors;
	return;
    }

	my $prms = join " ", @parameterlist;
	check_sections($file, $declaration_name, "function", $sectcheck, $prms, "");

        # This check emits a lot of warnings at the moment, because many
        # functions don't have a 'Return' doc section. So until the number
        # of warnings goes sufficiently down, the check is only performed in
        # verbose mode.
        # TODO: always perform the check.
        if (!$noret) {
                check_return_section($file, $declaration_name, $return_type);
        }

    output_declaration($declaration_name,
		       'function',
		       {'function' => $declaration_name,
			'module' => $modulename,
			'functiontype' => $return_type,
			'parameterlist' => \@parameterlist,
			'parameterdescs' => \%parameterdescs,
			'parametertypes' => \%parametertypes,
			'sectionlist' => \@sectionlist,
			'sections' => \%sections,
			'purpose' => $declaration_purpose
		       });
}

sub reset_state {
    $function = "";
    %constants = ();
    %parameterdescs = ();
    %parametertypes = ();
    @parameterlist = ();
    %sections = ();
    @sectionlist = ();
    $sectcheck = "";
    $struct_actual = "";
    $prototype = "";

    $state = 0;
    $split_doc_state = 0;
}

sub tracepoint_munge($) {
	my $file = shift;
	my $tracepointname = 0;
	my $tracepointargs = 0;

	if ($prototype =~ m/TRACE_EVENT\((.*?),/) {
		$tracepointname = $1;
	}
	if ($prototype =~ m/DEFINE_SINGLE_EVENT\((.*?),/) {
		$tracepointname = $1;
	}
	if ($prototype =~ m/DEFINE_EVENT\((.*?),(.*?),/) {
		$tracepointname = $2;
	}
	$tracepointname =~ s/^\s+//; #strip leading whitespace
	if ($prototype =~ m/TP_PROTO\((.*?)\)/) {
		$tracepointargs = $1;
	}
	if (($tracepointname eq 0) || ($tracepointargs eq 0)) {
		print STDERR "${file}:$.: warning: Unrecognized tracepoint format: \n".
			     "$prototype\n";
		++$warnings;
	} else {
		$prototype = "static inline void trace_$tracepointname($tracepointargs)";
	}
}

sub syscall_munge() {
	my $void = 0;

	$prototype =~ s@[\r\n\t]+@ @gos; # strip newlines/CR's/tabs
##	if ($prototype =~ m/SYSCALL_DEFINE0\s*\(\s*(a-zA-Z0-9_)*\s*\)/) {
	if ($prototype =~ m/SYSCALL_DEFINE0/) {
		$void = 1;
##		$prototype = "long sys_$1(void)";
	}

	$prototype =~ s/SYSCALL_DEFINE.*\(/long sys_/; # fix return type & func name
	if ($prototype =~ m/long (sys_.*?),/) {
		$prototype =~ s/,/\(/;
	} elsif ($void) {
		$prototype =~ s/\)/\(void\)/;
	}

	# now delete all of the odd-number commas in $prototype
	# so that arg types & arg names don't have a comma between them
	my $count = 0;
	my $len = length($prototype);
	if ($void) {
		$len = 0;	# skip the for-loop
	}
	for (my $ix = 0; $ix < $len; $ix++) {
		if (substr($prototype, $ix, 1) eq ',') {
			$count++;
			if ($count % 2 == 1) {
				substr($prototype, $ix, 1) = ' ';
			}
		}
	}
}

sub process_state3_function($$) {
    my $x = shift;
    my $file = shift;

    $x =~ s@\/\/.*$@@gos; # strip C99-style comments to end of line

    if ($x =~ m#\s*/\*\s+MACDOC\s*#io || ($x =~ /^#/ && $x !~ /^#\s*define/)) {
	# do nothing
    }
    elsif ($x =~ /([^\{]*)/) {
	$prototype .= $1;
    }

    if (($x =~ /\{/) || ($x =~ /\#\s*define/) || ($x =~ /;/)) {
	$prototype =~ s@/\*.*?\*/@@gos;	# strip comments.
	$prototype =~ s@[\r\n]+@ @gos; # strip newlines/cr's.
	$prototype =~ s@^\s+@@gos; # strip leading spaces
	if ($prototype =~ /SYSCALL_DEFINE/) {
		syscall_munge();
	}
	if ($prototype =~ /TRACE_EVENT/ || $prototype =~ /DEFINE_EVENT/ ||
	    $prototype =~ /DEFINE_SINGLE_EVENT/)
	{
		tracepoint_munge($file);
	}
	dump_function($prototype, $file);
	reset_state();
    }
}

sub process_state3_type($$) {
    my $x = shift;
    my $file = shift;

    $x =~ s@[\r\n]+@ @gos; # strip newlines/cr's.
    $x =~ s@^\s+@@gos; # strip leading spaces
    $x =~ s@\s+$@@gos; # strip trailing spaces
    $x =~ s@\/\/.*$@@gos; # strip C99-style comments to end of line

    if ($x =~ /^#/) {
	# To distinguish preprocessor directive from regular declaration later.
	$x .= ";";
    }

    while (1) {
	if ( $x =~ /([^{};]*)([{};])(.*)/ ) {
	    $prototype .= $1 . $2;
	    ($2 eq '{') && $brcount++;
	    ($2 eq '}') && $brcount--;
	    if (($2 eq ';') && ($brcount == 0)) {
		dump_declaration($prototype, $file);
		reset_state();
		last;
	    }
	    $x = $3;
	} else {
	    $prototype .= $x;
	    last;
	}
    }
}

# xml_escape: replace <, >, and & in the text stream;
#
# however, formatting controls that are generated internally/locally in the
# kernel-doc script are not escaped here; instead, they begin life like
# $blankline_html (4 of '\' followed by a mnemonic + ':'), then these strings
# are converted to their mnemonic-expected output, without the 4 * '\' & ':',
# just before actual output; (this is done by local_unescape())
sub xml_escape($) {
	my $text = shift;
	if (($output_mode eq "text") || ($output_mode eq "man")) {
		return $text;
	}
	$text =~ s/\&/\\\\\\amp;/g;
	$text =~ s/\</\\\\\\lt;/g;
	$text =~ s/\>/\\\\\\gt;/g;
	return $text;
}

# xml_unescape: reverse the effects of xml_escape
sub xml_unescape($) {
	my $text = shift;
	if (($output_mode eq "text") || ($output_mode eq "man")) {
		return $text;
	}
	$text =~ s/\\\\\\amp;/\&/g;
	$text =~ s/\\\\\\lt;/</g;
	$text =~ s/\\\\\\gt;/>/g;
	return $text;
}

# convert local escape strings to html
# local escape strings look like:  '\\\\menmonic:' (that's 4 backslashes)
sub local_unescape($) {
	my $text = shift;
	if (($output_mode eq "text") || ($output_mode eq "man")) {
		return $text;
	}
	$text =~ s/\\\\\\\\lt:/</g;
	$text =~ s/\\\\\\\\gt:/>/g;
	return $text;
}

#Regular expressions
our $Storage	= qr{extern|static|asmlinkage};
our $Inline	= qr{inline|__always_inline|noinline|__inline|__inline__};
our $InitAttributePrefix = qr{__(?:mem|cpu|dev|net_|)};
our $InitAttributeData = qr{$InitAttributePrefix(?:initdata\b)};
our $InitAttributeConst = qr{$InitAttributePrefix(?:initconst\b)};
our $InitAttributeInit = qr{$InitAttributePrefix(?:init\b)};
our $InitAttribute = qr{$InitAttributeData|$InitAttributeConst|$InitAttributeInit};
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
our @modifierList = (
	qr{fastcall},
);
our @modifierListFile = ();
my $mods = "(?x:  \n" . join("|\n  ", (@modifierList, @modifierListFile)) . "\n)";
our $Ident	= qr{
			[A-Za-z_][A-Za-z\d_]*
			(?:\s*\#\#\s*[A-Za-z_][A-Za-z\d_]*)*
		}x;
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
our @typeListFile = ();
my $all = "(?x:  \n" . join("|\n  ", (@typeList, @typeListFile)) . "\n)";
our $Modifier	= qr{(?:$Attribute|$Sparse|$mods)};
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
our $NonptrType	= qr{
		(?:$Modifier\s+|const\s+)*
		(?:
			(?:typeof|__typeof__)\s*\([^\)]*\)|
			(?:$typeTypedefs\b)|
			(?:${all}\b)
		)
		(?:\s+$Modifier|\s+const)*
	  }x;
our $Type	= qr{
		$NonptrType
		(?:(?:\s|\*|\[\])+\s*const|(?:\s|\*\s*(?:const\s*)?|\[\])+|(?:\s*\[\s*\])+)?
		(?:\s+$Inline|\s+$Modifier)*
	  }x;

sub process_file($) {
    my $file;
    my $identifier;
    my $func;
    my $descr;
    my $in_purpose = 0;
    my $initial_section_counter = $section_counter;
    my ($orig_file) = @_;

    if (defined($ENV{'SRCTREE'})) {
	$file = "$ENV{'SRCTREE'}" . "/" . $orig_file;
    }
    else {
	$file = $orig_file;
    }
    if (defined($source_map{$file})) {
	$file = $source_map{$file};
    }

    if (!open(IN,"<$file")) {
	print STDERR "Error: Cannot open file $file\n";
	++$errors;
	return;
    }

    $. = 1;

    $section_counter = 0;
    while (<IN>) {
	while (s/\\\s*$//) {
	    $_ .= <IN>;
	}

	if ($_ =~ /^(?:typedef\s+)?(?:(?:$Storage|$Inline)\s*)*\s*$Type\s*\(?\**($Ident)\s*\(/s &&
	    $_ !~ /.*;\s*$/)
	{
		#print STDOUT "Function found: $1\n";
		if (!length $identifier || $identifier ne $1) {
			print STDERR "${file}:$.: warning: no description found for function $1\n";
			++$warnings;
		}
	}

	if ($state == 0) {
	    if (/$doc_start/o) {
		$state = 1;		# next line is always the function name
		$in_doc_sect = 0;
	    }
	} elsif ($state == 1) {	# this line is the function name (always)
	    if (/$doc_block/o) {
		$state = 4;
		$contents = "";
		if ( $1 eq "" ) {
			$section = $section_intro;
		} else {
			$section = $1;
		}
	    }
	    elsif (/$doc_decl/o) {
		$identifier = $1;
		if (/\s*([\w\s]+?)\s*-/) {
		    $identifier = $1;
		}

		$state = 2;
		if (/-(.*)/) {
		    # strip leading/trailing/multiple spaces
		    $descr= $1;
		    $descr =~ s/^\s*//;
		    $descr =~ s/\s*$//;
		    $descr =~ s/\s+/ /g;
		    $declaration_purpose = xml_escape($descr);
		    $in_purpose = 1;
		} else {
		    $declaration_purpose = "";
		}

		if (($declaration_purpose eq "")) {
			print STDERR "${file}:$.: warning: missing initial short description\n";
			#print STDERR $_;
			++$warnings;
		}

		if ($identifier =~ m/^struct/) {
		    $decl_type = 'struct';
		} elsif ($identifier =~ m/^union/) {
		    $decl_type = 'union';
		} elsif ($identifier =~ m/^enum/) {
		    $decl_type = 'enum';
		} elsif ($identifier =~ m/^typedef/) {
		    $decl_type = 'typedef';
		} else {
		    $decl_type = 'function';
		}

		if ($verbose) {
		    print STDERR "${file}:$.: info: Scanning doc for $identifier\n";
		}
	    } else {
		print STDERR "${file}:$.: warning: Cannot understand $_ on line $.",
		" - I thought it was a doc line\n";
		++$warnings;
		$state = 0;
	    }
	} elsif ($state == 2) {	# look for head: lines, and include content
	    if (/$doc_sect/o) {
		$newsection = $1;
		$newcontents = $2;

		if (($contents ne "") && ($contents ne "\n")) {
		    if (!$in_doc_sect && $verbose) {
			print STDERR "${file}:$.: warning: contents before sections\n";
			++$warnings;
		    }
		    dump_section($file, $section, xml_escape($contents));
		    $section = $section_default;
		}

		$in_doc_sect = 1;
		$in_purpose = 0;
		$contents = $newcontents;
		if ($contents ne "") {
		    while ((substr($contents, 0, 1) eq " ") ||
			substr($contents, 0, 1) eq "\t") {
			    $contents = substr($contents, 1);
		    }
		    $contents .= "\n";
		}
		$section = $newsection;
	    } elsif (/$doc_end/) {
		if (($contents ne "") && ($contents ne "\n")) {
		    dump_section($file, $section, xml_escape($contents));
		    $section = $section_default;
		    $contents = "";
		}
		# look for doc_com + <text> + doc_end:
		if ($_ =~ m'\s*\*\s*[a-zA-Z_0-9:\.]+\*/') {
		    print STDERR "${file}:$.: warning: suspicious ending line: $_";
		    ++$warnings;
		}

		$prototype = "";
		$state = 3;
		$brcount = 0;
#		print STDERR "end of doc comment, looking for prototype\n";
	    } elsif (/$doc_content/) {
		# miguel-style comment kludge, look for blank lines after
		# @parameter line to signify start of description
		if ($1 eq "") {
		    if ($section =~ m/^@/ || $section eq $section_context) {
			dump_section($file, $section, xml_escape($contents));
			$section = $section_default;
			$contents = "";
		    } else {
			$contents .= "\n";
		    }
		    $in_purpose = 0;
		} elsif ($in_purpose == 1) {
		    # Continued declaration purpose
		    chomp($declaration_purpose);
		    $declaration_purpose .= " " . xml_escape($1);
		    $declaration_purpose =~ s/\s+/ /g;
		} else {
		    $contents .= $1 . "\n";
		}
	    } else {
		# i dont know - bad line?  ignore.
		print STDERR "${file}:$.: warning: bad line: $_";
		++$warnings;
	    }
	} elsif ($state == 5) { # scanning for split parameters
	    # First line (state 1) needs to be a @parameter
	    if ($split_doc_state == 1 && /$doc_split_sect/o) {
		$section = $1;
		$contents = $2;
		if ($contents ne "") {
		    while ((substr($contents, 0, 1) eq " ") ||
		           substr($contents, 0, 1) eq "\t") {
			$contents = substr($contents, 1);
		    }
		$contents .= "\n";
		}
		$split_doc_state = 2;
	    # Documentation block end */
	    } elsif (/$doc_split_end/) {
		if (($contents ne "") && ($contents ne "\n")) {
		    dump_section($file, $section, xml_escape($contents));
		    $section = $section_default;
		    $contents = "";
		}
		$state = 3;
		$split_doc_state = 0;
	    # Regular text
	    } elsif (/$doc_content/) {
		if ($split_doc_state == 2) {
		    $contents .= $1 . "\n";
		} elsif ($split_doc_state == 1) {
		    $split_doc_state = 4;
		    print STDERR "Warning(${file}:$.): ";
		    print STDERR "Incorrect use of kernel-doc format: $_";
		    ++$warnings;
		}
	    }
	} elsif ($state == 3) {	# scanning for function '{' (end of prototype)
	    if (/$doc_split_start/) {
		$state = 5;
		$split_doc_state = 1;
	    } elsif ($decl_type eq 'function') {
		process_state3_function($_, $file);
	    } else {
		process_state3_type($_, $file);
	    }
	} elsif ($state == 4) {
		# Documentation block
		if (/$doc_block/) {
			dump_doc_section($file, $section, xml_escape($contents));
			$contents = "";
			$function = "";
			%constants = ();
			%parameterdescs = ();
			%parametertypes = ();
			@parameterlist = ();
			%sections = ();
			@sectionlist = ();
			$prototype = "";
			if ( $1 eq "" ) {
				$section = $section_intro;
			} else {
				$section = $1;
			}
		}
		elsif (/$doc_end/)
		{
			dump_doc_section($file, $section, xml_escape($contents));
			$contents = "";
			$function = "";
			%constants = ();
			%parameterdescs = ();
			%parametertypes = ();
			@parameterlist = ();
			%sections = ();
			@sectionlist = ();
			$prototype = "";
			$state = 0;
		}
		elsif (/$doc_content/)
		{
			if ( $1 eq "" )
			{
				$contents .= $blankline;
			}
			else
			{
				$contents .= $1 . "\n";
			}
		}
	}
    }
    if ($initial_section_counter == $section_counter) {
	#print STDERR "${file}:1: warning: no structured comments found\n";
	if (($function_only == 1) && ($show_not_found == 1)) {
	    print STDERR "    Was looking for '$_'.\n" for keys %function_table;
	}
	if ($output_mode eq "xml") {
	    # The template wants at least one RefEntry here; make one.
	    print STDOUT "<refentry>\n";
	    print STDOUT " <refnamediv>\n";
	    print STDOUT "  <refname>\n";
	    print STDOUT "   ${orig_file}\n";
	    print STDOUT "  </refname>\n";
	    print STDOUT "  <refpurpose>\n";
	    print STDOUT "   Document generation inconsistency\n";
	    print STDOUT "  </refpurpose>\n";
	    print STDOUT " </refnamediv>\n";
	    print STDOUT " <refsect1>\n";
	    print STDOUT "  <title>\n";
	    print STDOUT "   Oops\n";
	    print STDOUT "  </title>\n";
	    print STDOUT "  <warning>\n";
	    print STDOUT "   <para>\n";
	    print STDOUT "    The template for this document tried to insert\n";
	    print STDOUT "    the structured comment from the file\n";
	    print STDOUT "    <filename>${orig_file}</filename> at this point,\n";
	    print STDOUT "    but none was found.\n";
	    print STDOUT "    This dummy section is inserted to allow\n";
	    print STDOUT "    generation to continue.\n";
	    print STDOUT "   </para>\n";
	    print STDOUT "  </warning>\n";
	    print STDOUT " </refsect1>\n";
	    print STDOUT "</refentry>\n";
	}
    }
}


$kernelversion = get_kernel_version();

# generate a sequence of code that will splice in highlighting information
# using the s// operator.
for (my $k = 0; $k < @highlights; $k++) {
    my $pattern = $highlights[$k][0];
    my $result = $highlights[$k][1];
#   print STDERR "scanning pattern:$pattern, highlight:($result)\n";
    $dohighlight .=  "\$contents =~ s:$pattern:$result:gs;\n";
}

# Read the file that maps relative names to absolute names for
# separate source and object directories and for shadow trees.
if (open(SOURCE_MAP, "<.tmp_filelist.txt")) {
	my ($relname, $absname);
	while(<SOURCE_MAP>) {
		chop();
		($relname, $absname) = (split())[0..1];
		$relname =~ s:^/+::;
		$source_map{$relname} = $absname;
	}
	close(SOURCE_MAP);
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
