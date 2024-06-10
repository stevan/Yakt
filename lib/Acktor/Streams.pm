#!perl

use v5.40;
use experimental qw[ class ];

package Acktor::Streams {
    use Acktor::Streams::OnNext;
    use Acktor::Streams::OnCompleted;
    use Acktor::Streams::OnError;

    use Acktor::Streams::Subscribe;
    use Acktor::Streams::OnSubscribe;
}
