<!---------------------------------------------------------------------------->
# TODO
<!---------------------------------------------------------------------------->

## API Improvements

### Signal Exporters
- Add exporters for common signals (Started, Stopped, Terminated, etc.)
- Currently requires full class names: `Yakt::System::Signals::Started`
- Goal: `use Yakt::Signals qw(Started Stopped Terminated);`

### Actor Lookup by Alias
- Add public API: `$system->lookup('//usr/logger')`
- Currently aliases are registered but not publicly accessible

### Context::add_selector
- Add method for adding IO Selectors directly from Context
- Currently requires: `$context->system->io->add_selector(...)`
- Goal: `$context->add_selector($selector)`

## Become/Unbecome

- find a place for the `Behaviors {}` helper
    - should I accept a CODE ref as well?
    - do they have any kind of lifecycle?
    - do they accept signals?

## Loggers

- Make the Logger async using a watcher
    - or a special purpose watcher perhaps
    - currently logging blocks the event loop

## Supervisors

- Supervisors need to be configurable for given errors
    - some kind of error dispatch table (`match`)

## Child Supervision

- need to add this

## Errors

- need to distinguish between errors to be caught, and fatal errors which
  should start the shutdown process

## Shutdown

- detect the shutdown precursors better
    - we need to also be able to catch zombies
        - and not just loop forever ...

## Backpressure

- No backpressure mechanism for mailboxes
- Runaway producers can fill memory

<!---------------------------------------------------------------------------->
# Maybe
<!---------------------------------------------------------------------------->

## Perl Stuff

`use warnings FATAL => qw[ once ]`

This will make using symbols better as this will make this a compile time
check.

Also check out https://metacpan.org/pod/strictures#VERSION-2 for this as well.

