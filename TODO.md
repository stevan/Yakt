<!---------------------------------------------------------------------------->
# TODO
<!---------------------------------------------------------------------------->

## Actors & Behaviors

- The Actor needs to own the Behavior, so that it can have `become` functionality
    - borrow from the old Acktor implementation
        - Mailbox called Actor::accept instead of Behavior::accept
    - the current model is kind of inverted, so ...
        - Make Mailbox call Actor::apply or Actor::signal
            - which will internally call Behavior::receive_{message,signal}
                - instead of the other way around

## IO

- build actors for this
    - Stream
    - Socket

## Context

- add method for adding Selectors
    - go via System

## Supervisors

- Supervisors need to be configurable for given errors
    - some kind of error dispatch table (`match`)

## Child Supervision

- need to add this

## Errors

- need to distinguish between errors to be caught, and fatal errors which
  should start the shutdown process

## Signals

- add exporters and constructors for Ready and Terminated as those are the only
  two which are used by Users

## Shutdown

- detect the shutdown precursors better
    - we need to also be able to catch zombies
        - and not just loop forever ...

<!---------------------------------------------------------------------------->
# Maybe
<!---------------------------------------------------------------------------->

## Address

- Re-add these ???

- don't do `0002@localhost:3000/foo/bar`
    - do `localhost:3000/foo/bar/2`
    - it is more REST appropriate and conveys the relationships better
        - i.e. - instance PID(2) of the `/foo/bar` actor

## Messages

- make all messages be able to stringify and desctructure-able
    - but do I really want to enforce a base class?

## Perl Stuff

`use warnings FATAL => qw[ once ]`

This will make using symbols better as this will make this a compile time
check.

Also check out https://metacpan.org/pod/strictures#VERSION-2 for this as well.



