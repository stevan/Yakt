#!/usr/bin/env perl

use v5.40;
use experimental qw[ class ];

use open ':std', ':encoding(UTF-8)';

use lib 'lib';

use Yakt::System;

# =============================================================================
# Messages
# =============================================================================

class Tick :isa(Yakt::Message) {}

class QueryState :isa(Yakt::Message) {
    field $generation :param :reader;
}

class ReportState :isa(Yakt::Message) {
    field $x :param :reader;
    field $y :param :reader;
    field $alive :param :reader;
    field $age :param :reader;
    field $generation :param :reader;
}

class ComputeNextState :isa(Yakt::Message) {
    field $live_neighbors :param :reader;
}

class SetNeighbors :isa(Yakt::Message) {
    field $neighbors :param :reader;
}

# =============================================================================
# Display - terminal rendering with colors
# =============================================================================

class Display {
    field $width  :param;
    field $height :param;

    my $RESET       = "\e[0m";
    my $HOME_CURSOR = "\e[H";
    my $DEAD_CELL   = "\e[90m\N{MIDDLE DOT}\e[0m";  # gray dot

    # Age-based colors: young (green) -> mature (yellow) -> old (red/orange)
    my @AGE_COLORS = (
        "\e[38;2;0;255;0m",      # 0: bright green (newborn)
        "\e[38;2;50;255;0m",     # 1: green-yellow
        "\e[38;2;100;255;0m",    # 2: yellow-green
        "\e[38;2;150;255;0m",    # 3: lime
        "\e[38;2;200;255;0m",    # 4: yellow-lime
        "\e[38;2;255;255;0m",    # 5: yellow
        "\e[38;2;255;200;0m",    # 6: gold
        "\e[38;2;255;150;0m",    # 7: orange
        "\e[38;2;255;100;0m",    # 8: red-orange
        "\e[38;2;255;50;0m",     # 9+: red (ancient)
    );

    method clear_screen { print "\e[2J" }
    method hide_cursor  { print "\e[?25l" }
    method show_cursor  { print "\e[?25h" }
    method home_cursor  { print $HOME_CURSOR }

    method cell_color ($age) {
        my $idx = $age > $#AGE_COLORS ? $#AGE_COLORS : $age;
        return $AGE_COLORS[$idx] . "\N{FULL BLOCK}" . $RESET;
    }

    method render ($grid, $ages, $stats) {
        my @lines;

        # Status bar with enhanced metrics
        my $status = sprintf(
            "Gen: %d | Live: %d | Actors: %d | Msgs: %d (%.0f/s) | FPS: %.1f (target: %.0f)",
            $stats->{generation},
            $stats->{live_count},
            $stats->{actor_count},
            $stats->{msg_count},
            $stats->{msgs_per_sec},
            $stats->{fps},
            $stats->{target_fps},
        );
        push @lines => $status;
        push @lines => "Ctrl+C to quit";
        push @lines => "";

        for my $y (0 .. $height - 1) {
            my $line = "";
            for my $x (0 .. $width - 1) {
                if ($grid->[$y][$x]) {
                    $line .= $self->cell_color($ages->[$y][$x] // 0);
                } else {
                    $line .= $DEAD_CELL;
                }
            }
            push @lines => $line;
        }

        print $HOME_CURSOR, join("\n", @lines), "\n", $RESET;
    }
}

# =============================================================================
# Cell Actor - each cell is an independent actor
# =============================================================================

class Cell :isa(Yakt::Actor) {
    field $x :param;
    field $y :param;
    field $alive :param = 0;
    field $age = 0;

    field @neighbors;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        # Cell is ready
    }

    method set_neighbors :Receive(SetNeighbors) ($context, $message) {
        @neighbors = $message->neighbors->@*;
    }

    method query_state :Receive(QueryState) ($context, $message) {
        $message->reply_to->send(ReportState->new(
            x          => $x,
            y          => $y,
            alive      => $alive,
            age        => $age,
            generation => $message->generation,
        ));
    }

    method compute_next :Receive(ComputeNextState) ($context, $message) {
        my $live = $message->live_neighbors;

        # Conway's rules:
        # 1. Live cell with 2-3 neighbors survives
        # 2. Dead cell with exactly 3 neighbors becomes alive
        # 3. All other cells die or stay dead
        my $was_alive = $alive;

        if ($alive) {
            $alive = ($live == 2 || $live == 3) ? 1 : 0;
        } else {
            $alive = ($live == 3) ? 1 : 0;
        }

        # Update age
        if ($alive) {
            $age = $was_alive ? $age + 1 : 0;  # increment if surviving, reset if newborn
        } else {
            $age = 0;  # dead cells have no age
        }
    }
}

# =============================================================================
# World Actor - coordinates the simulation
# =============================================================================

class World :isa(Yakt::Actor) {
    use Time::HiRes qw(time);

    field $width  :param;
    field $height :param;
    field $tick_interval :param = 0.2;
    field $initial_pattern :param = 'glider';

    field @cells;       # 2D array of cell refs
    field $display;
    field $generation = 0;
    field $live_count = 0;

    field @pending_reports;
    field $expected_reports;

    # FPS tracking
    field $last_render_time;
    field $current_fps = 0;
    field @fps_samples;  # rolling average for smoother display

    # Message count tracking
    field $message_count = 0;
    field $last_msg_count = 0;
    field $msgs_per_sec = 0;
    field @mps_samples;  # rolling average for smoother display

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $display = Display->new(width => $width, height => $height);
        $display->hide_cursor;
        $display->clear_screen;

        # Spawn all cells
        for my $y (0 .. $height - 1) {
            for my $x (0 .. $width - 1) {
                my $cell = $context->spawn(Yakt::Props->new(
                    class => 'Cell',
                    args  => { x => $x, y => $y, alive => 0 },
                ));
                $cells[$y][$x] = $cell;
            }
        }

        # Set up neighbors for each cell (toroidal wrap)
        for my $y (0 .. $height - 1) {
            for my $x (0 .. $width - 1) {
                my @neighbors;
                for my $dy (-1, 0, 1) {
                    for my $dx (-1, 0, 1) {
                        next if $dx == 0 && $dy == 0;
                        my $nx = ($x + $dx) % $width;
                        my $ny = ($y + $dy) % $height;
                        push @neighbors => $cells[$ny][$nx];
                    }
                }
                $cells[$y][$x]->send(SetNeighbors->new(neighbors => \@neighbors));
            }
        }

        # Set initial pattern
        $self->set_pattern($initial_pattern);

        # Start the tick loop
        $expected_reports = $width * $height;
        $context->schedule(after => 0.1, callback => sub {
            $context->self->send(Tick->new);
        });
    }

    method set_pattern ($pattern) {
        my @coords;

        if ($pattern eq 'glider') {
            my $ox = int($width / 4);
            my $oy = int($height / 4);
            @coords = (
                [$ox+1, $oy], [$ox+2, $oy+1], [$ox, $oy+2], [$ox+1, $oy+2], [$ox+2, $oy+2]
            );
        }
        elsif ($pattern eq 'blinker') {
            my $ox = int($width / 2);
            my $oy = int($height / 2);
            @coords = ([$ox, $oy-1], [$ox, $oy], [$ox, $oy+1]);
        }
        elsif ($pattern eq 'pulsar') {
            my $ox = int($width / 2) - 6;
            my $oy = int($height / 2) - 6;
            # Pulsar pattern (period 3 oscillator)
            my @rel = (
                [2,0],[3,0],[4,0],[8,0],[9,0],[10,0],
                [0,2],[5,2],[7,2],[12,2],
                [0,3],[5,3],[7,3],[12,3],
                [0,4],[5,4],[7,4],[12,4],
                [2,5],[3,5],[4,5],[8,5],[9,5],[10,5],
                [2,7],[3,7],[4,7],[8,7],[9,7],[10,7],
                [0,8],[5,8],[7,8],[12,8],
                [0,9],[5,9],[7,9],[12,9],
                [0,10],[5,10],[7,10],[12,10],
                [2,12],[3,12],[4,12],[8,12],[9,12],[10,12],
            );
            @coords = map { [$ox + $_->[0], $oy + $_->[1]] } @rel;
        }
        elsif ($pattern eq 'glider_gun') {
            my $ox = 2;
            my $oy = 2;
            @coords = (
                [$ox+0, $oy+4], [$ox+0, $oy+5], [$ox+1, $oy+4], [$ox+1, $oy+5],
                [$ox+10, $oy+4], [$ox+10, $oy+5], [$ox+10, $oy+6],
                [$ox+11, $oy+3], [$ox+11, $oy+7],
                [$ox+12, $oy+2], [$ox+12, $oy+8],
                [$ox+13, $oy+2], [$ox+13, $oy+8],
                [$ox+14, $oy+5],
                [$ox+15, $oy+3], [$ox+15, $oy+7],
                [$ox+16, $oy+4], [$ox+16, $oy+5], [$ox+16, $oy+6],
                [$ox+17, $oy+5],
                [$ox+20, $oy+2], [$ox+20, $oy+3], [$ox+20, $oy+4],
                [$ox+21, $oy+2], [$ox+21, $oy+3], [$ox+21, $oy+4],
                [$ox+22, $oy+1], [$ox+22, $oy+5],
                [$ox+24, $oy+0], [$ox+24, $oy+1], [$ox+24, $oy+5], [$ox+24, $oy+6],
                [$ox+34, $oy+2], [$ox+34, $oy+3], [$ox+35, $oy+2], [$ox+35, $oy+3],
            );
        }
        elsif ($pattern eq 'spaceship') {
            # Lightweight spaceship (LWSS)
            my $ox = int($width / 4);
            my $oy = int($height / 2);
            @coords = (
                [$ox+1, $oy], [$ox+4, $oy],
                [$ox, $oy+1],
                [$ox, $oy+2], [$ox+4, $oy+2],
                [$ox, $oy+3], [$ox+1, $oy+3], [$ox+2, $oy+3], [$ox+3, $oy+3],
            );
        }
        elsif ($pattern eq 'random') {
            for my $y (0 .. $height - 1) {
                for my $x (0 .. $width - 1) {
                    push @coords => [$x, $y] if rand() < 0.3;
                }
            }
        }
        elsif ($pattern eq 'acorn') {
            # Acorn - small pattern that takes 5206 generations to stabilize
            my $ox = int($width / 2) - 3;
            my $oy = int($height / 2);
            @coords = (
                [$ox+1, $oy], [$ox+3, $oy+1],
                [$ox, $oy+2], [$ox+1, $oy+2], [$ox+4, $oy+2], [$ox+5, $oy+2], [$ox+6, $oy+2],
            );
        }
        elsif ($pattern eq 'r_pentomino') {
            # R-pentomino - only 5 cells but runs for 1103 generations
            # Creates massive chaos before stabilizing
            my $ox = int($width / 2);
            my $oy = int($height / 2);
            @coords = (
                [$ox+1, $oy], [$ox+2, $oy],
                [$ox, $oy+1], [$ox+1, $oy+1],
                [$ox+1, $oy+2],
            );
        }
        elsif ($pattern eq 'diehard') {
            # Diehard - disappears after 130 generations
            my $ox = int($width / 2) - 4;
            my $oy = int($height / 2);
            @coords = (
                [$ox+6, $oy],
                [$ox, $oy+1], [$ox+1, $oy+1],
                [$ox+1, $oy+2], [$ox+5, $oy+2], [$ox+6, $oy+2], [$ox+7, $oy+2],
            );
        }
        elsif ($pattern eq 'lidka') {
            # Lidka - runs for 29,053 generations! (needs big grid ~150x150)
            my $ox = int($width / 2) - 6;
            my $oy = int($height / 2) - 2;
            @coords = (
                [$ox+1, $oy],
                [$ox+3, $oy+1],
                [$ox, $oy+2], [$ox+1, $oy+2],
                [$ox+3, $oy+2], [$ox+4, $oy+2], [$ox+5, $oy+2],
                [$ox+10, $oy+2], [$ox+11, $oy+2], [$ox+12, $oy+2],
                [$ox+10, $oy+3],
                [$ox+11, $oy+4],
            );
        }
        elsif ($pattern eq 'rabbits') {
            # Rabbits - exponential growth pattern, fills the grid with chaos
            my $ox = int($width / 2) - 3;
            my $oy = int($height / 2) - 1;
            @coords = (
                [$ox, $oy], [$ox+4, $oy], [$ox+5, $oy], [$ox+6, $oy],
                [$ox, $oy+1], [$ox+1, $oy+1], [$ox+2, $oy+1], [$ox+5, $oy+1],
                [$ox+1, $oy+2],
            );
        }
        elsif ($pattern eq 'infinite1') {
            # Infinite growth pattern 1 - grows forever
            my $ox = int($width / 2) - 4;
            my $oy = int($height / 2) - 2;
            @coords = (
                [$ox+6, $oy], [$ox+4, $oy+1], [$ox+6, $oy+1], [$ox+7, $oy+1],
                [$ox+4, $oy+2], [$ox+6, $oy+2],
                [$ox+4, $oy+3],
                [$ox+2, $oy+4],
                [$ox, $oy+5], [$ox+2, $oy+5],
            );
        }
        elsif ($pattern eq 'infinite2') {
            # 5x5 infinite growth pattern
            my $ox = int($width / 2) - 2;
            my $oy = int($height / 2) - 2;
            @coords = (
                [$ox, $oy], [$ox+1, $oy], [$ox+2, $oy], [$ox+4, $oy],
                [$ox, $oy+1],
                [$ox+3, $oy+2], [$ox+4, $oy+2],
                [$ox+1, $oy+3], [$ox+2, $oy+3], [$ox+4, $oy+3],
                [$ox, $oy+4], [$ox+2, $oy+4], [$ox+4, $oy+4],
            );
        }
        elsif ($pattern eq 'noah') {
            # Noah's Ark - a large, chaotic methuselah
            my $ox = int($width / 2) - 8;
            my $oy = int($height / 2) - 3;
            @coords = (
                [$ox, $oy], [$ox+1, $oy], [$ox+8, $oy], [$ox+9, $oy], [$ox+10, $oy], [$ox+16, $oy],
                [$ox, $oy+1], [$ox+8, $oy+1], [$ox+10, $oy+1], [$ox+14, $oy+1], [$ox+16, $oy+1],
                [$ox+1, $oy+2], [$ox+9, $oy+2], [$ox+14, $oy+2], [$ox+15, $oy+2], [$ox+16, $oy+2],
                [$ox+5, $oy+4], [$ox+6, $oy+4],
                [$ox+5, $oy+5],
                [$ox+6, $oy+6],
            );
        }
        elsif ($pattern eq 'blom') {
            # Blom - chaotic pattern that runs for thousands of generations
            my $ox = int($width / 2) - 7;
            my $oy = int($height / 2) - 2;
            @coords = (
                [$ox, $oy], [$ox+2, $oy],
                [$ox+1, $oy+1],
                [$ox+4, $oy+2],
                [$ox+5, $oy+3], [$ox+6, $oy+3], [$ox+7, $oy+3],
                [$ox+8, $oy+3], [$ox+9, $oy+3], [$ox+10, $oy+3], [$ox+11, $oy+3],
                [$ox+12, $oy+3], [$ox+13, $oy+3], [$ox+14, $oy+3],
            );
        }

        # Send initial alive state
        for my $coord (@coords) {
            my ($x, $y) = @$coord;
            next if $x < 0 || $x >= $width || $y < 0 || $y >= $height;
            $cells[$y][$x]->send(ComputeNextState->new(live_neighbors => 3));
        }
    }

    method tick :Receive(Tick) ($context, $message) {
        $message_count++;  # Count incoming Tick message

        # Query all cells for their current state
        @pending_reports = ();

        for my $y (0 .. $height - 1) {
            for my $x (0 .. $width - 1) {
                $cells[$y][$x]->send(QueryState->new(
                    reply_to   => $context->self,
                    generation => $generation,
                ));
                $message_count++;  # Count outgoing QueryState message
            }
        }
    }

    method report_state :Receive(ReportState) ($context, $message) {
        push @pending_reports => $message;
        $message_count++;  # Count incoming ReportState message

        if (@pending_reports == $expected_reports) {
            # Calculate FPS and msgs/sec
            my $now = time;
            if (defined $last_render_time) {
                my $elapsed = $now - $last_render_time;
                my $instant_fps = $elapsed > 0 ? 1 / $elapsed : 0;

                # Rolling average over 5 samples for smoother display
                push @fps_samples, $instant_fps;
                shift @fps_samples if @fps_samples > 5;
                $current_fps = 0;
                $current_fps += $_ for @fps_samples;
                $current_fps /= @fps_samples;

                # Calculate msgs/sec
                my $msgs_this_frame = $message_count - $last_msg_count;
                my $instant_mps = $elapsed > 0 ? $msgs_this_frame / $elapsed : 0;

                push @mps_samples, $instant_mps;
                shift @mps_samples if @mps_samples > 5;
                $msgs_per_sec = 0;
                $msgs_per_sec += $_ for @mps_samples;
                $msgs_per_sec /= @mps_samples;
            }
            $last_render_time = $now;
            $last_msg_count = $message_count;

            # All reports in - render and compute next generation
            my @grid;
            my @ages;
            my %alive_cells;
            $live_count = 0;

            for my $report (@pending_reports) {
                my ($x, $y, $alive, $age) = ($report->x, $report->y, $report->alive, $report->age);
                $grid[$y][$x] = $alive;
                $ages[$y][$x] = $age;
                if ($alive) {
                    $alive_cells{"$x,$y"} = 1;
                    $live_count++;
                }
            }

            # Render with enhanced stats
            my $actor_count = ($width * $height) + 1;  # cells + world
            $display->render(\@grid, \@ages, {
                generation  => $generation,
                live_count  => $live_count,
                actor_count => $actor_count,
                msg_count   => $message_count,
                msgs_per_sec => $msgs_per_sec,
                fps         => $current_fps,
                target_fps  => 1 / $tick_interval,
            });

            # Compute next state for each cell
            for my $y (0 .. $height - 1) {
                for my $x (0 .. $width - 1) {
                    my $live_neighbors = 0;
                    for my $dy (-1, 0, 1) {
                        for my $dx (-1, 0, 1) {
                            next if $dx == 0 && $dy == 0;
                            my $nx = ($x + $dx) % $width;
                            my $ny = ($y + $dy) % $height;
                            $live_neighbors++ if $alive_cells{"$nx,$ny"};
                        }
                    }
                    $cells[$y][$x]->send(ComputeNextState->new(
                        live_neighbors => $live_neighbors
                    ));
                    $message_count++;  # Count outgoing ComputeNextState message
                }
            }

            $generation++;
            @pending_reports = ();

            # Schedule next tick
            $context->schedule(after => $tick_interval, callback => sub {
                $context->self->send(Tick->new);
            });
        }
    }

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        $display->show_cursor;
        print "\e[0m";  # reset colors
    }
}

# =============================================================================
# Main
# =============================================================================

my $width   = $ARGV[0] // 40;
my $height  = $ARGV[1] // 20;
my $pattern = $ARGV[2] // 'glider';
my $speed   = $ARGV[3] // 0.1;

say "Game of Life - ${width}x${height} - pattern: $pattern - speed: ${speed}s";
say "";
say "Patterns:";
say "  Simple:    glider, blinker, pulsar, spaceship";
say "  Guns:      glider_gun";
say "  Chaos:     r_pentomino, acorn, diehard, rabbits";
say "  Long-lived: lidka (29K gens), noah, blom";
say "  Infinite:  infinite1, infinite2, random";
say "";
say "Press Ctrl+C to quit";
say "";

# Global reference to system for signal handler
my $system;

$SIG{INT} = sub {
    print "\e[?25h";  # show cursor
    print "\e[0m";    # reset colors
    print "\n\nExiting...\n";
    $system->shutdown if $system;
};

$system = Yakt::System->new->init(sub ($context) {
    $context->spawn(Yakt::Props->new(
        class => 'World',
        args  => {
            width           => $width,
            height          => $height,
            tick_interval   => $speed,
            initial_pattern => $pattern,
        },
    ));
});

$system->loop_until_done;

# Cleanup on normal exit
print "\e[?25h\e[0m";
