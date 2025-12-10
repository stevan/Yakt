#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';
use ok 'Yakt::Logging';

class Parse::Message {
    field $ref    :param :reader;
    field $source :param :reader;
}

class Parse::StatusLine {}
class Parse::Headers    {}
class Parse::Header     {}
class Parse::Body       {}
class Parse::Error      {}
class Parse::Completed  {}

class Parse::Result :isa(Yakt::Message) {}


class HTTP::Parser :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $ref;
    field $source;
    field %result;

    field $parse_status;
    field $parse_headers;
    field $parse_body;

    ADJUST {
        $parse_status = Yakt::Behavior->new(receivers => {
            Parse::StatusLine:: => method ($context, $message) {
                $context->logger->log(INFO, 'Got Parse::StatusLine') if INFO;

                $result{status}{method} = 'GET';
                $result{status}{url}    = '/index.html';

                # Pop back to base, then push headers
                $self->unbecome;
                $self->become($parse_headers);
                $context->self->send( Parse::Headers->new );
            }
        });

        $parse_headers = Yakt::Behavior->new(receivers => {
            Parse::Headers:: => method ($context, $message) {
                $context->logger->log(INFO, 'Got Parse::Headers') if INFO;

                $result{status}{headers} = [];
                $context->self->send( Parse::Header->new );
            },
            Parse::Header:: => method ($context, $message) {
                $context->logger->log(INFO, 'Got Parse::Header') if INFO;

                push $result{status}{headers}->@* => 'Hostname: example.com';

                # if not done with headers,
                    # send another header line to this receiver
                # but if done with headers ...
                    # either parse the body, or finish

                if ( $result{status}{method} eq 'GET' ) {
                    $self->unbecome;  # pop back to base behavior
                    $context->self->send( Parse::Completed->new );
                } else {
                    $self->unbecome;  # pop back to base first
                    $self->become($parse_body);
                    $context->self->send( Parse::Body->new );
                }
            }
        });

        $parse_body = Yakt::Behavior->new(receivers => {
            Parse::Body:: => method ($context, $message) {
                $result{status}{body} = 'FOO!!!!';

                # keep parsing the body until we get it all
                # and then finish the parsing

                $self->unbecome;
                $context->self->send( Parse::Completed->new );
            }
        });
    }

    # Regular methods ...

    method parse :Receive(Parse::Message) ($context, $message) {
        $context->logger->log(INFO, 'Got Parse::Message') if INFO;

        $ref    = $message->ref;
        $source = $message->source;

        $self->become($parse_status);
        $context->self->send( Parse::StatusLine->new );
    }

    method finish :Receive(Parse::Completed) ($context, $message) {
        $context->logger->log(INFO, 'Got Parse::Completed') if INFO;

        $context->logger->log(INFO, "Parsing done, sending Result to $ref") if INFO;
        $ref->send( Parse::Result->new(
            sender  => $context->self,
            payload => { %result } # send a copy
        ));

        %result = ();
        $ref    = undef;
        $source = undef;
    }

    method on_error :Receive(Parse::Error) ($context, $message) {
        $context->logger->log(INFO, 'Got Parse::Error') if INFO;

        %result = ();
        $ref    = undef;
        $source = undef;
    }

}

class Tester :isa(Yakt::Actor) {
    use Yakt::Logging;
    use Data::Dumper;

    our $RESULT;

    method hello :Receive(Parse::Result) ($context, $message) {
        $context->logger->log(INFO, 'got the Parse::Result message') if INFO;
        $context->logger->log(INFO, Dumper($message->payload)) if INFO;
        $RESULT = $message->payload;
        $message->sender->context->stop;
        $context->stop;
    }

}

my $sys = Yakt::System->new->init(sub ($context) {
    my $t = $context->spawn(Yakt::Props->new( class => 'Tester' ));

    my $p = $context->spawn(Yakt::Props->new( class => 'HTTP::Parser' ));

    $p->send(Parse::Message->new(
        ref    => $t,
        source => join '' => (
            "GET /images/logo.png HTTP/1.1\r\n",
            "Host: www.example.com\r\n",
            "Accept-Language: en\r\n",
        )
    ));
});

$sys->loop_until_done;

is_deeply(
    $Tester::RESULT,
    {
        status => {
            method  => 'GET',
            url     => '/index.html',
            headers => [
                'Hostname: example.com'
            ]
        }
    },
    '... got the expected parse structure back'
);

done_testing;
