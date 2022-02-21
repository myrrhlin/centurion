#! /usr/bin/env perl

use 5.26.0;
use warnings;
no warnings 'experimental';

use Test::Simple;
use Test::More;
use Test::Deep;

use Data::Printer;

use lib '.';
use GState;

my %input = (
  cubes => 'yygb',
  hand => [[113=>44],[44=>12333],[33=>1124],[33=>11222],[333=>444],[33=>224],[11=>2],[222=>333],[__=>11]],
  discard => [[11]],
  reward => [[ggbbpp=>19],[yyybb=>9],[ggbbb=>13],[pppp=>16],[gggpp=>14]],
  market => [[gg=>1113],[p=>1113],[gg=>33],[4],[yyy=>222]],
  market_cubes => ['y', ('')x4],
);
ok my $gstate = GState->new( %input ), 'instantiate a state';

my @menu = $gstate->report;
my $label = 'a';
foreach my $item (@menu) {
  my ($text, $card) = @$item;
  say $label++, ") $text";
}

done_testing;

