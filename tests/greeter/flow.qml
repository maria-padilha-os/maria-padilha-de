import QtQuick
import Quickshell
import Quickshell.Services.Greetd

ShellRoot {
    Component.onCompleted: {
        console.log("TEST_GREETD_AVAILABLE", Greetd.available);
        if (Greetd.available)
            Greetd.createSession("tester");
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            console.log("TEST_AUTH", message, responseRequired, echoResponse);
            if (responseRequired)
                Greetd.respond("secret");
        }

        function onReadyToLaunch() {
            console.log("TEST_READY");
            Greetd.launch(["true"], ["TEST=1"]);
        }

        function onLaunched() {
            console.log("TEST_LAUNCHED");
        }

        function onAuthFailure(message) {
            console.log("TEST_AUTH_FAILURE", message);
        }

        function onError(error) {
            console.log("TEST_ERROR", error);
        }
    }
}
