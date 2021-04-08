#!/usr/bin/perl -w
# NAME: gitstat.pl
# AIM: Give a trimmed version of 'git status` command
# 2021/04/05 - Initial cut...
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
use Cwd;
my $os = $^O;
my ($pgmname,$perl_dir) = fileparse($0);
my $curr_dir = cwd();
if ($perl_dir =~ /\.[\\\/]$/) {
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
my $VERS = "0.1.0 2021-04-05";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = '';
my $skip_blanks = 1;
my $skip_tail = 1;
my $skip_use = 1;

# ### DEBUG ###
my $debug_on = 0;
my $def_file = 'def_file';

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

sub process_in_file($) {
    my ($inf) = @_;
    if (! open INF, "<$inf") {
        pgm_exit(1,"ERROR: Unable to open file [$inf]\n"); 
    }
    my @lines = <INF>;
    close INF;
    my $lncnt = scalar @lines;
    prt("Processing $lncnt lines, from [$inf]...\n");
    my ($line,$inc,$lnn);
    $lnn = 0;
    foreach $line (@lines) {
        chomp $line;
        $lnn++;
        if ($line =~ /\s*#\s*include\s+(.+)$/) {
            $inc = $1;
            prt("$lnn: $inc\n");
        }
    }
}

sub gitstat() {
    open IF, "git status|" or mydie( "ERROR: Can not do 'git status' ... $! \n" );
    my @lines = <IF>;
    close IF;
    my $max = scalar @lines;
    prt("Got $max lines to scan... \n") if (VERB9());
    my ($i,$line,$acnt,$mcnt,$lnn,$len,$tline);
    $lnn = 0;
    $acnt = 0;
    $mcnt = 0;
    for ($i = 0; $i < $max; $i++) {
        $line = $lines[$i];
        chomp $line;
        $lnn++;
        $len = length($line);
        if ($skip_tail) {
            if ($line =~ /^Untracked\s+/) {
                $i++;
                for (; $i < $max; $i++) {
                    $line = $lines[$i];
                    chomp $line;
                    $lnn++;
                    $len = length($line);
                    $tline = trim_all($line);
                    if ($line =~ /^\t+/) {
                    # if (($len > 6) && (substr($line,0,4) eq '    ')) {
                    # if ($line =~ /^\s{6}.+$/) {
                        if (VERB2()) {
                            prt("Add: ") if ($acnt == 0);
                            prt("$tline ");
                        }
                        $acnt++;
                    }
                }
                prt("($acnt)\n") if (($acnt > 0) && VERB2());
                last;
            }
        }
        if ($skip_blanks) {
            next if ($line =~ /^\s*$/);
        }
        if ($line =~ /^\t+/) {
            $mcnt++;
        }
        if ($skip_use) {
            next if ($line =~ /^\s+\(use\s+/);
        }
        prt("$lnn: $line\n");
    }
    if (($mcnt == 0) && ($acnt == 0)) {
        prt("Appears nothing to commit, or add - clean\n");
    } else {
        prt("Mod: $mcnt, Add: $acnt\n");
    }
}


#########################################
### MAIN ###
parse_args(@ARGV);
#process_in_file($in_file);
gitstat();
pgm_exit(0,"");
########################################

sub need_arg {
    my ($arg,@av) = @_;
    pgm_exit(1,"ERROR: [$arg] must have a following argument!\n") if (!@av);
}

sub parse_args {
    my (@av) = @_;
    my ($arg,$sarg);
    my $verb = VERB2();
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
                $verb = VERB2();
                prt("Verbosity = $verbosity\n") if ($verb);
            } elsif ($sarg =~ /^l/) {
                if ($sarg =~ /^ll/) {
                    $load_log = 2;
                } else {
                    $load_log = 1;
                }
                prt("Set to load log at end. ($load_log)\n") if ($verb);
            } elsif ($sarg =~ /^o/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $out_file = $sarg;
                prt("Set out file to [$out_file].\n") if ($verb);
            } else {
                pgm_exit(1,"ERROR: Invalid argument [$arg]! Try -?\n");
            }
        } else {
            $in_file = $arg;
            #prt("Set input to [$in_file]\n") if ($verb);
            pgm_exit(1,"ERROR: Invalid argument [$arg]! Try -?\n");
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
    #if (length($in_file) ==  0) {
    #    pgm_exit(1,"ERROR: No input files found in command!\n");
    #}
    #if (! -f $in_file) {
    #    pgm_exit(1,"ERROR: Unable to find in file [$in_file]! Check name, location...\n");
    #}
}

sub give_help {
    prt("$pgmname: version $VERS\n");
    prt("Usage: $pgmname [options]\n");
    prt("Options:\n");
    prt(" --help  (-h or -?) = This help, and exit 0.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. def=$verbosity\n");
    prt(" --load        (-l) = Load LOG at end. ($outfile)\n");
    prt(" --out <file>  (-o) = Write output to this file.\n");
}

# eof - template.pl
