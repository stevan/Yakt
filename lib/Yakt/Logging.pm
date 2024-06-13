#!perl

use v5.40;
use experimental qw[ class ];

package Yakt::Logging {
    use Yakt::Logging::Logger;

    use constant LOG_LEVEL => $ENV{ACKTOR_DEBUG} ? 4 : ($ENV{ACKTOR_LOG} // 0);

    use constant INFO      => (LOG_LEVEL >= 1 ? 1 : 0);
    use constant WARN      => (LOG_LEVEL >= 2 ? 2 : 0);
    use constant ERROR     => (LOG_LEVEL >= 3 ? 3 : 0);
    use constant DEBUG     => (LOG_LEVEL >= 4 ? 4 : 0);
    use constant INTERNALS => (LOG_LEVEL >= 5 ? 5 : 0);

    use Exporter 'import';

    our @EXPORT = qw[
        DEBUG
        INFO
        WARN
        ERROR
        INTERNALS

        LOG_LEVEL
    ];

    sub logger ($, $target=undef) {
        state %loggers;
        $target //= (caller)[0];
        $loggers{$target} //= Yakt::Logging::Logger->new( target => $target );
    }

}
