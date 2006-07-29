
# Match Them Up
# A simple game of "pairs" by Martin Atkins

use strict;
#use warnings;
use SDL;
use SDL::App;
use SDL::Surface;
use SDL::Event;
use SDL::Tool::Font;

# Silly Hack: Add a few different colour schemes
#     by filtering components from the images as they
#     load. Pretty slow and crappy, though, and it
#     won't catch all of the colours right now.
my %clrfilters = (
    'sleekgrey' => [ 'g', 'g', 'g' ],
    'hot' => [ 'r', 'g', 0 ],
    'terminal' => [ 0, 'g', 0 ],
    'cga' => [ 0, 'g', 'b' ],
    'redwhite', [ 'r', 'g', 'g' ],
    'teal' => ['r', 'r', 'g'],
);

$main::filter = undef;

$main::app = new SDL::App(-width => 640, -height => 480, -depth => 32,
                       -title => "Match Them Up",
                       -icon => loadimg("icon"));

$main::event = new SDL::Event();
$main::all = new SDL::Rect( -height => 480, -width => 640 ); 


require 'ai.pl';
require 'menu.pl';
require 'game.pl';

while (1) {
    my @players = Matchem::Menu::menu();
    my $pa = 1;
    while ($pa) {
        # Reset scores to zero
        foreach (@players) {
            $_->[1] = 0;
            $_->[2]->reset() if defined $_->[2]; # Reset AI
        }
        
        $pa = Matchem::Game::game(@players);
    }
}


# 133 # 326

sub loadimg {

    my $fn;

    if (defined $PerlApp::VERSION) {
        $fn = PerlApp::extract_bound_file("data/graphics/$_[0].png");
    }
    else {
        $fn = "data/graphics/$_[0].png";
    }

    return undef unless defined $fn;
    return undef unless -f $fn;

    my $img = new SDL::Surface -name => $fn;
    
    if (defined $main::filter) {
        print "Applying Filter to $_[0]...";
        my $w = $img->width();
        my $h = $img->height();
        
        for (my $x = 0; $x < $w; $x++) {
            for (my $y = 0; $y < $h; $y++) {
                $img->pixel($x, $y, filterclr($img->pixel($x, $y)));
            }        
        }
        print "Done!\n";
    }
    
    return $img;
}

sub filterclr {
    return unless defined $main::filter;

    my ($clr) = @_;
    
    my $r = $clr->r();
    my $g = $clr->g();
    my $b = $clr->b();
    
    my @clr = ();
    
    for (my $i = 0; $i < 3; $i++) {
        if ($main::filter->[$i] == 0) {
            push @clr, 0;
        }
        elsif ($main::filter->[$i] == 'r') {
            push @clr, $r;
        }
        elsif ($main::filter->[$i] == 'g') {
            push @clr, $g;
        }
        elsif ($main::filter->[$i] == 'b') {
            push @clr, $b;
        }
    }
    
    return new SDL::Color(-r => $clr[0], -g => $clr[1], -b => $clr[2]);
}

# Just eat up all the queued events ... except QUIT
sub eatevents {
    $main::event->pump();
    
    while ($main::event->poll()) {
        my $etype = $main::event->type();
    
        exit(0) if ($etype == main::SDL_QUIT() );

        if ($etype == main::SDL_KEYDOWN()) {
            if ($main::event->key_sym() == main::SDLK_RSHIFT()) {
                $Matchem::Game::nodelay = 1;
            }
        }
        if ($etype == main::SDL_KEYUP()) {
            if ($main::event->key_sym() == main::SDLK_RSHIFT()) {
                $Matchem::Game::nodelay = 0;
            }
        }
        
    }

}

sub datafile {
    if (defined $PerlApp::VERSION) {
        return PerlApp::extract_bound_file($_[0]);
    }
    else {
        return $_[0];
    }
}
