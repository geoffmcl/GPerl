#!/perl -w
# MODULE: imgsize.pl 
# AIM: Use external imagemagick 'identify.exe' to get an image SIZE geometry
# Services: im_get_image_size( file_name ); returns geometry nnnnxnnnn
# im_get_image_width( geometry ); returns WIDTH
# im_get_image_height( geometry ); returns HEIGHT
# 19/05/2020 - adjust 'identify' to 'magick indentify'
# 21/08/2007 geoff mclane http://geoffair.net/mperl
use strict;
use warnings;

sub im_get_image_width {
	my ($is) = shift;
	my $wid = 0;
	my @arr = split(/x/,$is);
	if (scalar @arr == 2) {
		$wid = $arr[0];
	}
	return $wid;
}

sub im_get_image_height {
	my ($is) = shift;
	my $hgt = 0;
	my @arr = split(/x/,$is);
	if (scalar @arr == 2) {
		$hgt = $arr[1];
	}
	return $hgt;
}

sub im_get_image_size {
	my ($if) = shift;
	my $is = '';
	if (open (IDT, "magick identify \"$if\"|")) {
		my @arr2 = <IDT>;
		close IDT;
		foreach my $ln (@arr2) {
			chomp $ln;
			#prt( "[$ln]\n" );
			if (substr($ln,0,length($if)) eq $if) {
				my $ln2 = substr($ln,length($if));
				$ln2 =~ s/^\s//;
				#prt( "$ln2\n" );
				if ($ln2 =~ /\s(\d+x\d+)\s/) {
					$is = $1;
				}
			}
		}
	} else {
		prt( "ERROR: I can't open [$if]\n" );
	}
	return $is;
}

1;
# eof - imgsize.pl
