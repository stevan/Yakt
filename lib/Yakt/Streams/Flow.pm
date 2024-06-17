#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams::Actors::Observable::FromSource;
use Yakt::Streams::Actors::Observable::FromProducer;

use Yakt::Streams::Actors::Operator::Map;
use Yakt::Streams::Actors::Operator::Grep;

class Yakt::Streams::Flow {

    field $source;
    field $sink;

    field @operators;

    method from ($from) {
        $source = $from;
        return $self;
    }

    method to ($to) {
        $sink = $to;
        return $self;
    }

    method map ($f) {
        push @operators => {
            class => Yakt::Streams::Actors::Operator::Map::,
            args  => { f => $f }
        };
        return $self;
    }

    method grep ($f) {
        push @operators => {
            class => Yakt::Streams::Actors::Operator::Grep::,
            args  => { f => $f }
        };
        return $self;
    }

    method run ($context) {

        my $start = $context->spawn( Yakt::Props->new(
            class => Yakt::Streams::Actors::Observable::FromSource::,
            args  => { source => $source }
        ));

        my @ops;
        foreach my $operator ( @operators ) {
            push @ops => $context->spawn( Yakt::Props->new(
                class => $operator->{class},
                args  => $operator->{args},
            ));
        }

        my $op = $start;
        foreach my $next (@ops) {
            $op->send( Yakt::Streams::Subscribe->new( subscriber => $next ));
            $op = $next;
        }

        $op->send( Yakt::Streams::Subscribe->new( subscriber => $sink ));
    }

}
