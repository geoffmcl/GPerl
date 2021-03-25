#!/usr/bin/perl -w
# NAME: chkdirind.pl
# AIM: Given an input .dirindex path, walk the subdirectories indicated
# 2021/02/14 - Move to D:\GPerl dir
# 2021/01/29 - initial cut
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
use Digest::SHA qw(sha1_hex); # my $var = 123; my $sha1_hash = sha1_hex($var);
use File::stat; # get file info if ($sb = stat($fil)){$dt = $sb->mtime; $sz = $sb->size;}
use File::Spec; # File::Spec->rel2abs($rel);
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
my $VERS = "0.0.10 2021-01-29";
my $load_log = 0;
my $in_file = '';
my $verbosity = 0;
my $out_file = '';
my $out_dir_bat = $temp_dir.$PATH_SEP."tempdirs2.bat";
my $out_dirinds = $temp_dir.$PATH_SEP."tempdirind.txt";
my $out_updates = $temp_dir.$PATH_SEP."tempupdate.txt";
my $out_downloads = $temp_dir.$PATH_SEP."tempdown.txt";

my $use_size_cmp = 1;
my $skip_new_dirs = 1;

# D:\FG\S>type .dirindex
# version:1
# path:
# time:20210104-08:33Z
my %dir_ind = (
    'version' => 1,
    'path' => 2,
    'time' => 3
    );

# ### DEBUG ###
my $debug_on = 0;
# my $def_file = 'H:\FG\S-KATL\.dirindex';
# my $def_file = 'H:\FG\osm2city\.dirindex';
my $def_file = 'D:\FG\S\.dirindex';
# my $def_file = 'D:\DTEMP\FG\St\.dirindex';
# my $def_file = 'D:\DTEMP\FG\S-CYYR\.dirindex';
# my $def_file = 'D:\DTEMP\FG\S-KATL\.dirindex';
# my $def_file = 'G:\S\.dirindex';
# my $def_file = 'H:\FG\Scenery-2\.dirindex';

### program variables
my @warnings = ();
my $cwd = cwd();
my @newdirs = ();
my @upddirind = ();
my @updloads = ();
my @downloads = ();

my $tot_reload = 0; # count of RE-DOWNLOADS
my $tot_updates = 0; # bytes to RELOAD

my $tot_down = 0; # bytes to DOWNLOAD - in @downloads

my $tot_files = 0;  # total files examined... 'f', 't'
# $tot_done += $size; $tot_found++;
my $tot_done = 0; # bytes found
my $tot_found = 0; # count found

# if ($skip_new_dirs)
my $tot_dirs_skipped = 0;


my ($min_dt,$max_dt);
sub VERB1() { return $verbosity >= 1; }
sub VERB2() { return $verbosity >= 2; }
sub VERB5() { return $verbosity >= 5; }
sub VERB9() { return $verbosity >= 9; }

# handle Ctrl+C exit - write summaries
$SIG{INT} = \&tsktsk;

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

sub load_local_dirind($$) { # $dirind);
    my ($inf,$rh) = @_;
    my $txt = '';   # start with nothing
    if (! open INF, "<$inf") {
        prtw("WARNING: Unable to open file [$inf]\n"); 
        return $txt;
    }
    binmode INF;
    my @lines = <INF>;
    close INF;
    # my $lncnt = scalar @lines;
    $txt = join("",@lines);
    my $sha1_hash = sha1_hex($txt);
    ${$rh} = $sha1_hash;
    return $txt;
}
sub process_nxt_dir($$$);

sub process_nxt_dir($$$) {
    my ($inf,$bhash,$lev) = @_;
    my ($sb,$dt,$sz);
    if (!($sb = stat($inf))) {
        prt("WARNING: Unable to 'stat' file '$inf'!\n");
        return 0;
    }
    $dt = $sb->mtime;
    $sz = $sb->size;
    $min_dt = $dt if ($dt < $min_dt);
    $max_dt = $dt if ($dt > $max_dt);
    my $rhash = '';
    my $txt = load_local_dirind($inf,\$rhash);
    my $len = length($txt);
    if ($len == 0) {
        prtw("WARNING: In file '$inf' has no length!\n");
        return 0;
    }
    if ($bhash eq $rhash) {
        # good file - NO CHANGE
    } else {
        push(@upddirind,$inf);
    }

    my @lines = split("\n",$txt);
    $len = scalar @lines;
    prt("Processing $len lines, from $inf\n") if (VERB5());
    my ($nxt,$ndfil,$ra);
    my ($name,$dir) = fileparse($inf);
    my ($i,$line,@arr,$alen,$type,$item,$hash,$size);
    my $skip = 0;
    my @dirs = ();
    for ($i = 0; $i < $len; $i++) {
        $line = $lines[$i];
        chomp $line;
        @arr = split(":",$line);
        $alen = scalar @arr;
        $type = $arr[0];
        if (defined $dir_ind{$type}) {
            $skip++;
        } else {
            last;   # should be 'd', 't', 'f', type
        }
    }
    for ($i = $skip; $i < $len; $i++) {
        $line = $lines[$i];
        chomp $line;
        @arr = split(":",$line);
        $alen = scalar @arr;
        if ($alen >= 3) {
            $type = $arr[0];
            $item = $arr[1];
            $hash = $arr[2];
            # lots of noise
            prt(" t=$type i=$item, h=$hash\n") if (VERB9());
            $nxt = $dir.$item; # path plus subdir or filename
            $ndfil = $nxt.$PATH_SEP.'.dirindex';
            if ($type eq 'd') {
                if (-d $nxt) {
                    push(@dirs,[$ndfil,$hash]);
                } else {
                    if ($skip_new_dirs) {
                        $tot_dirs_skipped++;
                    } else {
                        prt("Need to create '$nxt'...\n") if (VERB5());
                        push(@newdirs,$nxt);
                    }
                }
            } elsif (($type eq 'f') || ($type eq 't')) {
                if ($alen >= 4) {
                    $size = $arr[3];
                    if (-f $nxt) {
                        $tot_done += $size;
                        $tot_found++;
                        # TODO: need SHA1 of this file, to compare to the hash in .dirindex file...
                        # but, as a fast compare, just compare SIZE
                        if ($use_size_cmp) {
                            my ($sb,$dt,$sz);
                            if ($sb = stat($nxt)) {
                                $dt = $sb->mtime;
                                $sz = $sb->size;
                                if ($sz == $size) {
                                    # no update needed...
                                } else {
                                    #push(@updloads, [$nxtdir,$nxt,$size]);
                                    push(@updloads, $nxt);
                                    $tot_updates += $size;
                                    $tot_reload++;
                                }
                            }
#                        } else {
#                            # this is GB of data - heavy slow load
#                            my $lhash = '';
#                            my $txt2 = load_local_dirind($nxt,\$lhash);
#                            # need to compare HASH
#                            if ($hash eq $lhash) {
#                                # file looks good to stay
#                            } else {
#                                push(@updloads, [$nxtdir,$nxt,$size]);
#                                $tot_updates += $size;
#                                $tot_reload++;
#                            }
                        }
                    } else {
                        # download ..e like w047s24.txz
                        # push(@downloads, [$nxtdir,$nxt,$size]);
                        push(@downloads, $nxt);
                        $tot_down += $size;
                    }
                } else {
                    prtw("WARNING: type '$type' array not GT 4 = $alen!- FIX ME1\n");
                }
                $tot_files++;   # total files examined...
            } else {
                prtw("WARNING: type '$type' not handled - FIX ME1\n");
            }
        } else {
            prtw("Warning: line '$line' NOT processed - FIX ME!\n");
        }
    }
    foreach $ra (@dirs) {
        $ndfil = ${$ra}[0];
        $hash  = ${$ra}[1];
        process_nxt_dir($ndfil,$hash,$lev+1);
    }

    return 1;
}

sub process_in_file($) {
    my ($inf) = @_;
    my $rhash = '';
    my ($sb,$dt,$sz);
    if (!($sb = stat($inf))) {
        prt("WARNING: Unable to 'stat' file '$inf'!\n");
        return;
    }
    $dt = $sb->mtime;
    $sz = $sb->size;
    $min_dt = $max_dt = $dt;
    my $txt = load_local_dirind($inf,\$rhash);
    my $len = length($txt);
    prt("SHA1:$len: $rhash\n");
    prt("Content:\n$txt");
    my @lines = split("\n",$txt);
    $len = scalar @lines;
    prt("Processing $len lines...\n");
    my ($i,$line,$type,$alen,@arr,$item,$hash,$size);
    my ($nxt,$ndfil,$ra);
    my ($name,$dir) = fileparse($inf);
    my $skip = 0;
    my @dirs = ();
    for ($i = 0; $i < $len; $i++) {
        $line = $lines[$i];
        chomp $line;
        @arr = split(":",$line);
        $alen = scalar @arr;
        $type = $arr[0];
        if (defined $dir_ind{$type}) {
            $skip++;
        } else {
            last;   # should be 'd', 't', 'f', type
        }
    }
    for ($i = $skip; $i < $len; $i++) {
        $line = $lines[$i];
        chomp $line;
        @arr = split(":",$line);
        $alen = scalar @arr;
        if ($alen >= 3) {
            $type = $arr[0];
            $item = $arr[1];
            $hash = $arr[2];
            prt(" t=$type i=$item, h=$hash\n") if (VERB9());
            $nxt = $dir.$item; # path plus subdir
            # $nxtdir = "$base/$item";
            $ndfil = $nxt.$PATH_SEP.'.dirindex';
            if ($type eq 'd') {
                if (-d $nxt) {
                    push(@dirs,[$ndfil,$hash]);
                } else {
                    if ($skip_new_dirs) {
                        $tot_dirs_skipped++;
                    } else {
                        prt("Need to create '$nxt'...\n");
                        push(@newdirs,$nxt);
                    }
                }
            } elsif (($type eq 'f') || ($type eq 't')) {
                if ($alen >= 4) {
                    $size = $arr[3];
                    prt("File($type): $item, size $size\n");
                } else {
                    prt("File($type): $item, but no size! $alen < 4!\n");
                }
                $tot_files++;   # total files examined...
            } else {
                prtw("EARNING: Uknonwn type $type! *** CHECK ME ***\n");
            }
        } else {
            prtw("Warning: line '$line' not processed! FIXN ME\n");
        }
    }
    $alen = scalar @dirs;
    prt("Begin processing $alen 'd' dir entries...\n");
    $len = 0;
    foreach $ra (@dirs) {
        $ndfil = ${$ra}[0];
        $hash  = ${$ra}[1];
        $len++;
        prt("$len:$alen: Processing next '$ndfil' file... todate $tot_files...\n");
        process_nxt_dir($ndfil,$hash,1);
    }
}

sub process_downloads() {
    # MISSING DIRS, FILES or UPDATE FILES - need to DOWNLOAD
    my ($out,$bat,$fil,$ccnt);
    my ($name,$dir) = fileparse($in_file);

    prt("\nProcessed $in_file, and found\n");
    prt(" count $tot_reload # RE-DOWNLOADS, $tot_updates # bytes to RELOAD\n");
    prt(" count $tot_files # files examined, $tot_down # bytes to DOWNLOAD\n");
    prt(" count $tot_found # found, $tot_done # bytes...\n");

    my $dcnt   = scalar @newdirs;
    $ccnt = sprintf("%6u",$dcnt);
    # directories to be created
    # my $dcnt = scalar @newdirs;
    $out = $out_dir_bat;
    prt("Need to create   $ccnt NEW dirs... Skip($skip_new_dirs) $tot_dirs_skipped... ");
    # prt( join("\n",@newdirs)."\n" ) 
    $bat = "\@echo create $dcnt dirs?\n";
    $bat .= "\@pause\n";
    foreach $fil (@newdirs) {
        $bat .= "md $fil\n";
    }
    $bat .= "\@echo done $dcnt dirs...\n";
    rename_2_old_bak($out);
    write2file($bat,$out);
    prt("List written to $out.\n");

    $out = $out_dirinds;
    my $dicnt = scalar @upddirind;
    $ccnt = sprintf("%6u",$dicnt);
    $bat = "Need to update   $ccnt '.dirindex' files... ";
    prt($bat);
    $bat .= "\nBase in_file: $in_file";
    $bat .= "\n".join("\n",@upddirind)."\n";
    rename_2_old_bak($out);
    write2file($bat,$out);
    prt("List written to $out.\n");

    $out = $out_updates;
    my $ucnt = scalar @updloads;
    $ccnt = sprintf("%6u",$ucnt);
    $bat = "Need to update   $ccnt files... ";
    prt($bat);
    $bat .= "\nBase in_file: $in_file";
    $bat .= "\n".join("\n",@updloads)."\n";
    rename_2_old_bak($out);
    write2file($bat,$out);
    prt("List written to $out.\n");

    $out = $out_downloads;
    my $dwcnt = scalar @downloads;
    $ccnt = sprintf("%6u",$dwcnt);
    $bat = "Need to download $ccnt files... ";
    prt($bat);
    $bat .= "\nBase in_file: $in_file";
    $bat .= "\n".join("\n",@downloads)."\n";
    rename_2_old_bak($out);
    write2file($bat,$out);
    prt("List written to $out.\n");

    my $tcnt = $dcnt + $dicnt + $ucnt + $dwcnt;
    my $fcnt = $dicnt + $ucnt + $dwcnt;
    if ($tcnt == 0) {
        prt("\n*** Dir '$dir' is fully UP-TO-DATE ***\n");
    } else {
        if ($dcnt) {
            prt("need to create $dcnt dirs in '$dir'\n");
        }
        if ($fcnt) {
            prt("Need $fcnt downloads to dir '$dir'\n");
        }
    }
    my $dt = 'DT min '.lu_get_YYYYMMDD_hhmmss($min_dt).', max '.lu_get_YYYYMMDD_hhmmss($max_dt);
    prt("\nDone Base in_file: $in_file, $dt\n");

}


#########################################
### MAIN ###
parse_args(@ARGV);
$max_dt = 0;
$min_dt = time();
process_in_file($in_file);
process_downloads();
pgm_exit(0,"");
########################################

sub tsktsk {
    $SIG{INT} = \&tsktsk;           # See ``Writing A Signal Handler''
    process_downloads();
    #warn "\aThe long habit of living indisposeth us for dying.\n";
    pgm_exit(1,"Ctrl+C: exit\n");
}


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
            } elsif ($sarg =~ /^d/) {
                $oo = 1;
                $oo = 0 if ($sarg =~ /-$/);
                $skip_new_dirs = $oo;
                prt("Skip new sub-directories $skip_new_dirs\n") if ($verb);
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
            $in_file = File::Spec->rel2abs($arg);
            if (-d $in_file) {
                if ( !($in_file =~ /[\\\/]$/) ) {
                    $in_file .= $PATH_SEP;
                }
                $in_file .= ".dirindex";
            }
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
    prt(" --dirs[-]     (-d) = Skip new sub-directries. (def=$skip_new_dirs)\n");
    prt(" --load        (-l) = Load LOG at end. ($outfile)\n");
    prt(" --out <file>  (-o) = Write output to this file.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. def=$verbosity\n");
    prt("\n");
    prt(" Given a valid terrasync directory, walk the '.dirindex chain.\n");
}

# eof - chkdirind.pl
