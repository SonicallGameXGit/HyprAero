import QtQuick
import QtTest
import qs.design

// The main colour of an icon: every reader of the same icon gets it, not only the first to read it (the
// taskbar shows one icon on several buttons, and a button left without it lit up white).
Item {
    id: root

    width: 100
    height: 100

    IconColorReader {
        id: first

        source: Qt.resolvedUrl('blue-16.png')
    }

    IconColorReader {
        id: second

        source: Qt.resolvedUrl('blue-16.png')
    }

    TestCase {
        name: 'IconColorReader'
        when: windowShown

        function test_sameIconOnSeveralReaders(): void {
            tryVerify(() => first.mainColor !== '' && second.mainColor !== '', 3000)
            compare(second.mainColor, first.mainColor)
        }
    }
}
