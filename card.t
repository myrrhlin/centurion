#! /usr/bin/env perl

use Test::More;
use Test::Deep;

use lib '.';
use Card;

ok my $card = Card->new(cost => '1111', benefit => 'bb'), 'instantiated with attributes';
cmp_deeply($card, methods(
  cost => 'YYYY',
  benefit => 'BB',
  type => 'xform',
  ), 'coerced cost benefit');

my $copy = Card->new($card);
cmp_deeply($copy, methods(
  cost => 'YYYY',
  benefit => 'BB',
  type => 'xform',
  ), 'copied card');

ok $card = Card->new([11]), 'instantiated from single element';
cmp_deeply($card, methods(
  cost => '',
  benefit => 'YY',
  type => 'xform',
  ), 'card with no cost');

ok $card = Card->new([ __ => 11]), 'instantiate arbitrary upgrade card';
cmp_deeply($card, methods(
  cost => '__',
  benefit => 'YY',
  type => 'xform',
  is_conversion => bool(1),
  ), 'arbitrary upgrade card');


my @menu = $card->conversion_list(uc 'yy');
cmp_deeply(\@menu, bag(
      re('YY->GG'),
      re('Y->B'),
    ), 'conversion choices of yy');
@menu = $card->conversion_list(uc 'byyg');
cmp_deeply(\@menu, bag(
      re('YY->GG'),
      re('YG->GB'),
      re('YB->GP'),
      re('GB->BP'),
      re('Y->B'),
      re('G->P'),
      re('B->P'),
    ), 'conversion choices of byyg');

ok $card = Card->new([11133 => '+9']), 'instantiate reward card';
cmp_deeply($card, methods(
  cost => 'YYYBB',
  benefit => '+9',
  type => 'reward',
  ), 'reward card');

cmp_deeply($card->as_json, bag("YYYBB", "+9"), 'as_json');

done_testing;
