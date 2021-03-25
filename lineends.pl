#!/usr/bin/perl -w
# NAME: lineendings.pl
# AIM: Check the line ending of a file
# 2021/02/21 - Move to D:\GPerl dir
# 2020/12/18 - add recursive folder checking - --recur
# 2020/11/20 - Also check and report trailing whitespace - ie space or tab
# 2016-11-10 - Change to byte by byte binary reading
# 11/09/2015 - Allow multiple file inputs...
# 14/10/2013 - update style and functionality
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
my $VERS = "0.0.7 2021-02-21";
##my $VERS = "0.0.6 2020-12-18";
##my $VERS = "0.0.5 2020-11-20";
##my $VERS = "0.0.4 2016-11-10";
##my $VERS = "0.0.3 2015-09-11";
##my $VERS = "0.0.2 2013-10-14";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
# my $out_file = '';
my @in_files = ();
my $recursive = 0;
my $show_trailing = 0;

# ### DEBUG ###
my $debug_on = 0;
my $def_file = 'def_file';
my $dbg1 = 0;

### program variables
my @warnings = ();
my $cwd = cwd();
my @fnd_files = ();
my %fnd_hash = ();
my $typ = '';
my $total_files = 0;
my %done_files = ();
my $tot_folders = 0;
my %done_folders = ();
my $total_lines = 0;
my $total_bytes = 0;
my $total_tw = 0;
my $files_with_tw = 0;
my @ts_lines = ();

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

my @repo_dirs = qw( CVS .svn .git .hg );

sub is_repo_dir($) {
    my $item = shift;
    my ($test);
    foreach $test (@repo_dirs) {
        return 1 if ($test eq $item);
    }
    return 0;
}


sub add_2_found {
	my ($ty, $fi) = @_;
	push(@fnd_files, [$ty, $fi]);
	$fnd_hash{$ty} .= '*' if (defined $fnd_hash{$ty});
	$fnd_hash{$ty} .= $fi;
	while (length($ty) < 8) {
		$ty .= ' ';
	}
	prt( "$ty $fi\n" ) if (VERB5());
}

sub process_directory {
	my ($inf) = shift;
    return if (defined $done_folders{$inf});
    $done_folders{$inf} = 1;
	prt( "Processing $inf folder ...\n" );
	if ( opendir( DIR, $inf ) ) {
        $tot_folders++;
		my @files = readdir(DIR);
		closedir DIR;
        my @dirs = ();
		foreach my $fl (@files) {
			if (($fl eq '.') || ($fl eq '..')) {
				next;
			}
			my $ff = $inf . $PATH_SEP . $fl;
			if (-f $ff) {
				$typ = process_file($ff);
				add_2_found( $typ, $fl );
			} elsif (-d $ff) {
                if (!is_repo_dir($fl)) {
                    push(@dirs,$ff);
                }
            }
		}
        if ($recursive) {
            my ($dir);
            foreach $dir (@dirs) {
                process_directory($dir);
            }
        }
	} else {
		prt( "ERROR: Could not open folder [$inf] ...\n" );
	}
}

sub process_file {
	my ($if) = shift;
    return if (defined $done_files{$if});
    $done_files{$if} = 1;
	my $type = "UNKNOWN";
	if (open INF, "<$if") {
		binmode INF;
        $total_files++;
        my $byte = '';
        my $pb = '';
        my $line = '';
        my $byte_cnt = 0;
        my $cr_cnt = 0;
        my $lf_cnt = 0;
        my $tr_cnt = 0;
        my $ln_cnt = 0;
        my $lnn = 0;
        while (read(INF, $byte, 1)) {
            $byte_cnt++;
            if ($byte eq "\r") {
                $lnn++;
                if (length($line) > 0) {
                    if ($line =~ /\s+$/) {
                        $tr_cnt++;
                        push(@ts_lines,[$if,$lnn,$line]);
                    }
                }
                $cr_cnt++;
                $line = '';
                next;
            } elsif ($byte eq "\n") {
                $lf_cnt++;
                $line = '';
                next;
            } elsif ($byte eq "\0") {
                $type = "BINARY";
                close INF;
                return $type;
            }
            $line .= $byte;
            $pb = $byte;
        }
        close INF;
        if (($cr_cnt == 0) && ($lf_cnt == 0)) {
            $type = "NO-LINES";
        } elsif ($cr_cnt == $lf_cnt) {
            $type = "WIN32";
            $ln_cnt = $lf_cnt;
        } elsif ($cr_cnt && ($lf_cnt == 0)) {
            $ln_cnt = $cr_cnt;
            $type = "MAC";
        } elsif ($lf_cnt && ($cr_cnt == 0)) {
            $ln_cnt = $lf_cnt;
            $type = "UNIX";
        } else {
            $ln_cnt = $lf_cnt;
            $type = "NIXED";
        }
        $total_bytes += $byte_cnt;
        $total_lines += $ln_cnt;
        $total_tw += $tr_cnt;
        $files_with_tw += 1 if ($tr_cnt);
        prt("[v5] $if: Type $type: bytes $byte_cnt, CR $cr_cnt, LF $lf_cnt, LN $ln_cnt, TW $tr_cnt\n") if (VERB5());
	} else {
		prt( "ERROR: Failed to open [$if] ...\n" );
	}
	return $type;
}

sub process_file_OK_but {
	my ($if) = shift;
	my $type = "UNKNOWN";
	if (open INF, "<$if") {
		binmode INF;
		my @lines = <INF>;
		close INF;
		my $cnt = scalar @lines;
		prt( "Got $cnt lines to process from [$if] ...\n" ) if (VERB9());
        $total_files++;
        my ($line,$ll,$ch,$i);
		my $crlfcnt = 0;
		my $crcnt = 0;
		my $lfcnt = 0;
		my $ncnt = 0;
		my $lcnt = 0;
        my $isbin = 0;
		foreach $line (@lines) {
			$ll = length($line);
			for ($i = 0; $i < $ll; $i++) {
				$ch = substr($line, $i, 1);
				if ($ch eq "\0") {
                    $isbin = 1;
                    prt("BINARY - Found 'null' at line $lcnt, char $i\n") if (VERB2());
                    last;
                }
            }
            last if ($isbin);
        }
        if ($isbin) {
			$type = "BINARY";
            return $type;
        }
		foreach $line (@lines) {
			$lcnt++;
			$ll = length($line);
			$ch = '';
			my $gotcr = 0;
			my $gotlf = 0;
			for ($i = $ll - 1; $i >= 0; $i--) {
			###for (my $i = 0; $i < $ll; $i++) {
				$ch = substr($line, $i, 1);
				if ($ch eq "\n") {
					$gotlf = 1;
				} elsif ($ch eq "\r") {
					$gotcr = 1;
				} else {
					last;
				}
			}
			if( $gotcr && $gotlf ) {
				$crlfcnt++;
			} elsif ( $gotcr ) {
				$crcnt++;
			} elsif ( $gotlf ) {
				$lfcnt++;
			} else {
				$ncnt++;
			}
		}
		if (($crlfcnt == $cnt)||($crlfcnt == ($cnt - 1))) {
			$type = "CRLF";
		} elsif (($crcnt == $cnt)||($crcnt == ($cnt - 1))) {
			$type = "MAC";
		} elsif (($lfcnt == $cnt)||($lfcnt == ($cnt - 1))) {
			$type = "UNIX";
		} else {
			$type = "MIXED";
		}
		prt( "$type - both=$crlfcnt cr=$crcnt lf=$lfcnt none=$ncnt ...\n" ) if (VERB2());

	} else {
		prt( "ERROR: Failed to open [$if] ...\n" );
	}
	return $type;
}

sub process_input() {
    foreach $in_file (@in_files) {
        if (-f $in_file) {
            $typ = process_file($in_file);
            add_2_found($typ, $in_file);
        } elsif (-d $in_file) {
            process_directory($in_file);
        } else {
            prt( "ERROR: [$in_file] is NOT file or folder???\n" );
        }
    }
    my $msg = '';
    if ($total_lines && $total_tw) {
        my $pct = $total_tw * 100 / $total_lines;
        $pct = int($pct * 10) / 10;
        $msg = "$pct%";
    }
    prt("\nSummary of $total_files files processed... folders $tot_folders, total lines $total_lines, with trailing $total_tw $msg files $files_with_tw\n");
    foreach my $key (keys %fnd_hash) {
        my $val = $fnd_hash{$key};
        my @arr = split(/\*/, $val);
        my $cnt = scalar @arr;
        prt("$key = $cnt\n");
        if (VERB5()) {
            $val =~ s/\*/, /g;
            prt( "$key = $val\n" );
        } elsif ( VERB1() && ($key ne 'WIN32')) {
            $val =~ s/\*/, /g;
            prt( "$key = $val\n" );
        }
    }
}

sub show_trailing() { # if ($show_trailing) (-s);
    my $cnt = scalar @ts_lines;
    my ($i,$ra,$file,$lnn,$line,$len,$len2,$diff);
    $file = get_nn($total_files);
    $lnn = get_nn($total_lines);
    $len = get_nn($cnt);
    $len2 = get_nn($total_bytes);
    if (!$cnt) {
        prt("Of the $file file(s), $len2 bytes, $lnn lines, NONE have trailing space.\n");
        return;
    }
    prt("Of the $file file(s), $len2 bytes, $lnn lines, $len have trailing space.\n");
    # push(@ts_lines,[$if,$lnn,$line]);
    my $tot_spaces = 0;
    for ($i = 0; $i < $cnt; $i++) {
        $ra = $ts_lines[$i];
        $file = ${$ra}[0];
        $lnn = ${$ra}[1];
        $line = ${$ra}[2];
        $len = length($line);
        $line =~ s/\s+$//;
        $len2 = length($line);
        $diff = $len - $len2;
        $line .= 'X' while (length($line) < $len);
        $line .= "($diff)";
        prt("$file:$lnn: $line\n");
        $tot_spaces += $diff;
    }
    $lnn = "NA";
    if ($total_bytes) {
        $lnn = ($tot_spaces * 100) / $total_bytes;
        $lnn = int(($lnn + 0.005) * 100) / 100;
    }
    $line = get_nn($total_bytes);
    $len = get_nn($cnt);
    $len2 = get_nn($tot_spaces);
    prt("Cleaning these $len lines would eliminate $len2 spaces. $lnn% of total $line bytes.\n");
}


##########################################
### MAIN ###
parse_args(@ARGV);
process_input();
show_trailing() if ($show_trailing);
pgm_exit(0,"");
########################################

sub need_arg {
    my ($arg,@av) = @_;
    pgm_exit(1,"ERROR: [$arg] must have a following argument!\n") if (!@av);
}

sub got_wild($) {
    my $file = shift;
    my $len = length($file);
    my ($i,$ch);
    for ($i = 0; $i < $len; $i++) {
        $ch = substr($file,$i,1);
        return 1 if ($ch eq '?');
        return 1 if ($ch eq '*');
    }
    return 0;
}

sub process_wild($) {
    my $file = shift;
    my @files = glob $file;
    my $cnt = 0;
    my ($fil);
    foreach $fil (@files) {
        push(@in_files,$fil);
        $in_file = $fil;
        $cnt++;
    }
    prt("Added $cnt input files from $file\n");
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
#            } elsif ($sarg =~ /^o/) {
#                need_arg(@av);
#                shift @av;
#                $sarg = $av[0];
#                $out_file = $sarg;
#                prt("Set out file to [$out_file].\n") if (VERB1());
            } elsif ($sarg =~ /^r/) {
                $recursive = 1;
                prt("Set recursive into folders.\n") if (VERB1());
            } elsif ($sarg =~ /^s/) {
                $show_trailing = 1;
                prt("Set to show trailing space lines.\n") if (VERB1());
            } else {
                pgm_exit(1,"ERROR: Invalid argument [$arg]! Try -?\n");
            }
        } else {
            if (got_wild($arg)) {
                process_wild($arg);
            } else {
                $in_file = $arg;
                push(@in_files,$in_file);
                prt("Set input to [$in_file]\n") if (VERB1());
            }
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
        pgm_exit(1,"ERROR: No input directory or files found in command!\n");
    }
    if ((! -f $in_file)&&(! -d $in_file)) {
        pgm_exit(1,"ERROR: Unable to find in file or folder [$in_file]! Check name, location...\n");
    }
}

sub give_help {
    prt("$pgmname: version $VERS\n");
    prt("Usage: $pgmname [options] in-file/in-dir/...\n");
    prt("Options:\n");
    prt(" --help  (-h or -?) = This help, and exit 0.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. def=$verbosity\n");
    prt(" --load        (-l) = Load LOG at end. ($outfile)\n");
    # prt(" --out <file>  (-o) = Write output to this file.\n");
    prt(" --recur       (-r) = Recursively search folders inputs. (def=$recursive)\n");
    prt(" --show        (-s) = Show the lines with trailing spaces. (def=$show_trailing)\n");
}

# eof - lineends.pl
