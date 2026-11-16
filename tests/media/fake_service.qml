import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Runs under `qs -p` inside a private session bus with tests/media/fake_mpris.py.
// It only touches the fake service: no audio daemon, player process or network
// is started.
QtObject {
    id: harness

    property MprisPlayer player
    property int step: 0
    property int failures: 0

    function fail(message: string): void {
        console.error(`FAIL ${message}`);
        harness.failures += 1;
    }

    function check(condition: bool, message: string): void {
        if (!condition)
            harness.fail(message);
    }

    function finish(): void {
        if (harness.failures === 0)
            console.log("fake MPRIS service: all checks passed");
        else
            console.error(`fake MPRIS service: ${harness.failures} checks failed`);
        Qt.exit(harness.failures === 0 ? 0 : 1);
    }

    function advance(): void {
        const player = harness.player;
        if (!player) {
            harness.fail("no player after the service appeared");
            harness.finish();
            return;
        }

        switch (harness.step) {
        case 0:
            harness.check(player.identity === "Fake Player", `identity is ${player.identity}`);
            harness.check(player.trackTitle === "Fake Track 1", `title is ${player.trackTitle}`);
            harness.check(player.trackArtist === "Fake Artist", `artist is ${player.trackArtist}`);
            harness.check(player.trackAlbum === "Fake Album", `album is ${player.trackAlbum}`);
            harness.check(Math.abs(player.length - 180) < 0.1, `length is ${player.length}`);
            harness.check(player.canSeek === true, "seek is exposed");
            harness.check(player.volumeSupported === true, "volume is exposed");
            harness.check(Math.abs(player.volume - 0.6) < 0.01, `volume is ${player.volume}`);
            harness.check(player.isPlaying === false, "the widget did not autoplay");
            player.togglePlaying();
            harness.step = 1;
            wait.restart();
            break;
        case 1:
            harness.check(player.isPlaying === true, "play/pause did not start playback");
            player.next();
            harness.step = 2;
            wait.restart();
            break;
        case 2:
            harness.check(player.trackTitle === "Fake Track 2", `next went to ${player.trackTitle}`);
            player.previous();
            harness.step = 3;
            wait.restart();
            break;
        case 3:
            harness.check(player.trackTitle === "Fake Track 1", `previous went to ${player.trackTitle}`);
            player.seek(10);
            harness.step = 4;
            wait.restart();
            break;
        case 4:
            harness.check(player.position >= 9 && player.position <= 13, `seek landed at ${player.position}`);
            player.volume = 0.25;
            harness.step = 5;
            wait.restart();
            break;
        case 5:
            harness.check(Math.abs(player.volume - 0.25) < 0.01, `volume write landed at ${player.volume}`);
            player.pause();
            harness.step = 6;
            wait.restart();
            break;
        case 6:
            harness.check(player.isPlaying === false, "pause did not stop playback");
            harness.finish();
            break;
        }
    }

    property Timer poll: Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (harness.player)
                return;
            const players = Mpris.players.values;
            if (players.length === 0)
                return;
            harness.player = players[0];
            poll.stop();
            wait.start();
        }
    }

    property Timer wait: Timer {
        interval: 500
        onTriggered: harness.advance()
    }

    property Timer timeout: Timer {
        interval: 20000
        running: true
        onTriggered: {
            harness.fail("timed out waiting for the fake MPRIS service");
            harness.finish();
        }
    }
}
