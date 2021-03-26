#!/usr/bin/perl -w
# NAME: bat2sh.pl
# AIM: Given a DOS BAT file, try to convert it to a linux shell script, hopefully...
# 2021/03/26 - Move to GPerl, and add some more conversion...
# 2013-03-17 - Initial cut
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
use Cwd;
my $os = $^O;
my ($pgmname,$perl_dir) = fileparse($0);
my $curr_dir = cwd();
if ($perl_dir =~ /^\.[\\\/]$/) {
    $perl_dir = $curr_dir;
}
my $PATH_SEP = '/';
my $temp_dir = '/tmp';
if ($os =~ /win/i) {
    $temp_dir = $perl_dir;
    $PATH_SEP = "\\";
}
unshift(@INC, $perl_dir);
require 'lib_utils.pl' or die "Unable to load 'lib_utils.pl' Check paths in \@INC...\n";
# log file stuff
our ($LF);
my $outfile = $temp_dir.$PATH_SEP."temp.$pgmname.txt";
open_log($outfile);

# user variables
my $VERS = "0.0.2 2021-03-26";
#  $VERS = "0.0.1 2013-03-17";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = $temp_dir.$PATH_SEP."temp.$pgmname.sh";

# ### DEBUG ###
my $debug_on = 0;
my $def_file = 'F:\FG\18\updopenssl.bat';

### program variables
my @warnings = ();
my $cwd = cwd();

sub VERB1() { return $verbosity >= 1; }
sub VERB2() { return $verbosity >= 2; }
sub VERB5() { return $verbosity >= 5; }
sub VERB9() { return $verbosity >= 9; }

sub show_warnings($) {
    my ($val) = @_;
    if (@warnings) {
        prt( "\nGot ".scalar @warnings." WARNINGS...\n" );
        foreach my $itm (@warnings) {
           prt("$itm\n");
        }
        prt("\n");
    } else {
        prt( "\nNo warnings issued.\n\n" ) if (VERB9());
    }
}

sub pgm_exit($$) {
    my ($val,$msg) = @_;
    if (length($msg)) {
        $msg .= "\n" if (!($msg =~ /\n$/));
        prt($msg);
    }
    show_warnings($val);
    close_log($outfile,$load_log);
    exit($val);
}


sub prtw($) {
   my ($tx) = shift;
   $tx =~ s/\n$//;
   prt("$tx\n");
   push(@warnings,$tx);
}

sub write2binfile {
	my ($txt,$fil) = @_;
	open WOF, ">$fil" or mydie("ERROR: Unable to open $fil! $!\n");
    binmode WOF;
	print WOF $txt;
	close WOF;
}


sub conv_vars($) {
    my $txt = shift;
    while ($txt =~ /\%(\w+)\%/) {
        $txt =~ s/\%(\w+)\%/\$$1/;
    }
    return $txt;
}

sub process_in_file($) {
    my ($inf) = @_;
    if (! open INF, "<$inf") {
        pgm_exit(1,"ERROR: Unable to open file [$inf]\n"); 
    }
    my @lines = <INF>;
    close INF;
    my $lncnt = scalar @lines;
    prt("Processing $lncnt lines, from [$inf]...\n");
    my ($line,$txt,$lnn,$var);
    $lnn = 0;
    my @shlines = ();
    my ($nm,$dir,$ext) = fileparse($inf, qr/\.[^.]*/ );
    my $sh = $nm.".sh";
    push(@shlines, "#!/bin/sh");
    push(@shlines, "#< $sh ".get_YYYYMMDD(time()).", from $nm$ext");
    push(@shlines, "BN=`basename \$0`");
    push(@shlines, "");
    push(@shlines, "ask()");
    push(@shlines, "{");
    push(@shlines, "\tpause");
    push(@shlines, "\tif [ ! \"\$?\" = \"0\" ]; then");
    push(@shlines, "\t\texit 1");
    push(@shlines, "\tfi");
    push(@shlines, "}");
    push(@shlines, "");
    # Process the input lines
    foreach $line (@lines) {
        chomp $line;
        $lnn++;
        $line = conv_vars($line);
        if ($line =~ /^\s*@*echo\s+(.+)$/i) {
            $txt = $1;
            push(@shlines,"echo \"$txt\"");
        } elsif ($line =~ /^@*set\s+(\w+)=(.+)$/i ) {
            $var = $1;
            $txt = $2;
            $txt =~ s/\\/\//g;
            push(@shlines, "$var=\"$txt\"");
        } elsif ($line =~ /^@*goto\s+/i) {
            push(@shlines,"# $line");
        } elsif ($line =~ /^@*if\s+/i) {
            push(@shlines,"# $line");
        } elsif ($line =~ /^@*setlocal/i) {
        } elsif ($line =~ /^@*endlocal/i) {
        } elsif ($line =~ /^@*pause/i) {
            push(@shlines,"ask");
        } elsif ($line =~ /^\s*:\s*(\w+)/i) {
            push(@shlines,"# $line");
        } elsif ($line =~ /^@*REM\s+/i) {
            push(@shlines,"# $line");
        } elsif ($line =~ /^@*exit\s+\/b\s+(\d+)$/i) {
            $var = $1;
            push(@shlines,"exit $var");
        } elsif ($line =~ /^@*call\s+(.+)$/i) {
            $txt = $1;
            if ($txt =~ /\s*nul$/) {
                $txt =~ s/\s*nul$/\/dev\/null/;
            }
            push(@shlines,"echo \"\$BN: Doing: '$txt'\"");
            push(@shlines,"$txt");
        } else {
            push(@shlines,$line);
        }
    }
    $line = join("\n",@shlines)."\n";
    $txt = rename_2_old_bak($out_file);
    write2binfile($line,$out_file);
    prt("Resutls written to '$out_file', b=$txt\n");
}

#########################################
### MAIN ###
parse_args(@ARGV);
process_in_file($in_file);
pgm_exit(0,"");
########################################

sub need_arg {
    my ($arg,@av) = @_;
    pgm_exit(1,"ERROR: [$arg] must have a following argument!\n") if (!@av);
}

sub parse_args {
    my (@av) = @_;
    my ($arg,$sarg);
    while (@av) {
        $arg = $av[0];
        if ($arg =~ /^-/) {
            $sarg = substr($arg,1);
            $sarg = substr($sarg,1) while ($sarg =~ /^-/);
            if (($sarg =~ /^h/i)||($sarg eq '?')) {
                give_help();
                pgm_exit(0,"Help exit(0)");
            } elsif ($sarg =~ /^v/) {
                if ($sarg =~ /^v.*(\d+)$/) {
                    $verbosity = $1;
                } else {
                    while ($sarg =~ /^v/) {
                        $verbosity++;
                        $sarg = substr($sarg,1);
                    }
                }
                prt("Verbosity = $verbosity\n") if (VERB1());
            } elsif ($sarg =~ /^l/) {
                if ($sarg =~ /^ll/) {
                    $load_log = 2;
                } else {
                    $load_log = 1;
                }
                prt("Set to load log at end. ($load_log)\n") if (VERB1());
            } elsif ($sarg =~ /^o/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $out_file = $sarg;
                prt("Set out file to [$out_file].\n") if (VERB1());
            } else {
                pgm_exit(1,"ERROR: Invalid argument [$arg]! Try -?\n");
            }
        } else {
            $in_file = $arg;
            prt("Set input to [$in_file]\n") if (VERB1());
        }
        shift @av;
    }

    if ($debug_on) {
        prtw("WARNING: DEBUG is ON!\n");
        if ((length($in_file) ==  0) && $debug_on) {
            $in_file = $def_file;
            prt("Set DEFAULT input to [$in_file]\n");
        }
    }
    if (length($in_file) ==  0) {
        pgm_exit(1,"ERROR: No input files found in command!\n");
    }
    if (! -f $in_file) {
        pgm_exit(1,"ERROR: Unable to find in file [$in_file]! Check name, location...\n");
    }
}

sub give_help {
    prt("$pgmname: version $VERS\n");
    prt("Usage: $pgmname [options] in-file\n");
    prt("Options:\n");
    prt(" --help  (-h or -?) = This help, and exit 0.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. def=$verbosity\n");
    prt(" --load        (-l) = Load LOG at end. ($outfile)\n");
    prt(" --out <file>  (-o) = Write output to this file.\n");
}

# eof - template.pl
