#!/usr/bin/perl -w
#< cmakeopts.pl - Given a directory, search for CMakeLists.txt files, recursively, 
# and show each option(NAME "test" ON) item
# 2021/04/27 - Move to D:\GPerl repo folder
# 20170902 - Add -e (--exec) and -l (--lib) to show executables and libraries
# 2016-12-18 - Add -s (--subdirs) to show the 'add_subdirectory' entries
# 2016-12-14 - Add -p (--package) to show the 'find_package' entries...
# 2016-11-15 - Be quieter, unless verbosity set
# 12/04/2015 - Hopefully improve substitutions
# 08/03/2014 - Show the project name, and path to CMakeLists.txt
# 19/05/2013 - Add -o for output file, and put the ON/OFF first
# 20/07/2012 - If no file given, but there is a CMakeLists.txt, then use that
# 01/04/2012 - If given a file, also search for and follow 'add_subdirectory(...)'
# 2012-01-29 - Convert to also run in Windows
# 2012-01-12 - Change to lib_utils.pl, and add a 'purpose' statement.
use strict;
use warnings;
use File::Basename; # split path ($name,$dir) = fileparse($ff); or ($nm,$dir,$ext) = fileparse($fil, qr/\.[^.]*/);
use File::Spec; # File::Spec->rel2abs($rel); # we are IN the SLN directory, get ABSOLUTE from RELATIVE
# example  $proj_targ = File::Spec->rel2abs($sarg);
use File::stat;
use Cwd;
my $os = $^O;
my $is_os_win = ($os =~ /win/i) ? 1 : 0;
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
my $outfile = $temp_dir.$PATH_SEP."temp.".$pgmname.".txt";
open_log($outfile);

my $pgm_vers = "0.0.6 2021-04-27";
# my $pgm_vers = "0.0.5 2016-12-18";
# my $pgm_vers = "0.0.4 2016-11-15";
# my $pgm_vers = "0.0.3 2012-04-01";
# my $pgm_vers = "0.0.2 2012-01-29";
# $pgm_vers = "0.0.1 2011-12-15";
my @in_files = ();

my @warnings = ();
my $load_log = 0;
my $verbosity = 0;
my $out_file = '';
my $final_msg = '';
my $min_option_name = 22;
my $show_find_package = 0;
my $show_subdirs = 0;
my $show_exe = 0;
my $show_lib = 0;

my $total_dirs = 0;
my $total_files = 0;
my $total_lines = 0;
my $total_bytes = 0;
my $total_options = 0;

my %options_found = ();
my %projects_found = ();
my %set_commands = ();
my $project_cnt = 0;
my @add_libs = ();
my @add_exes = ();

# debug
my $dbg01 = 0; # show each directory processed...
my $dbg02 = 0; # show sub-directory processed...
my $debug_on = 0;
my $def_file = 'C:\FG\30\flightgear';

sub VERB1() { return $verbosity >= 1; }
sub VERB2() { return $verbosity >= 2; }
sub VERB5() { return $verbosity >= 5; }
sub VERB9() { return $verbosity >= 9; }

sub process_dir($$$);

sub prtw($) {
   my ($tx) = shift;
   $tx =~ s/\n$//;
   prt("$tx\n");
   push(@warnings,$tx);
}

sub show_warnings() {
   if (@warnings) {
      prt( "Got ".scalar @warnings." WARNINGS..." );
      if (!VERB5()) {
          prt(" Use -v5 to list...");
      }
      prt("\n");
      if (VERB5()) {
          foreach my $itm (@warnings) {
             prt("$itm\n");
          }
          prt("\n");
      }
   } else {
      #prt( "\nNo warnings issued.\n\n" );
   }
}

sub pgm_exit($$) {
   my ($val,$msg) = @_;
   show_warnings();
   if (length($msg) > 1) {
        $msg .= "\n" if (!($msg =~ /\n$/));
        prt($msg);
   }
   prt("$final_msg\n") if (length($final_msg));
   close_log($outfile,$load_log);
   exit($val);
}

sub my_file_type($) {
    my ($file) = shift;
    return 1 if ($file eq 'CMakeLists.txt');
    return 2 if ($file =~ /\.cmake$/);
    return 0;
}

my %done_dirs = ();
my $cmlist_count = 0;
my $cmake_count = 0;
sub process_dir($$$) {
    my ($dir,$ra,$lev) = @_;
    my @dirs = ();
    my ($file,$ff,$cnt,$typ);
    my ($itm);
    $dir = ($is_os_win ? path_u2d($dir) : path_d2u($dir));
    return if (defined $done_dirs{$dir});
    $done_dirs{$dir} = 1;
    if (opendir( DIR, $dir )) {
        $total_dirs++;
        prt("Reading [$dir]...\n") if (VERB9());
        my @files = readdir(DIR);
        closedir(DIR);
        $dir .= '/' if !($dir =~ /\/$/);
        foreach $file (@files) {
            next if ($file eq '.');
            next if ($file eq '..');
            $ff = $dir.$file;
            if ( -d $ff ) {
                push(@dirs,$ff);
            } elsif ( -f $ff ) {
                $total_files++;
                $typ = my_file_type($file);
                if ($typ) {
                    push(@{$ra},$ff);
                    if ($typ == 1) {
                        $cmlist_count++;
                    } else {
                        $cmake_count++;
                    }
                }
            } else {
                # a link or ....
            }
        }
    } else {
        prtw("WARNING: Unable to open folder [$dir]... $!...\n");
    }
    if (@dirs) {
        $cnt = scalar @dirs;
        prt( "[$dbg02] $lev: Found $cnt subs in [$dir]...\n" ) if ($dbg02);
        foreach $itm (@dirs) {
            process_dir($itm,$ra,($lev + 1));
        }
    }
    if ($lev == 0) {
        $cnt = scalar @{$ra};
        prt("Found $cnt files of type CMakeLists.txt ($cmlist_count) or *.cmake ($cmake_count), in scan of [$dir]\n");
        if (VERB9()) {
            $cnt = 0;
            foreach $itm (@{$ra}) {
                $cnt++;
                prt("$cnt $itm\n");
            }
        }
    }
    return $ra;
}

sub full_opts_line($) {
    my ($line) = shift;
    my $len = length($line);
    my $inquot = 0;
    my $inbrac = 0;
    my ($i,$ch,$qc);
    for ($i = 0; $i < $len; $i++) {
        $ch = substr($line,$i,1);
        if ($inbrac) {
            if ($inquot) {
                $inquot = 0 if ($ch eq $qc);
            } elsif ($ch eq '"') {
                $inquot = 1;
                $qc = $ch;
            } elsif ($ch eq ')') {
                $inbrac--;
                if ($inbrac == 0) {
                    return 1;
                }
            }
        } else {
            if ($inquot) {
                $inquot = 0 if ($ch eq $qc);
            } elsif ($ch eq '"') {
                $inquot = 1;
                $qc = $ch;
            } elsif ($ch eq '(') {
                $inbrac++;
            }
        }
    }
    return 0;
}

sub full_fe_line($) {
    my $line = shift;
    return full_opts_line($line);
}

sub split_opts_line($) {
    my ($line) = shift;
    my $len = length($line);
    my $inquot = 0;
    my $inbrac = 0;
    my ($i,$ch,$qc,$command,$hadsp);
    my @arr = ();   # got nothing so far
    $command = '';  # start the collection
    $hadsp = 0;     # had no space yet
    for ($i = 0; $i < $len; $i++) {
        $ch = substr($line,$i,1);
        if ($ch eq '(') {
            last;   # found first '('
        } elsif ( !($ch =~ /\s/) ) {
            $command .= $ch;
        } else {    # have a SPACE
            if (length($command)) {
                # already had some non-space - trailing space
                # should check if the next sig char is the '('
            }
            # else have not yet started command,
            # so ignore this beginning space
        }
    }
    if (($ch ne '(')||(length($command)==0)) {
        prtw("WARNING: Option line did not conform! [$line]\n");
        return \@arr;
    }
    push(@arr,$command);    # push first item 'OPTION' or 'option'
    $command = '';
    # collect space spearated items, skipping spaces in quoted strings
    for (; $i < $len; $i++) {
        $ch = substr($line,$i,1);
        if ($inbrac) {
            if ($inquot) {
                $command .= $ch;
                $inquot = 0 if ($ch eq $qc);
            } else {
                if ($ch =~ /\s/) {
                    push(@arr,$command) if (length($command));
                    $command = '';
                } else {    # not a space
                    if ($ch eq ')') {
                        $inbrac--;
                        if ($inbrac == 0) {
                            last;
                        }
                    } else { # not end bracket
                        $command .= $ch;
                        if ($ch eq '"') {
                            $inquot = 1;
                            $qc = $ch;
                        }
                    }
                }
            }
        } else {
            if ($inquot) {
                $inquot = 0 if ($ch eq $qc);
            } elsif ($ch eq '"') {
                $inquot = 1;
                $qc = $ch;
            } elsif ($ch eq '(') {
                $inbrac++;
            }
        }
    }
    push(@arr,$command) if (length($command));
    return \@arr;
}

sub show_cmake_options($) {
    my $rha = shift;
    my ($in,$roptions);
    my ($i,$ra,$len,$option,$message,$default,$cnt,$msg,$abs,$n,$d,$p,$line,$i2);
    my $mino = $min_option_name;    # 0;
    my $minm = 0;
    my $mind = 0;
    my $dnhead = 0;
    $msg = '';
    my $out = '';
    my @arr = sort keys %{$rha};
    $cnt = scalar @arr;
    $n = 0;
    $d = 0;
    # this is the INPUT file, where the options found
    foreach $in (@arr) {
        $roptions = ${$rha}{$in};
        $len = scalar @{$roptions};
        if ($len) {
            $n++;
            $d += $len
        }
    }
    prt("Have $cnt files keys, $n with $d options...\n");
    foreach $in (@arr) {
        $abs = File::Spec->rel2abs($in);
        ($n,$d) = fileparse($abs);
        $p = '';
        $p = $projects_found{$in} if (defined $projects_found{$in});
        $roptions = ${$rha}{$in};
        $cnt = scalar @{$roptions};
        $total_options += $cnt;
        # try accumulating - $mino = 0;
        $minm = 0;
        if ($cnt) {
            prt("\nOPTIONS found $cnt, in [$in] $p $d\n") if (VERB5());
            $out .= "$cnt OPTIONS found in [$in] $p $d\n";
            # get LENGTHS
            for ($i = 0; $i < $cnt; $i++) {
                #                 0        1         2
                # push(@options, [$option, $message, $default]);
                $option = ${$roptions}[$i][0];
                $message = ${$roptions}[$i][1];
                $default = ${$roptions}[$i][2];
                $len = length($option);
                $mino = $len if ($len > $mino);
                $len = length($message);
                $minm = $len if ($len > $minm);
                $len = length($default);
                $mind = $len if ($len > $mind);
            }
            ###prt("Min. default is $mind\n");
            # but keep the 'default' to a min - should be "ON" or "OFF"
            if ($mind > 5) {
                $mind = 5;
                ###prt("Adjusted min. default to $mind\n");
            }
            if (!$dnhead) {
                $option = "Option";
                $default = "DEF";
                $message = 'Description';
                $option .= ' ' while (length($option) < $mino);
                $default .= ' ' while (length($default) < $mind);
                if (VERB1()) {
                    $message .= ' ' while (length($message) < $minm)
                }
                $line = "$option $default $message";
                $line .= " File" if (VERB1());
                prt("$line\n") if (length($out_file) == 0);
                $out .= "$line\n";
                $dnhead = 1;
            }
            for ($i = 0; $i < $cnt; $i++) {
                #                 0        1         2
                # push(@options, [$option, $message, $default]);
                $option = ${$roptions}[$i][0];
                $message = ${$roptions}[$i][1];
                $default = ${$roptions}[$i][2];
                $i2      = ${$roptions}[$i][3];
                $option .= ' ' while (length($option) < $mino);
                $default .= ' ' while (length($default) < $mind);
                if (VERB1()) {
                    $message .= ' ' while (length($message) < $minm)
                }
                $line = "$option $default $message";
                $line .= " $in" if (VERB1());
                $line .= " $i2" if (VERB2());
                prt("$line\n") if (length($out_file) == 0);
                $out .= "$line\n";
            }
        } else {
            $msg .= "Found NO options in [$in] $p $d\n" if (VERB9());
        }
    }
    prt($msg) if (length($msg) && VERB2());
    if (length($out_file)) {
        rename_2_old_bak($out_file); # NEVER overwrite any existing file!!!
        write2file($out,$out_file);
        $final_msg = "Option list written to [$out_file]";
    }
}

# escape ^ $ . | { } [ ] ( ) * + ? \
sub escape_regex($) {
    my $txt = shift;
    my $ntxt = '';
    my $len = length($txt);
    my ($i,$ch);
    for ($i = 0; $i < $len; $i++) {
        $ch = substr($txt,$i,1);
        if (($ch eq '^')||($ch eq '$')||($ch eq '.')||($ch eq '|')||($ch eq '{')||($ch eq '}')) {
            $ntxt .= '\\';
        } elsif (($ch eq '\\')||($ch eq '/')||($ch eq '(')||($ch eq ')')||($ch eq '[')||($ch eq ']')) {
            $ntxt .= '\\';
        } elsif (($ch eq '*')||($ch eq '+')||($ch eq '?')) {
            $ntxt .= '\\';
        }
        $ntxt .= $ch;
    }
    return $ntxt;
}

# processing a CMakeLists.txt
sub process_cmake_lines($$$);
#my %set_commands = ();

sub do_replacement($) {
    my $txt = shift;
    my $ntxt = '';
    my ($i,$ch,$len,$i2,$nc,$key);
    $len = length($txt);
    my $dn_sub = 0;
    for ($i = 0; $i < $len; $i++) {
        $i2 = $i + 1;
        $ch = substr($txt,$i,1);
        $nc = ($i2 < $len) ? substr($txt,$i2,1) : '';
        if (($ch eq '$')&&($nc eq '{')) {
            $key = '';
            $i += 2;
            for (; $i < $len; $i++) {
                #$i2 = $i + 1;
                $ch = substr($txt,$i,1);
                #$nc = ($i2 < $len) ? substr($txt,$i2,1) : '';
                if ($ch eq '}') {
                    last;
                } else {
                    $key .= $ch;
                }
            }
            if (length($key) && (defined $set_commands{$key})) {
                $ntxt .= $set_commands{$key};
                $dn_sub = 1;
            } else {
                $ntxt .= '$'.'{'.$key.'}';
            }
        } else {
            $ntxt .= $ch;
        }
    }
    return $ntxt;
}


sub do_replacements($) {
    my $txt = shift;
    my $ntxt = do_replacement($txt);
    if (($txt ne $ntxt) && ($ntxt =~ /\$\{.+\}/)) {
        $ntxt = do_replacement($ntxt);
    }
    return $ntxt;
}

my %add_subdirectory_done = ();
my %shown_includes = ();
my %done_cmake_lines = ();
# process the lines from the CMakeLists.txt file
sub process_cmake_lines($$$) {
    my ($inf,$rlines,$rha) = @_;
    my $in = $inf;
    ##########################################
    # make sure each file only processed ONCE
    my $abs = File::Spec->rel2abs($in);
    $abs = ($is_os_win ? path_u2d($abs) : path_d2u($abs));
    $abs = lc($abs) if ($is_os_win);
    return if (defined $done_cmake_lines{$abs});
    $done_cmake_lines{$abs} = 1;
    ###########################################
    my @options = ();
    my ($cnt,$lnn,$i,$i2,$line,$tline,$tmp,$ibgn);
    my ($ra,$len,$option,$message,$default,$subd,$ff);
    my ($feline,$fevar,$febgn,@arr,$msg);
    my $mino = 0;
    my $minm = 0;
    my ($name,$dir) = fileparse($in);
    if ($dir =~ /^\.(\\|\/){1}$/) {
        $dir = '';
    } else {
        $dir .= $PATH_SEP if ( !($dir =~ /(\\|\/)$/) );
    }
    $cnt = scalar @{$rlines};
    $in =~ s/^\.(\\|\/)//;
    $lnn = sprintf("%5d", $cnt);
    $in .= ' ' while (length($in) < 8+1+3);
    prt("Got $lnn lines, from [$in] to process...\n") if (VERB9());
    my @sub_dirs = ();
    my $project = '';
    for ($i = 0; $i < $cnt; $i++) {
        $total_lines++;
        $i2 = $i + 1;
        $ibgn = $i2;
        $line = ${$rlines}[$i];
        $total_bytes += length($line);
        chomp $line;
        $tline = trim_all($line);
        if ($tline =~ /^\s*option\s*\(/i) { # seek OPTION(...) line
            while (($i2 < $cnt)&&(!full_opts_line($tline))) {
                $total_lines++;
                $i++;
                $i2 = $i + 1;
                $tmp = ${$rlines}[$i];
                $total_bytes += length($tmp);
                $tline .= ' ';
                $tline .= trim_all($tmp);
            }
            prt("$tline\n") if (VERB9());
            $ra = split_opts_line($tline);
            $len = scalar @{$ra};
            if ($len >= 2) {
                $tmp = ${$ra}[0];
                $option = ${$ra}[1];
                $message = 'NO MESSAGE';
                if ($len > 2) {
                    $message = ${$ra}[2];
                }
                $default = 'OFF';
                if ($len > 3) {
                    $default = ${$ra}[3];
                }
                # Establish options
                push(@options, [$option, $message, $default, $i2]);
                if (VERB9()) {
                    prt("$i2: $option $message $default\n");
                    #foreach $tmp (@{$ra}) {
                    #    prt("$tmp ");
                    #}
                    #prt("\n");
                }
            } else {
                prtw("$pgmname:WARNING: Line $i2 did not SPLIT correctly! [$tline] file $in\n");
            }
        } elsif ($tline =~ /^\s*foreach\s*\(/i) {
            $febgn = $tline;
            $tmp = $tline;
            $tmp =~ s/^foreach\s*\(\s*//i;
            $fevar = $tmp;
            prt("In [$in] got 'foreach' [$fevar]\n") if (VERB9());
            while (($i2 < $cnt)&&(!full_fe_line($tline))) {
                $total_lines++;
                $i++;
                $i2 = $i + 1;
                $tmp = ${$rlines}[$i];
                $total_bytes += length($tmp);
                $tmp = trim_all($tmp);
                $tline .= ' ' if (length($tline) && length($tmp));
                $tline .= $tmp;
            }
            $tmp = escape_regex($febgn);
            $tline =~ s/$tmp//;
            $tline =~ s/\)\s*$//;
            $feline = trim_all($tline);
            prt("item set [$feline]\n") if (VERB9());
            $tline = '';
            while ($i2 < $cnt) {
                $total_lines++;
                $i++;
                $i2 = $i + 1;
                $tmp = ${$rlines}[$i];
                $total_bytes += length($tmp);
                $tmp = trim_all($tmp);
                last if ($tmp =~ /^endforeach/i);
                $tline .= ' ' if (length($tline));
                $tline .= $tmp;
            }
            prt("action: [$tline]\n") if (VERB9());
            $tmp = escape_regex($fevar);
            if ($tline =~ /^\s*add_subdirectory\s*\(\s*\$\{\s*$tmp\s*\}\s*\)/) {
                @arr = split(/\s+/,$feline);
                $tmp = scalar @arr;
                prt("Need to process the set of $tmp items as subdirectories...!\n") if (VERB5());
                foreach $tmp (@arr) {
                    $ff = $dir.$tmp;
                    if (-d $ff) {
                        $ff .= $PATH_SEP."CMakeLists.txt";
                        if (-f $ff) {
                            prt("[s] add_subdir '$tmp' $in $lnn\n") if ($show_subdirs || VERB5());
                            push(@sub_dirs,$ff);
                        } else {
                            prtw("WARNING:1: NOT found file [$ff]!\n");
                        }
                    } else {
                        prtw("WARNING:2: NOT found sub-directory [$ff]!\n");
                    }
                }
            }
        } elsif ($tline =~ /^\s*project\s*\((.+)\)/i) {
            # elsif ($tline =~ /project\s*\((.+)\)\s*$/i) {
            $tmp = trim_all($1);
            @arr = space_split($tmp);
            $project = $arr[0];
            $tmp = uc($project)."_SOURCE_DIR";
            $ff = $dir;
            $ff =~ s/(\\|\/)$//;
            ($ff,$subd) = fileparse($ff);
            $set_commands{$tmp} = $subd;
            $tmp = uc($project)."_BINARY_DIR";
            $set_commands{$tmp} = $subd;
            if ($project_cnt == 0) {
                prt("Project: $project $tmp=$subd - $inf\n");
            } elsif (VERB5()) {
                prt("v5: project: $project $tmp=$subd - $inf\n");
            }
            $projects_found{$subd} = 1;
            $project_cnt++;
        } elsif ($tline =~ /^\s*add_subdirectory\s*\((.+)\)\s*$/i) {
            $subd = trim_all($1);
            prt("$i2: [$line] sub [$subd]\n") if (VERB9());
            $subd = strip_double_quotes($subd);
            @arr = space_split($subd);
            foreach $tmp (@arr) {
                $tmp = strip_double_quotes($tmp);
                $subd = do_replacements($tmp);
                $ff = $subd;
                if (!-d $ff) {
                    $ff = $dir.$subd;
                }
                if (-d $ff) {
                    $ff .= $PATH_SEP."CMakeLists.txt";
                    if (-f $ff) {
                        prt("[s] add_subdir '$tmp' $in $lnn\n") if ($show_subdirs || VERB5());
                        # prt("Found added item [$ff]\n") if (VERB5());
                        push(@sub_dirs,$ff);
                    } else {
                        prtw("WARNING:3: NOT found file [$ff]\n");
                    }
                } else {
                    prtw("WARNING:4: NOT found sub-directory [$ff]\nline:$i2: '$tline'\nin: $abs\n");
                }
            }
        } elsif ($tline =~ /^\s*include\s*\((.+)\)/i) {
            $tmp = trim_all($1);
            $subd = do_replacements($tmp);
            $subd = path_u2d($subd);
            if (-f $subd) {
                process_file($subd);
            } else {
                if ( ! defined $shown_includes{$subd}) {
                    prtw("WARNING: include '$subd' NOT found!\n") if (VERB5());
                    $shown_includes{$subd} = 1;
                }
            }
            ###pgm_exit(1,"INCLUDE '$subd'!\norg ('$tmp') NOT processed! FIX ME!\n");
        } elsif ($tline =~ /^\s*find_package/i) {
#            while (($i2 < $cnt)&&(!full_opts_line($tline))) {
#                $total_lines++;
#                $i++;
#                $i2 = $i + 1;
#                $tmp = trim_all(${$rlines}[$i]);
#                $total_bytes += length($tmp);
#                $tline .= ' ';
#                $tline .= trim_all($tmp);
#            }
#            $tline .= trim_all($tline);
            $msg = $tline;
            if ($show_find_package) {
                $msg .= " $in $i2" if (VERB1());
                if ($tline =~ /^\s*find_package_handle_standard_args/i) {
                    prt("[v5] $msg\n") if (VERB5());
                } else {
                    prt("[p] $msg - $in:$ibgn\n");
                }
            }
        # } elsif ($tline =~ /^\s*add_executable\s*\((.+)\)/i) {
        #    $tmp = trim_all($1);
        } elsif ($tline =~ /^\s*add_executable\s*\(/i) {
            $tmp = $tline;
            if ($show_exe) {
                $subd = do_replacements($tmp);
                $msg = $subd;
                $msg .= " $in $i2";
                push(@add_exes,$msg);
                prt("[E] $msg\n") if (VERB5());
            }
        #} elsif ($tline =~ /^\s*add_library\s*\((.+)\)/i) {
        #    $tmp = trim_all($1);
        } elsif ($tline =~ /^\s*add_library\s*\(/i) {
            $tmp = trim_all($tline);
            if ($show_lib) {
                $subd = do_replacements($tmp);
                $msg = $subd;
                $msg .= " $in $i2";
                push(@add_libs,$msg);
                prt("[L] $msg\n") if (VERB5());
            }

        }
    }
    ${$rha}{$in} = \@options;
    foreach $in (@sub_dirs) {
        $in = ($is_os_win ? path_u2d($in) : path_d2u($in));
        next if (defined $add_subdirectory_done{$in});
        $add_subdirectory_done{$in} = 1;
        if (open FIL, "<$in") {
            my @lines = <FIL>;
            close FIL;
            process_cmake_lines($in,\@lines,$rha);
        }
    }
}

my %done_files = ();

sub process_file($) {
    my ($in) = @_;
    $in = ($is_os_win ? path_u2d($in) : path_d2u($in));
    my ($name,$dir) = fileparse($in);
    if (!my_file_type($name)) {
        return;
    }
    return if (defined $done_files{$in});
    $done_files{$in} = 1;
    if (open FIL, "<$in") {
        my @lines = <FIL>;
        close FIL;
        process_cmake_lines($in,\@lines,\%options_found);
    } else {
        prtw("WARNING: Unable to open file [$in]!\n");
    }
}

sub mycmp_decend {
   return -1 if ( ${$a}[0] > ${$b}[0] );
   return  1 if ( ${$a}[0] < ${$b}[0] );
   return 0;
}

sub process_input() {
    my ($in);
    my @files = ();
    foreach $in (@in_files) {
        if (-f $in) {
            process_file($in);
        } elsif (-d $in) {
            process_dir($in,\@files,0);
        } else {
            pgm_exit(1,"ERROR: Input [$in] is NOT file or directory!\n");
        }
    }
    foreach $in (@files) {
        process_file($in);
    }
}

sub show_libs_exes() {
    my ($cnt,$msg);
    $cnt = scalar @add_exes;
    if ($cnt) {
        prt("Found $cnt EXES...\n");
        foreach $msg (@add_exes) {
            prt("[E] $msg\n");
        }
    }
    $cnt = scalar @add_libs;
    if ($cnt) {
        prt("Found $cnt LIBS...\n");
        foreach $msg (@add_libs) {
            prt("[L] $msg\n");
        }
    }
}

#########################################
###### MAIN ######
process_args(@ARGV);
process_input();
show_libs_exes();
show_cmake_options(\%options_found);
prt("$total_dirs dirs, $total_files files, $total_lines lines, $total_bytes bytes, for $total_options options.\n");
pgm_exit(0,"");

####################################

sub need_arg {
    my ($arg,@av) = @_;
    pgm_exit(1,"ERROR: [$arg] must have a following argument!\n") if (!@av);
}

sub process_args {
    my (@av) = @_;
    my ($arg,$sarg);
    while (@av) {
        $arg = $av[0];
        if ($arg =~ /^-/) {
            $sarg = substr($arg,1);
            $sarg = substr($sarg,1) while ($sarg =~ /^-/);
            if (($sarg =~ /^h/) || ($sarg eq '?')) {
                give_help();
                pgm_exit(0,"Help exit 0");
            } elsif ($sarg =~ /^l/) {
                $load_log = 1;
                prt("Set to load log at end.\n");
            } elsif ($sarg =~ /^o/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $out_file = $sarg;
                prt("Output options to [$out_file].\n");
            } elsif ($sarg =~ /^v/) {
                if ($sarg =~ /^v.*(\d+)$/) {
                    $verbosity = $1;
                } else {
                    while ($sarg =~ /^v/) {
                        $verbosity++;
                        $sarg = substr($sarg,1);
                    }
                }
                prt("Set verbosity to $verbosity.\n") if (VERB1());
            } elsif ($sarg =~ /^p/) {
                $show_find_package = 1;
                prt("Set show find package on...\n") if (VERB1());
            } elsif ($sarg =~ /^s/) {
                $show_subdirs = 1;
                prt("Set show add_subdirectories on...\n") if (VERB1());
            } elsif ($sarg =~ /^E/) {
                $show_exe = 1;
                prt("Set show add_executable on...\n") if (VERB1());
            } elsif ($sarg =~ /^L/) {
                $show_lib = 1;
                prt("Set show add_library on...\n") if (VERB1());
            } else {
                pgm_exit(1,"$pgmname:ERROR: Unknown option [$arg]! Try -?\n");
            }
        } else {
            push(@in_files,$arg);
            prt("Added input [$arg]\n");
            if (-d $arg) {
                $set_commands{PROJECT_BINARY_DIR} = $arg;
            }
        }
        shift @av;
    }
    if (!@in_files && $debug_on) {
        push(@in_files,$def_file);
        prt("Added DEFAULT input [$def_file]\n");
    }
    if (!@in_files && (-f "CMakeLists.txt")) {
        push(@in_files,"CMakeLists.txt");
        prt("Added local input [CMakeLists.txt]\n");
    }
    if ( ! @in_files ) {
        pgm_exit(1,"$pgmname:ERROR: No input found in command!\n");
    }
}

sub give_help {
    prt("$pgmname version $pgm_vers\n");
    prt("Usage: [options] input\n");
    prt("Options:\n");
    prt(" --help      (-h,-?) = This help and exit.\n");
    prt(" --load         (-l) = Load log at end.\n");
    prt(" --out file     (-o) = Write options list to this file.\n");
    prt(" --verb[Num]    (-v) = Bump [or set] verbosity. (def=$verbosity)\n");
    prt(" --package      (-p) = Show the 'find_package' entries, a depends indication. (def=off)\n");
    prt(" --subdirs      (-s) = Show 'add_subdirectory' entries. (def=".($show_subdirs ? 'on' : 'off').")\n");
    prt(" --Exe          (-E) = Show 'add_executable' entries. (def=$show_exe)\n");
    prt(" --Lib          (-L) = Show 'add_library' entries. (def=$show_lib)\n");
    prt("Purpose: Given a directory, search for CMakeLists.txt files, recursively,\n");
    prt("and show each option(NAME \"test\" ON) item found.\n");
}

# eof - cmakeopts.pl
