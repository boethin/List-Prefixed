# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl List-Prefixed.t'

#########################

use strict;
use warnings;

use Test::More;
use File::Basename;
use PerlIO::gzip;

BEGIN { use_ok('List::Prefixed') };

#########################

my $all_names = dirname(__FILE__).'/data/modulenames.gz';
open DATA, "<:gzip", $all_names or die "Cannot open '$all_names': $!";
my @all_names = <DATA>;
binmode DATA, ":gzip(none)";
close DATA;
chomp(@all_names);

my $list_names = dirname(__FILE__).'/data/modulenames_List.gz';
open DATA, "<:gzip", $list_names or die "Cannot open '$list_names': $!";
my @list_names = <DATA>;
binmode DATA, ":gzip(none)";
close DATA;
chomp(@list_names);

my $prefixed = List::Prefixed->new(@all_names);

my $re = $prefixed->regex;
my $qr = qr/^$re$/;
like $_ => $qr foreach @all_names;

my $list = $prefixed->list('List::');
is_deeply $list => [ sort { $a cmp $b } @list_names ];

my $prefixed2 = List::Prefixed->unfold($re);
is_deeply $prefixed2 => $prefixed;

done_testing;


