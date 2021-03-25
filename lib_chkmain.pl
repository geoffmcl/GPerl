#!/perl -w
# NAME: lib_chkmain.pl - library
# AIM: Read a C/C++ file and check for main()
# 18/03/2014 - Maybe make note if main() is preceeded by an #ifdef TEST
# 2010-07-07 - Some tidying when used in makesrcs.pl
# 20090911 - version 2 with output indicator
# 20090828 - check for quotes "...", and only WARN if could have been in quotes
# 21/11/2007 - geoff mclane - http://geoffair.net/mperl
# Services:
# chkmain($file,$refarray)

# check_for_main - check for main()

sub chkmain_in_linearray($$$) {
	my ($fil,$rarr,$rla) = @_;
	my $fndm = 0;
	my ($ccnt, $pline, $j, $k, $k2, $ch, $pch, $cline, $tline, $ll, $incomm, $tag, $fnd1, $comment);
	my ($lncomm, $wascomm, $iftxt, $msg, $bch, $main, $ml, $mi, $cond);
	my @ifopen = ();
	my @conditional_stack = ();
	$ccnt = scalar @{$rla};
    $pline = '';
    $incomm = 0;
    $tag = '';
    $comment = '';
    $lncomm = 0;
    $iftxt = '';
    $msg = '';
    ###prt( "\nProcessing $ccnt lines of $fil ...\n" );
    for ($k = 0; $k < $ccnt; $k++) {
        $cline = ${$rla}[$k];
        $k2 = $k + 1;
        chomp $cline;
        $tline = trim_all($cline);
        $ll = length($tline);
        $tag = '';
        $fnd1 = 0;
        if ( !$incomm) {
            if ( $tline =~ /^\s*#\s*include\s+/ ) {
                next;	# skip '#include <main/main.h>' like INCLUDE lines
            } elsif ($tline =~ /^\s*#\s*if(.*)/ ) {
                $iftxt = $1;
                if ($iftxt =~ /^def\s+(.*)/ ) {
                    $msg = "Got ifdef [$1] ... TRUE";
                    push (@conditional_stack, "\@" . $1 . "_TRUE\@");
                } elsif ($iftxt =~ /^\s+(.*)/ ) {
                    $msg = "Got if [$1] ... TRUE";
                    push (@conditional_stack, "\@" . $1 . "_TRUE\@");
                } else {
                    $msg = "CHECK ME: What is this? [$tline]\n";
                }
                ###prt( "$msg\n" );
                next;
            } elsif ($tline =~ /^\s*#\s*else(.*)/ ) {
                $msg = "Got else ...";
                if (! @conditional_stack) {
                    $msg .= "ERROR: else without if";
                } elsif ($conditional_stack[$#conditional_stack] =~ /_FALSE\@$/) {
                    $msg .= "ERROR: else after else";
                } else {
                    $msg .= "tog ".$conditional_stack[$#conditional_stack];
                    $conditional_stack[$#conditional_stack] =~ s/_TRUE\@$/_FALSE\@/;
                    $msg .= " to ".$conditional_stack[$#conditional_stack];
                }
                ###prt( "$msg\n" );
                next;
            } elsif ($tline =~ /^\s*#\s*endif(.*)/ ) {
                $msg = "Got endif ...";
                if (! @conditional_stack) {
                    $msg .= "ERROR: endif without if";
                } else {
                    $msg = "pop ". pop @conditional_stack;
                }
                ###prt( "$msg\n" );
                next;
            }
        }
        $pline = '';
        $comment .= "\n" if length($comment);
        $lncomm = 0;
        $pch = '';
        $bch = ' ';
        for ($j = 0; $j < $ll; $j++) {
            $ch = substr($tline,$j,1);
            if ($incomm) {
                # only looking for CLOSE comment */
                $comment .= $ch;
                if (($ch eq '/') && ($pch eq '*')) {
                    $incomm = 0;
                    $tline = substr($tline,$j);
                    $ll = length($tline);
                    $j = 0;
                    $ch = '';
                    $bch = ' ';
                }
                $pch = $ch;
                next;
            } else {
                if ($ch eq '"') {
                    # start of QUOTE
                    $j++;	# to next char
                    $pch = $ch;
                    for ( ; $j < $ll; $j++) {
                        $ch = substr($tline,$j,1);
                        if (($ch eq '"')&&($pch ne "\\")) {
                            last;	# out of here
                        }
                        $pch = $ch;
                    }
                } elsif (($ch eq '*') && ($pch eq '/')) {
                    # comment start /* until */
                    $incomm = 1;
                    $wascomm = 1;
                    $comment = $pch.$ch;
                } elsif (($ch eq '/') && ($pch eq '/')) {
                    $j = $ll;	# skip rest of line
                    $lncomm = 1;
                } else {
                    if ($ch =~ /\w+/) { #if ($ch =~ /[main]/) {
                        $tag .= $ch;
                    } else {
                        # NOT alphanumeric
                        if (($tag eq 'main')&&($bch eq ' ')&&(($ch =~ /\s/)||($ch eq '('))) {
                            $mi = $j + 1;
                            for ($mi = $j + 1; $mi < $ll; $mi++) {
                                if (substr($tline,$mi,1) eq ')') {
                                    $mi++;
                                    last;
                                }
                            }
                            $main = substr($tline,0,$mi);
                            $main = substr($main,1) if ($main =~ /^\//);
                            #prt( "Found a main ... [$main]\n" );
                            $msg = '';
                            if (@conditional_stack) {
                                foreach $cond (@conditional_stack) {
                                    $msg .= " && " if (length($msg));
                                    $msg .= $cond;
                                }
                            }
                            $fndm++;
                            push(@{$rarr}, [$fndm, $main, $msg]);
                            ###prt( "$fndm: Found main [$main] cond [$msg]\n" );
                        }
                        $tag = '';
                        $bch = $ch;
                    }
                }
            }
            $pch = $ch;
            $pline .= $ch;
        }
        if (($pline =~ /\s+main(\s|\()+/)||
            ($pline =~ /^main(\s|\()+/)){
            $fnd1 = 1;
        }
        ###prt( "line $k2:[$tline]$ll ($incomm:$lncomm) $fnd1 $fndm\n" );
        if ($fnd1 && !$fndm && !$lncomm && !$incomm && !$wascomm) {
            prt( "\nERROR: MISSED main! WHY??? [$fil]\n" );
            prt( "CHECK ME [$pline]\n" );
        }
        $wascomm = $incomm;
    }
	return $fndm;

}


sub chkmain($$) {
	my ($fil,$rarr) = @_;
	if (open INF, "<$fil") {
		my @clines = <INF>;
		close INF;
        return chkmain_in_linearray($fil,$rarr,\@clines);
	} else {
		prt( "WARNING: Unable to open [$fil] file ... $! ...\n" );
	}
	return 0;
}

1;

# eof - lib_chkmain.pl

