#!/usr/bin/env perl
my $version = "1.2.0";

#################################################################################
# PROGRAM: Frequency List Wizard                                                #
# AUTHOR:  Scott Sadowsky                                                       #
# EMAIL:   s s a d o w s k y A T g m a i l D O T c o m                          #
# WEB:     http://sadowsky.cl/                                                  #
#                                                                               #
# HELP:    For help, run:  (SCRIPT)    ./frequency-list-wizard.pl -h            #
#                          (EXECUTABE) frequency-list-wizard.exe -h             #
#                                                                               #
# COPYRIGHT: Copyright (c) 2016 by Scott Sadowsky                               #
# LICENSE:  Licensed under the GNU General Public License, version 3 (GPLv3)    #
#                                                                               #
# This program is free software: you can redistribute it and/or modify          #
# it under the terms of the GNU General Public License as published by          #
# the Free Software Foundation, either version 3 of the License, or             #
# (at your option) any later version.                                           #
#                                                                               #
# This program is distributed in the hope that it will be useful,               #
# but WITHOUT ANY WARRANTY; without even the implied warranty of                #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                 #
# GNU General Public License for more details.                                  #
#                                                                               #
# You should have received a copy of the GNU General Public License             #
# along with this program.  If not, see <http://www.gnu.org/licenses/>.         #
#                                                                               #
# Thanks to Stefan Evert for his help with the merge routine.                   #
#                                                                               #
#################################################################################

# CHANGELOG
#
# 1.2.0
# - Now processes UTF-8 texts. FLW assumes this is the encoding used. To process
#   Latin-1, you must specify this with "-lat1" on the command line.

# CONFIGURE
use strict;					# quote strings, declare variables
use warnings;					# on by default
use utf8;						# so literals and identifiers can be in UTF-8
use v5.12;					# or later to get "unicode_strings" feature
use warnings qw(FATAL utf8);		# fatalize encoding glitches
use open     qw(:std :utf8);		# undeclared streams in UTF-8

# COMMENT THIS OUT when compiling executable!
#use warnings;


# Use modules
use Getopt::Long qw(:config no_auto_abbrev);    # Module for processing command line options.

# Define variables - these can be changed to alter default behavior. Do this with care, however!
my $no_nums    = 1;                             # Default value of option to NOT process words with numbers
my $no_punct   = 1;                             # Default value of option to NOT process words with punctuation
my $print_stats  = 1;
my $input_tokens = 0;                           # Initial count of all INPUT tokens
my $proc_tokens  = 0;                           # Initial count of PROCESSED tokens
my $input_types  = 0;                           # Initial count of all INPUT types
our $proc_types = 0;                            # Initial count of PROCESSED types
my $three_cols           = 0;
my $kill_head            = 1;
my $kill_tail            = 1;
my $spaces_as_split_char = 1;
my $merge_allomorphs     = 1;
my $pos_minimal          = 0;
my $pos_full             = 0;
my $calculate_hapax      = 0;                   # Set to 0 after finished writing the routine.
my $delimiter  = "\t";                          # Default delimiter inserted between columns in output file
my $split_char = "\t";                          # Default character that each input line is split on
my $punctuation = '(\*|\@|\.|\,|\;|\:|\=|\-|_|\"|\'|\+|\?|¿|\¿|\!|\¡|¡|\#|\$|\%|\&|\/|\(|\)|\^|\`|\[|\]|\{|\}|\~|\\\|\||<|>|¬|·)';
my $latin = 0;							   # Default encoding is UTF-8, expressed here as "not Latin-1"

# Define variables - INTERNAL USE ONLY! Changing these will most likely break FLW!
my $input_file_name  = "";
my $output_file_name = "";
my $in_basename      = "";
my $tokens;
my $word;
my %F;
my $extra_col            = "";
my $need_help            = 0;
my $need_usage           = 0;
my $debug   = 0;


# Meta-configs
my $process_as_words          = 0;
my $process_as_lemmas         = 0;
my $process_as_pos            = 0;
my $process_as_synrels        = 0;
my $process_as_word_plus_pos  = 0;
my $process_as_lemma_plus_pos = 0;

# Read command line options
GetOptions(
     "input|i=s"         => \$input_file_name,
     "output|o=s"        => \$output_file_name,
     "delimiter|del|d=s" => \$delimiter,
     "spliton|so=s"      => \$split_char,
     "nonums|nn!"        => \$no_nums,
     "nopunct|np!"       => \$no_punct,
     "print-stats|ps!"   => \$print_stats,
     "3-col|3c!"         => \$three_cols,
     "killhead|kh!"      => \$kill_head,
     "killtail|kt!"      => \$kill_tail,
     "spaces-split|ss!"  => \$spaces_as_split_char,
     "help|h"            => \$need_help,
     "usage|u"           => \$need_usage,
     "mergeallo|ma"      => \$merge_allomorphs,
     "latin|lat"         => \$latin,

     # Meta-configurations
     "words|w"     => \$process_as_words,
     "lemmas|l"    => \$process_as_lemmas,
     "pos|p"       => \$process_as_pos,
     "posfull|pf"  => \$pos_full,
     "posmin|pm"   => \$pos_minimal,
     "synrel|sr"   => \$process_as_synrels,
     "wordpos|wp"  => \$process_as_word_plus_pos,
     "lemmapos|lp" => \$process_as_lemma_plus_pos,

     # Other modes
     "debug|db!" => \$debug,
     "metafreq|mf|hapax|hx|legomena|leg!" => \$calculate_hapax
);

# Set variables for meta-configurations
if ( ( $pos_minimal == 1 ) || ( $pos_full == 1 ) ) {
     $process_as_pos = 1;
}

if ( ( $process_as_words == 1 ) || ( $process_as_lemmas == 1 ) ) {
     $three_cols = 0;
     $kill_head  = 0;
     $kill_tail  = 0;
}

if ( $process_as_pos == 1 ) {
     $no_nums    = 0;
     $no_punct   = 0;
     $three_cols = 0;
     $kill_head  = 1;
     $kill_tail  = 0;

     if ( $pos_minimal == 1 ) {
          $kill_head = 1;
          $kill_tail = 1;
     }
     if ( $pos_full == 1 ) {
          $kill_head = 0;
          $kill_tail = 0;
     }
}

if ( $process_as_synrels == 1 ) {
     $no_nums    = 0;
     $no_punct   = 0;
     $three_cols = 0;
     $kill_head  = 0;
     $kill_tail  = 0;
}

if ( $process_as_word_plus_pos == 1 ) {
     $no_nums    = 1;
     $no_punct   = 1;
     $three_cols = 1;
     $kill_head  = 1;
     $kill_tail  = 1;
}

if ( $process_as_lemma_plus_pos == 1 ) {
     $no_nums    = 1;
     $no_punct   = 1;
     $three_cols = 1;
     $kill_head  = 1;
     $kill_tail  = 1;
}

if ( $calculate_hapax == 1 ) {
     $no_nums    = 0;
     $no_punct   = 0;
     $three_cols = 0;
     $kill_head  = 0;
     $kill_tail  = 0;

     $process_as_synrels = 0;
     $merge_allomorphs   = 0;

}

# Forcibly set variables                                                        #
if ( $kill_tail == 1 ) {
     $kill_head = 1;
}


#print STDOUT "\n\$split_char = \"$split_char\"\n"; exit;   # FOR DEBUGGING

# CATCH HELP AND USAGE REQUESTS                                                 #
if ( $need_help == 1 ) {

     &help_me;
     exit;
}
if ( $need_usage == 1 ) {
     &help_me;      # Provide help info, until/unless a separate usage section is created
     exit;
}

# Print program info to terminal                                                #

print STDOUT "\n#####################################################################################";
print STDOUT "\n#                            FREQUENCY LIST WIZARD $version                            #";
print STDOUT "\n#                         Copyright (c) 2016 Scott Sadowsky                         #";
print STDOUT "\n#                                                                                   #";
print STDOUT "\n#                http://sadowsky.cl/ - ssadowsky at gmail period com                #";
print STDOUT "\n#          Licensed under the GNU General Public License, version 3 (GPLv3)         #";
print STDOUT "\n#                                                                                   #";
print STDOUT "\n#                    For help, run the program with the -h switch.                  #";
print STDOUT "\n#   Input files are expected to be UTF-8 encoded. Use the -lat switch for Latin-1   #";
print STDOUT "\n#####################################################################################";
print STDOUT "\n";

# INSURE AN INPUT FILE IS SPECIFIED                                             #
if ( $input_file_name eq "" ) {
     die "\nERROR: You must provide the name of the file to be processed with the -i switch:\n         frequency-list-wizard.pl -i=INPUT-FILE.txt\n         frequency-list-wizard.exe -i=INPUT-FILE.txt\n";
}

# IF NO OUTPUT FILE NAME IS SPECIFIED, GENERATE ONE AUTOMATICALLY               #
if ( $output_file_name eq "" ) {

     # Strip extension from input file name
     $in_basename = $input_file_name;
     $in_basename =~ s/(.+)\.(.+)/$1/;

     # Generate output file name from input basename
     if ( $calculate_hapax == 1 ) {
          $output_file_name = "$in_basename.METAFREQ.txt";
     }
     else {
          $output_file_name = "$in_basename.FLW.txt";
     }
}

# PROCESS SPECIAL CASES OF CHARACTERS PROVIDED ON COMMAND LINE                  #

# Delimiter string
if ( $delimiter eq "t" )   { $delimiter = "\t"; }
if ( $delimiter eq "\\t" ) { $delimiter = "\t"; }

# Split-on string
if ( $split_char eq "t" )   { $split_char = "\t"; }
if ( $split_char eq "\\t" ) { $split_char = "\t"; }


##### READ INPUT AND OUTPUT FILES #####

# IF LATIN-1 (ISO-8859-1) ENCODING IS SPECIFIED BY USER, OPEN FILES AS SUCH
if ( $latin == 1 ) {
	# READ INPUT FILE. MUST BE ISO-8859-1!                                          #
	open( INPUTFILE, '<:encoding(iso-8859-1)', "$input_file_name" )
	|| die "\nERROR: Input file \($input_file_name\) couldn't be read!\n";

	# OPEN OUTPUT FILE FOR WRITING. WILL BE ISO-8859-1                              #
	open( OUTPUTFILE, '>:encoding(iso-8859-1)', "$output_file_name" )
	|| die "\nERROR: The output file \($output_file_name\) couldn't be opened for writing!\n";
}
# IF NO ENCODING IS SPECIFIED BY USER, USE DEFAULT (UTF-8)
else {
	# READ INPUT FILE. MUST BE UTF-8!
	open( INPUTFILE, '<:encoding(utf8)', "$input_file_name" )
	|| die "\nERROR: Input file \($input_file_name\) couldn't be read!\n";

	# OPEN OUTPUT FILE FOR WRITING. WILL BE UTF-8
	open( OUTPUTFILE, '>:encoding(utf8)', "$output_file_name" )
	|| die "\nERROR: The output file \($output_file_name\) couldn't be opened for writing!\n";
}


# DEBUG
if ( $debug == 1 ) {
     print STDOUT "\n===================================";
     print STDOUT "\n\$no_nums=\t$no_nums";
     print STDOUT "\n\$no_punct=\t$no_punct";
     print STDOUT "\n\$three_cols=\t$three_cols";
     print STDOUT "\n\$kill_head=\t$kill_head";
     print STDOUT "\n\$kill_head=\t$kill_tail";
     print STDOUT "\n===================================\n\n";
}

# Print input and output file info to terminal

print STDOUT "\nInput file:\t$input_file_name";
print STDOUT "\nOutput file:\t$output_file_name";
print STDOUT "\n\n";

# PROCESS INPUT FILE LINE BY LINE                                               #
while (<INPUTFILE>) {

     chomp;

     # PREPROCESSING                                                            #

     # Strip leading spaces off line (CWB adds them to
     # 1st (frequency) column in some modes).
     $_ =~ s/^( )+//g;

     # Treat 2+ spaces as the split character, if desired
     if ( $spaces_as_split_char == 1 ) {
          $_ =~ s/( ){2,}/$split_char/g;
     }

     # Eliminate unwanted portion of SynRel field (Connexor output) if desired  #
     if ( $process_as_synrels == 1 ) {
          $_ =~ s/>.+$//;
     }

     # SPLIT INPUT LINES AND PRE-PROCESS THEM                              #

     # PROCESS THREE-COLUMN INPUT FILES
     if ( $three_cols == 1 ) {

          # FOR HAPAX PROCESSING
          # If hapax are to be calculated, read the FREQUENCY column of the     #
          # source file in as if it contained words, and set $tokens to 1       #
          # (this has the effect of making frequencies countable).              #
          if ( $calculate_hapax == 1 ) {
               ( $word, $tokens, $extra_col ) = split(/$split_char/);
               $tokens = 1;
          }

          # FOR NORMAL (NON-HAPAX) PROCESSING
          # In all other cases (most of them), read columns in normally         #
          else {
               ( $tokens, $word, $extra_col ) = split(/$split_char/);
          }

          # Eliminate head info from THIRD column, if desired.                  #
          if ( $kill_head == 1 ) {
               $extra_col =~ s/^\@\w+ //;
          }

          # Eliminate extra POS info from THIRD column, if desired.             #
          if ( $kill_tail == 1 ) {
               $extra_col =~ s/Heur /Heur_/;    # Fuse "Heur" to main POS that follows
               $extra_col =~ s/ .+$//;          # Kill tail of POS info
          }

          # Join column 2 (typically "word") and column 3 (typically "pos" or   #
          # similar) unless hapax are being calculated.                         #
          unless ( $calculate_hapax == 1 ) {
               $word = $word . "#####" . $extra_col;    # "#####" is a temporary divider
          }

          # Merge entries for specific allomorphs In LEMMA+POS or WORD+POS      #
          # form that Connexor treats separately, if desired                    #
          if ( $merge_allomorphs == 1 ) {

               # print STDOUT "\n\$word-BEF=\t$word";    # DEBUG

               # In LEMMA+POS or WORD+POS form
               $word =~ s/^(u|U)#####CC/o#####CC/;
               $word =~ s/^(e|E)#####CC/y#####CC/;
               $word =~ s/^(l|L)#####(DET.*)/el#####$2/; # For Connexor-style output, where "del" > "de" "l"
          }
     }

     # PROCESS TWO-COLUMN INPUT FILES
     else {

          # If calculating hapax, invert columns: read FREQUENCIES into $word   #
          # and, after reading words into $tokens, assign $tokens a value of 1  #
          # to make the frequencies countable.                                  #
          if ( $calculate_hapax == 1 ) {
               ( $word, $tokens ) = split(/$split_char/);
               $tokens = 1;
          }
          else {
               ( $tokens, $word ) = split(/$split_char/);
          }

          # ONLY if processing as input POS only, eliminate extra POS info      #
          # from SECOND column, if desired.                                     #

          # Eliminate POS head info
          if ( $kill_head == 1 ) {
               $word =~ s/^\@\w+ //;
          }

          # Eliminate POS tail info
          if ( ( $process_as_pos == 1 ) && ( $kill_tail == 1 ) ) {
               $word =~ s/Heur /Heur_/;    # Fuse "Heur" to main POS that follows
               $word =~ s/ .+$//;          # Kill tail of POS info
          }

          # Merge entries for specific allomorphs In LEMMA or WORD form    #
          # that Connexor treats separately, if desired                    #
          if ( $merge_allomorphs == 1 ) {
               $word =~ s/^(u|U)$/o/;
               $word =~ s/^(e|E)$/y/;
               $word =~ s/^(l|L)$/el/;
          }
     }

     # INCREMENT INPUT type AND FREQUENCY COUNTERS                             #
     $input_types  = $input_types + 1;
     $input_tokens = $input_tokens + $tokens;

     # ELIMINATE HEAD INFO FROM *SECOND* COLUMN (MERGED OR NOT), IF DESIRED.    #
     # (This refers to part of the grammatical tagging done by Connexor.        #
     if ( $kill_head == 1 ) {
          $word =~ s/^\@\w+ //;
     }

     # DEBUG
     if ( $debug == 1 ) {
          print STDOUT "\n\{$tokens\}\t\{$word\}\t\t\{$extra_col\}";
     }

     # PROCESS INPUT LINES                                                      #
     # EXCLUDE UNWANTED ENTRIES (NUMS AND/OR PUNCTUATION AND SUM FREQUENCIES)   #

     # If only the NO-NUMBERS option was selected
     if ( $no_nums == 1 && $no_punct == 0 ) {
          unless (( ( $three_cols == 1 ) && ( $word =~ m/[0-9].*?(#####)/ ) )
               || ( ( $three_cols == 0 ) && ( $word =~ m/[0-9].*?($)/ ) ) )
          {
               $F{ lc($word) } += $tokens;
               $proc_tokens = $proc_tokens + $tokens;
          }
     }

     # If only the NO-PUNCTUATION option was selected
     elsif ( $no_nums == 0 && $no_punct == 1 ) {
          unless (( ( $three_cols == 1 ) && ( $word =~ m/$punctuation.*?(#####)/ ) )
               || ( ( $three_cols == 0 ) && ( $word =~ m/$punctuation.*?($)/ ) ) )
          {
               $F{ lc($word) } += $tokens;
               $proc_tokens = $proc_tokens + $tokens;
          }
     }

     # If BOTH no-numbers and no-punctuation options selected
     elsif ( $no_nums == 1 && $no_punct == 1 ) {
          unless (( ( $three_cols == 1 ) && ( $word =~ m/($punctuation.*?(#####)|[0-9].*?(#####))/ ) )
               || ( ( $three_cols == 0 ) && ( $word =~ m/($punctuation.*?($)|[0-9].*?($))/ ) ) )
          {
               $F{ lc($word) } += $tokens;
               $proc_tokens = $proc_tokens + $tokens;
          }
     }

     # If NEITHER option selected
     else {
          $F{ lc($word) } += $tokens;
          $proc_tokens = $proc_tokens + $tokens;
     }
}

END {

     # PERFORM REVERSE NATURAL NUMERIC SORT (e.g. 200,10,2,1 instead of 200,2,10,1, etc.) #
     # AND PRINT RESULTS TO OUPUT FILE                                                    #

     # FOR HAPAX CALCULATIONS                                                   #
     if ( $calculate_hapax == 1 ) {

          # Print hapax output file header
          print OUTPUTFILE "TYPE-OF-LEGOMENA\tCOUNT\n";

          # Sort hash by VALUES and put keys in an array
          my @keys = ( sort { $a <=> $b || $F{$b} <=> $F{$a} || $a cmp $b } keys %F );

          # Process array
          foreach my $key (@keys) {

               # Don't process statistics lines from     #
               # source files (they begin with "=").     #
               unless ( $key =~ m/^=/ ) {
                    # Print each line of array to output file
                    print OUTPUTFILE $key, "$delimiter", $F{$key}, "\n";
               }
          }
     }

     # FOR NORMAL (NON-HAPAX) PROCESSING                                        #
     else {

          # Sort hash by KEYS
          foreach ( sort { $F{$b} <=> $F{$a} || length($b) <=> length($a) || $a cmp $b } keys %F ) {

               # Increment processed types count
               $proc_types = $proc_types + 1;

               # Place value of $_ in a temp variable so it can be transformed,
               # while allowing $_ to be used for hash lookup purposes
               my $transformed_word = $_;

               # Unmerge columns if they were merged
               if ( $three_cols == 1 ) {
                    $transformed_word =~ s/#####/$delimiter/;
               }

               # Print each line to output file
               print OUTPUTFILE $F{$_}, "$delimiter", $transformed_word, "\n";
          }
     }

     # Print statistics of processed items, if desired  (non-hapax only)        #
     if ( ( $print_stats == 1 ) && ( $calculate_hapax == 0 ) ) {

          #print STDOUT ">>>FINAL \$proc_types=\t$proc_types\n";    # DEBUG_TEMP

          # Calculate Type-Token Ratios and print type, token and TTR info      #
          if ( $input_tokens != 0 ) {    # Avoid divide by zero errors
               my $input_ttr = sprintf( '%.10f', ( $input_types / $input_tokens ) );

               # Print type, token and TTR info for INPUT  ITEMS
               print OUTPUTFILE "============\t============\t============\n";
               print OUTPUTFILE "=\t$input_types\t!INPUT_TYPES\n";
               print OUTPUTFILE "=\t$input_tokens\t!INPUT_TOKENS\n";
               print OUTPUTFILE "=\t$input_ttr\t!INPUT_TTR\n";
          }
          if ( $proc_tokens != 0 ) {     # Avoid divide by zero errors
               my $processed_ttr = sprintf( '%.10f', ( $proc_types / $proc_tokens ) );

               # Print type, token and TTR info for PROCESSED ITEMS
               print OUTPUTFILE "============\t============\t============\n";
               print OUTPUTFILE "=\t$proc_types\t!PROCESSED_TYPES\n";
               print OUTPUTFILE "=\t$proc_tokens\t!PROCESSED_TOKENS\n";
               print OUTPUTFILE "=\t$processed_ttr\t!PROCESSED_TTR\n";
               print OUTPUTFILE "============\t============\t============\n";
          }
     }
}

# End of program.                                                               #
exit;

# SUBROUTINE: HELP MESSAGE                                                     #
sub help_me {

     print STDOUT "\n#####################################################################################";
     print STDOUT "\n#                            FREQUENCY LIST WIZARD $version                            #";
     print STDOUT "\n#                         Copyright (c) 2016 Scott Sadowsky                         #";
     print STDOUT "\n#                                                                                   #";
     print STDOUT "\n#                 http://sadowsky.cl - ssadowsky at gmail period com                #";
     print STDOUT "\n#          Licensed under the GNU General Public License, version 3 (GPLv3)         #";
     print STDOUT "\n#####################################################################################";
     print STDOUT "\n";
     print STDOUT "\nUSAGE (script):   ./frequency-list-wizard.pl -i=INFILE.TXT [OPTIONS]";
     print STDOUT "\n      (.exe)  :   frequency-list-wizard.exe -i=INFILE.TXT [OPTIONS]";
     print STDOUT "\n";
     print STDOUT "\nSUMMARY:      Process frequency lists in various useful ways.";
     print STDOUT "\n";
     print STDOUT "\nREQUIREMENTS: - Input files are assumed to be in UTF-8 encoding.";
     print STDOUT "\n              - Use the -lat switch to process ISO-8859-1 (Latin-1) files.";
     print STDOUT "\n              - Frequency lists may have two or three columns. The third column is";
     print STDOUT "\n                optional. The -3c switch must be used with such lists.";
     print STDOUT "\n              - First column MUST contain the frequencies.";
     print STDOUT "\n";
     print STDOUT "\nDESCRIPTION:  The default processing mode takes a 2-column frequency list in UTF-8";
     print STDOUT "\n              encoding, merges all entries that vary only by their capitalization ";
     print STDOUT "\n              (e.g. \'house\', \'House\' and \'HOUSE\'), and sums the frequencies";
     print STDOUT "\n              of each of these items to give you the total frequency per \'allo-";
     print STDOUT "\n              capitalization\' (which is almost certainly what is desired when";
     print STDOUT "\n              working with lexical items, lemmas, etc.). It performs a reverse natural";
     print STDOUT "\n              numeric sort on the results and outputs them to a text file.";
     print STDOUT "\n";
     print STDOUT "\n              Three-column lists (e.g. frequency + lemma + POS) can be processed using";
     print STDOUT "\n              the \'-3c\' switch. This options allows identical lemmas with different";
     print STDOUT "\n              POSes to be processed (and counted) separately (e.g. \'jump\' (NOUN) and";
     print STDOUT "\n              \'jump\' (VERB)).";
     print STDOUT "\n";
     print STDOUT "\n              If desired, FLW can also calculate the total number of types and tokens";
     print STDOUT "\n              in the frequency list, as well as its type-token ratio. (This is done by";
     print STDOUT "\n              default, and printed at the end of the processed frequency list).";
     print STDOUT "\n";
     print STDOUT "\n              Optionally, FLW can eliminate entries containing numerals (-nn) and/or";
     print STDOUT "\n              punctuation marks (-np) from frequency lists. It can also merge certain";
     print STDOUT "\n              Spanish allomorphs (y + e, o + u) into a single item (-ma). All three";
     print STDOUT "\n              options are activated by default, and can be deactivated with the -nonn,";
     print STDOUT "\n              -nonp and -noma switches. The difference between the number of items in";
     print STDOUT "\n              the source frequency list and the number actually processed after";
     print STDOUT "\n              eliminating numbers or punctuation marks is reflected in the type and";
     print STDOUT "\n              token counts shown with the \'--print-stats\' option (\'INPUT_TYPES\'";
     print STDOUT "\n              versus \'PROCESSED_TYPES\', etc.).";
     print STDOUT "\n";
     print STDOUT "\n              When using the 3-column option, POS information in the third column can";
     print STDOUT "\n              be pruned if it is in a Connexor-style format (e.g. \'\@NH N MSC SG\').";
     print STDOUT "\n              The -kh (--killhead) switch will eliminate the head of the field (\'\@NH \'),";
     print STDOUT "\n              while -kt (--killtail) will eliminate the tail (\' MSC SG\').";
     print STDOUT "\n";
     print STDOUT "\n              The \'meta-frequency\' (AKA \'legomena\') processing mode (activated with the";
     print STDOUT "\n              \'-mf\' or \'-hx\' switches) calculates the frequency of each frequency in";
     print STDOUT "\n              the list. Its output is a frequency list of frequencies -- how many items";
     print STDOUT "\n              occur 1 time, 2 times, and so on.";
     print STDOUT "\n";
     print STDOUT "\nOPTIONS:";
     print STDOUT "\n";
     print STDOUT "\n  -i,  --input        Name of input file. MANDATORY! Assumed to be UTF-8.";
     print STDOUT "\n  -o,  --output       Name of output file. If not provided, a name will be automatically";
     print STDOUT "\n                        generated using the input file base name.";
	print STDOUT "\n  -lat,--latin        Process Latin-1 (ISO-8859-1) texts. Output will be encoded same way.";
     print STDOUT "\n  -ps,--print-stats   Calculate and print type, token and TTR statistics (DEFAULT: ON).";
     print STDOUT "\n  -mf, --meta-freq    Calculate the frequencies of each frequency in the list. In other";
     print STDOUT "\n                        words, generates a meta-frequency list, or list of n-legomena.";
     print STDOUT "\n  -leg, --legomena    Same as -mf or --meta-freq.";
     print STDOUT "\n";
     print STDOUT "\n  -nn, --nonums       Eliminate list entries that contain numbers (e.g. \"Bill7\").";
     print STDOUT "\n  -np, --nopunct      Eliminate list entries that contain punctuation (e.g. \"a\@b.com\").";
     print STDOUT "\n  -ma, --mergeallo    Merge Spanish allomorphs (e.g. \"y\" and \"e\", \"o\" and \"u\").";
     print STDOUT "\n";
     print STDOUT "\n  -3c, --3-col        Process 3-column lists. Temporarily merges columns 2 (typically";
     print STDOUT "\n                        \"word\") and 3 (\"POS\", \"lemma\", etc.). This allows processing";
     print STDOUT "\n                        of identical items that have different POSes/lemmas assigned to";
     print STDOUT "\n                        them (e.g. \"canto\" (NOUN SG MSC) and \"canto\" (V 1SG PRES IND)).";
     print STDOUT "\n                        After processing, the merge is undone, giving the original";
     print STDOUT "\n                        number of columns.";
     print STDOUT "\n  -kh, -killhead      In lists that provide head info in the format \"\@NH \", eliminate";
     print STDOUT "\n                        this information, leaving only POS info in the column (e.g.";
     print STDOUT "\n                        Connexor). Assumes that this info is in the THIRD column.";
     print STDOUT "\n  -kt, -killtail      In lists with POS info, eliminate all of this info EXCEPT the";
     print STDOUT "\n                        general grammatical category (e.g. \"DET MSC SG\" becomes \"DET\").";
     print STDOUT "\n                        Forces -killtail.";
     print STDOUT "\n";
     print STDOUT "\n  -so, --spliton      Define the character that input file lines will be split on. The";
     print STDOUT "\n                        default value is \\t (tab).";
     print STDOUT "\n  -d,  --delimiter    Allows an alternative delimiter character to be used. This is the";
     print STDOUT "\n                        character that is inserted between columns in the output file.";
     print STDOUT "\n                        Entering \"t\" will produce \\t. The default value is \\t (tab).";
     print STDOUT "\n  -st,--spaces-split  Treat 2 or more spaces as the split character. Typically for messy";
     print STDOUT "\n                        lists. Care must be taken with this option, as any extraneous";
     print STDOUT "\n                        space can (and will) have undesirable consequences.";
     print STDOUT "\n";
     print STDOUT "\nMETA-CONFIGURATIONS:";
     print STDOUT "\n";
     print STDOUT "\n  -w, --words         Process frequency list as words (2 columns: FREQ, WORD).";
     print STDOUT "\n  -l, --lemmas        Process frequency list as lemmas (2 columns: FREQ, LEMMA).";
     print STDOUT "\n  -pm, --posmin       Process frequency list as minimal POS (2 columns: FREQ, POS. Kills";
     print STDOUT "\n                         POS head and tail).";
     print STDOUT "\n  -p, --pos           Process frequency list as partial POS (2 columns: FREQ, POS. Kills";
     print STDOUT "\n                         POS head, leaves tail intact).";
     print STDOUT "\n  -pf, --posfull      Process frequency list as full POS (2 columns: FREQ, POS. Leaves";
     print STDOUT "\n                        entire POS intact).";
     print STDOUT "\n  -sr, --synrel       Process frequency list as syntactic relationships (2 columns, deactivates";
     print STDOUT "\n                        potentially destructive options).";
     print STDOUT "\n  -wp, --wordpos      Process frequency list as words + POS (3 columns: FREQ, WORD, POS. Kills";
     print STDOUT "\n                        POS head and tail, and eliminates numbers and punctuation).";
     print STDOUT "\n  -lp, --lemmapos     Process frequency list as lemmas + POS (3 columns: FREQ, LEMMA, POS. Kills";
     print STDOUT "\n                        POS head and tail, and eliminates numbers and punctuation).";
     print STDOUT "\n";
     print STDOUT "\n  -db, --debug        Print debug info to STDOUT.";
     print STDOUT "\n  -h,  --help         Show this help information.";
     print STDOUT "\n\n";
}
