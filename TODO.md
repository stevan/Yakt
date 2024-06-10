<!---------------------------------------------------------------------------->
# TODO
<!---------------------------------------------------------------------------->

## Loggers

Turn the current Logger into a Sync Logger, for use in class based stuff.

Add a new Async Logger for all actors to use.

The old Logger API will become a facade over the new Async Logger
    - and this can be handled via the context->logger

QUESTIONS:
But does this make sense to introduce this extra layer?
    - perhaps it can be useful for a Live Running Application
        - but less so on the command line
    - however, if the command line DEBUG flag is set
        - it can just use the SyncLogger
    - but this could be very powerful for a remote debugger

Or is it good enough to just make the print calls to STDERR be async?

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



