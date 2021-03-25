#!/usr/bin/perl -w
# NAME: hasmain.pl
# AIM: Check if a file, or files, or any C/C++ files in a directory, recursive if desired
# has a 'main' function. Uses the lib_chkmain.pl
# Is a complete RE-WRITE of the previous hasmain.pl, to hasmain02.pl
# 2021-03-15 - Move to GPerl, rename back to 'hasmain.pl'
# 2016-09-04 - Allow wildcard file input using glob
# 18/03/2014 - Maybe make note if main() is preceeded by an #ifdef TEST
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
require 'lib_chkmain.pl' or die "Unable to load 'lib_chkmain.pl' Check paths in \@INC...\n";
# log file stuff
our ($LF);
my $outfile = $temp_dir.$PATH_SEP."temp.$pgmname.txt";
open_log($outfile);

# user variables
my $VERS = "0.0.3 2021-04-15";
## $VERS = "0.0.2 2014-01-08";
## $VERS = "0.0.1 2013-12-18";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = '';
my $recursive = 0;
my $show_no_main = 0;
my $show_cmake = 0;
my $xf_none = '_NONE_';
my @in_files = ();
my @has_main = ();
my @has_ifdef = ();

my @no_main = ();
my $tot_cnt = 0;

# default exclude some cmake build things
my @exclude_files = qw(CMakeCCompilerId.c CMakeCXXCompilerId.cpp);
my @exclude_dirs  = qw(CMakeFiles);

# ### DEBUG ###
my $debug_on = 0;
my $def_file = 'f:\FG\18\gdal-1.10.1\bridge/bridge_test.cpp';

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

sub in_exclude_dirs($) {
    my $fil = shift;
    my $lcfil = lc($fil);
    my ($tst,$lctst);
    foreach $tst (@exclude_dirs) {
        $lctst = lc($tst);
        return 1 if ($lcfil eq $lctst);
    }
    return 0;
}

sub in_exclude_files($) {
    my $fil = shift;
    my $lcfil = lc($fil);
    my ($tst,$lctst);
    foreach $tst (@exclude_files) {
        $lctst = lc($tst);
        return 1 if ($lcfil eq $lctst);
    }
    return 0;
}


sub process_in_file($) {
    my ($inf) = @_;
    if (! open INF, "<$inf") {
        pgm_exit(1,"ERROR: Unable to open file [$inf]\n"); 
    }
    my @lines = <INF>;
    close INF;
    my $lncnt = scalar @lines;
    prt("Processing $lncnt lines, from [$inf]...\n") if (VERB9());
    $tot_cnt++;
    my @main = ();
    my $cnt = chkmain_in_linearray($inf,\@main,\@lines);
    my ($i,$fnd,$man,$msg);
    if ($cnt) {
        prt("Found $cnt 'main' references in $inf...\n") if (VERB5());
        for ($i = 0; $i < $cnt; $i++) {
            $fnd = $main[$i][0];
            $man = $main[$i][1];
            $msg = $main[$i][2];
            prt("$fnd $man $msg\n") if (VERB9());
        }
        push(@has_main,$inf);
        push(@has_ifdef,$msg);
    } else {
        prt("No 'main' found in $inf\n") if (VERB5());
        push(@no_main,$inf);
    }

}

sub process_in_files() {
    foreach $in_file (@in_files) {
        process_in_file($in_file);
    }
    ### DO NOT SORT @has_main = sort @has_main;
    my $cnt = scalar @has_main;
    prt("Found 'main' in $cnt of $tot_cnt files scannned\n");
    my ($msg,$man,$i,$fil,$min,$len);
    if ($cnt) {
        if ($show_cmake) {
            $msg = "set(EXE_LIST\n";
            foreach $man (@has_main) {
                $man =~ s/^\.(\\|\/)//;
                $msg .= "    $man\n";
            }
            $msg .= "    )\n";
            if (length($out_file)) {
                write2file($msg,$out_file);
                prt("CMake list written to $out_file\n");
            } else {
                prt($msg);
            }
        } elsif (VERB2()) {
            $min = 0;
            for ($i = 0; $i < $cnt; $i++) {
                $fil = $has_main[$i];
                $len = length($fil);
                $min = $len if ($len > $min);
            }
            $msg = '';
            for ($i = 0; $i < $cnt; $i++) {
                $fil = $has_main[$i];
                $man = $has_ifdef[$i];
                $fil .= ' ' while (length($fil) < $min);
                $msg .= "$fil [$man]\n";
            }
            prt($msg);
            if (length($out_file)) {
                write2file($msg,$out_file);
                prt("CMake list written to $out_file\n");
            }
        } elsif (VERB1()) {
            $msg = join("\n",@has_main)."\n";
            if (length($out_file)) {
                write2file($msg,$out_file);
                prt("CMake list written to $out_file\n");
            } else {
                prt($msg);
            }
        }
    }
    if ($show_no_main) {
        @no_main = sort @no_main;
        $cnt = scalar @no_main;
        if ($cnt) {
            prt("List if $cnt C/C++ files found with no 'main'\n");
            prt(join("\n",@no_main)."\n");
        } else {
            prt("No C/C++ files found with no 'main'\n");
        }
    }
}


my $found = 0;

sub scan_directory($$);


sub scan_directory($$) {
    my ($dir,$lev) = @_;
    $found = 0 if ($lev == 0);
    my @dirs = ();
    prt("Scanning folder '$dir', lev=$lev...\n") if (VERB9());
    if (opendir(DIR,$dir)) {
        my @files = readdir(DIR);
        closedir(DIR);
        ut_fix_directory(\$dir);
        my ($file,$ff);
        foreach $file (@files) {
            next if ($file eq '.');
            next if ($file eq '..');
            $ff = $dir.$file;
            if (-d $ff) {
                if (!in_exclude_dirs($file)) {
                    push(@dirs,$ff);
                }
            } elsif (-f $ff) {
                if (is_c_source($ff)) {
                    $in_file = $ff;
                    push(@in_files,$ff);
                    $found++;
                }
            } else {
                prtw("WARNING: What is THIS [$ff]\n");
            }
        }
    } else {
        prtw("WARNING: Unable to open dir '$dir'\n");
    }

    if ($recursive) {
        foreach $dir (@dirs) {
            scan_directory($dir,$lev+1);
        }
    }
    if ($lev == 0) {
        prt("In directory scan found $found C/C++ files...\n");
    }

}



#########################################
### MAIN ###
parse_args(@ARGV);
process_in_files();
pgm_exit(0,"");
########################################

sub has_wild($) {
    my $fil = shift;
    return 1 if ($fil =~ /\*/);
    return 1 if ($fil =~ /\?/);
    return 0;
}

sub get_files($) {
    my $fil = shift;
    my @files = glob($fil);
    my $cnt = scalar @files;
    if ($cnt) {
        prt("Adding $cnt files, from [$fil] input.\n") if (VERB1());
        push(@in_files,@files);
        $in_file = $files[0];
        prt(join("\n",@files)."\n") if (VERB9());
    }
    return $cnt;
}

sub need_arg {
    my ($arg,@av) = @_;
    pgm_exit(1,"ERROR: [$arg] must have a following argument!\n") if (!@av);
}

sub parse_args {
    my (@av) = @_;
    my ($arg,$sarg);
    my @dirs = ();
    my $verb = VERB1();
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
                prt("Verbosity = $verbosity\n") if ($verb);
            } elsif ($sarg =~ /^l/) {
                if ($sarg =~ /^ll/) {
                    $load_log = 2;
                } else {
                    $load_log = 1;
                }
                prt("Set to load log at end. ($load_log)\n") if ($verb);
            } elsif ($sarg =~ /^n/) {
                $show_no_main = 1;
                prt("Set to list files with no 'main'\n") if ($verb);
            } elsif ($sarg =~ /^c/) {
                $show_cmake = 1;
                prt("Set to list files as cmake list.\n") if ($verb);
            } elsif ($sarg =~ /^o/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $out_file = $sarg;
                prt("Set out file to [$out_file].\n") if ($verb);
            } elsif ($sarg =~ /^x/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                if ($sarg eq $xf_none) {
                    prt("Cleared exclude file list.\n") if ($verb);
                    @exclude_files = ();
                } else {
                    push(@exclude_files,$sarg);
                    prt("Added exclude file $sarg.\n") if ($verb);
                }
            } elsif ($sarg =~ /^X/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                if ($sarg eq $xf_none) {
                    prt("Cleared exclude directory list.\n") if ($verb);
                    @exclude_dirs = ();
                } else {
                    push(@exclude_dirs,$sarg);
                    prt("Added exclude directory $sarg.\n") if ($verb);
                }
            } elsif ($sarg =~ /^r/) {
                $recursive = 1;
                prt("Set recursive directory scan\n") if ($verb);
            } else {
                pgm_exit(1,"ERROR: Invalid argument [$arg]! Try -?\n");
            }
        } else {
            if (-f $arg) {
                push(@in_files,$arg);
                $in_file = $arg;
                prt("Added input to [$in_file]\n") if (VERB1());
            } elsif (-d $arg) {
                push(@dirs,$arg);
                prt("Added input '$arg', to dirs to scan\n") if (VERB1());
                # $in_file = $arg;
            } elsif (has_wild($arg)) {
                $sarg = get_files($arg);
                if ($sarg) {
                    prt("Added $sarg input files from '$arg'\n") if (VERB1());
                } else {
                    pgm_exit(1,"ERROR: Got no files, from [$arg] input.\n");
                }
            } else {
                pgm_exit(1,"Bare input [$arg] is neither file nor directory! nor wild!\n");
            }
        }
        shift @av;
    }
    if (@dirs) {
        foreach $arg (@dirs) {
            scan_directory($arg,0);
        }
    }

    if ($debug_on) {
        prtw("WARNING: DEBUG is ON!\n");
        if (length($in_file) ==  0) {
            $in_file = $def_file;
            push(@in_files,$in_file);
            prt("Set DEFAULT input to [$in_file]\n");
        }
    }
    if (length($in_file) ==  0) {
        pgm_exit(1,"ERROR: No input files, or folders, found in command!\n");
    }
    if (! -f $in_file) {
        pgm_exit(1,"ERROR: Unable to find in file [$in_file]! Check name, location...\n");
    }
}

sub give_help {
    prt("$pgmname: version $VERS\n");
    my ($cnt);
    prt("Usage: $pgmname [options] in-file|in-dir [in-file|in-dir [...]]\n");
    prt("Options:\n");
    prt(" --help   (-h or -?) = This help, and exit 0.\n");
    prt(" --verb[n]      (-v) = Bump [or set] verbosity. def=$verbosity\n");
    prt(" --load         (-l) = Load LOG at end. ($outfile)\n");
    prt(" --recursive    (-r) = Recursive into directories...\n");
    prt(" --out <file>   (-o) = Write output to this file.\n");
    prt(" --nomain       (-n) = List files where no 'main' found. (def=$show_no_main)\n");
    prt(" --cmake        (-c) = List files in a cmake set(EXE_SRCS list). (def=$show_cmake)\n");

    prt(" --xclud <file> (-x) = xclude this file from search. (def=");
    if (@exclude_files) {
        prt("[".join(" ",@exclude_files)."]");
    } else {
        prt($xf_none);
    }
    prt(")\n");

    prt(" --XCLUD <dir>  (-X) = Xclude this directory from search. (def=");
    if (@exclude_dirs) {
        prt("[".join(" ",@exclude_dirs)."]");
    } else {
        prt($xf_none);
    }
    prt(")\n");
    prt(" Wildcards, '?', '*', can be used in the input file or dir.\n");
    prt(" A special case $xf_none file or directory to clear existing list.\n");
    prt(" If given a file, scan for 'main' function.\n");
    prt(" If given a directory, scan all C/C++ files for a 'main' function.\n");

}

# eof - hasmain.pl
