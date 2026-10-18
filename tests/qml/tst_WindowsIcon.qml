import QtQuick
import QtTest
import qs.design
import '../../resources/icons/frames.js' as IconFrames

// Windows' own icons from `resources/icons/`: the frame Windows drew for the size is taken (the next bigger
// one between its sizes, the biggest past them), and every frame `frames.js` lists is there and loads.
Item {
    id: root

    width: 100
    height: 100

    WindowsIcon {
        id: icon

        name: 'network-wifi-5'
    }

    TestCase {
        name: 'WindowsIcon'
        when: windowShown

        function test_the_frame_made_for_the_size(): void {
            // network-wifi-5 has 16, 20, 24 and 32; signal-bars-5 only 32 and 48.
            const expected = [
                ['network-wifi-5', 16, 16],
                ['network-wifi-5', 18, 20],
                ['network-wifi-5', 24, 24],
                ['network-wifi-5', 40, 32],
                ['signal-bars-5', 24, 32],
                ['signal-bars-5', 48, 48],
                ['not-kept', 16, 0],
            ]
            for (const row of expected) {
                icon.name = row[0]
                icon.size = row[1]
                compare(icon.frame, row[2], row[0] + ' at ' + row[1])
            }
        }

        function test_every_frame_loads(): void {
            for (const name in IconFrames.frames) {
                for (const size of IconFrames.frames[name]) {
                    const image = createTemporaryQmlObject('import QtQuick; Image {}', root)
                    image.source = Qt.resolvedUrl(`../../resources/icons/${name}-${size}.png`)
                    tryCompare(image, 'status', Image.Ready)
                    compare(image.implicitWidth, size, name + '-' + size)
                }
            }
        }
    }
}
