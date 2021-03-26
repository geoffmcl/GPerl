#!/usr/bin/perl -w
# NAME: verhist.pl
# AIM: Given the output of 'git log -p version.txt', extract date, and version changes made
# 2021/03/25 - Move to GPerl
# 2017-11-23 - Just a review - all seems good...
# 07/04/2016 Only use the DATE in the log generation, not down to the second
# 06/09/2015 Handle the 'Merge: ...' entries, presently discarded
# 21/05/2015 geoff mclane http://geoffair.net/mperl
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
use Time::Local;
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
my $VERS = "0.0.8 2021-03-26";
### $VERS = "0.0.7 2017-11-23";
###my $VERS = "0.0.6 2015-09-06";
###my $VERS = "0.0.5 2015-01-09";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = '';

# ### DEBUG ###
my $debug_on = 0;
my $def_file = 'F:\Projects\tempv2.log';

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

sub parsedate2 { 
  my ($s) = @_;
  my ($year, $month, $day, $hour, $minute, $second);

  if($s =~ m{^\s*(\d{1,4})\W*0*(\d{1,2})\W*0*(\d{1,2})\W*0*
                 (\d{0,2})\W*0*(\d{0,2})\W*0*(\d{0,2})}x) {
    $year = $1;  $month = $2;   $day = $3;
    $hour = $4;  $minute = $5;  $second = $6;
    $hour |= 0;  $minute |= 0;  $second |= 0;  # defaults.
    $year = ($year<100 ? ($year<70 ? 2000+$year : 1900+$year) : $year);
    return timelocal($second,$minute,$hour,$day,$month-1,$year);  
  }
  return -1;
}

my %months = (
    'Jan' => 1,
    'Feb' => 2,
    'Mar' => 3,
    'Apr' => 4,
    'May' => 5,
    'Jun' => 6,
    'Jul' => 7,
    'Aug' => 8,
    'Sep' => 9,
    'Oct' => 10,
    'Nov' => 11,
    'Dec' => 12
    );

# sec,     # seconds of minutes from 0 to 61
# min,     # minutes of hour from 0 to 59
# hour,    # hours of day from 0 to 24
# mday,    # day of month from 1 to 31
# mon,     # month of year from 0 to 11
# year,    # year since 1900
# wday,    # days since sunday
# yday,    # days since January 1st
# isdst    # hours of daylight savings time
# /^\s*(\w+)\s+(\w+)\s+(\d+)\s+(\d{2}):(\d{2}):(\d{2}\s+(\d{4})/
#       Wed     May      13    12:37:20               2015       +0200
sub parsedate($) { 
  my ($s) = @_;
  my ($cday, $year, $month, $day, $hour, $minute, $second, $mon);
  #              cday    mon     day     hour   min      sec       year
  #              1       2       3       4      5        6         7
  if($s =~ /^\s*(\w+)\s+(\w+)\s+(\d+)\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})\b/) {
      $cday   = $1;
      $month  = $2;
      $day    = $3;
      $hour   = $4;
      $minute = $5;
      $second = $6;
      $year   = $7;
      if (defined $months{$month}) {
          $mon = $months{$month};
          # which is correct???
          #prt("timelocal($second,$minute,$hour,$day,".($mon-1).",$year)\n");  
          return timelocal($second,$minute,$hour,$day,$mon-1,$year);  
          #return timelocal($second,$minute,$hour,$day,$mon,$year);  
      }
  }
  return -1;
}

# Expect -
sub ver_text() {
    my $txt = <<EOF;
commit 1c9970deb461d5a35f1821d49aafc689a1b4c8a4
Author: Geoff McLane <ubuntu\@geoffair.info>
Date:   Wed May 13 12:37:20 2015 +0200

    bump version for #212 fix

diff --git a/version.txt b/version.txt
index 680f833..12f4ff9 100644
--- a/version.txt
+++ b/version.txt
\@\@ -1 +1 \@\@
-4.9.27
\ No newline at end of file
+4.9.28
\ No newline at end of file

commit d8a44988038749b501498582ea8788cae86e6df8
Merge: 652d4b4 dfdffd0
Author: Geoff McLane <ubuntu\@geoffair.info>
Date:   Mon Aug 10 18:42:58 2015 +0200

    Merge branch 'Andrew-Dunn-patch-1' into issue-228.

    That is reordering windows includes per #234
    
    In general the order of includes should be system <headers>,
    then local "headers", except perhaps for the ocassional local
    "version" or "config" header...
    
    Resolved conflicts in src/pprint.c by reverting to current master, and in
    version.txt by increasing the version.

commit 4e7c52607c8d9e34bca4ddbbee39144b9fc27019
...
EOF
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
    my ($line,$inc,$lnn,$tlin,$len);
    my ($commit,$author,$comment,$scomm,$auth,$epoch,$tmp,$merge);
    $lnn = 0;
    my $indiff = 0;
    my $inmerge = 0;
    $comment = '';
    $scomm = '';
    $merge = '';
    my $vers = '';
    my $dtutc = lu_get_YYYYMMDD_hhmmss_UTC(time());
    my @arr = split(/\s/,$dtutc);
    my $date = $arr[0];
    my $verhist = "# Version history at $date\n";
    my @mergetxt = ();
    foreach $line (@lines) {
        chomp $line;
        $lnn++;
        $tlin = trim_all($line);
        $len = length($tlin);
        next if ($len == 0);
        if ($line =~ /^commit\s(.+)$/) {
            $inc = $1;
            if ((defined $author)&&(defined $date)) {
                $tmp = "$vers $scomm $auth $date\n";
                $verhist .= $tmp;
                prt($tmp) if (VERB2());
            }

            $commit = $inc;
            #### NOTE: First 10 character of the 'commit' used
            $scomm = substr($commit,0,10);
            prt("$lnn: $commit\n") if (VERB9());
            $indiff = 0;
            undef $author;
            undef $date;
            $comment = '';
            $inmerge = 0;
            $merge = '';
            @mergetxt = ();
        } elsif ($line =~ /^Merge:\s+(.+)$/) {
            $merge = $1;
            $inmerge = 1;
        } elsif ($line =~ /^Author:\s+(.+)$/) {
            $author = $1;
            $len = index($author,'<');
            if ($len > 0) {
                $auth = trim_all(substr($author,0,$len));
            } else {
                $auth = 'missed';
            }
        } elsif ($line =~ /^Date:\s+(.+)$/) {
            $date = $1;
            $epoch = parsedate($date);
        } elsif ($line =~ /^\s+(.+)$/) {
            $inc = $1;
        } elsif ($line =~ /^diff\s+/) {
            $indiff = 1;
        } elsif ($indiff) {
            if ($line =~ /^index\s+/) {
            } elsif ($line =~ /^\s+/) {
            } elsif ($line =~ /^\+/) {
                if ($line =~ /^\+(\d{1}\.\d+\.\d+.*)$/) {
                    $vers = $1;
                }
            } elsif ($line =~ /^\-/) {
            } elsif ($line =~ /^\@/) {
            } elsif ($line =~ /^\\\s+/) {
            } elsif ($line =~ /^new file mode/) {
            } else {
                pgm_exit(1, "$lnn: Unprocessed '$line'! *** FIX ME ***\n");
            }
        } elsif ($inmerge) {
            push(@mergetxt,$tlin);
        } else {
            pgm_exit(1, "$lnn: UNPROCESSED '$line'! *** FIX ME ***\n");
        }
    }
    if ((defined $author)&&(defined $date)) {
        $tmp = "$vers $scomm $auth $date\n";
        $verhist .= $tmp;
        prt($tmp) if (VERB2());
    }
    $verhist .= "# eof\n";
    if (length($out_file)) {
        rename_2_old_bak($out_file);
        write2file($verhist,$out_file);
        prt("Version history written to '$out_file'\n");
    } else {
        prt($verhist);
    }
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
            prt("Set input to [$in_file]\n") if ($verb);
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
        give_help();
        pgm_exit(1,"\nERROR: No input files found in command!\n");
    }
    if (! -f $in_file) {
        pgm_exit(1,"ERROR: Unable to find in file [$in_file]! Check name, location...\n");
    }
}

sub give_help {
    prt("\n");
    prt("$pgmname: version $VERS\n");
    prt("Usage: $pgmname [options] in-file\n");
    prt("Options:\n");
    prt(" --help  (-h or -?) = This help, and exit 0.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. def=$verbosity\n");
    prt(" --load        (-l) = Load LOG at end. ($outfile)\n");
    prt(" --out <file>  (-o) = Write output to this file.\n");
    prt("\n");
    prt(" Given the git output from say 'git log -p version.txt > tempv.log'\n");
    prt(" process the log, and write a oneline verhist.log, like\n");
    prt(" 5.0.0 1e70fc6f15 Geoff McLane Tue Jun 30 19:59:00 2015 +0200\n");
    prt(" 4.9.37 daef037156 Geoff McLane Wed Jun 24 13:12:31 2015 +0200\n");
    prt(" ... etc... for inclusion in the repo.\n");

}

# eof - verhist.pl
