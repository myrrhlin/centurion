#! /usr/bin/env perl

use 5.26.0;
use warnings;
use autodie;
use feature 'signatures';
no warnings 'experimental';

use Carp;
use Getopt::Long;
use Data::Printer;
use Path::Tiny;
use JSON::MaybeXS;

my %opt;
GetOptions(\%opt,
  'debug',
  'input=s',
) || die "couldnt process options";

use lib '.';
use GState;

my $statef = 'centurion.dat';
sub load_state {
  my $stateh = decode_json(path($statef)->slurp_utf8);
  return GState->new(%$stateh);
}
sub save_state ($game) {
  path($statef)->spew(encode_json($game->as_json));
}

sub menuchoice {
  my @menu = @_;
  print 'Enter choice (a..qrs): ';
  my $choice = <STDIN>;
  $choice =~ s/^\s+//;
  return substr($choice, 0, 1);
}

my $game = GState->sample;
my @plays;

while (1) {
  my @menu = $game->report;
  @menu = grep !/BAD/, @menu unless $opt{debug};
  my $label = 'a';
  foreach my $item (@menu) {
    my ($text, $card) = @$item;
    say $label++, ") $text";
    last if $label eq 'q';
  }
  say 'q)uit   r)eport  s)ave';
  my $choice = '';
  $choice = menuchoice until $choice ge 'a' && $choice le 's';
  last if $choice eq 'q';
  next if $choice eq 'r';
  save_state($game), next if $choice eq 's';
  die "choice $choice was greater than listed menu" if $choice ge $label;
  my $index = ord($choice) - ord('a');
  $game->play($menu[$index]);
  push @plays, $choice;
}

if (@plays) {
  say scalar(@plays),' plays: ', join '', @plays;
  path('last-century.txt')->spew(join '', @plays);
}

__DATA__



