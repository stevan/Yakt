#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams::Actors::Observable::FromSource;
use Yakt::Streams::Actors::Observable::FromProducer;

use Yakt::Streams::Actors::Operator::Map;
use Yakt::Streams::Actors::Operator::Grep;

class Yakt::Streams::Composers::Flow {

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

        # TODO:
        # if there is something missing, then send
        # the error to the $to, and if there is no
        # $to, then throw a runtime exception
        #
        # maybe??

        my $start = ref $source eq 'CODE'
            ? $context->spawn( Yakt::Props->new(
                class => Yakt::Streams::Actors::Observable::FromProducer::,
                args  => { producer => $source }
              ))
            : $context->spawn( Yakt::Props->new(
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
