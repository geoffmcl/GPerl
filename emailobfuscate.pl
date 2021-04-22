#!/usr/bin/perl -w
# NAME: emailobfuscate.pl
# AIM: Give an input file, convert all email from <abc@def.com> to <abc _at_ def _dot_ com>
# 2021/04/22 - Add Change Log Summary table
# 2021/03/26 - Move to GPerl, bump version...
# 2017-11-23 - Idea to reduce 'version.txt' commits to ONE LINE - if -V verhist.log added...
# 23/11/2015 - Target to 'authors' needs to be in two places
# 07/09/2015 - Add link to authors, and back to top
# 04/06/2015 - Remove duplicate end html - TODO: Add some STYLE to HTML output ;=))
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
my $VERS = "0.0.9 2021-04-22";
#my $VERS = "0.0.8 2021-03-26";
#my $VERS = "0.0.7 2017-11-23";
#my $VERS = "0.0.6 2015-09-07";
#my $VERS = "0.0.5 2015-05-21";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = '';
my $html_version = '';
my $add_html = 0;
my $add_suthors = 0;
my $vers_file = '';

# ### DEBUG ###
my $debug_on = 0;
# my $def_file = 'F:\Projects\temp2.log';
my $def_vers = '5.7.46';
my $def_file = 'D:\UTILS\tidy\temp3-5.7.46.log';
my $def_out = "temp-$def_vers.html";

### program variables
my @warnings = ();
my $cwd = cwd();
my %vers_commits = ();
my $curr_date = lu_get_YYYYMMDD_hhmmss(time());

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

sub html_head($) {
    my $vers = shift;
    my $txt = <<EOF;
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Release $vers</title>
<style>
table {  margin-left: auto; margin-right: auto; }
table, td, th { border: 1px solid gray; }
.ctr { text-align: center; }
.rite { text-align: right; }
</style>
</head>
<body>
<a id="top"></a>
<h1>Release $vers</h1>
<p>Change log for this release. List of <a href="#authors">authors</a>. <a href="#chglog">summary</a></p>
<pre>
EOF
    return $txt;
}

sub html_end() {
    my $txt = <<EOF;

<p>eof <a href="#top">top</a></p>
</body>
</html>

EOF
    return $txt;
}


sub get_obs_line($) {
    my $line = shift;
    my ($len,$i,$ch);
    my $nline = '';
    $len = length($line);
    my $inem = 0;
    for ($i = 0; $i < $len; $i++) {
        $ch = substr($line,$i,1);
        if ($inem) {
            if ($ch eq '@') {
                $nline .= ' _at_ ';
            } elsif ($ch eq '.') {
                $nline .= ' _dot_ ';
            } else {
                $nline .= $ch;
            }
            $inem = 0 if ($ch eq '>');
        } else {
            $nline .= $ch;
            $inem = 1 if ($ch eq '<');
        }
    }
    return $nline;
}

######################################################
# Converting SPACES to '&nbsp;'
# Of course this could be done just using perl's
# powerful search and replace, but this handles
# any number of spaces, only converting the number
# minus 1 to &nbsp; ... not sure how to have
# this level of control with regex replacement
######################################################
sub conv_spaces {
   my $t = shift;
   my ($c, $i, $nt, $ln, $sc, $sp);
   $nt = ''; # accumulate new line here
   $ln = length($t);
   for ($i = 0; $i < $ln; $i++) {
      $c = substr($t,$i,1);
      if ($c eq ' ') {
         $i++; # bump to next 
         $sc = 0;
         $sp = '';
         for ( ; $i < $ln; $i++) {
            $c = substr($t,$i,1);
            if ($c ne ' ') {
               last; # exit
            }
            $sc++;
            $sp .= $c;
         }
         if ($sc) {
            $sp =~ s/ /&nbsp;/g;
            $nt .= $sp;
         }
         $i--; # back up one
         $c = ' '; # add back the 1 space
      }
      $nt .= $c;
   }
   if ($t ne $nt) {
       prt( "conv_space: from [$t] to [$nt] ...\n" ) if (VERB9());
   }
   return $nt;
}

###########################################################################
# VERY IMPORTANT SERVICE
# This converts the 'text' into HTML text, but only does a partial job!
# 1. Convert '&' to '&amp;' to avoid interpreting as replacement
# 2. Convert '<' to '&lt;' and '>' to '&gt;', to avoid interpreting as HTML
# 3. Convert '"' to '&quot;'
# if flag & 1
# 4. Convert '\t' to SPACES
# if flag & 2
# 5. Finally, if there are double or more SPACES, convert to '&nbsp;'
###########################################################################
my $tab_space = '    ';
sub html_line($$) {
   my ($t,$flag) = @_;
   my $ot = $t;
   $t =~ s/&/&amp;/g; # all '&' become '&amp;'
   $t =~ s/</&lt;/g; # make sure all '<' is/are swapped out
   $t =~ s/>/&gt;/g; # make sure all '>' is/are swapped out
   $t =~ s/\"/&quot;/g; # and all quotes become &quot;
   if ($flag & 1) {
       $t =~ s/\t/$tab_space/g; # tabs to spaces
   }
   if ($flag & 2) {
       if ($t =~ /\s\s/) { # if any two consecutive white space
            $t = conv_spaces($t);
       }
   }
   if ($ot ne $t) {
       prt( "html_line: from [$ot] to [$t] ...\n" ) if (VERB9());
   }
   return $t;
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

sub process_in_file($) {
    my ($inf) = @_;
    if (! open INF, "<$inf") {
        pgm_exit(1,"ERROR: Unable to open file [$inf]\n"); 
    }
    my @lines = <INF>;
    close INF;
    my $lncnt = scalar @lines;
    prt("Processing $lncnt lines, from [$inf]...\n");
    my ($line,$inc,$lnn,$author,$off,@arr,$date,$epoch,$tline,$len);
    my ($raa,$tmp);
    $lnn = 0;
    my @nlines = ();
    my @tlines = ();
    my @rlines = (); # collect change info
    my @chglines = ();  # list of collected changes
    my %authors = ();
    my $bdate = '';
    my $edate = '';
    my $bep = time();
    my $eep = 0;
    my $gotdate = 0;
    my $commits = 0;
    my $comm = '';
    my $got_vers = 0;
    my $got_merge = 0;
    my $got_bump = 0;
    my $got_date = 0;
    foreach $line (@lines) {
        chomp $line;
        $lnn++;
        $tline = trim_all($line);
        $len = length($tline);
        if ($len == 0) {
            # blank line
        } elsif ($line =~ /^Author:\s+/) {
            $author = $line;
            $author =~ s/^Author:\s+//;
            $off = index($author,'<');
            if ($off > 0) {
                $author = substr($author,0,$off-1);
            }
            $author = trim_all($author);
            $author = 'Geoff R. McLane' if ($author eq 'Geoff McLane');
            if ($author =~ /Buo-ren/) {
                $author = "Buo-ren, Lin";
            } elsif ($author =~ /Jacobson/) {
                $author = "Dan Jacobson";
            }

            if (! defined $authors{$author}) {
                $authors{$author} = [0,0,0];
            }
            $raa = $authors{$author};
            ${$raa}[0]++;
        } elsif ($line =~ /^Date:\s+/) {
            $date = $line;
            $date =~ s/^Date:\s+//;
            $date = trim_all($date);
            $epoch = parsedate($date);
            if ($epoch != -1) {
                if ($epoch > $eep) {
                    $eep = $epoch;
                    $edate = $date;
                }
                if ($epoch < $bep) {
                    $bep = $epoch;
                    $bdate = $date;
                }
                $gotdate++;
                $got_date = 1;
            } else {
                prtw("Warning: Date failed on '$line'\n");
            }
        } elsif ($line =~ /^commit\s+/) {
            if (@tlines) {
                if ($got_vers) {
                    push(@nlines,$vers_commits{$comm});
                    ${$raa}[1]++;
                } elsif ($got_merge) {
                    ${$raa}[2]++;
                    $tmp = $tlines[0];
                    push(@nlines,$tmp);
                    $len = scalar @tlines;
                    if ($len > 1) {
                        $tmp = $tlines[1];
                        push(@nlines,$tmp);
                    }
                    push(@nlines,"");
                } else {
                    push(@nlines,@tlines);
                }
                @tlines = ();
                if (@rlines) {
                    # build commit comment summary
                    $tmp = join(" ",@rlines);
                    push(@chglines,[ $epoch, $comm, $tmp ]);
                }
            }
            # clear previous
            $got_vers = 0;
            $got_merge = 0;
            undef $raa;
            $commits++;
            $comm = $line;
            $comm =~ s/^commit\s+//;
            $len = length($comm);
            if ($len > 10) {
                $comm = substr($comm,0,10);
            }
            if (defined $vers_commits{$comm}) {
                $got_vers = 1;
            }
            $got_bump = 0;
            $got_date = 0;
            @rlines = ();
        } elsif ($line =~ /^Merge:\s+/) {
            # Merge: 9e09f1a e4fc470
            $got_merge = 1;
        } elsif ($line =~ /^\s+/) {
            # comment text
            if (($line =~ /\s+Bump\s+/i) && ($line =~ /\s+\d+\.\d+\.\d+\s+/)) {
                $got_bump = 1;
                #pgm_exit(1,"Got line '$line'\n");
            }
            push(@rlines,$tline);
        } else {
            pgm_exit(1,"$lnn: $line NOT PARSED\n");
        }

        if ($line =~ /<(.+)>/) {
            $inc = get_obs_line($line);
            prt("$lnn: converted\n$line TO\n$inc\n") if (VERB5());
            $line = $inc;
        }
        $line = html_line($line,0) if ($add_html);
        push(@tlines,$line);
        #push(@nlines,$line);
    }
    # add any remainder
    if (@tlines) {
        if ($got_vers) {
            push(@nlines,$vers_commits{$comm});
            ${$raa}[1]++;
        } elsif ($got_merge) {
            ${$raa}[2]++;
            $tmp = $tlines[0];
            push(@nlines,$tmp);
            $len = scalar @tlines;
            if ($len > 1) {
                $tmp = $tlines[1];
                push(@nlines,$tmp);
            }
            push(@nlines,"");
        } else {
            push(@nlines,@tlines);
        }
        @tlines = ();
    }
    $line = '';
    $line .= html_head($html_version) if ($add_html);
    $line .= join("\n",@nlines);
    $line .= "</pre>\n";    # close the pre
    @arr = keys %authors;
    $lnn = scalar @arr;
    $off = int(($eep-$bep) / 86400);
    if ($add_html) {
        ###########################################################################
        if ($add_suthors && $lnn) {
            $line .= "<a name=\"authors\"></a>\n";
            $line .= "\n<p>This log has  $commits commits by $lnn Authors. \n";
            $line .= "'T' is total, 'V' is version.txt, 'M' is merges. \n";
            $line .= "</p>\n";
            $line .= "<table>\n";
            my $cols = 4;
            my $wrap = 0;
            while ($wrap < $cols) {
                $line .= "<tr>\n" if ($wrap == 0);
                $line .= "<th>Author</th>\n";
                $line .= "<th>T</th>\n";
                $line .= "<th>V</th>\n";
                $line .= "<th>M</th>\n";
                $wrap++
            }
            $line .= "</tr>\n";
            $wrap = 0;
            foreach $inc (@arr) {
                #$lnn = $authors{$inc};
                $raa = $authors{$inc};
                $lnn = ${$raa}[0];
                $got_vers = ${$raa}[1];
                $got_merge = ${$raa}[2];
                #$line .= "$inc $lnn; ";
                $line .= "<tr>\n" if ($wrap == 0);
                $line .= "<td>$inc</td>\n";
                $line .= "<td>$lnn</td>\n";
                $line .= "<td>$got_vers</td>\n";
                $line .= "<td>$got_merge</td>\n";
                $wrap++;
                if ($wrap == $cols) {
                    $line .= "</tr>\n";
                    $wrap = 0;
                }
            }
            if ($wrap) {
                while ($wrap < $cols) {
                    $wrap++;
                    $line .= "<td>&nbsp;</td>\n";
                    $line .= "<td>&nbsp;</td>\n";
                    $line .= "<td>&nbsp;</td>\n";
                    $line .= "<td>&nbsp;</td>\n";
                }
            }
            $line .= "</table>\n";
            if (@chglines) {
                $line .= "<a id=\"chglog\"></a>\n";
                $line .= "<h2>Change Log Summary</h2>\n";
                $line .= "<table>\n";
                $line .= "<tr>\n";
                $line .= "<th>Date</th><th>Commit</th><th>Comments</th>\n";
                $line .= "</tr>\n";
                foreach $raa (@chglines) {
                    $epoch = ${$raa}[0];
                    $date = lu_get_YYYYMMDD_UTC($epoch);
                    $comm = ${$raa}[1];
                    $tmp  = ${$raa}[2];
                    $inc = html_line($tmp,0);
                    $line .= "<tr>\n";
                    $line .= "<td>$date</td>\n";
                    $line .= "<td><a target=\"_blank\" href=\"https://github.com/htacg/tidy-html5/commit/$comm\">$comm</a></td>\n";
                    $line .= "<td>$inc</td>\n";
                    $line .= "</tr>\n";
                }
                $line .= "</table>\n";
            }
        }
        if (($gotdate > 2)&&($eep > $bep)) {
            $line .= "\n<p>Date: from $bdate to $edate ($off days)</p>\n";
        } 
        if (length($out_file)) {
            $line .= "<p class='rite'>";
            my ($n,$d) = fileparse($out_file);
            $line .= "$n, by <a href=\"https://github.com/geoffmcl/GPerl/blob/next/emailobfuscate.pl\">emailobfuscate.pl</a>, on $curr_date, from 'git log'";
            $line .= "</p>\n";
        }
        $line .= html_end();
        ###########################################################################
    } else {
        ###########################################################################
        if ($add_suthors && $lnn) {
            $line .= "<a id=\"authors\"></a>";
            $line .= "\nThis log has $commits commits by $lnn authors: ";
            foreach $inc (@arr) {
                $lnn = $authors{$inc};
                $line .= "$inc $lnn; ";
            }
            $line .= "\n";
        }
        if (($gotdate > 2)&&($eep > $bep)) {
            ###$line .= "Date: from ".lu_get_YYYYMMDD_hhmmss_UTC($bep)." to ".lu_get_YYYYMMDD_hhmmss_UTC($eep)." UTC\n";
            $line .= "Date: from $bdate to $edate ($off days)\n";
        }
        $line .= "\n\n; eof <a href=\"#top\">top</a>\n";
        ###########################################################################
    }
    if (length($out_file)) {
        rename_2_old_bak($out_file);
        write2file($line,$out_file);
        prt("New lines written to '$out_file'\n");
    } else {
        prt($line);
        prt("Use -o file to write to a file...\n");
    }
}

##############################################
## Version history at 2017/11/23
#5.5.85 19e8796a5b Geoff McLane Wed Nov 22 15:01:44 2017 +0100
#5.5.84 c2c7b1dab2 Jim Derry Mon Nov 20 09:32:08 2017 -0500
#5.5.83 9e09f1a722 Jim Derry Mon Nov 20 09:29:51 2017 -0500
#5.5.82 302660e3cb Jim Derry Mon Nov 20 09:28:48 2017 -0500
#...
#4.9.2 e2cbd9e89f Geoff McLane Thu Jan 29 18:25:57 2015 +0100
## eof

sub load_vers_file() {
    if (length($vers_file) == 0) {
        return;
    }
    my $inf = $vers_file;
    if (! open INF, "<$inf") {
        pgm_exit(1,"ERROR: Unable to open file [$inf]\n"); 
    }
    my @lines = <INF>;
    close INF;
    my $lncnt = scalar @lines;
    prt("Processing $lncnt lines, from [$inf]...\n");
    my ($line,$comm);
    my $lnn = 0;
    foreach $line (@lines) {
        chomp $line;
        $lnn++;
        next if ($line =~ /^\#/);
        if ($line =~ /^\d+\.\d+\..+\s+([0-9a-f]{10})\s/) {
            $comm = $1;
            $vers_commits{$comm} = $line;
        } else {
            pgm_exit(1,"Error:$lnn: $line NOT handled!\n");
        }
    }
    my @arr = keys( %vers_commits);
    my $cnt = scalar @arr;
    prt("From $lnn lines, got $cnt commit lines...\n");
}

my $def_test = 'F:\Projects\tidy-html5\README\verhist.log';
sub do_test() {
    $vers_file = $def_test;
    load_vers_file();
    pgm_exit(1,"TEMP EXIT\n");
}

#########################################
### MAIN ###
#do_test();
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
            } elsif ($sarg =~ /^i/) {
                $add_suthors = 1;
                prt("Set to add Authors, Summary tables to html end.\n") if ($verb);
            } elsif ($sarg =~ /^a/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $html_version = $sarg;
                $add_html = 1;
                prt("Add html with version [$html_version].\n") if ($verb);
            } elsif ($sarg =~ /^o/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $out_file = $sarg;
                prt("Set out HTML file to [$out_file].\n") if ($verb);
            } elsif ($sarg =~ /^V/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $vers_file = $sarg;
                prt("Set vers file to [$vers_file].\n") if ($verb);
                load_vers_file();
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
            $out_file = $def_out;
            $html_version = $def_vers;
            $add_html = 1;
            $add_suthors = 1;
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
    prt(" --add vers    (-a) = Add HTML head and tail using this version number.\n");
    prt(" --out <file>  (-o) = Write HTML output to this file.\n");
    prt(" --inc         (-i) = Include authors and summary tables at end.\n");
    prt(" --Vers <file> (-V) = Load verhist.log file, and its commits added as 1 line.\n");
    prt("\n");
    prt(" Given an input of a git log created with a command like -\n");
    prt(" \$ git log \"--decorate=full\" 4a4f209..HEAD > temp.log\n");
    prt(" and using a command like '\$ emailobs tidy-html5\\temp.log -o 5.1.8.html -a 5.1.8 -i\n");
    prt(" generate a suitable html file to publish with the tidy binaries.\n");
}

# eof - emailobfuscate.pl
