pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import 'volume.js' as VolumeLogic

// The sound, for the notification area's volume icon, its flyout and the Volume Mixer (Windows 7's): the
// default output device's volume and mute from PipeWire, the apps playing sound and the output devices to
// choose from. Without PipeWire the icon is not shown (`available`); without an output device it says so,
// as Windows 7's red cross does.
Singleton {
    id: root

    readonly property bool available: Pipewire.ready
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool present: available && sink !== null && sink.audio !== null
    readonly property real volume: present ? sink.audio.volume : 0
    readonly property bool muted: present && sink.audio.muted
    readonly property int percent: VolumeLogic.percent(volume)
    readonly property string level: VolumeLogic.iconLevel(volume, muted, present)
    readonly property string deviceName: {
        if (present === false) {
            return ''
        }

        if (sink.description !== '') {
            return sink.description
        }

        return sink.nickname !== '' ? sink.nickname : sink.name
    }
    readonly property string tooltip: {
        if (present === false) {
            return qsTr('No audio output device is installed')
        }

        return muted ? qsTr('%1: Muted').arg(deviceName) : qsTr('%1: %2%').arg(deviceName).arg(percent)
    }

    // The Volume Mixer window is open: only then are the apps' streams tracked (their volumes read).
    property bool mixerOpen: false
    readonly property var nodes: available ? Pipewire.nodes.values : []
    // `{ id, name, icon, node }` per app playing sound, and `{ id, name, node }` per output device.
    readonly property var streams: withNodes(VolumeLogic.playbackStreams(nodes.map(describe)))
    readonly property var outputs: withNodes(VolumeLogic.outputDevices(nodes.map(describe)))

    // A node's words for `services/volume.js`. Its kind comes from its type, which PipeWire gives for
    // every node; its properties (the app's name and icon) only while it is tracked (the mixer is open).
    function describe(node: var): var {
        const properties = node.properties
        const word = name => typeof properties[name] === 'string' ? properties[name] : ''
        let mediaClass = ''
        if (node.type === PwNodeType.AudioSink) {
            mediaClass = 'Audio/Sink'
        } else if (node.type === PwNodeType.AudioOutStream) {
            mediaClass = 'Stream/Output/Audio'
        }

        return {
            id: node.id,
            mediaClass: mediaClass,
            appName: word('application.name'),
            appIcon: word('application.icon-name'),
            appBinary: word('application.process.binary'),
            description: node.description,
            nickname: node.nickname,
            name: node.name,
        }
    }

    function withNodes(entries: var): var {
        return entries.map(entry => {
            const node = nodes.find(candidate => candidate.id === entry.id)
            return Object.assign({ node: node === undefined ? null : node }, entry)
        })
    }

    // Moving the volume takes the mute off, as on Windows 7.
    function setVolume(value: real): void {
        if (present === false) {
            return
        }

        sink.audio.volume = Math.min(1, Math.max(0, value))
        if (sink.audio.muted && value > 0) {
            sink.audio.muted = false
        }
    }

    function toggleMute(): void {
        if (present) {
            sink.audio.muted = sink.audio.muted === false
        }
    }

    function wheel(delta: int): void {
        if (present) {
            setVolume(VolumeLogic.wheeled(volume, delta))
        }
    }

    function setNodeVolume(node: var, value: real): void {
        if (node === null || node.audio === null) {
            return
        }

        node.audio.volume = Math.min(1, Math.max(0, value))
        if (node.audio.muted && value > 0) {
            node.audio.muted = false
        }
    }

    function toggleNodeMute(node: var): void {
        if (node !== null && node.audio !== null) {
            node.audio.muted = node.audio.muted === false
        }
    }

    function setOutput(node: var): void {
        if (node !== null) {
            Pipewire.preferredDefaultAudioSink = node
        }
    }

    // Asked for while it is open (on another workspace, behind a window), it is shown again where the user
    // is.
    function openMixer(): void {
        mixerOpen = false
        mixerOpen = true
    }

    // PipeWire only fills in a node's volume while something tracks it.
    PwObjectTracker {
        objects: {
            const tracked = root.sink === null ? [] : [root.sink]
            if (root.mixerOpen) {
                const nodes = root.streams.concat(root.outputs).map(entry => entry.node)
                return tracked.concat(nodes.filter(node => node !== null))
            }

            return tracked
        }
    }
}
