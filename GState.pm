package GState;

use 5.26.0;
use warnings;
use feature 'signatures', 'postderef';

use Carp;
use Carp::Always;
use Data::Printer;
use Path::Tiny;
use JSON::MaybeXS;

use Moo;
use Types::Standard qw( Str Int Enum ArrayRef Object InstanceOf );
use Card;

no warnings 'experimental';
use namespace::clean;

use MooX::Clone;

sub _cardify {
  my @refs;
  if (@_>1 || Card::cardlike($_[0])) { @refs = @_ }
  elsif (ref $_[0] eq 'ARRAY') {
    @refs = grep {Card::cardlike($_)} @{$_[0]};
    croak "cant cardify something here" unless @refs == @{$_[0]};
  } else {
    croak "cant cardify a non arrayref!";
  }
  my @cards = map {Card->new($_)} @refs;
  return wantarray? @cards : \@cards;
}

# player attributes:
has score => (is => 'rw', isa => Int, default => 0);
has cubes => (is => 'rw', isa => Str, required => 1, coerce => \&Card::norm);
has [qw(hand discard)] => (is => 'rw', required => 1,
  isa => ArrayRef[InstanceOf["Card"]],
  coerce => sub {[_cardify( @_ )]},
  default => sub {[_cardify( [__=>11],[11] )]},  # starting hand
);

# these normally have 5 cards, but some could be unknown in a future state
has [qw(reward market)] => (is => 'rw', required => 1,
  isa => ArrayRef[InstanceOf["Card"], 1, 5] );
has market_cubes => (is => 'rw', required => 1, isa => ArrayRef[Str, 5, 5],
  coerce => \&Card::norm, default => sub {[('')x5]} );

# dont need decks if we're not playing a full game
has deck => (is => 'rw', isa => ArrayRef[InstanceOf["Card"]]);
has reward_deck => (is => 'rw', isa => ArrayRef[InstanceOf["Card"]]);

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  my %args;
  if (@args % 2 == 0) { %args = @args }
  elsif (@args != 1) { croak 'new takes a hash or hashref only' }
  elsif (ref $args[0] eq 'HASH') { %args = %{$args[0]} }
  elsif (blessed $args[0] && $args[0]->isa('GState')) {
    # %args = %{$args[0]};  # ugly dereference
    croak 'use clone method instead';
  } else { croak 'new takes a hash or hashref only' }

  foreach my $att (qw<hand discard market reward>) {
    next unless $args{$att} && ref $args{$att} eq 'ARRAY';
    my @cards = _cardify(  # build cards from arrayref
      map {$att eq 'reward' ? [$_->[0], "+".$_->[1]] : $_}  # insert plus sign on reward cards
      $args{$att}->@* );  # arrayrefs we start with
    $args{$att} = \@cards;
  }
  $args{cubes} = Card::norm($args{cubes});
  return $class->$orig(%args);
};

sub scored ($self, $points) { $self->score( $self->score + $points) }

# sortign cards by usefulness; conversions last
sub by_use {
  return 1 if $a->is_conversion;
  return -1 if $b->is_conversion;
  Card::value($a->cost) <=> Card::value($b->cost);
}
sub sort_hand ($self) {
  my @c = sort by_use grep { $self->playable($_) } $self->hand->@*;
  push @c, sort by_use grep { !$self->playable($_) } $self->hand->@*;
  $self->hand(\@c);
}
sub spend ($self, $amount) {
  my (%cubes, %cost);
  $cubes{$_}++ for split //, $self->cubes;
  $cost{$_}++ for split //, $amount;
  foreach my $color (keys %cost) {
    $cubes{$color} -= $cost{$color};
    croak if $cubes{$color} < 0;
  }
  $self->cubes(join '', map {$_ x $cubes{$_}} keys %cubes);
}
sub earn ($self, $amount) {
  $self->cubes($amount . $self->cubes);
}

sub can_play ($self) {
  return grep {$self->playable($_)} $self->hand->@*;
}
sub can_claim ($self) {
  return grep {$self->playable($_)} $self->reward->@*;
}
sub playable ($self, $card) {
  return 1 if $self->cubes && $card->is_conversion;
  my $left = Card::subtract($self->cubes, $card->cost);
  return defined $left ? 1 : 0;
}

sub report ($self) {
  my @menu;
  if (my @c = $self->can_claim) {
    say 'can NOW claim ',scalar(@c),' cards: ', join ', ', map {$_->describe} @c;
  }
  print 'Rewards: ';
  my $num = $self->reward->@*;
  for my $i (1..$num) {
    my $card = $self->reward->[$i-1];
    my $bonus = $i == 1 ? '***' : $i == 2 ? '*' : '';
    print $i,$bonus,':',$card->describe(13); print $i==$num? "\n" : '  ';
    next unless $self->playable($card);
    my $left = Card::subtract($self->cubes, $card->cost);
    push @menu, ["Claim reward $i$bonus: ". $card->describe, $i-1];
  }
  my @mktmenu;
  print 'Market:  ';
  $num = $self->market->@*;
  for my $i (1..$num) {
    my $card = $self->market->[$i-1];
    my $mcubes = $self->market_cubes->[$i-1];
    my $bonus = $mcubes ? "+$mcubes" : '';
    print $i,$bonus,':',$card->describe(13); print $i==$num? "\n" : '  ';
    next unless $i-1 <= length $self->cubes;
    my $mincost = substr($self->cubes, 0, $i-1);
    my $netcost = Card::value($mcubes) - Card::value($mincost);
    my $bad = $netcost < -2 ? ' BAD!': '';
    $mincost &&= " spending $mincost";
    $mincost ||= ' for free';
    $netcost = "+$netcost" unless $netcost <0;
    $mincost .= " (net $netcost)";
    push @mktmenu, ["Purchase market $i$bonus: ". $card->describe . $mincost . $bad, $i-1];
  }
  $self->sort_hand;
  #say "\nHand: ", join '  ', map {$_->describe} $self->hand->@*;
  if (my @c = $self->can_play) {
    #say 'can play ',scalar(@c),' cards: ', join ', ', map {$_->describe} @c;
  }
  print "\nHand: ";
  $num = $self->hand->@*;
  for my $i (1 .. $num) {
    my $card = $self->hand->[$i-1];
    my $playable = $self->playable($card) ? '>' : '';
    # print "\n         Rest: " unless $playable;
    # print $card->describe; print $i==$self->hand->@* ? "\n" : '  ';
    print $playable,$card->describe; print $i==$num ? "\n" : '  ';
    next unless $self->playable($card);
    if ($card->is_conversion) {
      push @menu, map {; [sprintf('Convert %s with card %u', $_, $i), $i-1]}
        $card->conversion_list($self->cubes);
    } else {
      push @menu, ["Play ".$card->describe, $i-1];
    }
  }
  print 'Cubes: ', $self->cubes; say '       Score: ', $self->score;
  return @menu, @mktmenu, ['Reclaim used cards'];
}

sub play ($self, $menuchoice) {
  croak 'play takes a menu choice' unless ref $menuchoice eq 'ARRAY';
  my ($text, $index) = @$menuchoice;
  my ($action) = split ' ', lc $text;
  my $copy = $self->clone;
  if ($action eq 'claim') {
    my $card = splice($self->reward->@*, $index, 1);
    push $self->reward->@*, shift $self->reward_deck->@*
      if $self->reward_deck && $self->reward_deck->@*;
    $self->spend($card->cost);
    $self->scored($card->benefit);
  } elsif ($action eq 'purchase') {
    my $card = splice($self->market->@*, $index, 1);
    push $self->market->@*, shift $self->deck->@* if $self->deck && $self->deck->@*;
    push $self->hand->@*, $card;
    my $mcubes = splice($self->market_cubes->@*, $index, 1);
    push $self->market_cubes->@*, '';
    $self->earn($mcubes);
  } elsif ($action eq 'play' || $action eq 'convert') {
    my $card = splice($self->hand->@*, $index, 1);
    push $self->discard->@*, $card;
    my ($cost, $benefit) = ($card->cost, $card->benefit);
    if ($card->is_conversion) {
      croak 'text unexpected' unless $text =~ /([YGB]+)->([GBP]+)/;
      ($cost, $benefit) = ($1, $2);
    }
    $self->spend($cost);
    $self->earn($benefit);
  } elsif ($action eq 'reclaim') {
    push $self->hand->@*, $self->discard->@*;
    $self->discard([]);
  }
}



sub sample {
  my %gstate = (
    cubes => 'yygb',
    hand => [[113=>44],[44=>12333],[33=>1124],[33=>11222],[333=>444],[33=>224],[11=>3],[222=>333],[__=>11]],
    discard => [[11]],
    reward => [[ggbbpp=>19],[yyybb=>9],[ggbbb=>13],[pppp=>16],[gggpp=>14]],
    market => [[gg=>1113],[p=>1113],[gg=>33],[4],[yyy=>222]],
    market_cubes => ['y', ('')x4],
  );
  return __PACKAGE__->new(%gstate);
}


1;

