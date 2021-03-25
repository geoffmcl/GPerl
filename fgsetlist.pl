#!/usr/bin/perl -w
# NAME: fgsetlist.pl
# AIM: Given an input directory, rescursively scan the directory, outputing a *-set.xml
# simple file list
# 2021/02/11 - Move to D:\PerlG, added $skip_sub_subs...
# 2021/01/25 - format the *-set.xml list to output 'aero,file'
# 2020/11/29 - review
# 02/11/2014 geoff mclane http://geoffair.net/mperl
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
use File::Spec; # File::Spec->rel2abs($rel);
use Cwd;
my $os = $^O;
my $curr_dir = cwd();
my ($pgmname,$perl_dir) = fileparse($0);
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
my $VERS = "0.0.4 2021-02-11";
##my $VERS = "0.0.3 2020-11-29";
##my $VERS = "0.0.2 2014-01-13";
my $load_log = 0;
my $in_dir = '';
my $verbosity = 0;
my $out_file = $temp_dir.$PATH_SEP."tempset.txt";
my $skip_sub_subs = 1;

# ### DEBUG ###
my $debug_on = 0;
my $def_dir = 'D:\FG\fgaddon\Aircraft';

### program variables
my @warnings = ();
my $cwd = cwd();
my $g_dot_cnt = 0;
my $g_dir_cnt = 0;

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

my @set_files = ();

sub mycmp_nc_sort {
   return -1 if (lc($a) lt lc($b));
   return 1 if (lc($a) gt lc($b));
   return 0;
}

sub remove_in_dir($) {
    my $path = shift;
    my $plen = length($path);   # ful PATH to set file
    my $len = length($in_dir);  # base direcory
    my $sub = $path;
    if ($len && ($plen > $len)) {
        $sub = substr($path,$len);
        $sub =~ s/^\\//;
        $sub =~ s/(\\|\/)$//;
    }
    return $sub;
}

sub show_found() {
    my @arr = sort mycmp_nc_sort @set_files;
    my $cnt = scalar @arr;
    prt("In a recursive scan of $in_dir, $g_dir_cnt folders, found $cnt set files...\n");
    my $txt = "# $pgmname: Scan $in_dir, $g_dir_cnt dirs, found $cnt set files, on ";
    $txt .= lu_get_YYYYMMDD_hhmmss(time())."\n";
    my ($file,$name,$dir,$ext,$aero,$sub,$len);
    # $txt .= join("\n",@arr)."\n";
    my @skipped = ();
    my $max_aero = 0;
    my $max_sub = 0;
    foreach $file (@arr) {
        ($name,$dir,$ext) = fileparse($file , qr/\.[^.]*/ );
        $aero = $name;
        $aero =~ s/-set$//;
        $sub = remove_in_dir($dir);
        if ($skip_sub_subs) {
            if ($sub =~ /[\\\/]/) {
                # push(@skipped,$file);
                next;
            }
        }
        $len = length($aero);
        $max_aero = $len if ($len > $max_aero);
        $len = length($sub);
        $max_sub = $len if ($len > $max_sub);
        # $txt .= "$aero,$sub,$file\n";
    }
    foreach $file (@arr) {
        ($name,$dir,$ext) = fileparse($file , qr/\.[^.]*/ );
        $aero = $name;
        $aero =~ s/-set$//;
        $sub = remove_in_dir($dir);
        if ($skip_sub_subs) {
            if ($sub =~ /[\\\/]/) {
                push(@skipped,$file);
                next;
            }
        }
        $aero .= ' ' while (length($aero) < $max_aero);
        $sub .= ' ' while (length($sub) < $max_sub);
        $txt .= "$aero,$sub,$file\n";
    }
    if ($cnt > 0) {
        if (length($out_file)) {
            rename_2_old_bak($out_file);
            write2file($txt,$out_file);
            prt("List of $cnt files, written to $out_file\n");
        } else {
            prt($txt);
            prt("List of $cnt files to stdout due no -o out_file.\n");
        }
        $cnt = scalar @skipped;
        if ($cnt > 0) {
            prt("Note: $cnt set files skipped. -v to show.\n");
            if (VERB1()) {
                #prt(join("\n",@skipped)."\n");
                prt("[v1] Base directory '$in_dir'\n");
                foreach $file (@skipped) {
                    $sub = remove_in_dir($file);
                    prt("  $sub\n");
                }
                prt("[v1] Listed $cnt set files skipped. Use -s- to disable skipping.\n");
            }
        }
        prt("Can use fgxmlset.exe, hfgxmlsetmf.bat, to view contents of the 'set' files.\n");
    }
}

sub process_in_dir($$);

sub process_in_dir($$) {
    my ($in_dir,$lev) = @_;
    if (!opendir(DIR,$in_dir)) {
        prtw("WARNING: Unable to open dir $in_dir\n");
        return;
    }
    my @files = readdir(DIR);
    closedir(DIR);
    my ($file,$ff,$cnt);
    my $dir = $in_dir;
    ut_fix_directory(\$dir);
    my @dirs = ();
    $g_dir_cnt++;
    if (VERB9()) {
        local $| = 1;
        prt('.'); 
    } else {
       if (($g_dir_cnt % 1000) == 0) {
           $cnt = scalar @set_files;
           prt("Directories scanned $g_dir_cnt... found $cnt *.set.xml files...\n");
       }
    }
    foreach $file (@files) {
        next if ($file eq '.');
        next if ($file eq '..');
        $ff = $dir.$file;
        if (-d $ff) {
            push(@dirs,$ff);
        } elsif (-f $ff) {
            if ($file =~ /-set\.xml$/) {
                push(@set_files,$ff);
            }
        } else {
            pgm_exit(1,"What is this $ff! ($file)!\n *** FIX ME ***\n");
        }
    }
    foreach $dir (@dirs) {
        process_in_dir($dir,($lev+1));
    }
    if ($lev == 0) {
        if (VERB9()) {
            prt("\n"); 
        }
        $cnt = scalar @set_files;
        prt("Scanned $g_dir_cnt dirs, from base $in_dir, for $cnt '*-set.xml' files...\n"); #if (VERB1());
    }

}

#########################################
### MAIN ###
parse_args(@ARGV);
process_in_dir($in_dir,0);
show_found();
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
            } elsif ($sarg =~ /^s/) {
                my $set = 1;
                $set = 0 if ($sarg =~ /-$/);
                $skip_sub_subs = $set;
                prt("Set skip sub/sub dirs [$skip_sub_subs].\n") if ($verb);
            } else {
                pgm_exit(1,"ERROR: Invalid argument [$arg]! Try -?\n");
            }
        } else {
            ###$in_dir = $arg;
            $in_dir = File::Spec->rel2abs($arg);   # get ABSOLUTE path of input
            prt("Set input to [$in_dir]\n") if ($verb);
        }
        shift @av;
    }

    if ($debug_on) {
        prtw("WARNING: DEBUG is ON!\n");
        if (length($in_dir) ==  0) {
            $in_dir = $def_dir;
            prt("Set DEFAULT input to [$in_dir]\n");
        }
    }
    if (length($in_dir) ==  0) {
        give_help();
        pgm_exit(1,"ERROR: No input directory found in command!\n");
    }
    if (! -d $in_dir) {
        pgm_exit(1,"ERROR: Unable to find in directory [$in_dir]! Check name, location...\n");
    }
}

sub give_help {
    prt("$pgmname: version $VERS\n");
    prt("Usage: $pgmname [options] in-dir\n");
    prt("Options:\n");
    prt(" --help  (-h or -?) = This help, and exit 0.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. def=$verbosity\n");
    prt(" --load        (-l) = Load LOG at end. ($outfile)\n");
    prt(" --out <file>  (-o) = Write output to this file. (def=$out_file)\n");
    prt(" --skipsubs[-] (-s) = Skip in multiple sub-dirs. (def=$skip_sub_subs)\n");
    prt("\n");
    prt(" Recursively scan the given directory for fg *-set.xml files,\n");
    prt(" and output a list, in alphabetic order.\n");
    prt("\n");
    prt(" See fgsetfile.pl to process a FG *-set.xml file and try to find the model ac file...\n"); 
    prt(" See findset.pl, scan the input directory for 'aero'-set.xml files, and output the list found.\n");
    #prt(" See fgsetlist.pl, which perversely does the same as the above file!!!\n");
    prt(" Can use fgxmlset.exe, hfgxmlsetmf.bat, to view contents of the 'set' files.\n");
    prt(" See fgaclist.pl to output the full list of *.ac files found in a directory.\n");
    prt(" See findmodel.pl to scan dir looking for model ac files.\n");
    prt(" See findac.pl, scan dir for model .ac file and output a list, like fgaclist.pl.\n");
    prt("\n");
}

# eof - fgsetlist.pl
