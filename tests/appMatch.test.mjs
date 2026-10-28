import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/appMatch.js', import.meta.url), 'utf8').replace('.pragma library', '')
const match = new Function(source + '\nreturn { matchKey, classIndex, appForClass }')()

const adsEditor = {
    // As Quickshell gives it: without `.desktop`.
    id: 'wine-Programs-Google Ads Editor-Google Ads Editor',
    name: 'Google Ads Editor',
    startupClass: 'google_ads_editor_launcher.exe',
}

test('key: case, punctuation and .exe or .desktop are left out', () => {
    assert.equal(match.matchKey('Google Ads Editor'), 'googleadseditor')
    assert.equal(match.matchKey('google_ads_editor.exe'), 'googleadseditor')
    assert.equal(match.matchKey('Google-Ads-Editor.desktop'), 'googleadseditor')
    assert.equal(match.matchKey('Блокнот'), 'блокнот')
    assert.equal(match.matchKey(undefined), '')
})

test('a Wine program is found by its name, though its entry names its launcher', () => {
    const index = match.classIndex([adsEditor])
    assert.equal(match.appForClass(index, 'google_ads_editor.exe'), adsEditor.id)
    assert.equal(match.appForClass(index, 'google_ads_editor_launcher.exe'), adsEditor.id)
})

test('an entry is found by its id and the id\'s last part too', () => {
    const index = match.classIndex([{ id: 'org.example.Viewer.desktop', name: 'Pictures', startupClass: '' }])
    assert.equal(match.appForClass(index, 'org.example.viewer'), 'org.example.Viewer.desktop')
    const wine = match.classIndex([{ id: 'wine-Programs-Tools-Notepad++.desktop', name: 'Text', startupClass: '' }])
    assert.equal(match.appForClass(wine, 'notepad++.exe'), 'wine-Programs-Tools-Notepad++.desktop')
})

test('nothing is guessed between two apps, or from a key too short to mean anything', () => {
    const index = match.classIndex([
        { id: 'a.desktop', name: 'Editor', startupClass: '' },
        { id: 'b.desktop', name: 'editor', startupClass: '' },
        { id: 'c.desktop', name: 'Go', startupClass: '' },
    ])
    assert.equal(match.appForClass(index, 'editor'), '')
    assert.equal(match.appForClass(index, 'go'), '')
    assert.equal(match.appForClass(index, 'unknown'), '')
})
