#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

package Acktor::Streams {
    use Acktor::Streams::OnNext;
    use Acktor::Streams::OnCompleted;
    use Acktor::Streams::OnError;

    use Acktor::Streams::Subscribe;
    use Acktor::Streams::OnSubscribe;
}
