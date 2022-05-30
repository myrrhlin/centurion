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

cmp_deeply($gstate->as_json, superhashof({
  # default values
  golds   => 5,
  silvers => 5,
  score   => 0,
  maxcubes => 10,
  # market cards
  reward => [[GGBBPP=>'+19'], [YYYBB=>'+9'], [GGBBB=>'+13'], [PPPP=>'+16'], [GGGPP=>'+14']],
  market => [[GG=>'YYYB'],[P=>'YYYB'],[GG=>'BB'],[''=>'P'],[YYY=>'GGG']],
  market_cubes => ['Y','','','',''],
  # player
  hand => [[YYB=>'PP'],[PP=>'YGBBB'],[BB=>'YYGP'],[BB=>'YYGGG'],[BBB=>'PPP'],
    [BB=>'GGP'],[YY=>'G'],[GGG=>'BBB'],[__=>'YY']],
  discard => [[''=>'YY']],
  cubes => 'YYGB',
}), 'as_json');

my @menu = $gstate->report;
my $label = 'a';
foreach my $item (@menu) {
  my ($text, $card) = @$item;
  say $label++, ") $text";
}

done_testing;

