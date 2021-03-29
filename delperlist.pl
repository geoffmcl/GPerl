#!/usr/bin/perl -w
# NAME: delperlist.pl
# AIM: Delete a set of file per an input file list
# 2021/03/29 - Moved to GPerl repo
# 16/05/2016 - Handle wildcards with glob
# 23/05/2013 geoff mclane http://geoffair.net/mperl
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
use Term::ReadKey;
use File::stat;
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
my $VERS = "0.0.4 2021-03-29";
#  $VERS = "0.0.3 2020-09-11";
#my $VERS = "0.0.2 2016-05-16";
##my $VERS = "0.0.1 2013-05-23";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = '';

# ### DEBUG ###
my $debug_on = 0;
my $def_file = 'C:\FG\18\FLU_2.8\build\install_manifest_dbg.txt';

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

sub got_keyboard {
    my ($rc) = shift;
    if (defined (my $char = ReadKey(-1)) ) {
		# input was waiting and it was $char
        $$rc = $char;
        return 1;
	}
    return 0;
}

sub delay {
    my ($secs) = shift;
    select(undef, undef, undef, $secs);
}

sub wait_for_input() {
    my ($char);
    while (1) {
        if (got_keyboard(\$char)) {
            last;
        }
        delay(0.1); # if ($add_delay);
    }
    return $char;
}

sub got_wild($) {
    my $txt = shift;
    my $len = length($txt);
    my ($i,$ch);
    for ($i = 0; $i < $len; $i++) {
        $ch = substr($txt,$i,1);
        return 1 if ($ch eq '?');
        return 1 if ($ch eq '*');
    }
    return 0;
}

# assume each file is a file name
# exception skip lines that commence with '#'
sub process_in_file($) {
    my ($inf) = @_;
    if (! open INF, "<$inf") {
        pgm_exit(1,"ERROR: Unable to open file [$inf]\n"); 
    }
    my @lines = <INF>;
    close INF;
    my $lncnt = scalar @lines;
    prt("Processing $lncnt lines, from [$inf]...\n");
    my ($line,$fcnt,$lnn,$nofind,$fnd);
    $lnn = 0;
    my @nlines = ();
    $fcnt = 0;
    $nofind = 0;
    my @failed = ();
    my @notfound = ();
    foreach $line (@lines) {
        chomp $line;
        $lnn++;
        if ($line =~ /^\s*\#/) {
            ### push(@nlines,$line);
            next;
        }
        if ($os =~ /win/i) {
            $line = path_u2d($line);
        } else {
            $line = path_d2u($line);
        }
        $fnd = 0;
        if (-f $line) {
            $fcnt++;
            push(@nlines,$line);
            prt("$line ok\n") if (VERB9());
            $fnd = 1;
        } elsif (got_wild($line)) {
            my @files = glob($line);
            if (@files) {
                foreach my $fil (@files) {
                    if (-f $fil) {
                        $fcnt++;
                        $fnd++;
                        push(@nlines,$fil);
                        prt("$fil gok\n") if (VERB9());
                    } else {
                        pgm_exit(1, "ERROR: glob $line gave $fil!\n");
                    }
                }
            }
            # else {
            # silently ignore none - treat as a no find
        }
        if (! $fnd) {
            $nofind++;
            prt("$line - NOT FOUND!\n") if (VERB9());
            push(@notfound,$line);
        }
    }
    prt("In processing $lncnt lines, found $fcnt files to delete...\n");
    if ($nofind) {
        prt("Note $nofind files were NOT found.\n");
        prt(join("\n",@notfound)."\n") if (VERB1());
    }
    if ($fcnt == 0) {
        prt("For $lncnt lines, NO files were found to delete. Increase verbosity to see details...\n");
        return;
    }
    prt("List $fcnt to be deleted... use -v1 to list...\n");
    if (VERB1()) {
        prt(join("\n",@nlines)."\n");
    }
    prt("Proceed to DELETE these $fcnt files? Only 'y' to continue... all others keys abort.\n");
    $lnn = wait_for_input();
    if ($lnn ne 'y') {
        prt("Aborting process...\n");
        return;
    }
    prt("Doing $fcnt deletions...\n");
    my $dcnt = 0;
    my @deleted = ();
    foreach $line (@nlines) {
        if (unlink $line) {
            prt("$line DELETED.\n") if (VERB5());
            $dcnt++;
            push(@deleted,$line);
        } else {
            prt("FAILED: to delete [$line]! $!\n");
            push(@failed,$line);
        }
    }
    if (@failed) {
        $lnn = @failed;
        prtw("WARNING: $lnn FAILED to be deleted!\n");
        prt(join("\n",@failed)."\n") if (VERB1());
    }
    prt("Deleted $dcnt files...\n");


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
        if (length($in_file) ==  0) {
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
