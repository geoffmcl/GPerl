#!/usr/bin/perl
#< trim.pl - 20131025 - trim a file
# 2021/03/09 - Review
# 16/12/2014 - No output unless -v
# 03/03/2014 - Added line count if VERB1()
# 20/02/2014 - Copy to linux
# 31/10/2013 - Add --strip <col> to strip col count from left of line
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

my $VERS = "0.0.4 2021-03-09";
##my $VERS = "0.0.3 2014-12-16";
##my $VERS = "0.0.2 2013-10-31";
##my $VERS = "0.0.2 2013-10-31";
##my $VERS = "0.0.1 2013-10-25";
my $in_file = '';
my $verbosity = 0;
my $out_file = '';
my $col_cnt = 0;
my $keep_paras = 0;
my $del_lines = 0;

sub VERB1() { return $verbosity >= 1; }
sub VERB2() { return $verbosity >= 2; }
sub VERB5() { return $verbosity >= 5; }
sub VERB9() { return $verbosity >= 9; }

sub prt($) { print shift; }

sub pgm_exit($$) {
    my ($val,$msg) = @_;
    if (length($msg)) {
        $msg .= "\n" if (!($msg =~ /\n$/));
        prt($msg);
    }
    #show_warnings($val);
    #close_log($outfile,$load_log);
    exit($val);
}


sub trim_leading($) {
    my ($ln) = shift;
	$ln = substr($ln,1) while ($ln =~ /^\s/); # remove all LEADING space
    return $ln;
}

sub trim_tailing($) {
    my ($ln) = shift;
	$ln = substr($ln,0, length($ln) - 1) while ($ln =~ /\s$/g); # remove all TRAILING space
    return $ln;
}

sub trim_ends($) {
    my ($ln) = shift;
    $ln = trim_tailing($ln); # remove all TRAINING space
	$ln = trim_leading($ln); # remove all LEADING space
    return $ln;
}

sub trim_all {
	my ($ln) = shift;
	$ln =~ s/\n/ /gm;	# replace CR (\n)
	$ln =~ s/\r/ /gm;	# replace LF (\r)
	$ln =~ s/\t/ /g;	# TAB(s) to a SPACE
    $ln = trim_ends($ln);
	$ln =~ s/\s{2}/ /g while ($ln =~ /\s{2}/);	# all double space to SINGLE
	return $ln;
}

sub write2file {
	my ($txt,$fil) = @_;
	open WOF, ">$fil" or pgm_exit(3,"ERROR: Unable to open $fil! $!\n");
	print WOF $txt;
	close WOF;
}

# RENAME A FILE TO .OLD, or .BAK
# 0 - do nothing if file does not exist.
# 1 - rename to .OLD if .OLD does NOT exist
# 2 - rename to .BAK, if .OLD already exists,
# 3 - deleting any previous .BAK ...
sub rename_2_old_bak {
	my ($fil) = shift;
	my $ret = 0;	# assume NO SUCH FILE
	if ( -f $fil ) {	# is there?
		# my ($nm,$dir,$ext) = fileparse( $fil, qr/\.[^.]*/ );
		my $nmbo = $fil . '.old';
		$ret = 1;	# assume renaming to OLD
		if ( -f $nmbo) {	# does OLD exist
			$ret = 2;		# yes - rename to BAK
			$nmbo = $fil . '.bak';
			if ( -f $nmbo ) {
				$ret = 3;
				unlink $nmbo;
			}
		}
		rename $fil, $nmbo;
	}
	return $ret;
}


sub process_file($) {
    my $fil = shift;
    my @olines = ();
    if (open(FIL, "<$fil")) {
        my @lines = <FIL>;
        close FIL;
        my ($line,$len);
        my $in_para = 0;
        my $lns = 0;
        my $del_cnt = 0;
        foreach $line (@lines) {
            chomp $line;
            $lns++;
            if ($del_lines) {
                if ($line =~ /^>/ ) {
                    #pgm_exit(1,"Del line $line\n");
                    $del_cnt++;
                    next;
                }
            }
            $len = length($line);
            if ($col_cnt > 0) {
                if ($len > $col_cnt) {
                    $line = substr($line,$col_cnt);
                } else {
                    $line = '';   # line too short to be included
                }
            }
            $line = trim_all($line);
            $len = length($line);
            if ($len == 0) {
                if ($keep_paras) {
                    if ($in_para) {
                        $in_para = 0;
                        next;
                    } else {
                        $in_para = 1;
                    }
                } else {
                    next;
                }
            } else {
                $in_para++;
            }
            prt("$line\n") if (VERB9());
            push(@olines,$line);
            ###prt("$line\n");
        }
        if (@olines) {
            $len = scalar @olines;
            $line = join("\n",@olines)."\n";
            my $msg = "From in $lns, ";
            $msg .= "del $del_cnt, " if ($del_lines);
            $msg .= "written $len lines to ";
            if (length($out_file)) {
                $in_para = rename_2_old_bak($out_file);
                $msg .= "out file $out_file (ren=$in_para)";
                write2file($line,$out_file);
                #prt("From in $lns, written $len lines to out file $out_file (ren=$in_para)\n"); # if (VERB1());
            } else {
                prt("$line");
                $msg .= "stdout, due no -o file in command";
                #prt("Written $len lines to stdout, due no -o file in command\n") if (VERB1());
            }
            prt("$msg\n");
        }
    } else {
        prt("ERROR: Can NOT open file [$fil]\n");
        exit 3;
    }
}


###################################################
parse_args(@ARGV);
process_file($in_file);
exit 0;
###################################################

sub need_arg {
    my ($arg,@av) = @_;
    pgm_exit(3,"ERROR: [$arg] must have a following argument!\n") if (!@av);
}

sub parse_args {
    my (@av) = @_;
    my ($arg,$sarg,$oo);
    while (@av) {
        $arg = $av[0];
        if ($arg =~ /^-/) {
            $sarg = substr($arg,1);
            $sarg = substr($sarg,1) while ($sarg =~ /^-/);
            if (($sarg =~ /^h/i)||($sarg eq '?')) {
                give_help();
                pgm_exit(2,"");
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
            } elsif ($sarg =~ /^o/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $out_file = $sarg;
                prt("Set out file to [$out_file].\n") if (VERB1());
            } elsif ($sarg =~ /^p/) {
                $oo = 1;
                if ($arg =~ /-$/) {
                    $oo = 0;
                }
                $keep_paras = $oo;
                prt("Set keep paras $keep_paras.\n") if (VERB1());
            } elsif ($sarg =~ /^d/) {
                $oo = 1;    # set it ON
                if ($arg =~ /-$/) {
                    $oo = 0;    # set it OFF
                }
                $del_lines = $oo;
                prt("Set delete lines = $del_lines (bgn '<').\n") if (VERB1());
            } elsif ($sarg =~ /^s/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                if ($sarg =~ /^\d+$/) {
                    $col_cnt = $sarg;
                    prt("Strip $col_cnt from left of line.\n") if (VERB1());
                } else {
                    pgm_exit(1,"ERROR: Only an integer value can follow -s!\n");
                }
            } else {
                pgm_exit(3,"ERROR: Invalid argument [$arg]! Try -?\n");
            }
        } else {
            $in_file = $arg;
            prt("Set input to [$in_file]\n") if (VERB1());
        }
        shift @av;
    }

    if (length($in_file) ==  0) {
        pgm_exit(3,"ERROR: No input files found in command!\n");
    }
    if (! -f $in_file) {
        pgm_exit(1,"ERROR: Unable to find in file [$in_file]! Check name, location...\n");
    }
}

sub give_help {
    prt("$pgmname: version $VERS\n");
    prt("Usage: $pgmname [options] in-file\n");
    prt("Options:\n");
    prt(" --help  (-h or -?) = This help, and exit 2.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. def=$verbosity\n");
    prt(" --delete      (-d) = Delete lines beginning with a '<' char. (def=$del_lines)\n");
    prt(" --out <file>  (-o) = Write output to this file.\n");
    prt(" --paras[-]    (-p) = Set or clear keep paragraphs. (def=$keep_paras)\n");
    prt(" --strip <col> (-s) = Strip column count from left of lines.\n");
}

# eof
