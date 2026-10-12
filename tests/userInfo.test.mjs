import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, writeFileSync, mkdtempSync, readdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/userInfo.js', import.meta.url), 'utf8').replace('.pragma library', '')
const user = new Function(source + '\nreturn { userFolders, fullName, initial, avatarIndex, pictureFilter, chosenPicture, savePictureCommand }')()

// Runs a command array as Quickshell's `Process` would: no shell around it.
const run = command => spawnSync(command[0], command.slice(1))

const home = '/home/me'

test('folders: without a file, the usual names in home', () => {
    assert.deepEqual(user.userFolders('', home), [
        { key: 'documents', path: '/home/me/Documents' },
        { key: 'pictures', path: '/home/me/Pictures' },
        { key: 'music', path: '/home/me/Music' },
        { key: 'videos', path: '/home/me/Videos' },
        { key: 'downloads', path: '/home/me/Downloads' },
    ])
})

test('folders: names from user-dirs.dirs, $HOME expanded, comments and junk skipped', () => {
    const text = [
        '# This file is written by xdg-user-dirs-update',
        'XDG_DOCUMENTS_DIR="$HOME/Документы"',
        'XDG_PICTURES_DIR="/data/pictures/"',
        'XDG_MUSIC_DIR=relative',
        'XDG_VIDEOS_DIR="videos/not/absolute"',
    ].join('\n')
    const folders = user.userFolders(text, home)
    assert.equal(folders[0].path, '/home/me/Документы')
    assert.equal(folders[1].path, '/data/pictures')
    assert.equal(folders[2].path, '/home/me/Music')
    assert.equal(folders[3].path, '/home/me/Videos')
})

test('folders: one set to home is turned off and left out', () => {
    const folders = user.userFolders('XDG_MUSIC_DIR="$HOME/"\nXDG_VIDEOS_DIR="$HOME"', home)
    assert.deepEqual(folders.map(folder => folder.key), ['documents', 'pictures', 'downloads'])
})

test('full name: the first part of the comment field, or nothing', () => {
    const passwd = [
        'root:x:0:0::/root:/bin/bash',
        'me:x:1000:1000:Mikhail K,Room 1,,:/home/me:/bin/bash',
        'other:x:1001:1001:Other:/home/other:/bin/bash',
    ].join('\n')
    assert.equal(user.fullName(passwd, 'me'), 'Mikhail K')
    assert.equal(user.fullName(passwd, 'root'), '')
    assert.equal(user.fullName(passwd, 'nobody'), '')
})

test('avatar: an upper-case initial, and a stable colour within range', () => {
    assert.equal(user.initial(' mike'), 'M')
    assert.equal(user.initial(''), '?')
    const index = user.avatarIndex('sonicall', 6)
    assert.equal(index, user.avatarIndex('sonicall', 6))
    assert.ok(index >= 0 && index < 6)
})

test('picture filter: a label and every kind in both cases', () => {
    const filter = user.pictureFilter('Pictures')
    assert.ok(filter.startsWith('Pictures | '))
    assert.ok(filter.includes('*.png *.PNG'))
    assert.ok(filter.includes('*.jpeg *.JPEG'))
})

test('chosen picture: the printed path without its last newline', () => {
    assert.equal(user.chosenPicture('/home/me/Pictures/me.png\n'), '/home/me/Pictures/me.png')
    assert.equal(user.chosenPicture('/home/me/My Pictures/ me .JPG\n'), '/home/me/My Pictures/ me .JPG')
    assert.equal(user.chosenPicture('/home/me/a.webp'), '/home/me/a.webp')
})

test('chosen picture: nothing, a relative path, two paths or not a picture give nothing', () => {
    assert.equal(user.chosenPicture(''), '')
    assert.equal(user.chosenPicture('\n'), '')
    assert.equal(user.chosenPicture('me.png\n'), '')
    assert.equal(user.chosenPicture('/a.png\n/b.png\n'), '')
    assert.equal(user.chosenPicture('/home/me/notes.txt\n'), '')
    assert.equal(user.chosenPicture('/home/me/png\n'), '')
    assert.equal(user.chosenPicture('/home/me/.png\n'), '')
    assert.equal(user.chosenPicture('/home/me.png/picture\n'), '')
})

// A PPM picture (Qt reads and writes it without plugins): `width` x `height`, green in the middle square
// and red outside it, so a cut that keeps the middle comes out all green.
const middlePicture = (width, height) => {
    const side = Math.min(width, height)
    const left = (width - side) / 2
    const top = (height - side) / 2
    const pixels = Buffer.alloc(width * height * 3)
    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            const inside = x >= left && x < left + side && y >= top && y < top + side
            pixels.set(inside ? [0, 255, 0] : [255, 0, 0], (y * width + x) * 3)
        }
    }

    return Buffer.concat([Buffer.from(`P6\n${width} ${height}\n255\n`), pixels])
}

// The size and the pixel reader of a binary PPM.
const readPicture = data => {
    const header = /^P6\s+(\d+)\s+(\d+)\s+255\s/.exec(data.subarray(0, 32).toString('latin1'))
    assert.notEqual(header, null)
    const width = Number(header[1])
    const offset = header[0].length
    return {
        width: width,
        height: Number(header[2]),
        pixel: (x, y) => [...data.subarray(offset + (y * width + x) * 3, offset + (y * width + x) * 3 + 3)],
    }
}

const tool = new URL('../tools/shrinkPicture.qml', import.meta.url).pathname
const hasQuickshell = spawnSync('sh', ['-c', 'command -v qs']).status === 0
const shrinkTest = (name, body) => test(name, { skip: hasQuickshell ? false : 'qs (Quickshell) is not installed' }, () => {
    const folder = mkdtempSync(join(tmpdir(), 'hypraero-face-'))
    try {
        body(folder)
    } finally {
        rmSync(folder, { recursive: true, force: true })
    }
})

const shrink = (source, target) => spawnSync('qs', ['-p', tool], {
    env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', HYPRAERO_PICTURE_SOURCE: source, HYPRAERO_PICTURE_TARGET: target },
})

for (const [width, height] of [[1200, 400], [300, 900]]) {
    shrinkTest(`shrink: a ${width}x${height} picture becomes its middle square at 256px`, folder => {
        const source = join(folder, 'picture.ppm')
        const target = join(folder, 'face.ppm')
        writeFileSync(source, middlePicture(width, height))
        assert.equal(shrink(source, target).status, 0)
        const picture = readPicture(readFileSync(target))
        assert.equal(picture.width, 256)
        assert.equal(picture.height, 256)
        for (const [x, y] of [[0, 0], [255, 0], [0, 255], [255, 255], [128, 128]]) {
            const [red, green] = picture.pixel(x, y)
            assert.ok(green > 200 && red < 50, `pixel ${x}, ${y} is ${picture.pixel(x, y)}`)
        }
    })
}

shrinkTest('save: the shrunk picture replaces the old one, odd names included, nothing left beside it', folder => {
    const picked = join(folder, 'it\'s "me" $HOME `x`.ppm')
    const face = join(folder, '.face')
    writeFileSync(picked, middlePicture(800, 600))
    writeFileSync(face, 'old picture')
    assert.equal(run(user.savePictureCommand(tool, picked, face)).status, 0)
    const saved = readFileSync(face)
    assert.equal(saved.subarray(1, 4).toString('latin1'), 'PNG')
    assert.equal(saved.readUInt32BE(16), 256)
    assert.equal(saved.readUInt32BE(20), 256)
    assert.deepEqual(readdirSync(folder).sort(), ['.face', 'it\'s "me" $HOME `x`.ppm'])
})

shrinkTest('save: not a picture keeps the old one and leaves nothing beside it', folder => {
    const picked = join(folder, 'notes.png')
    const face = join(folder, '.face')
    writeFileSync(picked, 'not a picture')
    writeFileSync(face, 'old picture')
    assert.notEqual(run(user.savePictureCommand(tool, picked, face)).status, 0)
    assert.equal(readFileSync(face, 'utf8'), 'old picture')
    assert.deepEqual(readdirSync(folder).sort(), ['.face', 'notes.png'])
})
