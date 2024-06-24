<!---------------------------------------------------------------------------->
# TODO
<!---------------------------------------------------------------------------->


https://reactivex.io/documentation/contract.html



- make become/unbcome just do one thing
    - add become_stacked/unbecome_stacked for that if desired
    - how do they work together?

- find a place for the `Behaviors {}` helper
    - should I accept a CODE ref as well?
    - do they have any kind of lifecycle?
    - do they accept signals?

## Streams - non-reactive

- Add some actors for this:
    - Observers:
        - Observer : which takes callbacks for events
        - ObserverSink : which takes a Sink object, and collects everything into it
    - Observables:
        - Observable : takes a source to publish
    - Processors:
        - Map, Grep, etc.

## IO

- create a protocol for reading/writing
    - it should be based an Observables

- build actors for this
    - Stream
    - Socket

## Context

- add method for adding Selectors
    - go via System

## Loggers

- Make the Logger async using a watcher
    - or a special purpose watcher perhaps

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

## Perl Stuff

`use warnings FATAL => qw[ once ]`

This will make using symbols better as this will make this a compile time
check.

Also check out https://metacpan.org/pod/strictures#VERSION-2 for this as well.



