## Description

Updated bitrate metric attributes to align with standard definitions across all New Relic video tracking agents (v4.1.1).

### Changed
- Renamed `contentMeasuredBitrate` to `contentSegmentDownloadBitrate`
- Added `contentNetworkDownloadBitrate` attribute to track raw network download speed from recent segments
- Updated bitrate metric definitions to match standard definitions across all video tracking agents
- Changed `nrCalculateContentNetworkBitrate()` return type from `Integer` to `LongInteger` to prevent overflow with high-bandwidth streams

### Fixed
- Fixed `contentNetworkDownloadBitrate` tracker initialization by adding reset on `CONTENT_REQUEST` to ensure accurate measurements from video start
- Fixed memory leak by properly resetting content bitrate tracker in `NewRelicVideoStop()`
- Fixed edge case where `downloadedBytes` decrease (stream restart/seek) could cause incorrect bitrate calculations by gracefully handling byte counter resets

### Removed
- Removed `contentSegmentBitrate` attribute (consolidated into standard bitrate metrics)

### Files Changed
- `CHANGELOG.md` — Added 4.1.1 changelog entry
- `DATAMODEL.md` — Updated attribute names
- `components/NewRelicAgent/NRAgent.brs` — Core bitrate metric logic changes
- `components/NewRelicAgent/NRAgent.xml` — Version bump
- `components/VideoScene.brs` — Updated bitrate attribute references
- `package.json` — Version bump to 4.1.1

## Type of Change

- [x] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [x] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)

## 📺 Roku Device Testing (Required)

Since Roku tests cannot be automated, manual testing on a physical Roku device is **required** for all PRs.

### Manual Testing Checklist

- [ ] I have run tests on a physical Roku device
- [ ] All existing tests pass on the device
- [ ] New functionality (if any) has been manually verified
- [ ] Video playback events are being tracked correctly

### Testing Evidence
<!-- Please provide screenshots, logs, or a detailed description of the manual testing performed -->

## Additional Context

This is a **breaking change** — `contentMeasuredBitrate` has been renamed to `contentSegmentDownloadBitrate` and `contentSegmentBitrate` has been removed. Any dashboards or alerts referencing the old attribute names will need to be updated.

## Related Issues
<!-- Link any related issues here using #issue_number -->

---
**Note:** A GitHub Action will post a reminder comment about manual testing requirements.
