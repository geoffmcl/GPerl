#!/usr/bin/perl -w
# NAME: listdirs.pl
# AIM: Given an in input path, list just the dirs
# 2021/03/28 - Move to GPerl repo
# 2019-12-11 - Initial cut
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
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
my $VERS = "0.0.19 2021-03-28";
#  $VERS = "0.0.9 2019-12-11";
my $load_log = 0;
my $in_dir = '';
my $verbosity = 0;
my $out_file = '';
my $recursive = 1;

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
sub get_dir_stats($$);

sub get_dir_stats($$) {
    my ($dir,$lev) = @_;
    my $cnt = 0;
    my $dirs = 0;
    my $fils = 0;
    my $oths = 0;
    my $byts = 0;
    my ($sb,$tm,$sz);
    if (! opendir(DIR,$dir)) {
        prtw("WARNING: Unable to open dir '$dir'!\n");
        return ($cnt,$dirs,$fils,$byts);
    }
    my @files = readdir(DIR);
    closedir(DIR);
    my ($itm,$ff);
    ut_fix_directory(\$dir);
    $cnt = scalar @files;
    my @dirs = ();
    foreach $itm (@files) {
        next if ($itm eq '.');
        next if ($itm eq '..');
        $ff = $dir.$itm;
        if ($sb = stat($ff)) {
            $tm = $sb->mtime;
            $sz = $sb->size;
        }
        if (-d $ff) {
            $dirs++;
            #prt("$ff\n");
            push(@dirs,$ff);
        } elsif (-f $ff) {
            $fils++;
            $byts += $sz;
        } else {
            $oths++;
        }
    }
    if ($recursive) {
        foreach $ff (@dirs) {
            my ($c,$d,$f,$b) = get_dir_stats($ff,($lev+1));
            $cnt  += $c;
            $dirs += $d;
            $fils += $f;
            $byts += $b;
        }
    }
    return ($cnt,$dirs,$fils,$byts);
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
    my ($cnt,$dirs,$fils,$oths,$byts,$len,$sb,$tm,$sz,$ra);
    my @dirs = ();
    ut_fix_directory(\$dir);
    my $bytes = 0;
    my $max_dir = 3;
    my $tot_dirs = 0;
    my $tot_fils = 0;
    my $tot_byts = 0;
    $oths = 0;
    foreach $itm (@files) {
        next if ($itm eq '.');
        next if ($itm eq '..');
        $ff = $dir.$itm;
        if ($sb = stat($ff)) {
            $tm = $sb->mtime;
            $sz = $sb->size;
        }
        $len = length($itm);
        if (-d $ff) {
            $dir_cnt++;
            ($cnt,$dirs,$fils,$byts) = get_dir_stats($ff,0);
            prt("$ff - ($dirs,$fils,$byts)\n") if (VERB9());
            push(@dirs, [ $itm, $ff, $dirs, $fils, $oths, $byts ]);
            $max_dir = $len if ($len > $max_dir);
        } elsif (-f $ff) {
            $fil_cnt++;
            $bytes += $sz;
        } else {
            prtw("WARNING: Not dir or file '$ff'\n");
        }
    }
    $tot_dirs += $dir_cnt;
    $tot_fils += $fil_cnt;
    $tot_byts += $bytes;

    my ($cfils,$cdirs,$coths,$cbyts,$ckb);
    foreach $ra (@dirs) {
        #push(@dirs, [ $itm, $ff, $dirs, $fils, $oths, $bytes ]);
        $itm  = ${$ra}[0];
        $ff   = ${$ra}[1];
        $dirs = ${$ra}[2];
        $fils = ${$ra}[3];
        $oths = ${$ra}[4];
        $byts = ${$ra}[5];
        # for display
        $tot_dirs += $dirs;
        $tot_fils += $fils;
        $tot_byts += $byts;

        $itm .= ' ' while (length($itm) < $max_dir);
        $cdirs = sprintf("%5d", $dirs); # up to  100000
        $cfils = sprintf("%6d", $fils); # up to 1000000
        # $coths = sprintf("%2d", $oths);
        # $cbyts = sprintf("%9d", $byts);
        $cbyts = get_nn($byts);
        $cbyts = ' '.$cbyts while (length($cbyts) < 15); # up to 1,000,000,000,000 (10T)
        $ckb = util_bytes2ks($byts);
        $ckb = ' '.$ckb while (length($ckb) < 8);
        prt("$itm: $cdirs,$cfils,$cbyts ($ckb)\n");
    }
    $itm = "Sum";
    $itm .= ' ' while (length($itm) < $max_dir);
    $cdirs = sprintf("%5d", $tot_dirs); # up to  100000
    $cfils = sprintf("%6d", $tot_fils); # up to 1000000
    $cbyts = get_nn($tot_byts);
    $cbyts = ' '.$cbyts while (length($cbyts) < 15); # up to 1,000,000,000,000 (1OOTB)
    $ckb = util_bytes2ks($tot_byts);
    $ckb = ' '.$ckb while (length($ckb) < 8);

    prt("$itm: $cdirs,$cfils,$cbyts ($ckb)\n");
    # prt("$itm: found $tot_dirs dirs, $tot_fils files, $cbyts ($ckb)\n");
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
    my ($arg,$sarg,$oo);
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
            } elsif ($sarg =~ /^r/) {
                $oo = 1;
                $oo = 0 if ($sarg =~ /-$/);
                $recursive = $oo;
                prt("Set recursive to [$recursive].\n") if ($verb);
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
    prt(" --recur       (-r) = Resursive into sub-dirs. (def=$recursive)\n");
}

# eof - listdirs.pl
