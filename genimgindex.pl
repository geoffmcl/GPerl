#!perl -w
# ===========================================================================================
# NAME: genimgindex.pl (see earlier simpe imgindex.pl)
# AIM: Given a BASE folder, seek all IMAGE files, and build
# an 'index' table of images, as HTML ...
# Commands: in-folder [-out out-file]
# 2021/03/27 - Move to GPerl, add -x *.bmp globbing...
# 2018-08-25 - Included BMP image files...
# 2018-06-01 - Generate HTML5 template
# 20/04/2016 - Add -a to add text under image
# 06/03/2014 - Add -t <num> to set target width, and -b bare table, suitable for printing
#
# *********************************************************************************
# BUT, is really QUITE SPECIALIZED to generate my 'fg' folder 'Image Index' update,
# in that the @excluded_imgs, and %excluded_html are mainly for that folder,
# and the 'links' are to 'index.htm', #top or #end ... and other things, like
# the CSS include, and javascript include ...
# *********************************************************************************
# 22/12/2011 - Do not do a 'table' is just 1 image
# 08/05/2011 - Fix -out file, and fix image paths
# 08/11/2010 - checkout on FSWeekend pics
# 08/12/2008 - externalise im_get_image_size(file_name), adding imgsize.pl requires
# 19/11/2008 - modified to produce say fg/images index
# 27/09/2007 - some features
# $add_dir and $add_siz to ADD a directory and size columns
# and using ImageMagick identify (if installed) to get image dimensions
# 15/03/2008 - add mutiple columns, especially if image constrained to small thumbnail size
# ===========================================================================================
use strict;
use warnings;
use File::Basename;  # split path ($name,$dir,$ext) = fileparse($file [, qr/\.[^.]*/] )
use File::Spec; # File::Spec->rel2abs($rel); # we are IN the SLN directory, get ABSOLUTE from RELATIVE
use File::stat;
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
require 'imgsize.pl' or die "Unable to load imgsize.pl ...\n";
# log file stuff
my ($LF);
my $outfile = $temp_dir.$PATH_SEP."temp.$pgmname.txt";
open_log($outfile);
###prt( "$0 ... Hello, World ...\n" );

# user variables
my $VERS = "0.0.8 2021-03-27";
###my $VERS = "0.0.7 2020-05-21";
### my $VERS = "0.0.6 2018-06-01";
### my $VERS = "0.0.5 2016-04-20";
my $perl_base = $temp_dir;
my $def_in_folder = 'C:\HOMEPAGE\GA\FSWeekend\small'; 
## my $def_in = 'C:\Documents and Settings\Geoff McLane\My Documents\My Pictures\Pan\20101108'; 
my $def_out = $perl_base; 
my $out_file = $def_out .'\tempout.htm';
my $got_user_out = 0;
my $got_user_folder = 0;
my $copy_bat = $perl_base . '\tempcopy.bat';
if (-d "C:\\MDOS") {
    $copy_bat = "C:\\MDOS\\tempcopy.bat";
}
my $list_file = $def_out .'\templist.txt';
my @excluded_imgs = qw( new.gif closeXp.jpg closeXb.jpg valid-html401.gif spacer.gif
checked_by_tidy.gif construc.gif );

my %excluded_html = (
    'tempout.htm' => 1,
    'fgimgvw.htm' => 2,
    'fgimgvw2.htm' => 3
);

my $def_alt = '';

my $my_cwdir = getcwd();

# FEATURES
my $link2file = 0;  # quite specialized - find the first file with the image
# has to also have $date_sort, AND the $def_out MUST be the folder to search
my $date_sort = 0;  # sort images to DATE order
my $row_jump = 5;   # add a ROW jumper - TO BE DONE
my $one_cell = 1;	# put ALL information in one cell
my $add_name = 1;	# add FILENAME (column)
my $add_imsz = 1;   # add IMAGE SIZE - full
my $add_file_name = 0;  # add the file name in the cell
my $add_valid_stg = 0;  # Add tidy and valid string
my $add_old_link = 0;   # add link to OLD index
my $drop_thumb = 1;     # remove '-t' from name....
my $add_name_sttr = 1;  # add a jump name attribute to each image
my $add_dir = 0;	# add DIRECTORY (column)
my $add_siz = 0;	# add FILE SIZE (column)
my $add_isz = 0;	# add IMAGE SIZES - full and constrained sizes (column)
my $add_script = 0;  # add JAVA SCRIPT
# ### TARGET WIDTH/HEIGHT maximum ###
my $set_max = 1;	# constrain image size to $targwid img_max
my $targwid = 150;	# maximum display size
my $usr_targ_wid = 0;
#my $targwid = 300;	# maximum display size
#my $targwid = 200;	# maximum display size
#my $targwid = 800;	# maximum display size
my $add_img_txt = 0;    # add alt text under image

# ### ADD CLICK LINK ###
my $add_lnk = 1;	# add LINK to image
my $add_alt_link = 0; # add link to another folder
my $alt_src_link = '..';
# ######################

# NUMBER OF COLUMNS - This is really only if $one_cell used
##my $add_cols = 1;	# number of COLUMNS in output
##my $add_cols = 3;	# number of COLUMNS in output
my $add_cols = 4;	# number of COLUMNS in output
##my $add_cols = 5;	# number of COLUMNS in output
#################################################

my $add_blank = 1;	# open LINK in NEW PAGE - $add_link must be ON above
my $recursive = 0;	# recursive into sub-folders
my $fix_relat = 0;	# images relative to named output file
my $load_html = 1;	# load written HTML
my $load_log  = 0;   # load the LOG file
my $thumb_dir = '';
my $html_title = "Image Index";
my $order_file = '';
my $target_dir = ''; # write src references relative to here...
my $bare_table = 0;

### program constants
my @imgfiles = qw( .jpg .jpeg .gif .png .bmp );
my @fpfolders = qw( _vti_cnf _vti_cnf _private _derived );
my @xclude_list = ();
my $xclude_cnt = 0;

# debug stuff
my $debug_on = 0;	# use default in folder, so can be RUN without command line

my $dbg2 = 0;	# use full file name, else relative, to SEE images
my $dbg3 = 0;	# show image size stuff
my $tdbg_rel = 0;
my $show_full = 0;  # output the HTML also to the log file

### program variables
my @imglist = ();
my $in_folder = '';
my $full_html = ''; # string that is the HTML file
my $htm_cnt = 0;
my %hash_html = ();
my $img_cnt = 0;
my $got_order = 0;
# FORWARD REFS
sub collect_image_files($);

my $verbosity = 0;

sub VERB1() { return $verbosity >= 1; }
sub VERB2() { return $verbosity >= 2; }
sub VERB5() { return $verbosity >= 5; }
sub VERB9() { return $verbosity >= 9; }

#################################################################
### subs below
sub in_xclude_list($) {
    my $fil = shift;
    my ($tst);
    foreach $tst (@xclude_list) {
        return 1 if ($fil eq $tst);
    }
    return 0;
}

sub get_htm_file_list {
    my ($inf) = shift;  # = $def_out
    my @hlist = ();
    my @done = ();
    my %dn = ();
    my ($fl, $ff, $fnd, $ln, @lns, $fil, $sf, $i, $j, $htm, $i2, $tlns, $lcnt);
    my ($sb);
	if ( opendir( DIR, $inf ) ) {
		my @files = readdir(DIR);
		closedir DIR;
		foreach $fl (@files) {
			next if (($fl eq '.') || ($fl eq '..'));
            next if (defined $excluded_html{$fl});
            next if (in_xclude_list($fl));
            next if ($fl =~ /tempout\.htm/);
            if ($fl =~ /\.htm$/i) {
    			$ff = $inf . "\\" . $fl;
                $sb = stat($ff);
                push(@hlist, [$sb->mtime, $ff, $fl]);
            }
        }
        @hlist = sort mycmp_decend @hlist; 
        $htm_cnt = scalar @hlist;
        # Process the HTML list of files, looking for the IMAGE name
        prt( "Got list of $htm_cnt HTML files ... searching for $img_cnt ... moment ...\n" );
        $tlns = 0;
        for ($i = 0; $i < $htm_cnt; $i++) {
            $ff = $hlist[$i][1];
            $htm = $hlist[$i][2];
            $i2 = $i + 1;
            if (open INF, "<$ff") {
                @lns = <INF>;
                close INF;
                $fnd = 0;
                $lcnt = scalar @lns;
                $tlns += $lcnt;
                prt( "Processing $lcnt lines, from $htm ...\n" );
                foreach $ln (@lns) {
                    for ($j = 0; $j < $img_cnt; $j++) {
                        $fil = $imglist[$j];
                        if (!defined $dn{$fil}) {
                        ###if (!is_in_array($fil,@done)) {
                            $sf = substr($fil, length($in_folder) + 1 );
                            if ($ln =~ /$sf/) {
                                $hash_html{$sf} = $htm;
                                $fnd = 1;
                                push(@done,$fil);
                                $dn{$fil} = 1;
                                prt("Found $sf in $htm ... done ".scalar @done." imgs, in $i2 html, $tlns lines ...\n");
                            }
                        }
                    }
                }
            } else {
                prt( "\nWARNING: FAILED TO OPEN [$ff] FILE!\n" );
            }
        }
        for ($j = 0; $j < $img_cnt; $j++) {
            $fil = $imglist[$j];
            if (!defined $dn{$fil}) {
                prt( "WARNING: $fil NOT FOUND!\n" );
            }
        }
    } else {
        prt( "\nWARNING: FAILED TO OPEN [$inf] DIRECTORY!\n" );
    }
    return @hlist;
}

#  if ($drop_thumb) {
sub drop_thumb_name($) {
    my ($sf) = @_;
	my ($n,$d,$e) = fileparse( $sf, qr/\.[^.]*/ );
    $n =~ s/-t$//;
    return $d.$n.$e;
}

# 22/12/2011 - Change output if just 1, 2, ... files...
sub write_html_file {
    my ($of) = shift;
    my ($i, $fil);
    my ($nm, $dir, $ext);
    my ($i2, $sf, $sb);
    my ($isz, $ratio, $iwd, $iht, $attr, $const);
    my ($imgSx, $imgSy);
    my ($src, $relsrc, $relhrf, $relpath, $outsrc, $imgsrc, $alttxt, $lhtm, $lfile, $linksrc);
    my ($txt,$thsrc,$tmp,$isblank);
	my $wrap = 0;
	my $targ = '';
	my $irel = '';
    my $rcnt = 0;
    my $cwdir = (length($target_dir)) ? $target_dir : $my_cwdir;
    my @img_list = ();
    prt("Writing HTML for $img_cnt images... moment...\n");
    if ($img_cnt < $add_cols) {
        $add_cols = $img_cnt;   # can not have more columns than images
        if (!$usr_targ_wid) {
            # if USER gave no TARGET WIDTH, auto adjust upward, if small image count
            if ($img_cnt == 1) {
                $targwid = 800;
            } elsif ($img_cnt == 2) {
                $targwid = 400;
            } elsif ($img_cnt == 3) {
                $targwid = 300;
            }
        }
    }
    my $addbr = "       <br>\n";

	$targ = "target=\"_blank\"" if ($add_blank);

    $irel = '.';

    if ($fix_relat && (length($in_folder))) {
        $irel = get_relative_path_test( $in_folder, $target_dir );
	    # $irel = get_relative_path_test( $def_in, $def_out );
   	    prt( "Using relative path of [$irel] ...\n" );
    }

    if ($date_sort && ($img_cnt > 1)) {
        prt("Do 'stat' each, get date/time, and sort by date...\n");
        my @files_to_search = ();
        my @arr = ();
        my @arrs = ();
        for ($i = 0; $i < $img_cnt; $i++) {
    		$fil = $imglist[$i];
    		$sb = stat($fil);    # get the file date, time, size, etc
            push(@arr, [$sb->mtime, $fil]);
        }
        @arrs = sort mycmp_decend @arr;
        @imglist = ();  # reset list, and put in DATE order
        for ($i = 0; $i < $img_cnt; $i++) {
            $fil = $arrs[$i][1];
    		$sf = substr($fil, length($in_folder) + 1 );
            push(@imglist, $fil);
        }
        if ($link2file) {
            @files_to_search = get_htm_file_list( $def_out );
        }
    }

    # start HTML text collection
    prt("Start HTML text collection...\n");
	$full_html = get_html_bgn();
    $full_html .= get_html_body_bgn();
    if (!$bare_table) {
        $full_html .= "\n  <p>\n";
        $full_html .= "     <b>";
        $full_html .= get_YYYYMMDD(time());
        $full_html .= "</b>: ";
        $full_html .= "This is a list of $img_cnt images";
        if ($date_sort) {
            $full_html .= ", in approximate date order.";
        }
        $full_html .= "\n";

        if ($add_lnk) {
            $full_html .= "   Click on the image to load the full image";
            $full_html .= " in a new window" if ($add_blank);
            $full_html .= ".\n";
        }
        if ($link2file) {
            $full_html .= "   The link below each image links to the most recent page where this \n";
            $full_html .= "   image is featured, if found.\n"; 
        }
        $full_html .= "  </p>\n";
    }

    $full_html .= get_html_begin_table();

    if (!$bare_table) {
        $full_html .= "     <tr>\n";
        $wrap = 0;
        while ($wrap < $add_cols) {
            $wrap++;
            $full_html .= "      <th>\n       Name\n      </th>\n" if ($add_name && !$one_cell);
            $full_html .= "      <th>\n       Directory\n      </th>\n" if ($add_dir && !$one_cell);
            $full_html .= "      <th>\n       Image\n      </th>\n";
            $full_html .= "      <th>\n       Size\n      </th>\n" if ($add_isz && !$one_cell);
            $full_html .= "      <th>\n       Bytes\n      </th>\n" if ($add_siz && !$one_cell);
        }
        $full_html .= "     </tr>\n";
    }
    my $order = '';
	$wrap = 0;	# restart WRAP
	for ($i = 0; $i < $img_cnt; $i++) {
		###last if ($i > 1);
		$i2 = $i + 1;
		$fil = $imglist[$i];
        $isblank = ($fil eq 'blank') ? 1 : 0;
        $sf = $fil; # this is the image SOURCE file, with or without an input folder...
        if (!$got_order) {
    		$sf = substr($fil, length($in_folder) + 1 ) if (length($in_folder));
        }
        ($nm, $dir, $ext) = fileparse( $sf, qr/\.[^.]*/ );
		$sb = stat($fil) if (!$isblank);    # get the file date, time, size, etc
		$isz = '';
		$ratio = 1;
		$iwd = 1;
		$iht = 1;
		$attr = '';
		$const = '';
		$src = $sf;
		$relsrc = $irel.$sf;
        $relhrf = $irel.$sf;
		$relpath = get_relative_path( $cwdir, $dir );
		$outsrc = $src;
		$outsrc = $relsrc if ($fix_relat);
		$imgsrc = $outsrc;
        $thsrc  = $imgsrc;
        if (length($thumb_dir)) {
            $tmp = $thumb_dir;
            ut_fix_directory(\$tmp);
            $tmp .= $nm;
            if (-f $tmp.".jpg") {
                $thsrc = $tmp.".jpg"
            } elsif (-f $tmp.".png") {
                $thsrc = $tmp.".png"
            } else {
                prg_exit(1,"ERROR: Thumb $tmp jpg nor png found! FIX ME \n");
            }
        }
        $linksrc = $src;
        $linksrc = $relhrf if ($fix_relat);

        # exceptions....
		if ($add_alt_link && length($alt_src_link)) {
            if ($drop_thumb) {
                $linksrc = drop_thumb_name($linksrc);
            }
			$outsrc = $alt_src_link . '/' . $linksrc;
		}

		#$src = dos_2_unix($fil) if ($dbg2);
		$src = path_2_html($fil) if ($dbg2);
        if (!$isblank) {
            $isz = im_get_image_size($fil);
            $iwd = im_get_image_width($isz);
            $iht = im_get_image_height($isz);
            $ratio = $iwd / $iht;
            $imgSx = $iwd;
            $imgSy = $iht;
        }
		if ($add_isz || $set_max) {
			if ($set_max) {
				if (($iwd > $targwid) || ($iht > $targwid)) {
					if($ratio > 1) {
						$imgSx = $targwid;
						$imgSy = int($targwid / $ratio);
					} else {
						$imgSx = int($targwid * $ratio);
						$imgSy = $targwid;
					}
					$attr =  "            width=\"$imgSx\"\n";
                    $attr .= "            height=\"$imgSy\"";
					$const = "".$imgSx."x".$imgSy;
				}
			}
		}
		$dir = "." if (length($dir) == 0);

		$full_html .= "\n     <tr>\n" if ($wrap == 0);

        if (!$one_cell) {
            if ($add_name) {
                $full_html .= "<td align=\"left\" valign=\"top\">\n";
                $full_html .= $sf;
                $full_html .= "\n</td>\n";
            }

            if ($add_dir) {
                $full_html .= "<td align=\"left\" valign=\"top\">\n";
                ##$full_html .= dos_2_unix($dir);
                $full_html .= $relpath;
                $full_html .= "\n</td>\n";
            }
        }

        $alttxt = "$src";
        $alttxt .= " ".$iwd.'x'.$iht if ($set_max);
        $alttxt .= " index $i2";
        # ======================================================================================
		# main IMAGE cell, class .ctr
        # ===============================================================================
		$full_html .= "      <td class=\"ctr\">\n";
        # **********************************************************
        if ($add_lnk && !$isblank) {
            # lllllllllllllllllllllllllllllllllllllllllllllllll
            $full_html .= "       <a ";
            if (length($targ)) {
                $full_html .= "$targ\n           ";
            }
            $full_html .= "href=\"$outsrc\"";
            if ($add_name_sttr) {
                $full_html .= "\n           name=\"$nm\"";
            }
            $full_html .= ">";  # close the <a href
            # lllllllllllllllllllllllllllllllllllllllllllllllll
       }
       # *************************************************************************
       # ADD IMAGE
       # =========
       $order .= "$imgsrc ";
       if ($isblank) {
           $full_html .= "\n       is blank\n";
       } else {
            $full_html .= "        <img src=\"";
            if (length($thumb_dir)) {
                $full_html .= $thsrc;
                $attr = ''; # no size attribute on thumbs
            } else {
                $full_html .= $imgsrc;
            }
            push(@img_list, path_u2d($imgsrc));
            $full_html .= "\"\n";
            $full_html .= "$attr" if length($attr);
            $full_html .= "\n            alt=\"$alttxt\"";
            $full_html .= ">\n";
            if ($add_img_txt) {
                $full_html .= "            <br>$alttxt\n";
            }
       }
       # *************************************************************************
        # =======
        if ($add_lnk && !$isblank) {
    		$full_html .= "       </a>\n";
        }
		if ($one_cell) {
			$full_html .= "$addbr       rp: $relpath\n" if ($add_dir && length($relpath));
            if ($add_name && length($sf)) {
                $lhtm = $sf;
                if ($link2file) {
                    if (defined $hash_html{$sf}) {
                        $lfile = $hash_html{$sf};
                        $lhtm = '<a target="_blank" href="'.$lfile.'">'.$lfile.'</a>';
                    }
                }
                $lhtm .= " ($isz)" if ($add_imsz);
                if ($add_file_name) {
                   if ($set_max) {
                       if ($imgSx >= $targwid) {
                           $full_html .= " $lhtm";
                       } else {
                           $full_html .= "$addbr       $lhtm";
                       }
                   } else {
                       $full_html .= "$addbr       $lhtm";
                   }
                }
                $full_html .= "\n";
            }
			$full_html .= "$addbr       is: $isz\n" if ($add_isz && length($isz) && !$add_imsz);
			$full_html .= "$addbr       ct: $const\n" if ($add_isz && length($const));
			$full_html .= "$addbr       fs: ".get_nn($sb->size)."\n" if ($add_siz);
		}
        # **********************************************************
		$full_html .= "      </td>\n";
        # ======================================================================================

        if (!$one_cell) {
            if ($add_isz  && length($isz)) {
                $full_html .= "<td align=\"left\" valign=\"top\">\n";
                $full_html .= $isz;
                $full_html .= $const if length($const);
                $full_html .= "\n</td>\n";
            }
            if ($add_siz) {
                $full_html .= "<td align=\"right\" valign=\"top\">\n";
                $full_html .= get_nn($sb->size);
                $full_html .= "\n</td>\n";
            }
        }

		$wrap++;
		if ($wrap == $add_cols) {
			$full_html .= "     </tr>\n";
			$wrap = 0;
            $rcnt++;
            if ( ($row_jump > 0) && ($rcnt >= $row_jump) && (($img_cnt - $i) > ($row_jump + 2)) ) {
                $full_html .= get_row_jump($add_cols) if (!$bare_table && !$got_order);
                $rcnt = 0;
            }
            $order .= "\n";
		}

		prt( "Image: [$sf] ".$iwd."x".$iht.", scaled ".$imgSx."x".$imgSy." ($fil) (irel=$irel)\n" ) if (VERB5());
	}

	# finish off the row, if required
	if ($wrap) {
		while ($wrap < $add_cols) {
			$full_html .= "      <td>\n&nbsp;/n      </td>\n" if ($add_name && !$one_cell);
			$full_html .= "      <td>\n&nbsp;/n      </td>\n" if ($add_dir && !$one_cell);
			$full_html .= "      <td align=\"center\">\n       no image\n      </td>\n";
			$full_html .= "      <td>\n&nbsp;\n      </td>\n" if ($add_isz && !$one_cell);
			$full_html .= "      <td>\n&nbsp;\n      </td>\n" if ($add_siz && !$one_cell);
			$wrap++;
            $order .= "blank ";
		}
		$full_html .= "     </tr>\n";
        $order .= "\n";
	}

    $full_html .= get_html_end_table();

    if (!$bare_table) {
        $full_html .= get_end_link();

       if ($add_valid_stg) {
          $full_html .= get_tidy_valid();
       } else {
          $full_html .= "  <p><a name=\"end\" id=\"end\">&nbsp;</a></p>\n";
       }
       if ($add_old_link) {
          $full_html .= get_old_link();
       }
    }

    $full_html .= "  <!-- Generated by $pgmname on ".get_YYYYMMDD_hhmmss(time())." -->\n";

    $full_html .= get_html_end();
    if ($show_full) {
        prt( "======================================================================\n" );
        prt( "$full_html\n" );
        prt( "======================================================================\n" );
    }
    prt("Image order:\n$order");
    $txt = join("\n",@img_list)."\n";
    rename_2_old_bak($list_file);
    write2file($txt,$list_file);
    prt("Image list written to $list_file...\n");

    rename_2_old_bak($of);
    # dump it to FILE
	if (open OUTF, ">$of") {
        print OUTF $full_html;
        close OUTF;
    	prt( "Written HTML to $of ...\n" );
		$outsrc = "copy $of .\n";
        write2file($outsrc,$copy_bat);
        prt("Written $copy_bat to update...\n");
    } else {
    	prt( "ERROR: FAILED TO WRITE $of !!!\n" );
    }
}


sub in_excluded_images {
    my ($fil) = shift;
    my ($nm, $dir) = fileparse($fil);
    foreach my $f (@excluded_imgs) {
        if ($nm eq $f) {
            return 1;
        }
    }
    return 0;
}

sub my_in_file {
	my ($fil) = shift;
	my ($nm, $dir, $ext) = fileparse( $fil, qr/\.[^.]*/ );
	foreach my $e (@imgfiles) {
		if (lc($e) eq lc($ext)) {
			return 1;
		}
	}
	return 0;
}


sub is_fp_folder {
	my ($fil) = shift;
	foreach my $fp (@fpfolders) {
		if (lc($fp) eq lc($fil)) {
			return 1;
		}
	}
	return 0;
}


sub collect_image_files($) {
	my $inf = shift;
    my $cnt = 0;
	prt( "Processing $inf folder ...\n" );
	if ( opendir( DIR, $inf ) ) {
		my @files = readdir(DIR);
		closedir DIR;
        $cnt = scalar @files;
        prt("readdir returned $cnt items...\n");
		foreach my $fl (@files) {
			if (($fl eq '.') || ($fl eq '..') || is_fp_folder($fl) ) {
				next;
			}
			my $ff = $inf . "\\" . $fl;
			if (-d $ff) {
				collect_image_files($ff) if ($recursive);
			} else {
                prt("Checking '$fl' ... ") if (VERB9());
				if (my_in_file($fl) && !in_excluded_images($fl)) {
                    if (in_xclude_list($fl)) {
                        $xclude_cnt++;
                        prt("in exclude") if (VERB9());
                    } else {
    					push(@imglist, $ff);
                        prt("Added") if (VERB9());
                    }
				} else {
                    prt("NOT image") if (VERB9());
                }
                prt("\n") if (VERB9());
			}
		}
	} else {
		prt( "WARNING: Can NOT open $inf ... $! ...\n" );
	}
}


#sub get_nn { # perl nice number nicenum add commas
#	my ($n) = shift;
#	if (length($n) > 3) {
#		my $mod = length($n) % 3;
#		my $ret = (($mod > 0) ? substr( $n, 0, $mod ) : '');
#		my $mx = int( length($n) / 3 );
#		for (my $i = 0; $i < $mx; $i++ ) {
#			if (($mod == 0) && ($i == 0)) {
#				$ret .= substr( $n, ($mod+(3*$i)), 3 );
#			} else {
#				$ret .= ',' . substr( $n, ($mod+(3*$i)), 3 );
#			}
#		}
#		return $ret;
#	}
#	return $n;
#}

sub dos_2_unix {
	my ($du) = shift;
	$du =~ s/\\/\//g;
	return $du;
}
sub unix_2_dos {
	my ($du) = shift;
	$du =~ s/\//\\/g;
	return $du;
}

sub path_2_html {
	my ($pth) = shift;
	$pth = dos_2_unix($pth);
	###$pth =~ s/ /%20/g;
	return $pth;
}


sub get_relative_path_test {
	my ($target, $fromdir) = @_;
	my ($colonpos, $path, $posval, $diffpos);
    ##my ($from, $to);
	my ($tlen, $flen);
    my ($tolen, $fromlen);
    my ($cht, $chf);
	my $retrel = "";
	# only work with slash - convert DOS backslash to slash
	$target = path_d2u($target);
	$fromdir = path_d2u($fromdir);
	# add '/' to target. if missing
	if (substr($target, length($target)-1, 1) ne '/') {
		$target .= '/';
	}
	# add '/' to fromdir. if missing
	if (substr($fromdir, length($fromdir)-1, 1) ne '/') {
		$fromdir .= '/';
	}

	# remove drives, if present
    if ( ( $colonpos = index( $target, ":" ) ) != -1 ) {
		$target = substr( $target, $colonpos+1 );
	}
	if ( ( $colonpos = index( $fromdir, ":" ) ) != -1 ) {
        $fromdir = substr( $fromdir, $colonpos+1 );
    }
	# got the TO and FROM ...
	#$to = $target;
	#$from = $fromdir;
    $tolen = length($target);
    $fromlen = length($fromdir);
	prt( "To   [$target]($tolen),\nfrom [$fromdir]($fromlen) ...\n" ) if ($tdbg_rel);
	$path = '';
	$posval = 0;
	$retrel = '';
	# // Step through the paths until a difference is found (ignore slash differences)
	# // or until the end of one is found
	# while ( substr($from,$posval,1) && substr($to,$posval,1) ) {
	while ( ($posval < $tolen) && ($posval < $fromlen) ) {
        $chf = substr($fromdir,$posval,1);
        $cht = substr($target,$posval,1);
		if ( $chf eq $cht ) {
			$posval++; # bump to next
		} else {
            prt( "First diff [$chf] ne [$cht] ...\n" ) if ($tdbg_rel);
			last; # break;
		}
	}
	##if ( !substr($from,$posval,1) ) {
	if ( $posval >= $fromlen ) {
        prt( "Ran out of from ...\n" ) if ($tdbg_rel);
    }
    ##if ( !substr($to,$posval,1) ) {
    if ( $posval >= $tolen ) {
        prt( "Ran out of to ...\n" ) if ($tdbg_rel);
    }

	# // Save the position of the first difference
	$diffpos = $posval;
    prt( "First diff found at offset $posval ... ".substr($target,$posval)." ...\n" ) if ($tdbg_rel);

	# // Check if the directories are the same or
	# // the if target is in a subdirectory of the fromdir
	if ( ( !substr($fromdir,$posval,1) ) &&
		 ( substr($target,$posval,1) eq "/" || !substr($target,$posval,1) ) )
	{
		# // Build relative path
		$diffpos = length($target);
		if (($posval + 1) < $diffpos) {
			$diffpos-- if ($diffpos);
			if ($diffpos > $posval) {
				$diffpos -= $posval;
			} else {
				$diffpos = 0;
			}
			###$retrel = substr( $target, $posval+1, length( $target ) );
			prt( "Return substr of target, from ".($posval+1).", for $diffpos length ...\n" ) if ($tdbg_rel);
			###$retrel = substr( $target, $posval+1, $diffpos );
			$retrel = substr( $target, ($posval+1) );
		} else {
			prt( "posval+1 (".($posval+1).") greater than length $diffpos ...\n" ) if ($tdbg_rel);
		}
	} else {
		# // find out how many "../"'s are necessary
		# // Step through the fromdir path, checking for slashes
		# // each slash encountered requires a "../"
		#$posval++;
		while ( substr($fromdir,$posval,1) ) {
			prt( "Check for slash ... $posval in $fromdir\n" ) if ($tdbg_rel);
			if ( substr($fromdir,$posval,1) eq "/" ) { # || ( substr($fromdir,$posval,1) eq "\\" ) ) {
				prt( "Found a slash, add a '../' \n" ) if ($tdbg_rel);
				$path .= "../";
			}
			$posval++;
		}
		prt( "Backed relative path = [$path] ...\n" ) if ($tdbg_rel);

		# // Search backwards to find where the first common directory
		# // as some letters in the first different directory names
		# // may have been the same
		$diffpos--;
		while ( ( substr($target,$diffpos,1) ne "/" ) && substr($target,$diffpos,1) ) {
			$diffpos--;
		}
		# // Build relative path to return
		$retrel = $path . substr( $target, $diffpos+1, length( $target ) );
    }
	prt( "Returning [$retrel] ...\n" ) if ($tdbg_rel);
	return $retrel;
}

###################################################
#### bit of the HTML file

sub get_html_bgn {
   my $html_bgn = '';

    my $html_bgn1 = <<EOF;
<!DOCTYPE html>
<html lang="en">
 <head>
  <meta charset="UTF-8">
  <meta name="generator"
        content="genimgindex.pl">
  <meta name="keywords"
        content=
        "geoff, mclane, geoffmclane, computer, consultant, programmer, FlightGear, SimGear, PLIB, zlib, openal, pthreads, freeglut, openscenegraph">
  <meta name="description"
        content="FlightGear Build Center Image Index">
  <title>
   $html_title
  </title>
  <link rel="stylesheet"
        type="text/css"
        href="fgcode.css">
EOF

    my $html_bgn2 = <<EOF;
  <script type="text/javascript"
        src="qlfgmenu.js">
</script>
EOF

    my $html_bgn3 = <<EOF;
  <style>
/* some added styles, ... */
.ctr { text-align:center; }
h1 { text-align:center; }
table
{ 
margin-left: auto;
margin-right: auto;
}
  </style>
 </head>
EOF

   if ($add_script) {
      $html_bgn = $html_bgn1 . $html_bgn2 . $html_bgn3;
   } else {
      $html_bgn = $html_bgn1 . $html_bgn3;
   }
    return $html_bgn;
}

sub get_html_body_bgn {
    my $html_body_bgn = <<EOF;
 <body>
  <h1>
  <a id=\"top\"></a>
   $html_title
  </h1>

  <p class="ctr">
   <a target=\"_self\" href="index.htm">index</a> -|-
   <a target=\"_self\" href="#end">end</a>
  </p>
EOF
    if ($bare_table) {
        return "  <body>\n";
    }

    return $html_body_bgn;
}

sub html_bare_table {
    my $html_bare_table = <<EOF;
    <table border="0"
           cellpadding="0"
           cellspacing="0"
           id="Num1">
EOF

    return $html_bare_table
}   


sub get_html_begin_table {
    return html_bare_table() if ($bare_table);
    my $html_begin_table = <<EOF;
    <table border="2"
           cellpadding="2"
           id="Num1">
EOF

    return $html_begin_table
}   

sub get_html_end_table {
    my $html_end_table = <<EOF;
    </table>
EOF

    return $html_end_table;
}

sub get_end_link {
    my $html_link = <<EOF;

  <p class="ctr">
   <a target=\"_self\" href="#top">top</a> -|- 
   <a target=\"_self\" href="index.htm">index</a> 
  </p>
EOF

    return $html_link;
}

sub get_old_link {
    my $old_link = <<EOF;

  <p align="right">
   <a target="_blank"
      href="fgimgvw2.htm">old image index</a>
  </p>
EOF

    return $old_link;
}

sub get_html_end {
    my $html_end = <<EOF;
 </body>
</html>

EOF

    return $html_end;
}

sub get_row_jump {
    my ($cs) = shift;
    my $row_jump = <<EOF;
     <tr>
      <td colspan="$cs">
       <p class="ctr">
        <a target="_self" 
           href="#end">end</a> -|- 
        <a target="_self"
           href="index.htm">index</a> -|- 
        <a target="_self" 
           href="#top">top</a>
       </p>
      </td>
     </tr>

EOF

    return $row_jump;
}


sub get_tidy_valid {
   my $tidy_valid = <<EOF;
  <p>
   <a name="end"
      id="end"></a> <a target="_blank"
      href="http://tidy.sourceforge.net/"><img border="0"
        src="images/checked_by_tidy.gif"
        alt="checked by tidy"
        width="32"
        height="32"></a>&nbsp; <a href="http://validator.w3.org/check?uri=referer"
      target="_blank"><img src="images/valid-html401.gif"
        alt="Valid HTML 4.01 Transitional"
        width="88"
        height="31"></a>
  </p>
EOF

   my $qlinks = <<EOF;
     <script type="text/javascript">
<!-- 
  QuickLinks();
  ModifiedDate();
  // -->
  </script>
EOF
   
   if ($add_script) {
      $tidy_valid = $qlinks . $tidy_valid;
   }
   return $tidy_valid;
}

sub mycmp_decend {
   if (${$a}[0] < ${$b}[0]) {
      return 1;
   }
   if (${$a}[0] > ${$b}[0]) {
      return -1;
   }
   return 0;
}

#sub get_YYYYMMDD {
#    my ($t) = shift;
#    my @f = (localtime($t))[0..5];
#    my $m = sprintf( "%04d/%02d/%02d",
#        $f[5] + 1900, $f[4] +1, $f[3]);
#    return $m;
#}

sub get_YYYYMMDD_hhmmss {
    my ($t) = shift;
    my @f = (localtime($t))[0..5];
    my $m = sprintf( "%04d/%02d/%02d %02d:%02d:%02d",
        $f[5] + 1900, $f[4] +1, $f[3], $f[2], $f[1], $f[0]);
    return $m;
}

### MAIN ###
############################################
parse_args(@ARGV);

$img_cnt = scalar @imglist;
if ($img_cnt) {
    prt( "Found $img_cnt image files in command..." );
    write_html_file( $out_file );
} else {
    collect_image_files( $in_folder ); # if (length($in_folder));
    $img_cnt = scalar @imglist;
    if ($img_cnt) {
        prt( "Found $img_cnt image files in [$in_folder]..." );
        if ($xclude_cnt) {
            prt(" excluded $xclude_cnt");
        }
        prt("\n");
        write_html_file( $out_file );
        # system $out_file if ($load_html);
    } else {
        prt( "No image files found ...\n" );
    }
}
close_log($outfile,$load_log);
#unlink($outfile);
exit(0);

my @g_order = ();

############################################
sub has_wild($) {
    my $fil = shift;
    return 1 if ($fil =~ /\*/);
    return 1 if ($fil =~ /\?/);
    return 0;
}

sub get_files($$) {
    my ($fil,$ha) = @_;
    my @files = glob($fil);
    my $cnt = scalar @files;
    if ($cnt) {
        prt("Adding $cnt files, from [$fil] input.\n") if (VERB1());
        push(@{$ha},@files);
        prt(join("\n",@files)."\n") if (VERB9());
    }
    return $cnt;
}

sub load_order_file($) {
    my $inf = shift;
    if (open INF, "<$inf") {
        my @lines = <INF>;
        close INF;
        my $lncnt = scalar @lines;
        my ($line,@arr,$len,$cnt,$ra,$fil,$sb);
        my $lnn = 0;
        my $icnt = 0;
        my $lnn2 = 0;
        foreach $line (@lines) {
            $lnn++;
            chomp $line;
            $line = trim_all($line);
            $len = length($line);
            next if ($len == 0);
            next if ($line =~ /^\#/); # skip comment lines
            $lnn2++;
            @arr = split(/\s+/,$line);
            $cnt = scalar @arr;
            if ($lnn2 > 1) {
                if ($cnt != $icnt) {
                    mydie("ERROR: Line $lnn, not same image count $cnt, as other lines $icnt\n");
                }
            }
            $icnt = $cnt;
            push(@g_order,[@arr]);
        }
        my $row = scalar @g_order;
        prt("Loaded image order $inf, with $icnt columns, by $row rows...\n");
        $add_cols = $icnt;
        $row = 0;
        foreach $ra (@g_order) {
            $row++;
            $cnt = 0;
            foreach $fil (@{$ra}) {
                $cnt++;
                if ($fil eq 'blank') {
                    # ok
                } elsif ($sb = stat($fil)) {
                    # ok
                } else {
                    mydie("ERROR: Unable to 'stat' $fil, row $row, col $cnt\n");
                }
                push(@imglist,$fil);
            }
        }
        $cnt = scalar @imglist;
        $date_sort = 0;
        $got_order = 1;
        $add_lnk = 0;
        prt("Loaded $cnt ordered images...\n");
    } else {
        mydie("ERROR: Failed to open order file $inf`\n");
    }

}



sub need_arg {
   my ($a,@b) = @_;
   mydie("ERROR: Argument [$a] needs a following argument!\n") if (! @b);
}


sub parse_args {
    my (@av) = @_;
    my ($arg,$sarg,$tmp);
    my ($nm, $dir,@arr,@lines,$cnt,$ff,@arr2,$len);
	while (@av) {
		$arg = $av[0];
		if (substr($arg,0,1) eq "-") {
         $sarg = substr($arg,1);
         $sarg = substr($sarg,1) if ($sarg =~ /^-/);
         if (($sarg =~ /^h/)||(substr($sarg,0,1) eq '?')) {
             give_help();
             exit(0);
         } elsif ($sarg =~ /^o/) {
             need_arg($arg,@av);
             shift @av;
             $got_user_out = 1;
             $out_file = File::Spec->rel2abs($av[0]);
             prt( "Set out file to [$out_file]...\n" );
         } elsif ($sarg =~ /^d/) {
             $date_sort = 1;
             prt( "Set to date sort images...\n" );
         } elsif ($sarg =~ /^b/) {
             $bare_table = 1;
             $add_img_txt = 0;
             prt( "Set to bare table...\n" );
         } elsif ($sarg =~ /^a/) {
             $add_img_txt = 1;
             prt( "Set to alt text under image...\n" );
         } elsif ($sarg =~ /^c/) {
               need_arg($arg,@av);
               shift @av;
               $add_cols = $av[0];
               if ($add_cols =~ /^\d+$/) {
                   prt( "Set column count to $add_cols...\n" );
               } else {
    				mydie( "ERROR: Expected an integer number! Got [$add_cols]!\n" );
               }
         } elsif ($sarg =~ /^t/) {
               need_arg($arg,@av);
               shift @av;
               $html_title = $av[0];
               prt("Set html title to '$html_title'\n");
         } elsif ($sarg =~ /^w/) {
               need_arg($arg,@av);
               shift @av;
               $targwid = $av[0];
               if ($targwid =~ /^\d+$/) {
                   prt( "Set target width to $targwid...\n" );
                   $usr_targ_wid = 1;
               } else {
    				mydie( "ERROR: Expected an integer number! Got [$add_cols]!\n" );
               }
         } elsif ($sarg =~ /^x/) {
               need_arg($arg,@av);
               shift @av;
               $sarg = $av[0];
               @arr = split(';',$sarg);
               $len = 0; # scalar @arr;
               foreach $tmp (@arr) {
                   if (has_wild($tmp)) {
                       @arr2 = ();
                       $cnt = get_files($tmp,\@arr2);
                       if ($cnt) {
                           $len += $cnt;
                           push(@xclude_list,@arr2);
                       }
                   } else {
                       $len++;
                       push(@xclude_list,$tmp);
                   }
               }
               prt("Added $len to the exclude list.\n");
         } elsif ($sarg =~ /^X/) {
               need_arg($arg,@av);
               shift @av;
               $sarg = $av[0];
               if (open INF, "<$sarg") {
                    @lines = <INF>;
                    close INF;
                    @arr = ();
                    foreach $sarg (@lines) {
                        $sarg = trim_all($sarg);
                        next if ($sarg =~ /^\#/);
                        push(@xclude_list,$sarg);
                        push(@arr,$sarg);
                    }
                    push(@xclude_list,@arr);
                    prt("Added ".scalar @arr." to eXluded list.\n");
               } else {
    				mydie( "ERROR: Unable to open exclude list file $sarg!\n" );
               }
         } elsif ($sarg =~ /^T/) {
               need_arg($arg,@av);
               shift @av;
               $sarg = $av[0];
               if (-d $sarg) {
                   $thumb_dir = $sarg;
                   prt("Will seek a thumbnail image in $thumb_dir\n");
               } else {
                   mydie("Error: Directory $thumb_dir NOT FOUND!\n");
               }
         } elsif ($sarg =~ /^O/) {
               need_arg($arg,@av);
               shift @av;
               $sarg = $av[0];
               if (-f $sarg) {
                   $order_file = $sarg;
                   prt("Will try to order the image per $sarg file.\n");
               } else {
                   mydie("Error: Directory $thumb_dir NOT FOUND!\n");
               }
         } elsif ($sarg =~ /^f/) {
             need_arg($arg,@av);
             shift @av;
             $tmp = $av[0];
             @arr = split(";",$tmp);
             $cnt = scalar @arr;  
             # LIKE sub collect_image_files($);
             if ($cnt > 0) {
                 $cnt = 0;
                 foreach $tmp (@arr) {
                     if (-f $tmp) {
                         $ff = $tmp;
                         # $ff = File::Spec->rel2abs($tmp);
                         push(@imglist, $ff);
                         $cnt++;
                     }
                 }
             }
             if ($cnt > 0) {
                 prt( "Added input $cnt files...\n" );
             } else {
    				mydie( "ERROR: Expected existing file list... Got [$av[0]]!\n" );
             }
         } elsif ($sarg =~ /^v/) {
              if ($sarg =~ /^v.*(\d+)$/) {
                  $verbosity = $1;
              } else {
                  while ($sarg =~ /^v/) {
                    $verbosity++;
                    $sarg = substr($sarg,1);
                  }
              }
              prt("Verbosity = $verbosity\n") if (VERB2());
         } else {
             mydie( "ERROR: Unknown argument! What is this? [$arg]?\n" );
         }
		} else {
			if (length($in_folder)) {
				mydie( "ERROR: Already have IN-FOLDER [$in_folder]! What is this? [$arg]?\n" );
			}
			$in_folder = File::Spec->rel2abs($arg);
            $got_user_folder = 1;
			prt( "Set in folder to [$in_folder] ...\n" );
            if (! -d $in_folder) {
				mydie( "ERROR: Can NOT locate IN-FOLDER [$in_folder]!\n" );
            }
		}
		shift @av;
	}

    $cnt = scalar @imglist;
    if (length($order_file)) {
        if ($cnt) {
			mydie( "ERROR: Already have $cnt images. Can NOT process [$order_file]!\n" );
        }
        load_order_file($order_file);
    }

#   if ($got_user_folder && $got_user_out) {
#		($nm, $dir) = fileparse($out_file);
#      #prt( "Name = [$nm]\n" );
#      #prt( "Dir  = [$dir]\n");
#      $nm = $out_file;
#      if ($dir =~ /^\.(\\|\/)$/) {
#         if ($in_folder eq '.') {
#            $nm = $my_cwdir;
#            $nm .= "\\" if ( !(($nm =~ /(\\|\/)$/)||($out_file =~ /^(\\|\/)/ )) );
#            $nm .= $out_file;
#         } else {
#            $nm = $in_folder;
#            $nm .= "\\" if ( !(($nm =~ /(\\|\/)$/)||($out_file =~ /^(\\|\/)/ )) );
#            $nm .= $out_file;
#         }
#      }
#      if ($nm ne $out_file) {
#         $out_file = unix_2_dos($nm);
#         prt( "Adjusted out file to\n [$out_file] ...\n" );
#      }
#      #exit(1);
#   }
    $cnt = scalar @imglist;
    if (!$got_user_folder && !$cnt) {
        #$in_folder = $my_cwdir;
        #$got_user_folder = 1;
		#prt( "Set in folder to current [$in_folder] ...\n" );
        mydie("No 'folder' found in command! Give INPUT folder to scan.\n");
    }

#	if ( (length($alt_src_link) == 0) && $debug_on && length($def_alt) ) { # like = '../pics';
#		$alt_src_link = $def_alt;
#		prt( "Set in alternate source to [$alt_src_link], the debug default ...\n" );
#	}
#	if (length($in_folder) == 0) {
#		if ($debug_on) {
#			$in_folder = $def_in_folder;
#			prt( "Set in folder to [$in_folder], the debug DEFAULT ...\n" );
#		} else {
#			mydie( "ERROR: No input folder found ...\n" );
#		}
#	}
    if (!$got_user_out) {
        prt("Using output file of [$out_file]\n");
    }

}


# perl dealing with images
# imglist.pl 
# AIM: Given a folder, search for ALL image files
#
# genimgindex.pl - (see earlier simpe imgindex.pl)
# AIM: Given a BASE folder, seek all IMAGE files, and build
# an 'index' table of images, as HTML ...
#
# imgindex.pl
# AIM: To read a FOLDER, finding all image files, and preparing a simple table index
#
# getimgsize.pl
# AIM: Given a folder, use Imagemagick identify to get the image sizes
# and write a tempjs.js with the image sizes in an array
#
# imagemagic.pl
# AIM: Test of ImageMagic installation - use Image::Magick;
#
# imgalt02.pl
# AIM: To extract the <img alt="..." atribute of each image,
# in all (both) English and French version ...
# Read a JetPhoto, fix each entry in the 
# studio.plist XML file ... each has to be inserted as 
# <key>Description</key>
# <string>English description ... French Description</string>
# and save the new studio.plist file ...
#
# imgsize.pl - MODULE
# AIM: Use external imagemagick 'identify.exe' to get an image SIZE geometry
# Services: im_get_image_size( file_name ); returns geometry nnnnxnnnn
# im_get_image_width( geometry ); returns WIDTH
# im_get_image_height( geometry ); returns HEIGHT
#
# imgratio.pl
# AIM: Play with MATH, to re-size an image, keeping the aspect ratio ...
#
# eof - genimgindex.pl

sub give_help {
   prt("\n");
   prt("$pgmname: version $VERS\n");
   prt("$pgmname [Options] Folder\n");
   prt("Options:\n");
   prt("  -h or -?          = This help, and exit 0\n");
   prt("  -a                = Add alt text under image. (def=$add_img_txt)\n");
   prt("  -b                = Bare table, suitable for printing. (def=$bare_table)\n");
   prt("  -c <num>          = Set table column count. (def=$add_cols)\n");
   prt("  -d                = Date sort the images.\n");
   prt("  -f fil1[;fil2...] = Treat this as the input image list.\n");
   prt("  -o <file>         = Output the HTML to this file.\n");
   prt("  -t <title>        = Set title string. (def=$html_title)\n");
   prt("  -w <num>          = Set target width. (def=$targwid)\n");
   prt("  -x fil1[;fil2...] = Exclude these files.\n");
   prt("  -X file_list.txt  = List of files to exclude.\n");
   prt("  -T <dir>          = Seek and show a thumbnail image of same name in this directory.\n");
   prt("  -O <file>         = File to set the image order.\n");
   prt("  -v[n]             = Bump [or set] verbosity. def=$verbosity\n");
   prt("\n");
   prt(" Scan the input folder for images, and generate a table of images\n");
   prt(" using $targwid target width, keeping aspect ratio, in $add_cols columns.\n");
   prt(" If given '-O file', try to order the images per that file list.\n");
}

# EOF
