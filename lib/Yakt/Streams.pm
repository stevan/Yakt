#!perl

use v5.40;
use experimental qw[ class ];

package Yakt::Streams {
    use Yakt::Streams::OnNext;
    use Yakt::Streams::OnCompleted;
    use Yakt::Streams::OnError;

    use Yakt::Streams::Subscribe;
    use Yakt::Streams::OnSubscribe;
}
