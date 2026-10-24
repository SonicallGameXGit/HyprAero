import Quickshell.Services.Notifications
import QtQuick
import qs.design
import qs.services

// One notification as Windows 7's balloon (`design/Balloon.qml`). It fades in, stays as long as
// `Notifications.timeout` says (the pointer resting on it holds it, and the time starts again once the
// pointer leaves), then fades out and expires; the pointer coming back while it fades brings it back.
// A click on it, its close button or one of its actions (each a button) closes it at once, as Windows 7's did.
Balloon {
    id: root

    required property Notification notification
    property bool leaving: false

    readonly property var shownWords: Notifications.words(notification)
    readonly property var shownIcon: Notifications.icon(notification)
    readonly property var shownButtons: Notifications.buttons(notification)
    readonly property int stays: Notifications.timeout(notification)

    title: shownWords.title
    text: shownWords.text
    iconName: shownIcon.name
    iconSource: shownIcon.source
    // Every notification comes from some app; without an icon of its own it gets the generic one.
    genericIcon: shownIcon.name === '' && shownIcon.source === ''
    pictureSource: shownIcon.picture
    actions: shownButtons.map(button => button.text === '' ? qsTr('Open') : button.text)
    opacity: 0

    onClicked: Notifications.activate(notification)
    onCloseClicked: notification.dismiss()
    onActionClicked: index => Notifications.invoke(notification, shownButtons[index].index)
    onHoveredChanged: {
        if (hovered && leaving) {
            leaving = false
            fadeOut.stop()
            fadeIn.start()
        }
    }

    Component.onCompleted: fadeIn.start()

    // An app that replaces its notification with new words gets the whole time again.
    function renew(): void {
        if (stayTimer.running) {
            stayTimer.restart()
        }
    }

    NumberAnimation {
        id: fadeIn

        target: root
        property: 'opacity'
        to: 1
        duration: Theme.motionSoft
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOut

        target: root
        property: 'opacity'
        to: 0
        duration: Theme.motionSoft
        easing.type: Easing.OutCubic
        onFinished: root.notification.expire()
    }

    Timer {
        id: stayTimer

        interval: root.stays
        running: root.stays > 0 && root.hovered === false && root.leaving === false
        onTriggered: {
            root.leaving = true
            fadeIn.stop()
            fadeOut.start()
        }
    }

    Connections {
        target: root.notification

        function onSummaryChanged(): void {
            root.renew()
        }

        function onBodyChanged(): void {
            root.renew()
        }
    }
}
