
package Matchem::Game;

use strict;

$Matchem::Game::nodelay = 0;

my $app = $main::app;
my $event = $main::event;
my $all = $main::all;

my $img_box = main::loadimg("box_open");
my $img_boxhilite = main::loadimg("box_highlight");
my $img_boxclosed = main::loadimg("box_closed");
#my $img_boxclosed = main::loadimg("box_dim"); # TEMP! (show tiles)
my $img_topbox = main::loadimg("topbox");
my $img_minilogo = main::loadimg("minilogo");

my $bgcolor = $img_box->pixel(0,0);
my $emptycolor = $img_box->pixel(10,10);

$img_box->set_color_key(main::SDL_SRCCOLORKEY,$emptycolor);
#$img_boxclosed->set_color_key(main::SDL_SRCCOLORKEY,$img_boxclosed->pixel(10,10)); # TEMP!
$img_boxhilite->set_color_key(main::SDL_SRCCOLORKEY,$emptycolor);
$img_topbox->set_color_key(main::SDL_SRCCOLORKEY,$emptycolor);

my $font_ph = new SDL::Tool::Font 
                -normal => 1,
                -ttfont => main::datafile("data/trebuc.ttf"), 
                -size => 20,
                -fg => $SDL::Color::white,
                -bg => $SDL::Color::black;

my $font_big = new SDL::Tool::Font 
                -normal => 1,
                -ttfont => main::datafile("data/trebuc.ttf"), 
                -size => 28,
                -fg => $SDL::Color::white,
                -bg => $SDL::Color::black;

my @openbox = ();
my $cp;

my $font_score;
my $score_spacing;
my $score_start;
my $score_marker;
my $score_digwid;

my @box;
my @tile;
for (my $i = 29; $i >= 0; $i--) {
    my $zp = $i < 10 ? "0$i" : $i;
    #next unless -f "data/graphics/tile$zp.png";
    $tile[$i] = main::loadimg("tile$zp");
}


sub game {
    my @players = @_;

    srand;

    $box[$_] = { state => 0, index => $_ } for (0 .. 59);

    for (my $i = 29; $i >= 0; $i--) {
        while (1) {
            my $dbox = int(rand(60));
            unless (defined $box[$dbox]->{tile}) {
                $box[$dbox]->{tile} = $i;
                last;
            }
        }
        while (1) {
            my $dbox = int(rand(60));
            unless (defined $box[$dbox]->{tile}) {
                $box[$dbox]->{tile} = $i;
                last;
            }
        }
    }

    @openbox = ();

    $cp = 0;


    if (@players == 3) {
        $font_score = new SDL::Tool::Font 
                        -normal => 1,
                        -ttfont => main::datafile("data/trebuc.ttf"), 
                        -size => 10,
                        -fg => $SDL::Color::white,
                        -bg => $SDL::Color::black;
        $score_spacing = 11;
        $score_start = 2;
        $score_digwid = 5;
        $score_marker = main::loadimg("marker_small");
    }
    else {
        $font_score = new SDL::Tool::Font 
                        -normal => 1,
                        -ttfont => main::datafile("data/trebuc.ttf"), 
                        -size => 16,
                        -fg => $SDL::Color::white,
                        -bg => $SDL::Color::black;
        $score_spacing = 17;
        $score_start = 1;
        $score_digwid = 8;
        $score_marker = main::loadimg("marker_big");
    }

    my $found = 0;

    GAME:
    while (1) {

        if (@openbox == 2) {
           if ($openbox[0]->{tile} == $openbox[1]->{tile}) {
               my $tile = $openbox[0]->{tile};
               if ($tile == 0) { $players[$cp][1] += 2; }
               elsif ($tile == 1) { $players[$cp][1] += 3; }
               elsif ($tile == 2) { $players[$cp][1] += 4; }
               else { $players[$cp][1]++; }
               $found++;
               if ($found == 30) {
                   return gameend(\@players, \@box);
               }
           }
           else {
               $openbox[0]->{state} = 0;
               $openbox[1]->{state} = 0;
               $cp++;
               $cp = 0 if ($cp == @players);
           }
           
           foreach my $p (@players) {
               if (my $bot = $p->[2]) {
                   foreach my $box (@openbox) {
                       $bot->remember($box->{tile}, $box->{index});
                   }
               }
           }
           
           @openbox = ();
           $app->delay(500) unless $Matchem::Game::nodelay;
           main::eatevents();
        }
        else {
            if (my $bot = $players[$cp]->[2]) {
                my $ailoop = 0;
                TRYAGAIN:
                if ($ailoop > 3) {
                    $font_ph->print($app, 267, 0, "AI JAM");
                    $font_ph->print($app, 267, 19, "This is a bug :(");
                    $app->flip();
                }
                $app->delay(500) unless $Matchem::Game::nodelay;
                main::eatevents();
                my $move = $bot->makemove(\@box, \@openbox);
                if ($move > 59) {
                    print "AI Move out of range. Let's try again.\n";
                    $ailoop++;
                    goto TRYAGAIN;
                }
                if ($box[$move]->{state} != 0) {
                    print "AI's chosen box is already open. Let's try again.\n";
                    $ailoop++;
                    goto TRYAGAIN;
                }
                $box[$move]->{state} = 1;
                push @openbox, $box[$move];                
            }
            else {
                $event->pump;
                if ($event->wait)
                {
                    my $etype=$event->type();

                    next GAME if $etype == main::SDL_MOUSEMOTION();

                    # handle quit events
                    exit(0) if ($etype == main::SDL_QUIT() );

                    if ($etype == main::SDL_KEYDOWN()) {
                        if ($event->key_sym() == main::SDLK_RSHIFT()) {
                            $Matchem::Game::nodelay = 1;
                        }
                    }
                    if ($etype == main::SDL_KEYUP()) {
                        if ($event->key_sym() == main::SDLK_RSHIFT()) {
                            $Matchem::Game::nodelay = 0;
                        }
                    }

                    if ($etype == main::SDL_MOUSEBUTTONDOWN()) {
                        next GAME unless $event->button() == 1;
                        my $x = $event->button_x();
                        my $y = $event->button_y();

                        next GAME unless $y > 48;

                        my $bx = int($x / 64);
                        my $by = int(($y - 48) / 72);
                        #next GAME unless $bx >= 0 && $bx <= 6;
                        my $bi = ($by * 10) + $bx;
                        next GAME unless $box[$bi]->{state} == 0;
                        $box[$bi]->{state} = 1;
                        push @openbox, $box[$bi];
                    }
                }
            }
        }

        $app->fill($all, $bgcolor);
        draw_topstuff(\@players);
        draw_all_boxes(\@box);

        $app->flip;

    }

}


sub draw_topstuff {
    my ($players) = @_;
    
    my $src = new SDL::Rect -x => 0, -y => 0, -width => 183, -height => 44;
    my $dest = new SDL::Rect -x => 0, -y => 0, -width => 183, -height => 44;

    $dest->x(261);
    $app->fill($dest, $emptycolor);
    $img_topbox->blit($src, $app, $dest);

    $dest->x(453);
    $app->fill($dest, $emptycolor);
    $img_topbox->blit($src, $app, $dest);

    my $y = $score_start;
    my $marker_dest = new SDL::Rect -x => 458, -y => 0, -width => $score_marker->width(), -height => $score_marker->height();
    my $marker_src = new SDL::Rect -x => 0, -y => 0, -width => $score_marker->width(), -height => $score_marker->height();
    my $pi = 0;
    foreach my $p (@$players) {
        my $score = $p->[1] + 0;
        $marker_dest->y($y);
        $score_marker->blit($marker_src, $app, $marker_dest) if $cp == $pi;
        $font_score->print($app, 470, $y, $p->[0]);
        $font_score->print($app, 628 - (length($score) * $score_digwid), $y, $score);
        $y += $score_spacing;
        $pi++;
    }

    $dest->x(28);
    $dest->y(10);
    $dest->width(199);
    $dest->height(31);
    $src->width(199);
    $src->height(31);

    $img_minilogo->blit($src, $app, $dest);

}

sub draw_all_boxes {
    my ($list) = @_;

    my $x = 5;
    my $y = 52;

    my $src = new SDL::Rect -x => 0, -y => 0, -width => 54, -height => 64;
    my $dest = new SDL::Rect -x => 0, -y => 0, -width => 54, -height => 64;

    for (my $i = 0; $i < 60; $i++) {
        $dest->x($x);
        $dest->y($y);

        $app->fill($dest, $emptycolor);
        my $t = $box[$i]->{tile};
        if (defined $t && defined $tile[$t]) {
            $tile[$t]->blit($src, $app, $dest);
        }
        else {
            $font_ph->print($app, $x + 10, $y + 10,"[$t]");
        }

        if ($box[$i]->{state} == 0) {
            $img_boxclosed->blit($src, $app, $dest);
        }
        else {
            if (($openbox[0] && $openbox[0]{index} == $i) ||
                ($openbox[1] && $openbox[1]{index} == $i)) {
                $img_boxhilite->blit($src, $app, $dest);
            }
            else {
                $img_box->blit($src, $app, $dest);
            }
        }

        $x += 64;
        if ($x > 584) {
            $y += 72;
            $x = 5;
        }
    }

}

sub gameend {
    my ($players, $boxes) = @_;

    my $infobox = main::loadimg("infobox");
    my $infobox_src = new SDL::Rect -x => 0, -y => 0, -width => 374, -height => 280;
    my $infobox_dst = new SDL::Rect -x => 133, -y => 124, -width => 374, -height => 280;

    my $pabox = main::loadimg("playagainbox");
    my $pabox_src = new SDL::Rect -x => 0, -y => 0, -width => 374, -height => 78;
    my $pabox_dst = new SDL::Rect -x => 133, -y => 326, -width => 374, -height => 78;

    my $box_dim = main::loadimg("box_dim");
    my $box_src = new SDL::Rect -x => 0, -y => 0, -width => 54, -height => 64;
    my $box_dst = new SDL::Rect -x => 0, -y => 0, -width => 54, -height => 64;

    my $winner = [0,0,0];
    my @winners = ();
    foreach my $p (@$players) {
       if ($p->[1] > $winner->[1]) {
           @winners = ( $p );
           $winner = $p;
       }
       elsif ($p->[1] == $winner->[1]) {
           push @winners, $p;
       }
    }

    FRAME:
    while (1) {

        $app->fill($all, $bgcolor);
        draw_topstuff($players);
        draw_all_boxes($app, $boxes);

        my $x = 5;
        my $y = 52;

        for (my $i = 0; $i < 60; $i++) {
            $box_dst->x($x);
            $box_dst->y($y);

            $box_dim->blit($box_src, $app, $box_dst);

            $x += 64;
            if ($x > 584) {
                $y += 72;
                $x = 5;
            }
        }


        $infobox->blit($infobox_src, $app, $infobox_dst);
        $pabox->blit($pabox_src, $app, $pabox_dst);

        if (@winners == 1) {
            #print "The end! $winner->[0] won!\n";
            $font_big->print($app, 143, 164, "$winner->[0] wins!");
        }
        else {
            $font_big->print($app, 143, 164, "It's a draw!");
        }

        $app->flip;

        $event->pump;
        if ($event->wait)
        {
                my $etype=$event->type();

                next FRAME if $etype == main::SDL_MOUSEMOTION();

                # handle quit events
                exit() if ($etype == main::SDL_QUIT() );
                
                if ($etype == main::SDL_MOUSEBUTTONDOWN()) {
                    next FRAME unless $event->button() == 1;
                    my $x = $event->button_x();
                    my $y = $event->button_y();

                    next FRAME unless $y > 375 && $y < 397;
                    next FRAME unless $x > 249 && $x < 390;

                    return 1 if ($x < 317);
                    return 0 if ($x > 322);

                    next FRAME;

                }
        }

    }
}

1;
