
package Matchem::Bot;

use strict;

# A general AI "bot" for playing Match Them Up
#
# Each instance has a "memory" of cards it has scene recently
# with a value indicating the "time to live" of that memory item.
# This time-to-live is increased each time the card is seen by
# (card value * memory multiplier), so the player will remember
# the bonus cards for longer than the standard cards.
#
# There are several settings affecting the skill of the AI player:
#    memmult - The memory multiplier affecting how long memory items last
#    simchance - The chance of accidentally picking a similar-looking card, from 0 to 1
#    offchance - The chance of accidentally choosing an adjacent card
#    offthres - The threshold that the memory TTL must be below for offchance to be considered
#
# The 'memory' field is set up as follows:
#    hash of tile numbers -> hashref of known positions -> TTL

# Which cards are similar to which other cards?
my %similar = (
    9 => 10,
    10 => 9,
    11 => 12,
    12 => 11,
    28 => 29,
    29 => 28,
);

sub new {
    my ($class, $memmult, $simchance, $offchance, $offthres) = @_;

    my $ret = {
        'memmult' => $memmult,
        'simchance' => $simchance,
        'offchance' => $offchance,
        'offthres' => $offthres,
        'memory' => {},
        'mixmemory' => {},  # Memory of mixups to avoid making them over and over
    };
    return bless $ret, $class;
}

# Ready the AI for the next game
# Depending on the simchance setting, some memories
# might be left behind to simulate the human problem
# of remembering the previous game's positions.
sub reset {
    my ($self) = @_;

    my $memory = $self->{memory};
    foreach my $m (keys %$memory) {
        if (rand(1) > $self->{simchance}) {
            delete $memory->{$m};
        }
    }
    
    $self->{mixmemory} = {};
}

sub remember {
    my ($self, $tile, $box) = @_;
    
    if ($tile > 29) {
        #print "**** ACK! TILE OUT OF RANGE! ****";
    }
    if ($box > 59) {
        #print "**** ACK! BOX OUT OF RANGE! ****";
    }
    
    my $memory = $self->{memory};
    
    # First decrement all of the memory TTLs
    foreach my $t (keys %$memory) {
        my $thismem = $memory->{$t};
        foreach my $l (keys %$thismem) {
            $thismem->{$l}-- if $thismem->{$l} > 0;
            if ($thismem->{$l} == 0) {
                delete $thismem->{$l};
                #print "I've forgotten what's in box $l (tile $t)\n";
            }
        }
    }
    
    my $mixmemory = $self->{mixmemory};
    # ...and the mixmemory TTLs
    foreach my $t (keys %$mixmemory) {
        $mixmemory->{$t}--;
        if ($mixmemory->{$t} == 0) {
            delete $mixmemory->{$t};
        }
    }
    
    my $value = 1;
    $value += 1 if $tile == 0;
    $value += 2 if $tile == 1;
    $value += 3 if $tile == 2;
    
    # It's easier to remember the corner and edge tiles
    # (corners will match two of these rules and thus get an extra score)
    $value += 1 if ($box % 10) == 0 || ($box % 10) == 9;
    $value += 1 if $box > 19;
    $value += 1 if $box < 10;

    $value *= $self->{memmult};
    
    $memory->{$tile}->{$box} += $value;
}

sub makemove {
    my ($self, $boxes, $open) = @_;
    
    my $memory = $self->{memory};

    # The general idea here is to build a list of candidate
    # moves with scores attached and then pick the best one.
    my @moves = ();
    
    # If there's already a box open, we want to try to
    # match it.
    if (scalar(@$open) == 1) {
        my $openbox = $open->[0]->{index};
        my $tile = $open->[0]->{tile};
        
        # Maybe get "confused" with a similar-looking tile
        if (defined $similar{$tile} && ! defined $self->{'mixmemory'}->{$similar{tile}}) {
            if (rand(1) < $self->{simchance}) {
                $self->{'mixmemory'}->{$similar{$tile}} = 2 * $self->{memmult};
                $tile = $similar{$tile};
            }
        }
        
        my $options = $memory->{$tile};
        
        if (ref $options eq 'HASH') {
            foreach my $cb (keys %$options) {
                #print "$cb is a candidate...";
                next if $boxes->[$cb]->{state} != 0;
                if ($cb != $openbox) {
                    #print "Success!";
                    push @moves, [$cb, 255, $options->{$cb} ];  # Making a pair always wins
                }
                #print "\n";
            }
        }
    } else {
        # Find all known pairs
        foreach my $t (keys %$memory) {
            if (scalar(%{$memory->{$t}}) == 2) {
                my $score = 10;
                $score += 1 if $t == 0;
                $score += 2 if $t == 1;
                $score += 3 if $t == 2;
                my @options = keys(%{$memory->{$t}});
                next if $boxes->[$options[0]]->{state} != 0;
                push @moves, [ $options[0], $score, $memory->{$t}->{$options[0]} ];
            }
        }
    }
    
    
    # If there are no candidates yet, push everything we don't know about onto
    # the possibility list.
    unless (@moves) {
        for (my $i = 0; $i < 60; $i++) {
            next if $boxes->[$i]->{state} != 0;
            my $tile = $boxes->[$i]->{tile};
            push @moves, [ $i, 1, 0 ] unless $memory->{$tile}->{$i};
        }
    }
    
    # TODO: use the memory TTLs included in the third move member to introduce
    #      similarity and proximity mistakes.

    if (@moves) {
        my @moves = sort({ $b->[1] <=> $a->[1] } @moves);
        # FIXME: make sure this is sorting in the right order!
        
        my $highest = $moves[0]->[1];
        #print "Highest score is $highest\n";
        #my @moves = grep({ $_->[1] == $highest } @moves);
        
        my $choice = $moves[int(rand($#moves))];

        # TODO: Pick one of the probably-many options with the highest score
        #     at random rather than just taking the topmost

        #print "Picking $choice->[0] because it has score $choice->[1]\n";

        if ($boxes->[$choice->[0]]->{state} == 0) {
            return $choice->[0];
        }
        else {
            #print "Somehow I picked a door that is already open";
        }
    }
    
    
    # FIXME: Pick any card that isn't in the memory.
        
    #print "*shrug*\n";
        
    for (my $i = 0; $i < 60; $i++) {
        if ($boxes->[$i]->{state} == 0) { return $i; }
    }
}

1;
