#!perl

use v5.40;
use experimental qw[ class ];

package Yakt::Streams {
    # Messages ...

    use Yakt::Streams::OnNext;
    use Yakt::Streams::OnCompleted;
    use Yakt::Streams::OnError;

    use Yakt::Streams::Subscribe;
    use Yakt::Streams::OnSubscribe;

    use Yakt::Streams::Unsubscribe;
    use Yakt::Streams::OnUnsubscribe;

    use Yakt::Streams::OnSuccess;

    # Actors ...

    use Yakt::Streams::Actors::Observer;

    use Yakt::Streams::Actors::Observable::FromSource;
    use Yakt::Streams::Actors::Observable::FromProducer;

    use Yakt::Streams::Actors::Operator::Map;
    use Yakt::Streams::Actors::Operator::Grep;

    # Composors ...

    use Yakt::Streams::Composers::Flow;
}
