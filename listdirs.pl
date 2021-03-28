#!/usr/bin/perl -w
# NAME: listdirs.pl
# AIM: Given an in input path, list just the dirs
# 2021/03/28 - Move to GPerl repo
# 2019-12-11 - Initial cut
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
my $VERS = "0.0.19 2021-03-28";
#  $VERS = "0.0.9 2019-12-11";
my $load_log = 0;
my $in_dir = '';
my $verbosity = 0;
my $out_file = '';

# ### DEBUG ###
my $debug_on = 0;
my $def_file = '.';

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

my $dir_cnt = 0;
my $fil_cnt = 0;
sub get_dir_stats($$) {
    my ($dir,$lev) = @_;
    my $cnt = 0;
    my $dirs = 0;
    my $fils = 0;
    my $oths = 0;
    if (! opendir(DIR,$dir)) {
        prtw("WARNING: Unable to open dir '$dir'!\n");
        return ($cnt,$dirs,$fils,$oths);
    }
    my @files = readdir(DIR);
    closedir(DIR);
    my ($itm,$ff);
    ut_fix_directory(\$dir);
    $cnt = scalar @files;
    foreach $itm (@files) {
        next if ($itm eq '.');
        next if ($itm eq '..');
        $ff = $dir.$itm;
        if (-d $ff) {
            $dirs++;
            #prt("$ff\n");
        } elsif (-f $ff) {
            $fils++;
        } else {
            $oths++;
        }
    }
    return ($cnt,$dirs,$fils,$oths);
}

sub process_in_dir($$) {
    my ($dir,$lev) = @_;
    if (! opendir(DIR,$dir)) {
        prtw("WARNING: Unable to open dir '$dir'!\n");
        return;
    }
    my @files = readdir(DIR);
    closedir(DIR);
    my ($itm,$ff);
    my ($cnt,$dirs,$fils,$oths);
    ut_fix_directory(\$dir);
    foreach $itm (@files) {
        next if ($itm eq '.');
        next if ($itm eq '..');
        $ff = $dir.$itm;
        if (-d $ff) {
            $dir_cnt++;
            ($cnt,$dirs,$fils,$oths) = get_dir_stats($ff,0);
            prt("$ff - ($dirs,$fils,$oths)\n");
        } elsif (-f $ff) {
            $fil_cnt++;
        } else {
            prtw("WARNING: Not dir or file '$ff'\n");
        }
    }
    prt("In '$dir', found $dir_cnt dirs, $fil_cnt file...\n");
}

#########################################
### MAIN ###
parse_args(@ARGV);
process_in_dir($in_dir,0);
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
            $in_dir = $arg;
            prt("Set input dir to [$in_dir]\n") if ($verb);
        }
        shift @av;
    }

    if ($debug_on) {
        prtw("WARNING: DEBUG is ON!\n");
        if (length($in_dir) ==  0) {
            $in_dir = $def_file;
            prt("Set DEFAULT input to [$in_dir]\n");
        }
    }
    if (length($in_dir) ==  0) {
        pgm_exit(1,"ERROR: No input directory found in command!\n");
    }
    if (! -d $in_dir) {
        pgm_exit(1,"ERROR: Unable to find in dir [$in_dir]! Check name, location...\n");
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

# eof - listdirs.pl
