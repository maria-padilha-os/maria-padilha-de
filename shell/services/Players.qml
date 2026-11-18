pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components.misc
import "MediaInfo.js" as MediaInfo

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    // Dedup key for progressive metadata (e.g. mpv-mpris/yt-dlp player fills title then artist later).
    property string lastNowPlayingKey: ""

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.values.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function getArtUrl(player: MprisPlayer): string {
        return MediaInfo.artUrl(player);
    }

    function getTrackTitle(player: MprisPlayer, fallback: string): string {
        return MediaInfo.trackTitle(player, fallback);
    }

    function getTrackArtist(player: MprisPlayer, fallback: string): string {
        return MediaInfo.trackArtist(player, fallback);
    }

    function getTrackAlbum(player: MprisPlayer, fallback: string): string {
        return MediaInfo.trackAlbum(player, fallback);
    }

    function formatTime(value: real): string {
        return MediaInfo.formatTime(value);
    }

    function isKnownLength(player: MprisPlayer): bool {
        return MediaInfo.isKnownLength(player);
    }

    function canSeek(player: MprisPlayer): bool {
        return MediaInfo.canSeek(player);
    }

    function progress(player: MprisPlayer): real {
        return MediaInfo.progress(player);
    }

    function seekTarget(player: MprisPlayer, ratio: real): real {
        return MediaInfo.seekTarget(player, ratio);
    }

    function seekTo(player: MprisPlayer, position: real): void {
        MediaInfo.seekTo(player, position);
    }

    function seekBy(player: MprisPlayer, offset: real): void {
        MediaInfo.seekBy(player, offset);
    }

    function getVolume(player: MprisPlayer): real {
        return MediaInfo.volume(player);
    }

    function getVolumePercent(player: MprisPlayer): int {
        return MediaInfo.volumePercent(player);
    }

    function canSetVolume(player: MprisPlayer): bool {
        return MediaInfo.canSetVolume(player);
    }

    function setVolume(player: MprisPlayer, value: real): void {
        MediaInfo.setVolume(player, value);
    }

    function changeVolume(player: MprisPlayer, delta: real): void {
        MediaInfo.changeVolume(player, delta);
    }

    function actionForKey(key: int, shift: bool): string {
        const player = root.active;
        return MediaInfo.actionForKey(key, shift, canSeek(player), canSetVolume(player));
    }

    function perform(action: string): void {
        const player = root.active;
        if (!player)
            return;

        switch (action) {
        case "toggle":
            if (player.canTogglePlaying)
                player.togglePlaying();
            break;
        case "play":
            if (player.canPlay)
                player.play();
            break;
        case "pause":
            if (player.canPause)
                player.pause();
            break;
        case "previous":
            if (player.canGoPrevious)
                player.previous();
            break;
        case "next":
            if (player.canGoNext)
                player.next();
            break;
        case "seekBackward":
            seekBy(player, -MediaInfo.SEEK_STEP);
            break;
        case "seekForward":
            seekBy(player, MediaInfo.SEEK_STEP);
            break;
        case "seekStart":
            seekTo(player, 0);
            break;
        case "seekEnd":
            seekTo(player, player.length);
            break;
        case "volumeUp":
            changeVolume(player, GlobalConfig.services.audioIncrement);
            break;
        case "volumeDown":
            changeVolume(player, -GlobalConfig.services.audioIncrement);
            break;
        case "mute":
            setVolume(player, getVolume(player) > 0 ? 0 : 0.5);
            break;
        }
    }

    // Quickshell only emits postTrackChanged when trackid/url/title change, so late
    // artist updates (common with mpv-mpris + yt-dlp player) never retrigger it. Watch
    // title/artist too and toast once both are usable.
    function maybeToastNowPlaying(): void {
        if (!GlobalConfig.utilities.toasts.nowPlaying)
            return;

        const player = root.active;
        if (!player)
            return;

        const title = player.trackTitle ?? "";
        const artist = player.trackArtist ?? "";
        if (!title || !artist)
            return;

        const key = `${getIdentity(player)}\0${player.uniqueId}\0${title}\0${artist}`;
        if (key === lastNowPlayingKey)
            return;

        lastNowPlayingKey = key;
        Toaster.toast(Tr.tr("Now playing"), Tr.trCtx("%1 - %2", "track artist and title").arg(artist).arg(title), "music_note");
    }

    onActiveChanged: lastNowPlayingKey = ""

    // One position tick for every surface. The bar, popout, dashboard and
    // lock screen all read Players.active, so a timer per widget would wake
    // the process several times per interval for the same MPRIS update.
    Timer {
        running: root.active?.isPlaying ?? false
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.active?.positionChanged()
    }

    Connections {
        function onPostTrackChanged(): void {
            root.maybeToastNowPlaying();
        }

        function onTrackTitleChanged(): void {
            root.maybeToastNowPlaying();
        }

        function onTrackArtistChanged(): void {
            root.maybeToastNowPlaying();
        }

        target: root.active
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: Tr.tr("Toggle media playback")
        onPressed: {
            const active = root.active;
            if (active && active.canTogglePlaying)
                active.togglePlaying();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: Tr.tr("Previous track")
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: Tr.tr("Next track")
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: Tr.tr("Stop media playback")
        onPressed: root.active?.stop()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaSeekBackward"
        description: Tr.tr("Seek media backward")
        onPressed: root.perform("seekBackward")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaSeekForward"
        description: Tr.tr("Seek media forward")
        onPressed: root.perform("seekForward")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaVolumeUp"
        description: Tr.tr("Raise the active player's volume")
        onPressed: root.perform("volumeUp")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaVolumeDown"
        description: Tr.tr("Lower the active player's volume")
        onPressed: root.perform("volumeDown")
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        function seek(offset: real): void {
            root.seekBy(root.active, offset);
        }

        function setPosition(position: real): void {
            root.seekTo(root.active, position);
        }

        function volume(): string {
            const player = root.active;
            return player ? `${root.getVolumePercent(player)}%` : "No active player";
        }

        function setVolume(volume: real): void {
            root.setVolume(root.active, volume);
        }

        target: "mpris"
    }
}
