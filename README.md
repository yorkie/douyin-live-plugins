# Douyin Live Plugins

[简体中文](README.zh-CN.md)

Douyin Live Plugins is an open-source collection of tools and integrations for Douyin Live Companion. This repository currently includes **Lyric Bridge**, a macOS companion for synchronizing NetEase Cloud Music lyrics with a dedicated live-capture window.

## Included plugin: Lyric Bridge

### Features

- Detects the current NetEase Cloud Music track and playback progress.
- Searches for timed lyrics and translations and highlights the current line.
- Imports local `.lrc` lyric files.
- Provides controls for lyric size, translation visibility, timing offset, and next track.
- Opens a compact lyric banner that can be captured as a separate window.

### Requirements

- macOS 13 or later.
- Xcode Command Line Tools (for building from source).
- NetEase Cloud Music for track detection and playback control.

### Build and run

Clone the repository, then run:

```sh
./scripts/build-app.sh
open "build/Lyric Bridge.app"
```

The build script uses an available Apple Development signing identity so macOS Accessibility authorization can remain associated with the app across rebuilds. To choose an identity explicitly, set `LYRIC_BRIDGE_SIGNING_IDENTITY`. If no valid identity is available, the script uses an ad-hoc signature; macOS may then require you to remove and re-add Lyric Bridge in Accessibility settings after rebuilding.

### macOS permissions

Lyric Bridge needs **System Settings → Privacy & Security → Accessibility** access to read the visible track information from NetEase Cloud Music and send the next-track action when you click the button. Grant access to the built `Lyric Bridge.app` and relaunch it if macOS prompts you to do so.

### Use with Douyin Live Companion

1. Launch Lyric Bridge. The lyric banner opens automatically.
2. In Douyin Live Companion, add a **Window Capture** source.
3. Select the separate window named **Lyric Bridge — 歌词**.
4. Position and resize the source in the live canvas as needed.

The banner uses a compact dark background by design. This gives the Mac window-capture source an intentional subtitle-bar appearance when its transparent areas are composited as opaque black. The main Lyric Bridge control window can be hidden while the lyric banner remains open.

### Lyrics and network access

Lyric Bridge searches NetEase Music's web endpoints using the detected track title and artist, then fetches timed lyrics and translations when available. These endpoints are not a documented public desktop API and may change or become unavailable. If automatic matching fails, choose another search result or import a timestamped `.lrc` file.

The app does not require a NetEase account login and does not read account cookies. Network requests use an ephemeral URL session with cookie storage disabled.

### Troubleshooting

#### The current track is not detected

- Open NetEase Cloud Music and start playback.
- Confirm that Lyric Bridge is enabled under **System Settings → Privacy & Security → Accessibility**.
- Restart Lyric Bridge after changing the permission.

#### Lyrics do not match or are unavailable

- Use **选择匹配版本** in the control window to select another search result.
- Import a local timestamped `.lrc` file if no suitable result is available.
- Check the network connection; the lyric service depends on NetEase Music web endpoints.

#### The lyric banner is missing from the capture list

Make sure the lyric banner is open, then refresh the Window Capture source list and select **Lyric Bridge — 歌词**.

## License

Douyin Live Plugins is distributed under the MIT License. See [LICENSE](LICENSE).
