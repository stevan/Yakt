#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Logging::Logger {
    use Term::ReadKey qw[ GetTerminalSize ];
    use Time::HiRes   qw[ time ];

    our $TERM_WIDTH = (GetTerminalSize())[0];

    state %level_color_map = (
        1 => "\e[96m",
        2 => "\e[93m",
        3 => "\e[91m",
        4 => "\e[92m",
        5 => "\e[34m",
    );
    state %level_map = (
        1 => $level_color_map{1}.".o(INFO)\e[0m",
        2 => $level_color_map{2}."^^[WARN]\e[0m",
        3 => $level_color_map{3}."!{ERROR}\e[0m",
        4 => $level_color_map{4}."?<DEBUG>\e[0m",
        5 => $level_color_map{5}."~%<GUTS>\e[0m",
    );
    state %target_to_color;

    field $fh     :param = \*STDERR;
    field $target :param = undef;

    method format_message ($target, $level, @msg) {
        join '' => map {
            join '' =>
                $level_map{ $level },
                (sprintf " \e[20m\e[97m\e[48;2;%d;%d;%d;m %s \e[0m " => (
                    @{ $target_to_color{ $target }
                        //= [ map { (int(rand(20)) * 10) } 1,2,3 ] },
                    $target,
                )),
                $level_color_map{ $level }, $_, "\e[0m",
                "\n"
        } split /\n/ => "@msg";
    }

    method write ($msg) { $fh->print( $msg ) }

    method log ($level, @msg) {
        $self->write($self->format_message($target, $level, @msg));
    }

    method header ($label, $more_label=time()) {
        my $width = ($TERM_WIDTH - ((length $label) + 2 + 2));
        $width -= ((length $more_label) + 1) if $more_label;
        $fh->print(
            "\e[38;2;200;200;200;m",
            '== ', $label, ' ', ('=' x $width), ($more_label ? (' ', $more_label) : ()),
            "\e[0m",
            "\n"
        );
    }

    method line ($label, $more_label=time()) {
        my $width = ($TERM_WIDTH - ((length $label) + 2 + 2));
        $width -= ((length $more_label) + 1) if $more_label;
        $fh->print(
            "\e[38;2;125;125;125;m",
            '-- ', $label, ' ', ('-' x $width), ($more_label ? (' ', $more_label) : ()),
            "\e[0m",
            "\n"
        );
    }

    method alert ($label, $more_label=time()) {
        my $width = ($TERM_WIDTH - ((length $label) + 2 + 2));
        $width -= ((length $more_label) + 1) if $more_label;
        $fh->print(
            "\e[48;2;105;55;55;m",
            "\e[38;2;255;55;55;m",
            '>> ', $label, ' ', ('-' x $width), ($more_label ? (' ', $more_label) : ()),
            "\e[0m",
            "\n"
        );
    }

    method notification ($label, $more_label=time()) {
        my $width = ($TERM_WIDTH - ((length $label) + 2 + 2));
        $width -= ((length $more_label) + 1) if $more_label;
        $fh->print(
            "\e[48;2;100;100;200;m",
            "\e[38;2;0;0;100;m",
            '>> ', $label, ' ', ('-' x $width), ($more_label ? (' ', $more_label) : ()),
            "\e[0m",
            "\n"
        );
    }

    method bubble ($label, $contents) {
        my $width = ($TERM_WIDTH - 4);
        my @lines = ref $contents ? @$contents : split /\n/ => $contents;
        $fh->print(
            "\e[38;2;200;100;200;m",
            '╭─',(('─' x ($width - (length($label) + 2))), ' ', $label, ' '),'─╮',"\n",
            (map { ('│ ',(sprintf("%-${width}s", $_)),' │',"\n",) } @lines),
            '╰─',('─' x $width),'─╯',
            "\e[0m",
            "\n"
        );
    }

}

