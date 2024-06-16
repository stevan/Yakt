#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Behavior;

class Yakt::Actor {
    use Yakt::Logging;

    sub behavior_for;

    field $behavior;
    field @behaviors;

    field $logger;

    ADJUST {
        $logger   = Yakt::Logging->logger(__PACKAGE__) if LOG_LEVEL;
        $behavior = behavior_for( blessed $self );
    }

    # ...

    method become ($b) { $behaviors[0] = $b; }
    method unbecome    { @behaviors    = (); }


    method receive ($context, $message) {
        $logger->log( INTERNALS, "Actor got message($message) for $context" ) if INTERNALS;
        return ($behaviors[0] // $behavior)->receive_message( $self, $context, $message );
    }

    method signal ($context, $signal) {
        $logger->log( INTERNALS, "Actor got signal($signal) for $context" ) if INTERNALS;
        return ($behaviors[0] // $behavior)->receive_signal( $self, $context, $signal );
    }

    ## ...

    my (%BEHAVIORS,
        %RECEIVERS,
        %HANDLERS,
        %ATTRIBUTES);

    sub behavior_for ($pkg) {
        $BEHAVIORS{$pkg} //= Yakt::Behavior->new(
            receivers => $RECEIVERS{$pkg},
            handlers  => $HANDLERS{$pkg},
        );
    }

    sub FETCH_CODE_ATTRIBUTES  ($pkg, $code) { $ATTRIBUTES{ $pkg }{ $code } }
    sub MODIFY_CODE_ATTRIBUTES ($pkg, $code, @attrs) {
        grep { $_ !~ /^(Receive|Signal)/ }
        map  {
            if ($_ =~ /^(Receive|Signal)/) {
                $ATTRIBUTES{ $pkg }{ $code } = $_;

                my $type;
                if ($_ =~ /^(Receive|Signal)\((.*)\)$/ ) {
                    $type = $2;
                }
                else {
                    die "You must specify a type to Receive/Signal not $_";
                }

                if ($_ =~ /^Receive/) {
                    $RECEIVERS{ $pkg }{ $type } = $code;
                } elsif ($_ =~ /^Signal/) {
                    $HANDLERS{ $pkg }{ $type } = $code;
                }
            }
            $_;
        }
        @attrs;
    }
}

