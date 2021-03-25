#!/usr/bin/perl -w
# NAME: sha1sump.pl
# AIM: Output 40 (hex) char SHA1, given an in file to process... as per sha1sum GNU tool...
# 2021/02/14 - Moved to D:\GPerl dir
# 2021/02/10 - Add sum to test with... -c <SHA1>
# 2021/01/22 - Initial cut
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
# and for this issue
use Digest::SHA qw(sha1_hex);
# digest in hexadecimal form. The length of the returned string will be 40
# and it will only contain characters from this set: '0'..'9' and 'a'..'f'.
use Cwd;
my $os = $^O;
my ($pgmname,$perl_dir) = fileparse($0);
my $curr_dir = cwd();
if ($perl_dir =~ /^\.[\\\/]$/) {
    $perl_dir = $curr_dir;
}

# user variables
my $VERS = "0.0.10 2020-05-15";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = '';
my $sha1sum = '';

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

sub prt($) {
    print shift;
}

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
    #close_log($outfile,$load_log);
    exit($val);
}


sub prtw($) {
   my ($tx) = shift;
   $tx =~ s/\n$//;
   prt("$tx\n");
   push(@warnings,$tx);
}

sub write2file {
	my ($txt,$fil) = @_;
	open WOF, ">$fil" or die("ERROR: Unable to open $fil! $!\n");
	print WOF $txt;
	close WOF;
}

#my $var = 123;
#my $sha1_hash = sha1_hex($var);
# add/output test...
# print $sha1_hash;

sub process_in_file($) {
    my ($inf) = @_;
    if (! open INF, "<$inf") {
        prt("ERROR: Unable to open file [$inf]\n"); 
        exit(1);
    }
    binmode INF;
    my @lines = <INF>;
    close INF;
    my $lncnt = scalar @lines;
    ### prt("Processing $lncnt lines, from [$inf]...\n");
    my ($line,$inc,$lnn);
    my ($n,$d) = fileparse($inf);
    $lnn = 0;
    $line = join("",@lines);
    my $sum = sha1_hex($line);
    my $msg = '';
    if (length($sha1sum)) {
        if ($sha1sum eq $sum) {
            $msg = '= check same';
        } else {
            $msg = '= NOT same as check sum given';
        }
    }
    prt("$sum *$n $msg\n");
    if (length($out_file)) {
        write2file("$sum *$n $msg\n",$out_file);
        prt("Output written to '$out_file'\n");
    }
}

#if (@ARGV) {
#    # prt("\n");
#    my $file = pop @ARGV;
#    process_in_file($file);
#    exit(0);
#} else {
#    prt("Give valid file name. Will generate SHA1 sum output\n");
#}

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
            } elsif ($sarg =~ /^c/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $sha1sum = $sarg;
                prt("Compare results to [$sha1sum].\n") if ($verb);
#            } elsif ($sarg =~ /^l/) {
#                if ($sarg =~ /^ll/) {
#                    $load_log = 2;
#                } else {
#                    $load_log = 1;
#                }
#                prt("Set to load log at end. ($load_log)\n") if ($verb);
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
        pgm_exit(1,"ERROR: No input files found in command!\n");
    }
    if (! -f $in_file) {
        pgm_exit(1,"ERROR: Unable to find in file [$in_file]! Check name, location...\n");
    }
}

sub give_help {
    prt("$pgmname: version $VERS\n");
    prt("Usage: $pgmname [options] in-file\n");
    prt("Options:\n");
    prt(" --help  (-h or -?) = This help, and exit 0.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. def=$verbosity\n");
    #prt(" --load        (-l) = Load LOG at end. ($outfile)\n");
    prt(" --out <file>  (-o) = Write output to this file.\n");
    prt(" --check <SHA1> (-c) = Compare with given SHA1 sum, and report\n");
}


# eof - sha1sump.pl
