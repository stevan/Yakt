#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams::Actors::Observable::FromSource;
use Yakt::Streams::Actors::Observable::FromProducer;

use Yakt::Streams::Actors::Operator::Map;
use Yakt::Streams::Actors::Operator::Grep;
use Yakt::Streams::Actors::Operator::Peek;

use Yakt::Streams::Actors::Flow;

class Yakt::Streams::Composers::Flow {

    field $source;
    field $sink;

    field @operators;

    method from_source ($src) {
        $source = Yakt::Props->new(
            class => Yakt::Streams::Actors::Observable::FromSource::,
            args  => { source => $src }
        );
        return $self;
    }

    method from_callback ($f) {
        $source = Yakt::Props->new(
            class => Yakt::Streams::Actors::Observable::FromProducer::,
            args  => { producer => $f }
        );
        return $self;
    }

    method from ($from) {
        $source = $from;
        return $self;
    }

    method to ($to) {
        $sink = $to;
        return $self;
    }

    method map ($f) {
        push @operators => Yakt::Props->new(
            class => Yakt::Streams::Actors::Operator::Map::,
            args  => { f => $f }
        );
        return $self;
    }

    method grep ($f) {
        push @operators => Yakt::Props->new(
            class => Yakt::Streams::Actors::Operator::Grep::,
            args  => { f => $f }
        );
        return $self;
    }

    method peek ($f) {
        push @operators => Yakt::Props->new(
            class => Yakt::Streams::Actors::Operator::Peek::,
            args  => { f => $f }
        );
        return $self;
    }

    method spawn ($context) {
        return $context->spawn(Yakt::Props->new(
            class => Yakt::Streams::Actors::Flow::,
            args  => {
                source    => $source,
                operators => \@operators,
                sink      => $sink,
            }
        ));
    }

}
