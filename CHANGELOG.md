# CHANGELOG
All notable changes to this project will be documented in this file.

## [1.3.0] - 2021/05/13
### Add
- Ad errors.

## [1.2.0] - 2021/05/10
### Add
- Support for Ad trackers: RAF and Google IMA.

## [1.1.3] - 2021/04/14
### Fix
- Use `GetOSVersion()` (when available) instead of deprecated `GetVersion()`.

## [1.1.2] - 2021/04/14
### Add
- DRM related events and attributes.

## [1.1.1] - 2021/03/09
### Change
- Fix NewRelicVideoStop function - remove timer observer.

## [1.1.0] - 2021/03/04
### Change
- Added NewRelicVideoStop function. In case the scene changes from the one containing a video player to another without it.

## [1.0.8] - 2021/02/10
### Change
- Improved how the events are sent to New Relic. Now are sent in batches, instead of one by one.

### Fix
- In case of a network link disconnection, the NRTask doesn't wait forever.

## [1.0.7] - 2021/02/04
### Fix
- Check if `Video.content` exists before using it.

## [1.0.6] - 2020/10/28
### Fix
- Multiple bug fixes.

## [1.0.5] - 2020/04/29
### Change
- Improve nrGetBackEvents and nrExtractAllEvents array handling. 

## [1.0.4] - 2020/04/08
### Fix
- Check for the existance of errorInfo before adding attributes.

## [1.0.3] - 2020/04/01
### Add
- Attribute totalPlaytime.
- Attribute timeToStartStreaming.
- Attribute playtimeSinceLastEvent.
- Attribute uptime.

### Change
- Update documentation.

### Fix
- Issue with all timeSinceXXX attributes.
- Reduce rendezvous events in NRTask.

## [1.0.2] - 2020/03/17
### Add
- Error attributes.

### Change
- Update documentation.

## [1.0.1] - 2020/02/26
### Change
- Improve task rendezvous.
- Update documentation.

## [1.0.0rc3] - 2020/02/19
### Remove
- Argument "nr" from NewRelicSystemStart function.

## [1.0.0rc2] - 2020/02/18
### Change
- Use post async in NRTask.

## [1.0.0rc1] - 2020/02/14
- Initial Version.
