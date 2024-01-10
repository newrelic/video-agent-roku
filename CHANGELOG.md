# CHANGELOG
All notable changes to this project will be documented in this file.

## [3.2.4] - 2024/01/10
### Add
- Memory attributes.

## [3.2.3] - 2023/10/24
### Add
- Device model attributes.

## [3.2.2] - 2023/09/01
### Update
- Improve NRTask console logging, reducing task rendezvous.

## [3.2.1] - 2023/06/06
### Add
- Instrumentation specific tags

## [3.2.0] - 2023/03/27
### Add
 - Domain substitution patterns.
### Update
 - OOTB count metrics aggregated by domain.

## [3.1.2] - 2023/03/16
### Fix
 - `nrUpdateConfig` bug.
 - Documentation errata.
### Update
 - Remove unused field in NRAgent.

## [3.1.1] - 2022/10/04
### Fix
 - Crash happening when using a playlist.

## [3.1.0] - 2022/09/01
### Add
 - Attribute `domain` to all HTTP events and metrics.

## [3.0.2] - 2022/08/30
### Fix
 - Harvest initial time, from 10 to 60 seconds.

## [3.0.1] - 2022/08/25
### Add
 - Added package json file
### Fix
 - Updated Main.brs with note about HttpEvents

## [3.0.0] - 2022/07/22
### Add
- Metrics API.
- OOTB HTTP metrics.
### Remove
- Grouped events for `HTTP_CONNECT`/`HTTP_COMPLETE`.
### Fix
- Broken tests.

## [2.1.3] - 2022/05/16
### Fix
- Timing issue.

## [2.1.2] - 2022/04/21
### Add
- `timeSinceHttpRequest` attribute into `HTTP_RESPONSE` events.

## [2.1.1] - 2022/03/08
### Add
- `counter` attribute into `HTTP_ERROR` events, with value 1, to simplify HTTP related NRQL requests.

## [2.1.0] - 2022/03/03
### Add
- System log events custom grouping mechanism.
### Fix
- Improve harvest performance in high density event traffic situations.

## [2.0.0] - 2022/01/25
### Add
- New Relic Logs.
- US/EU end point selection.

## [1.4.0] - 2021/11/09
### Add
- added network proxy support

## [1.3.4] - 2021/08/02
### Fix
- Fix hbTimer callback attachment

## [1.3.3] - 2021/06/18
### Fix
- Fix NewRelicVideoStop function - remove license status observer.

## [1.3.2] - 2021/05/31
### Add
- `totalAdPlaytime` attribute and NRAgent `nrAddToTotalAdPlaytime` public method (not wrapped).

## [1.3.1] - 2021/05/28
### Add
- Unit testing.

### Fix
- `nrGetOSVersion` bug.

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
