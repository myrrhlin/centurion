#! /usr/bin/env perl

use 5.26.0;
use warnings;

use Scalar::Util qw<refaddr>;
use Test::More;
use Test::Deep;
use Test::Exception;
use Data::Printer;

use lib '.';
use Cubes;

is Cubes::cstring($_), $_, 'cstring matches' for qw(Y YB YGP GB), '';


ok my $cs = Cubes->new('113'), 'instantiate from shorthand';
is $cs->str, 'YYB', 'str method returns normalized cstring';
is "$cs", 'YYB', 'obj interpolate as its cstring';
is $cs . '', 'YYB', 'obj concat as its cstring';
is $cs . 'G', 'YYGB', 'obj concat as its cstring';
is sprintf('%s', $cs), 'YYB', 'obj sprintf as its cstring';

is $cs->value, 5, 'value method';
is Cubes::value($cs), 5, 'value as function';

ok my $cs2 = Cubes->new($cs), 'instantiate from object';
isa_ok $cs2, 'Cubes', 'result';
isnt refaddr($cs2), refaddr($cs), '.. (different object)';
is $cs2->str, 'YYB', '.. same string';

ok $cs2 = $cs->plus(''), 'can add empty string';
is $cs2->str, 'YYB', '.. string value unchanged';

# plus and minus return new instance, dont change original
ok my $cs3 = $cs->plus($cs2), 'plus method with object lives';
isa_ok $cs3, 'Cubes', '..result';
isnt refaddr($cs3), refaddr($cs), '..(not the same one)';
is $cs->str, 'YYB', '..original object unchanged';
is $cs3->str, 'YYYYBB', '..result object string is correct';
is $cs3->value, 10, '.. value of YYYBB correct';

ok $cs3 = $cs + $cs2, 'plus operator lives';
isa_ok $cs3, 'Cubes', 'plus result';
is $cs3->str, 'YYYYBB', 'sum object is correct';

ok $cs3 = $cs->plus('G'), 'plus method with string';
isa_ok $cs3, 'Cubes', '..result';
isnt refaddr($cs3), refaddr($cs), '..(not the same one)';
is $cs3->str, 'YYGB', '..result object string is correct';
is $cs3->value, 7, '..value correct';

ok $cs2 = $cs3->minus('Y'), 'minus method with string';
isa_ok $cs2, 'Cubes', '..result';
isnt refaddr($cs2), refaddr($cs3), '..(not the same one)';
is $cs2->str, 'YGB', '..result object string is correct';

# YYGB - YYB = G
ok $cs2 = $cs3->minus($cs), 'minus method with object';
isa_ok $cs2, 'Cubes', '..result';
isnt refaddr($cs2), refaddr($cs3), '..(not the same one)';
is $cs2->str, 'G', '..result object string is correct';

# cant remove color that doesnt exist
is $cs2->minus('Y'), undef, 'minus returns undef on impossible';

$cs3 = $cs->minus($cs);
isa_ok $cs3, 'Cubes', 'object minus itself';
is $cs3->str, '', 'result object is empty string';
isnt refaddr($cs3), refaddr($cs), '..(a different one)';
is $cs->str, 'YYB', 'original operand unchanged';

# YYB + G
ok $cs3 = $cs->add('G'), 'add with string';
isa_ok $cs3, 'Cubes', '..result';
is refaddr($cs3), refaddr($cs), '..(the same one)';
is $cs->str, 'YYGB', 'stringified result';

# YYGB - G
ok $cs3 = $cs->subtract($cs2), 'subtract with object';
isa_ok $cs3, 'Cubes', '..result';
is refaddr($cs3), refaddr($cs), '..(the same one)';
is $cs->str, 'YYB', 'stringified result';

ok $cs->add(Cubes->new('P')), 'add with object';
is $cs->str, 'YYBP', '..cubestring';
is $cs->value, 9, '..value';

throws_ok {
  $cs->subtract('G');
} qr/cant subtract (?:[YGBP]+) from (?:[YGBP]+)/, 'cant subtract color that isnt there';

done_testing;
