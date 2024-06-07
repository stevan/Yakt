#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor {
    use Acktor::Logging;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(sprintf '%s[%d]' => blessed($self), refaddr($self)) if LOG_LEVEL;
    }

    method apply ($context, $message) {
        $self->logger->log( WARN, "Unhandled message! $context => $message" ) if WARN;
        return false;
    }

    method signal ($context, $message) {}

    ## ...

    my %ATTRIBUTES;
    my %RECEIVERS;
    my %HANDLERS;
    sub FETCH_RECEIVERS ($pkg) { $RECEIVERS{ $pkg } }
    sub FETCH_HANDLERS  ($pkg) {  $HANDLERS{ $pkg } }
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

