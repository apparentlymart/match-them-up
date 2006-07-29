
package Matchem::Menu;

use strict;

my $app = $main::app;
my $event = $main::event;
my $all = $main::all;

# [ name, botparams ]
my @aiplayers = (
    [ "Mr Forget", [1, 0.8, 0.3, 2] ],
    [ "Mr Silly", [2, 0.7, 0.3, 2] ],
    [ "Mr Reasonable", [3, 0.5, 0.3, 2] ],
    [ "Mr Memory", [8, 0.4, 0.3, 2] ],
    [ "Mr Impossible", [64, 0.2, 0.3, 2] ],
);

my @playertypes = qw(None Human Computer);

my @sidetiles = qw(4 8 6 19 7 17 14 15 21 27);

my $img_logo = main::loadimg("mainlogo");
my $bgcolor = $img_logo->pixel(0,0);
my $img_sidebar = main::loadimg("menusidebar");
my $img_start = main::loadimg("menu_start");
my $img_row = main::loadimg("menu_row");

my $font_row = new SDL::Tool::Font 
                -normal => 1,
                -ttfont => main::datafile("data/trebuc.ttf"), 
                -size => 10,
                -fg => $SDL::Color::white,
                -bg => $SDL::Color::black;

my @players = (
    [ 1, 'Player 1' ],  # Nameless human
    [ 2, 2 ],           # AI at skill level 2
    [ 0, undef ],       # No third player
);

sub menu {

    my $typefocus = -1;

    FRAME:
    while (1) {

        $event->pump;
        $event->set_unicode(1);
        if ($event->wait)
        {
                my $etype=$event->type();

                next FRAME if $etype == main::SDL_MOUSEMOTION();

                # handle quit events
                exit() if ($etype == main::SDL_QUIT() );

                if ($etype == main::SDL_KEYDOWN()) {
                    next FRAME unless $typefocus != -1;
                    if ($main::event->key_sym() == main::SDLK_BACKSPACE()) {
                        $players[$typefocus][1] = substr($players[$typefocus][1], 0, -1)
                             if $players[$typefocus][1] ne '';
                    }
                    elsif (my $asc = $main::event->key_unicode()) {
                        next FRAME unless $asc < 128;
                        # handle ASCII-producing keys
                        $players[$typefocus][1] .= chr($asc);
                    }
                }

                if ($etype == main::SDL_MOUSEBUTTONDOWN()) {
                    next FRAME unless $event->button() == 1;
                                        
                    my $x = $event->button_x();
                    my $y = $event->button_y();
                    
                    # Unset focus (it might get set below, though)
                    $typefocus = -1;
                    
                    if ($y > 195 && $y < 275 && $x > 104 && $x < 533) {
                        my $row = int(($y - 196) / 26);

                        if ($x < 177) {
                            $players[$row][0] = ($players[$row][0] + 1) % 3;
                            
                            if ($players[$row][0] == 1) {
                                $players[$row][1] = "Player ".($row + 1);
                            }
                            elsif ($players[$row][0] == 2) {
                                $players[$row][1] = 2;
                            }
                        }
                        elsif ($x > 182) {
                            if ($players[$row][0] == 1) {
                                $typefocus = $row;
                            }
                            elsif ($players[$row][0] == 2) {
                                $players[$row][1] = ($players[$row][1] + 1) % @aiplayers;
                            }                            
                        }
                    }

                    next FRAME unless $y > 375 && $y < 397;
                    next FRAME unless $x > 249 && $x < 390;


                    my @ret;
                    
                    $Matchem::Game::nodelay = SDL::GetKeyState(main::SDLK_LSHIFT());
                    
                    foreach my $p (@players) {
                        my $type = $p->[0];
                        
                        if ($type == 1) {
                            push @ret, [ $p->[1], 0, undef ];
                        }
                        elsif ($type == 2) {
                            push @ret, [ $aiplayers[$p->[1]]->[0], 0, new Matchem::Bot(@{$aiplayers[$p->[1]]->[1]}) ];
                        }
                    }

                    next FRAME if @ret == 0;
                    
                    return @ret;

                    next FRAME;

                }
        }

        $app->fill($all, $bgcolor);
        blitimg($img_logo, 105, 15);
        blitimg($img_sidebar, 10, 0);
        blitimg($img_sidebar, 556, 0);

        blitimg($img_start, 269, 375);

        my $y = 200;
        my $row = 0;

        foreach my $p (@players) {
            blitimg($img_row, 105, $y);
            
            $font_row->print($app, 111, $y + 2, $playertypes[$p->[0]]);

            if ($p->[0] != 2) {
                # Blank out the arrow thingy to show it's now a type-in box
                $app->fill(new SDL::Rect( -x => 522, -y => $y + 4, -width => 7, -height => 10 ),
                           $SDL::Color::black);
            }
            
            if ($p->[0] == 1) {
                my $caption = $p->[1].($typefocus == $row ? '_' : '');
                $font_row->print($app, 189, $y + 2, $caption) if $caption ne '';
            }
            elsif ($p->[0] == 2) {
                $font_row->print($app, 189, $y + 2, $aiplayers[$p->[1]]->[0]);
            }
        
            $y += 26;
            $row++;
        }

        $app->flip;

    }

    
}

sub blitimg {
    my ($img, $x, $y) = @_;
    
    my $w = $img->width();
    my $h = $img->height();
    
    $img->blit(new SDL::Rect(-x => 0, -y => 0, -width => $w, -height => $h),
               $app, new SDL::Rect(-x => $x, -y => $y, -width => $w, -height => $h));
}

1;
