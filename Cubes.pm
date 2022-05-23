package Cubes;

use 5.26.0;
use warnings;
use feature 'signatures', 'postderef';
use autodie;

use Carp;
use Scalar::Util qw( blessed );
use List::Util qw( sum );
use Data::Printer;

use Exporter::Shiny qw( norm cstring value byvalue );

no warnings 'experimental';

use overload
    "+" => 'plus',
    "." => 'concat',
    "-" => 'minus',
    '""' => 'str';

=head1 NAME

Cubes

=head1 SYNOPSIS

=head1 SUMMARY

An object representing a group of colored cubes in a game.

It has overloaded +, -, and . binary operators for combining
and removing sets of cubes, and "" for printing.

=head2 Cube-string

Internally, a Cubes object is a reference to a normalized E<cube-string>.

A cube-string is a string containing zero or more characters, each of
which represents a cube.  Permitted characters, and the cube they represent:

 [Yy1]   yellow (value 1)
 [Gg2]   green (value 2)
 [Bb3]   blue (value 3)
 [Pp4]   pink (value 4)
 [_]     wildcard - any color cube

Letters and the wildcard character are mutually exclusive -- a legal
cube-string cannot contain both.  When normalized, a cube-string with
letters will only contain capitals, and they will be sorted in ascending
order (YGBP).

=head1 FUNCTIONS

=head2 norm

Normalizes a cube-string.  If the argument is not a valid cube-string,
returns an empty string.  If the argument was a Cubes object, returns
its internal cube-string (other objects throw an exception).

Given an arrayref, normalizes all its elements and return an arrayref of them.

=cut

# coerce cubestring (or arrayref of them) into normal representation
sub norm ($val) {
   if (ref $val eq 'ARRAY') {
     my $new = [map {norm($_)} @$val];
     return $new;
   } elsif (blessed $val && $val->isa('Cubes')) {
     return $$val;
   } elsif (ref $val) {
     croak "cannot coerce reference to cubestring";
   } elsif ($val eq '') {
     return $val;
   } elsif ($val =~ /^_+$/) {
      # don't touch- this is match any color symbol
   } elsif ($val =~ /^\+\d+$/) {
      # don't touch- this is point value for reward card
   } else {
     $val =~ tr/ygbpYGBP/1-41-4/; # make numeric
     $val =~ tr/1-4//cd;   # remove any other chars
     $val = join '', sort {$a <=> $b} split //, $val;  # sort digits ascending
     $val =~ tr/1-4/YGBP/; # make letters
   }
   return $val;
}

=head2 cstring

given an argument, return a cube-string (a string suitable for
constructing a Cubes object) if possible, or undef.

used to normalize input for various functions that could take
a cube-string or else a Cubes object (which converts to its
underlying cube-string.

=head2 value

Returns the summed value of a cube-string (an integer),
or '' if the cube-string contains wildcards.

Also a method on a Cubes object (called with no args).

=head2 byvalue

A function for sorting cube-strings (or Cubes objects, or a mix) by value.
Wildcard cube-strings are sorted to the end.

=cut

# given an argument, return a string suitable for constructing a Cubes 
# object, if possible.
# this is a function, but can safely be called as instance method!
sub cstring ($string) {
  if (ref $string) {
    return unless blessed $string && $string->isa('Cubes');
    return $string->str;
  }
  return $string if $string eq '' ||   # empty string acceptable
    $string =~ /^[_YGBP]*$/;  # order doesnt matter
  return;
}

my %cubeval = (Y => 1, G => 2, B => 3, P => 4);

# this is both an instance method _and_ a function!
sub value ($arg) {
  my $string = cstring($arg) //   # stringify a Cubes obj
    croak "value operates only on cubestrings";
  return 0 if $string eq '';
  return '' if $string =~ /^_+$/;
  return $cubeval{$string} if length $string == 1;
  my %cnt;
  $cnt{$_}++ for split //, $string;
  my $value = 0;
  $value += sum map { $cubeval{$_}*$cnt{$_} } keys %cnt if %cnt;
  return $value;
}

sub byvalue :prototype($$) {
  my ($a, $b) = @_;
  return $a eq '' ? 1 : $b eq '' ? -1 : value($a) <=> value($b);
}

=head1 METHODS

=head2 new

constructor, takes a cube-string.

=head2 str

returns the internal normalized cube-string.

=head2 concat

returns a normalized cube-string for the group of cubes in the invocant
plus another cube-string.

=head2 plus, minus

The C<plus> method returns a new Cubes object representing the sum of the
current object (invocant) and a second cube-string (or Cubes object).

The C<minus> method returns a new Cubes object containing the cubes
remaining after subtracting a cube-string from the invocant, or
undef, if there were not sufficient cubes to remove the desired amount.

=head2 add, subtract

The C<add> method adds a cube-string to the invocant Cubes object
(altering it), while the C<subtract> removes cubes in the same way.
If the subtract is impossible, the method dies.

=cut

sub new ($invocant, $given) {
  my $class = ref $invocant || $invocant;
  my $string = cstring(norm($given)) //
    croak "cannot coerce '$given' to cubestring";
  return bless \$string, $class;
}
# sub str ($self) { $$self }
sub str ($self, $=undef, $swap=undef) { $$self }
# sub str { $$self }


# returns just the string, not a new object (like plus)
sub concat ($self, $other, $swap = '') {
  my $string = cstring($other);
  if (defined $string) {
    return norm($self->str . $string);
  } else {
    return $self->str . $other;
  }
}
# return new object
sub plus ($self, $other, $swap = '') {
  my $string = cstring($other) // croak "not a cubestring";
  return $self->new($self->str . $string);
}
#return new object, or undef if impossible
sub minus ($self, $other, $swap = '') {
  my $string = cstring($other) // croak "not a cubestring";
  my %cubes;
  my ($pool, $cost) = $swap ? ($string, $self->str) : ($self->str, $string);
  $cubes{$_}++ for split //, $pool;
  $cubes{$_}-- for split //, $cost;
  my $remain = '';
  foreach my $color (sort byvalue keys %cubes) {
    return undef if $cubes{$color} < 0;
    $remain .= $color x $cubes{$color};
  }
  return $self->new($remain);
}
# change my value
sub add ($self, $other) {
  my $string = cstring($other) // croak "not a cubestring";
  $$self = norm($self->str . $string);
  return $self;
}
# change value, or die if impossible
sub subtract ($self, $other) {
  my $string = cstring($other) // croak "not a cubestring";
  my $remain = $self->minus($string);
  croak "cant subtract $string from $$self" unless defined $remain;
  $$self = $remain->str;  # no norm necessary
  return $self;
}

1;
