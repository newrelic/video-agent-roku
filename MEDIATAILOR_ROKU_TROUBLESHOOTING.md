# MediaTailor Roku Troubleshooting Summary

## What We Are Trying To Do

We are trying to make the Roku sample app play an AWS Elemental MediaTailor stitched SSAI stream and track ads/content through New Relic and RAF.

The intended flow is:

1. The Roku app calls the MediaTailor session-init endpoint.
2. MediaTailor returns a stitched playback manifest URL and tracking URL.
3. The Roku Video node plays the stitched HLS stream.
4. RAF observes stitched ad markers and forwards ad events to the New Relic tracker.

## Summary Of Issues Seen From The Start

### 1. Sample app noise made the logs misleading

The sample app starts a background `SearchTask` from `source/Main.brs`.

That task continuously sends Google requests and logs them as `Google Search` URL requests.

This created unrelated noise in the deploy logs and initially made it look like the app was making unexpected network calls during MediaTailor playback debugging.

Root cause:

- `runSearchTask("hello")` is called in `source/Main.brs`
- `components/SearchTask.brs` sends repeated Google requests on purpose

Impact:

- MediaTailor-specific playback failures were mixed with unrelated sample HTTP traffic

### 2. Deploy telnet logs included stale output from previous sessions

The original `deploy.sh` started capturing telnet output immediately, so logs often included old Roku app/device output from before the current deploy session.

Impact:

- It was difficult to tell which lines belonged to the current run

Mitigation added:

- `deploy.sh` was updated to filter telnet output until the current app session marker appears:
  `------ Running dev 'NR Video Agent' runuserinterface ------`

### 3. Initial MediaTailor session URL was wrong for session-init

Early in the debugging flow, the session-init URL used in the app did not match the format that MediaTailor expected.

Observed variants included:

- a playlist-style path
- a session path missing the required `/hls` suffix

Symptoms:

- `404` on session init for the Roku-specific config when `/hls` was missing
- earlier failures and fallbacks when the wrong path shape was used

Confirmed behavior:

- `.../v1/session/.../lab-hls-vod-roku/` returned `404`
- `.../v1/session/.../lab-hls-vod-roku/hls` returned `200`

### 4. The app originally trusted the returned `manifestUrl` too literally

For the non-Roku playback config, MediaTailor session-init returned a relative `manifestUrl` ending in `/hls?...`.

The app originally used that returned value directly as the playback URL.

Problem:

- that returned `/v1/master/.../hls?...` path was not a playable HLS master manifest for Roku in the tested config

Symptoms:

- playback stalled early
- direct checks showed manifest generation failures on that path

Mitigation added:

- `components/MediaTailorTask.brs` was updated to normalize session playback URLs to `master.m3u8` when needed

### 5. The older non-Roku MediaTailor config failed downstream on child playlists

After session-init started succeeding on the earlier config, Roku still failed during playback.

Observed symptom in logs:

- buffering at position `0`
- later `HTTP 409` on a child MediaTailor playlist URL such as `/v1/manifest/.../26.m3u8?...`

Impact:

- playback never started
- Roku eventually transitioned to `error`

Interpretation at that stage:

- Roku reached the stitched master level, but downstream MediaTailor media playlist resolution was failing

### 6. The Roku-specific MediaTailor config improved session-init but playback still did not start

After switching to the Roku-specific playback config and fixing the URL to include `/hls`, session-init succeeded.

Confirmed behavior:

- session response code was `200`
- a stitched master URL was resolved for the Roku playback config

Device symptom:

- player entered `buffering`
- `Manifest data = invalid`
- `Current position = 0`
- later `Player state = error`

This showed that:

- session-init was no longer the blocker
- playback was still failing before Roku could actually begin consuming the stitched stream

### 7. RAF `Innovid` / `BrightLine` lines were investigated and are not the root cause

These lines appeared during playback startup:

- `Failed to create roSGNode with type InnovidDCL:InteractiveAdVersion`
- `Failed to create roSGNode with type BrightLine:InteractiveAdEngine`

Why they are not the root cause:

- session-init had already succeeded before these lines
- playback continued into buffering after these lines
- the app remained alive long enough to emit content heartbeats in the same run

Interpretation:

- these are optional RAF interactive renderer probes/noise
- they are not the thing preventing content playback

### 8. The current Roku-specific MediaTailor stitched manifest appears to fail server-side

The most important current finding from direct URL inspection is:

- session-init succeeds
- but fetching the stitched Roku manifest returned by MediaTailor can fail with `504`

Observed response:

```json
{
  "message": "failed to generate manifest: Unable to obtain template playlist. sessionId:[...]"
}
```

This happened when directly requesting the exact stitched manifest URL returned by MediaTailor for the Roku-specific playback config.

Related child-playlist behavior also showed errors such as:

```json
{
  "message": "Invalid media playlist assetId: Master playlist has not yet been requested or contained no variant playlists ..."
}
```

Interpretation:

- MediaTailor session creation works
- MediaTailor stitched manifest generation for the Roku playback config is not consistently succeeding
- if the stitched master is not generated correctly, Roku cannot parse/play the stream and child playlist resolution also breaks

### 9. The current content source itself is not enough to explain the failure

The provided source content URL is:

`https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`

This may be a better Roku candidate than the earlier advanced Apple fMP4 example, but it does not by itself explain the current behavior.

The current failure is still happening at the MediaTailor stitched-manifest generation stage for the Roku playback config.

## Current Best Understanding

The current dominant issue is not:

- the New Relic agent
- the `SearchTask` Google requests
- the optional RAF `Innovid` / `BrightLine` renderer messages
- the app failing to call session-init

The current dominant issue is:

- MediaTailor session-init succeeds for the Roku playback config
- but the stitched manifest returned for that session is not reliably generated into a usable HLS master for Roku
- Roku then stays at `position = 0`, reports `Manifest data = invalid`, and eventually errors out

## Practical Conclusions

1. The sample app logging noise made troubleshooting harder, but it is not the playback root cause.
2. The Roku app-side session URL issues have been identified and corrected.
3. The app-side normalization issue for playback URLs was identified and corrected.
4. The remaining issue now appears to be in the MediaTailor playback config / source template handling for the Roku-specific stream.

## Files That Were Most Relevant During Debugging

- `components/VideoScene.brs`
- `components/MediaTailorTask.brs`
- `components/NewRelicAgent/trackers/MediaTailorTracker.brs`
- `source/Main.brs`
- `components/SearchTask.brs`
- `deploy.sh`

## Recommended Next Checks

1. Verify the MediaTailor playback config `lab-hls-vod-roku` is pointing at the intended Mux HLS origin URL and that the origin/template playlist is valid from MediaTailor's perspective.
2. Disable `runSearchTask("hello")` in `source/Main.brs` for cleaner logs during further playback debugging.
3. Re-test the Roku-specific MediaTailor config after confirming the playback config's source/origin settings in AWS.
4. Inspect MediaTailor playback-config details in AWS for anything specific to template playlist resolution, not just ad decisioning.
