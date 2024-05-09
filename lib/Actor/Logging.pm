package Actor::Logging;

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Logger;

use constant LOG_LEVEL => $ENV{ACTOR_DEBUG} ? 4 : ($ENV{ACTOR_LOG} // 0);

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
    $loggers{$target} //= Actor::Logger->new( target => $target );
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Acktor::Logging

=head1 DESCRIPTION

=cut
