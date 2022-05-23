package Card;

use 5.26.0;
use warnings;
use feature 'signatures', 'postderef';

=head1 Card

A card in the game.  Generally, its C<cost> and C<benefit> fields are
strings of the letters [YGBP], each representing a cube of the color
Yellow Green Blue or Pink.  (During instantiation, though, it is acceptable
to use lowercase, or digits 1-4 to represent the colors instead;
1=Yellow 2=Green 3=Blue 4=Pink.)

Exceptions to the above:
* A reward type card has a benefit value of an integer preceded by a + sign.
* A generic upgrade card has a cost value of '__', representing two cubes
of arbitrary color.

Aside from the usual way, a card can be instantiated from a
single arrayref that follows some conventions;

* an arrayref with two elements represent the cost and benefit respectively.
e.g. [113, 44] swaps 2Y+1B for 2P
* an arrayref with one element represents the benefit (there was no cost).
e.g. [11] just gives two yellow
* a card which upgrades an arbitrary color has a _ char for cost, and 1.
e.g. [__ => 11] upgrades any two cubes 1 level
* a reward card has an integer point value for the benefit, with a leading +
e.g. [11133 => '+9'] pay 3Y+2B for 9 points

=cut

use Carp;
use Scalar::Util qw( blessed );
use Data::Printer;
use List::Util qw( sum );

use Moo;
use Types::Standard qw( Str Int Enum ArrayRef Maybe InstanceOf );

no warnings 'experimental';
use namespace::clean;

use Cubes qw( norm value byvalue );  # also brings us: norm, cstring, value, byvalue

# test whether a scalar could be coerced into a Card
sub cardlike ($val) {
  return unless my $type = ref $val;
  return 1 if blessed $val && $val->isa('Card');
  return if blessed $val || $type ne 'ARRAY';
  return if @$val > 2 || !@$val;
  return if grep ref, @$val;  # all elements must be plain scalars
  return if grep !/^(?:[ygbp1234]+|__|\+\d+)$/i, @$val;
  return 1;
}

my %cubeval = (Y => 1, G => 2, B => 3, P => 4);

# increment a color -- used by conversion card
sub colorinc ($cube, $plus = 1) {
  my $colors = 'YGBP';
  my $current = index($colors, $cube);
  croak "not a color: $cube" if $current < 0;
  return 'P' if $current + $plus > 3;
  return substr($colors, $current+$plus, 1);
}

has type => (is => 'ro', required => 1,
  isa => Enum[qw(reward xform)], default => 'xform',
);
has cost => (is => 'ro', required => 1, isa => Str, coerce => \&norm);
has benefit => (is => 'ro', required => 1, isa => Str, coerce => \&norm);
has vgain => (is => 'lazy', isa => Maybe[Int]);  # change in value
has cgain => (is => 'lazy', isa => Maybe[Int]);  # change in length

sub _build_vgain ($self) {
  return if $self->type eq 'reward';
  return 2 if $self->cost eq '__';
  return value($self->benefit) - value($self->cost);
}
sub _build_cgain ($self) {
  return if $self->type eq 'reward';
  return 0 if $self->cost eq '__';
  return length($self->benefit) - length($self->cost);
}

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  if (@args == 1) {
    my $onearg = $args[0];
    if (ref $onearg eq 'ARRAY') {
      my $val = norm($args[0]);
      unshift @$val, '' if @$val == 1;  # single element -- no cost
      my ($cost, $benefit) = @$val;
      @args = (cost => $cost, benefit => $benefit);
      push @args, type => 'reward' if $benefit =~ /^\+/;
    } elsif (blessed $onearg && $onearg->isa('Card')) {
      my $card = $onearg;
      @args = (type => $card->type, cost => $card->cost, benefit => $card->benefit);
    } else {
      croak "got unexpected one arg: ".np($onearg);
    }
  }
  return $class->$orig(@args);
};

sub is_conversion ($self) { $self->cost =~ /^_+$/ }
sub conversion_list ($self, $cubestring) {
  croak 'not conversion card?' unless $self->is_conversion;
  my (%cubes, %result);
  $cubes{$_}++ for split //, $cubestring;
  my (@cost, @menu);
  # combinatorics... on the costs
  my @colors = sort byvalue keys %cubes;
  pop @colors if $colors[-1] eq 'P';  # its a waste to convert P
  while (@colors) {
    my $color1 = shift @colors;
    push @cost, $color1 x2 if $cubes{$color1} > 1;
    push @cost, $color1 . $_ for @colors;
  }
  foreach my $cost (@cost) {
    my $result = join '', map {colorinc($_)} split //, $cost;
    push @menu, sprintf '%s->%s', $cost, $result;
  }
  foreach my $color (sort byvalue keys %cubeval) {
    last if $color eq 'P';
    next unless $cubes{$color};
    push @menu, sprintf '%s->%s', $color, colorinc($color,2);
    $menu[-1] .= ' BAD!' if $color eq 'B';
  }
  return @menu;
}

sub describe ($self, $width = 0) {
  my $tag = substr($self->type, 0, 1);
  $tag .= '+' . $self->vgain if $self->type eq 'xform';
  my $out = sprintf '%s:%s->%s', $tag, $self->cost, $self->benefit;
  if (length $out < $width) { $out .= ' 'x($width - length $out) }
  return $out;
}


1;
