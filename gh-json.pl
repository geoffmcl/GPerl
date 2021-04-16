#!/usr/bin/perl -w
# NAME: gh-json.pl
# AIM: Read a 'issues.json' file, and write/append to log. 
# Coded to deal with -
# issues   - GET /repos/{owner}/{repo}/issues
# comments - GET /repos/{owner}/{repo}/issues/comments
# 2021/04/15 - Initial cut...
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
use JSON;   # use JASON::XS;
use Data::Dumper;
use DateTime;
use HTTP::Date; # for 'str2time($date)'
use Cwd;
my $os = $^O;
my ($pgmname,$perl_dir) = fileparse($0);
my $curr_dir = cwd();
if ($perl_dir =~ /\.[\\\/]$/) {
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
my $VERS = "0.1.0 2021-04-15";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = $temp_dir.$PATH_SEP."tempissues.txt";

# ### DEBUG ###
my $debug_on = 1;
# my $def_file = 'C:\Users\ubunt\Documents\Tidy\github\issues-10.json';
my $def_file = 'C:\Users\ubunt\Documents\Tidy\github\comments-10.json';

### program variables
my @warnings = ();
my $cwd = cwd();
my $isep = '*******************************************************';
my $csep = '=======================================================';
my @ns_headers = (
    'Accept' => 'application/vnd.github.v3+json'
    );

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

sub mycmp_ascend_n {
   return -1 if ($a < $b);
   return  1 if ($a > $b);
   return 0;
}


sub is_comment($) {
    my $rh = shift;
    return 1 if ((defined ${$rh}{'id'}) && (defined ${$rh}{'issue_url'}) && (defined ${$rh}{'created_at'}) && (defined ${$rh}{'body'}) && (defined ${$rh}{'user'}{'login'}));
    return 0;
}

sub is_issue($) {
    my $rh = shift;
    return 1 if ((defined ${$rh}{'number'}) && (defined ${$rh}{'title'}) && (defined ${$rh}{'state'}) && (defined ${$rh}{'created_at'}) && (defined ${$rh}{'body'}) && (defined ${$rh}{'user'}{'login'}));
    return 0;
}

my %issues = ();


sub process_in_file($) {
    my ($inf) = @_;
    if (! open INF, "<$inf") {
        pgm_exit(1,"ERROR: Unable to open file [$inf]\n"); 
    }
    my @lines = <INF>;
    close INF;
    my $lncnt = scalar @lines;
    prt("Processing $lncnt lines, from [$inf]...\n");
    my ($line,$cnt,$inc,$lnn,$rh,$is,$body,$date,$user,$epoc,$ccnt);
    my ($cis,$title,$state,$cdat,$rh2,$id);
    my $comments = 0;
    $lnn = 0;
    $cnt = 0;
    $line = join("",@lines);
    my $perl = decode_json($line);
    #prt(Dumper($perl));
    #$load_log = 1;
    #pgm_exit(1,"Tempexit\n");
    foreach $rh (@{$perl}) {
        $lnn++;
        # if ((defined ${$rh}{'issue_url'}) && (defined ${$rh}{'created_at'}) && (defined ${$rh}{'body'}) && (defined ${$rh}{'user'}{'login'})) {
        if (is_comment($rh)) {
            $cnt++;
            $ccnt = sprintf("%3u",$cnt);
            $inc = ${$rh}{'issue_url'};
            $cis = '???';
            $is = 0;
            if ($inc =~ /\/(\d+)$/) {
                $is = $1;
                $cis = sprintf("%3u",$is);
            } else {
                prtw("Warning: Skipping enty $cnt! No issue detected in '$inc'\n");
                next;
            }
            $comments++;
            $date = ${$rh}{'created_at'};
            $epoc = str2time($date);
            $body = ${$rh}{'body'};
            $user = ${$rh}{'user'}{'login'};
            $id   = ${$rh}{'id'};
            $cdat = lu_get_YYYYMMDD_hhmmss_UTC($epoc);
            #prt("$cnt:$is: $inc\n");
            #prt("$cnt:$is:$date:$user\n");
            #prt("$ccnt:$cis:$epoc:$user\n");
            prt("$ccnt:$cis:$id:$cdat:$user\n");
        }
        elsif (is_issue($rh)) {
            $cnt++;
            $ccnt = sprintf("%3u",$cnt);
            $is = ${$rh}{'number'};
            $title = ${$rh}{'title'};
            $state = ${$rh}{'state'};
            $date = ${$rh}{'created_at'};
            $body = ${$rh}{'body'};
            $user = ${$rh}{'user'}{'login'};

            $epoc = str2time($date);
            $cdat = lu_get_YYYYMMDD_hhmmss_UTC($epoc);
            $cis = sprintf("%3u",$is);
            prt("$ccnt:$cis:$cdat:$user:$state\n");
            if (defined $issues{$is}) {
                prtw("Warning: Issue $is already exists...\n");
            } else {
                $issues{$is} = {};
            }
            $rh2 = $issues{$is};
            ${$rh2}{'title'} = $title;
            ${$rh2}{'state'} = $state;
            ${$rh2}{'user'}  = $user;
            ${$rh2}{'date'}  = $cdat;
            ${$rh2}{'body'}  = $body;
            ${$rh2}{'epoc'}  = $epoc;
        }
        else {
            pgm_exit(1, "$lnn: NOT 'comment', NOT 'issue'! What is this...\n");
        }
    }

    prt("Got $lnn ref hashes... $cnt 'number|issue_url'...\n");
    my @arr = sort mycmp_ascend_n keys(%issues);
    $cnt = scalar @arr;
    if ($cnt == 0) {
        prtw("Warning: No ;keys' found!\n");
        return;
    }
    prt("Got keys ".join(" ",@arr)."\n");
    my @out = ();
    foreach $is (@arr) {
        $rh2 = $issues{$is};
        push(@out,$isep);
        $title = ${$rh2}{'title'};
        $state = ${$rh2}{'state'};
        $user  = ${$rh2}{'user'};
        $date  = ${$rh2}{'date'};
        $body  = ${$rh2}{'body'};
        push(@out,"$title #$is [$state]");
        push(@out,"$user opened on $date");
        push(@out,"$body");
        push(@out,$csep);
        push(@out,"end #$is [$state]");
    }
    $line = join("\n",@out)."\n";
    rename_2_old_bak($out_file);
    write2file($line,$out_file);
    prt("Results written to '$out_file'\n");
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
    prt(" --load        (-l) = Load LOG at end. ($outfile)\n");
    prt(" --out <file>  (-o) = Write output to this file.\n");
}

# eof - template.pl
