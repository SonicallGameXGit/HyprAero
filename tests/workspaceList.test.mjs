import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/workspaceList.js', import.meta.url), 'utf8').replace('.pragma library', '')
const buildEntries = new Function(source + '\nreturn buildEntries')()
const { cornerPosition, parseOpenWindow } = new Function(source + '\nreturn { cornerPosition, parseOpenWindow }')()

const ids = entries => entries.map(entry => entry.id)
const entryOf = (entries, id) => entries.find(entry => entry.id === id)

test('fresh desktop shows the minimum, first one focused, no icons', () => {
    const entries = buildEntries([], [], 1, 5)
    assert.deepEqual(ids(entries), [1, 2, 3, 4, 5])
    assert.equal(entries[0].focused, true)
    assert.equal(entries.some(entry => entry.occupied), false)
    assert.equal(entries[0].mainApp, null)
    assert.equal(entries[0].secondApp, null)
})

test('existing workspaces beyond the minimum are added in order', () => {
    const entries = buildEntries([8, 2], [], 2, 5)
    assert.deepEqual(ids(entries), [1, 2, 3, 4, 5, 8])
    assert.equal(entryOf(entries, 8).occupied, true)
    assert.equal(entryOf(entries, 3).occupied, false)
})

test('a focused empty workspace beyond the minimum is still shown', () => {
    assert.deepEqual(ids(buildEntries([], [], 7, 3)), [1, 2, 3, 7])
})

test('special workspaces are never listed', () => {
    assert.deepEqual(ids(buildEntries([-98], [], -98, 2)), [1, 2])
})

test('a single app gives only a main icon, even with several windows', () => {
    const windows = [
        { workspaceId: 1, appId: 'code', area: 100 },
        { workspaceId: 1, appId: 'code', area: 50 },
    ]
    const entry = entryOf(buildEntries([1], windows, 1, 2), 1)
    assert.equal(entry.mainApp, 'code')
    assert.equal(entry.secondApp, null)
    assert.equal(entry.occupied, true)
})

test('several apps: the biggest is main, the second biggest is the badge, the rest are dropped', () => {
    const windows = [
        { workspaceId: 1, appId: 'small', area: 10 },
        { workspaceId: 1, appId: 'big', area: 300 },
        { workspaceId: 1, appId: 'middle', area: 200 },
        { workspaceId: 2, appId: 'other', area: 999 },
    ]
    const entry = entryOf(buildEntries([1, 2], windows, 1, 2), 1)
    assert.equal(entry.mainApp, 'big')
    assert.equal(entry.secondApp, 'middle')
})

test('an app counts with its biggest window', () => {
    const windows = [
        { workspaceId: 1, appId: 'a', area: 100 },
        { workspaceId: 1, appId: 'a', area: 400 },
        { workspaceId: 1, appId: 'b', area: 300 },
    ]
    const entry = entryOf(buildEntries([1], windows, 1, 1), 1)
    assert.equal(entry.mainApp, 'a')
    assert.equal(entry.secondApp, 'b')
})

test('equal sizes are ordered by app id', () => {
    const windows = [
        { workspaceId: 1, appId: 'b', area: 100 },
        { workspaceId: 1, appId: 'a', area: 100 },
    ]
    assert.equal(entryOf(buildEntries([1], windows, 1, 1), 1).mainApp, 'a')
})

test('an entry lists its own windows, biggest first, ties by app id then title', () => {
    const windows = [
        { workspaceId: 1, appId: 'b', title: 'two', area: 100 },
        { workspaceId: 1, appId: 'a', title: 'zed', area: 100 },
        { workspaceId: 1, appId: 'a', title: 'alpha', area: 100 },
        { workspaceId: 1, appId: 'big', title: 'main', area: 900 },
        { workspaceId: 2, appId: 'other', title: 'elsewhere', area: 5000 },
    ]
    const entry = entryOf(buildEntries([1, 2], windows, 1, 2), 1)
    assert.deepEqual(entry.windows.map(window => window.title), ['main', 'alpha', 'zed', 'two'])
})

test('an empty workspace has no windows', () => {
    assert.deepEqual(entryOf(buildEntries([], [], 1, 2), 1).windows, [])
})

const hangsOffMonitor = new Function(source + '\nreturn hangsOffMonitor')()
const monitor = { x: 0, y: 0, width: 1920, height: 1080 }

test('a window inside its monitor does not hang off it', () => {
    assert.equal(hangsOffMonitor([0, 0], [1920, 1080], monitor), false)
})

test('a window one pixel past any edge hangs off its monitor', () => {
    assert.equal(hangsOffMonitor([-1, 0], [800, 600], monitor), true)
    assert.equal(hangsOffMonitor([0, -1], [800, 600], monitor), true)
    assert.equal(hangsOffMonitor([1121, 0], [800, 600], monitor), true)
    assert.equal(hangsOffMonitor([0, 481], [800, 600], monitor), true)
})

test('an unknown monitor or position counts as on screen', () => {
    assert.equal(hangsOffMonitor([-100, 0], [800, 600], null), false)
    assert.equal(hangsOffMonitor(undefined, [800, 600], monitor), false)
})

const firstEmptyWorkspace = new Function(source + '\nreturn firstEmptyWorkspace')()

test('the first empty workspace is the lowest one without windows', () => {
    const windows = [
        { workspaceId: 1, appId: 'a', area: 1 },
        { workspaceId: 2, appId: 'b', area: 1 },
        { workspaceId: 4, appId: 'c', area: 1 },
    ]
    assert.equal(firstEmptyWorkspace(buildEntries([1, 2, 4], windows, 1, 5)), 3)
})

test('the focused workspace counts when it is the first empty one', () => {
    assert.equal(firstEmptyWorkspace(buildEntries([], [], 1, 3)), 1)
})

test('when every listed workspace has windows, the next one after the highest is used', () => {
    const windows = [
        { workspaceId: 1, appId: 'a', area: 1 },
        { workspaceId: 2, appId: 'b', area: 1 },
        { workspaceId: 7, appId: 'c', area: 1 },
    ]
    assert.equal(firstEmptyWorkspace(buildEntries([1, 2, 7], windows, 7, 2)), 8)
})

test('an entry keeps the window address for focusing and closing', () => {
    const windows = [{ workspaceId: 1, address: '0x1', appId: 'a', area: 1 }]
    assert.equal(entryOf(buildEntries([1], windows, 1, 1), 1).windows[0].address, '0x1')
})

const isWindowAddress = new Function(source + '\nreturn isWindowAddress')()

test('a window address is 0x and hex digits, nothing else', () => {
    assert.equal(isWindowAddress('0x55f3b1d9b170'), true)
    assert.equal(isWindowAddress('0xABCdef01'), true)
    assert.equal(isWindowAddress(''), false)
    assert.equal(isWindowAddress('0x'), false)
    assert.equal(isWindowAddress('55f3b1d9b170'), false)
    assert.equal(isWindowAddress('0x1\' }) hl.exec_cmd(\'rm\''), false)
    assert.equal(isWindowAddress(undefined), false)
})

const dropWorkspace = new Function(source + '\nreturn dropWorkspace')()
// Buttons 40 wide with 4 between them, starting at 100: 1 [100-140], 2 [144-184], 3 [188-228], 4 [232-272].
// Reach of the bar: 48 over the buttons, 240 at the sides.
const near = { buttons: 48, sides: 240 }
const slotsOf = emptyIds => [1, 2, 3, 4].map((id, index) => ({
    id: id,
    left: 100 + index * 44,
    right: 140 + index * 44,
    empty: emptyIds.includes(id),
}))

test('a drop on a button goes to that workspace, empty or not', () => {
    assert.equal(dropWorkspace(160, 0, slotsOf([]), near), 2)
    assert.equal(dropWorkspace(200, -10, slotsOf([3]), near), 3)
})

test('a drop in the gap between buttons goes to the closer one, the left one on a tie', () => {
    assert.equal(dropWorkspace(141, 0, slotsOf([]), near), 1)
    assert.equal(dropWorkspace(143, 0, slotsOf([]), near), 2)
    assert.equal(dropWorkspace(142, 0, slotsOf([]), near), 1)
})

test('a drop a little above the buttons still counts as on them', () => {
    assert.equal(dropWorkspace(250, 48, slotsOf([]), near), 4)
})

test('right of the buttons, near the bar, goes to the rightmost free workspace', () => {
    assert.equal(dropWorkspace(900, 0, slotsOf([1, 3]), near), 3)
    assert.equal(dropWorkspace(273, 30, slotsOf([2]), near), 2)
    assert.equal(dropWorkspace(900, 240, slotsOf([1, 3]), near), 3)
})

test('left of the buttons, near the bar, goes to the leftmost free workspace', () => {
    assert.equal(dropWorkspace(10, 0, slotsOf([2, 4]), near), 2)
    assert.equal(dropWorkspace(99, 40, slotsOf([4]), near), 4)
    assert.equal(dropWorkspace(10, 240, slotsOf([2, 4]), near), 2)
})

test('the sides reach higher than the buttons', () => {
    // 200 above the bar: still the rightmost free one at the side, but already "up" over the buttons.
    assert.equal(dropWorkspace(900, 200, slotsOf([1, 3]), near), 3)
    assert.equal(dropWorkspace(160, 200, slotsOf([1, 3]), near), 1)
    // Past the side's reach it is "up" there too.
    assert.equal(dropWorkspace(900, 241, slotsOf([1, 3]), near), 1)
})

test('away from the bar goes to the lowest free workspace, wherever along the bar', () => {
    assert.equal(dropWorkspace(160, 49, slotsOf([3, 4]), near), 3)
    assert.equal(dropWorkspace(900, 500, slotsOf([3, 4]), near), 3)
    assert.equal(dropWorkspace(10, 500, slotsOf([4]), near), 4)
})

test('with no free workspace the sides and away from the bar do nothing', () => {
    assert.equal(dropWorkspace(900, 0, slotsOf([]), near), 0)
    assert.equal(dropWorkspace(10, 0, slotsOf([]), near), 0)
    assert.equal(dropWorkspace(160, 300, slotsOf([]), near), 0)
})

test('no buttons at all: nowhere to drop', () => {
    assert.equal(dropWorkspace(160, 0, [], near), 0)
})

const workspaceMovePlan = new Function(source + '\nreturn workspaceMovePlan')()

test('a workspace moved to a number nobody has just takes that number', () => {
    assert.equal(workspaceMovePlan(2, 7, true, false, [1, 2, 3], 1), 'renumber')
})

test('moving the workspace on screen keeps the view on its old number', () => {
    assert.equal(workspaceMovePlan(1, 7, true, false, [1, 2, 3], 1), 'renumberAndStay')
})

test('moving onto the empty workspace on screen shows the source first, then renumbers it', () => {
    assert.equal(workspaceMovePlan(2, 5, true, false, [1, 2, 5], 5), 'showThenRenumber')
})

test('moving onto a workspace with windows moves the windows one by one', () => {
    assert.equal(workspaceMovePlan(2, 3, true, true, [1, 2, 3], 1), 'moveWindows')
    assert.equal(workspaceMovePlan(2, 3, true, true, [1, 2, 3], 3), 'moveWindows')
})

test('an empty workspace shown on another monitor cannot be renumbered onto, so windows move', () => {
    assert.equal(workspaceMovePlan(2, 4, true, false, [1, 2, 4], 1), 'moveWindows')
})

test('nothing to move, the same workspace or bad ids: nothing happens', () => {
    assert.equal(workspaceMovePlan(2, 7, false, false, [1, 2], 1), 'none')
    assert.equal(workspaceMovePlan(2, 2, true, true, [1, 2], 1), 'none')
    assert.equal(workspaceMovePlan(0, 2, true, false, [1], 1), 'none')
    assert.equal(workspaceMovePlan(2, -1, true, false, [1, 2], 1), 'none')
})

const workspaceNumber = new Function(source + '\nreturn workspaceNumber')()

test('a workspace number is its id when Quickshell knows it', () => {
    assert.equal(workspaceNumber(7, '7'), 7)
    assert.equal(workspaceNumber(3, 'web'), 3)
})

test('a placeholder workspace (id -1) is numbered by its name', () => {
    assert.equal(workspaceNumber(-1, '6'), 6)
})

test('a placeholder without a numeric name stays unknown', () => {
    assert.equal(workspaceNumber(-1, 'web'), -1)
    assert.equal(workspaceNumber(-1, ''), -1)
    assert.equal(workspaceNumber(-1, undefined), -1)
})

const startOnWorkspace = new Function(source + '\nreturn startOnWorkspace')()

// Text that has broken quoting somewhere: quotes of both kinds, backslashes, a Lua long bracket, shell and
// Lua syntax, line breaks, a control character followed by digits, and text beyond ASCII.
const trickyArguments = [
    'plain',
    'two words',
    'it\'s',
    '"double"',
    'back\\slash\\',
    '\'; rm -rf ~; echo \'',
    '$(echo no) `echo no` $HOME',
    '\' }) hl.dsp.exit() --',
    ']] [[ ]=]',
    'line\nbreak\r\ttab',
    '\u00012345',
    'Привет 🌊',
    '',
]

// Runs the dispatcher through real Lua with `exec_cmd` replaced by a stand-in that hands back what it was
// given, then the command text through `sh`, so both layers of quoting are checked as Hyprland reads them.
const runDispatch = dispatch => {
    const stub = 'hl = { dsp = { exec_cmd = function(cmd, rules) io.write(cmd, \'\\0\', rules.workspace) end } }\n'
    const output = execFileSync('lua', ['-'], { input: stub + dispatch, encoding: 'utf8' })
    const [shellText, workspace] = output.split('\0')
    return { shellText: shellText, workspace: workspace }
}

const hasLua = (() => {
    try {
        execFileSync('lua', ['-v'])
        return true
    } catch {
        return false
    }
})()

test('an app goes to the workspace without the view following it', () => {
    assert.equal(
        startOnWorkspace(['kitty'], '', 4),
        'hl.dsp.exec_cmd(\'exec \\\'kitty\\\'\', { workspace = \'4 silent\' })',
    )
})

test('nothing to start or no real workspace: no dispatcher', () => {
    assert.equal(startOnWorkspace([], '', 4), '')
    assert.equal(startOnWorkspace(['kitty'], '', 0), '')
    assert.equal(startOnWorkspace(['kitty'], '', -2), '')
    assert.equal(startOnWorkspace(['kitty'], '', 2.5), '')
})

test('every argument reaches the app exactly as it was, through Lua and sh', { skip: hasLua === false && 'lua is not installed' }, () => {
    const dispatch = startOnWorkspace(['printf', '%s\\n'].concat(trickyArguments), '', 3)
    const { shellText, workspace } = runDispatch(dispatch)
    assert.equal(workspace, '3 silent')
    const printed = execFileSync('sh', ['-c', shellText], { encoding: 'utf8' })
    assert.equal(printed, trickyArguments.map(argument => argument + '\n').join(''))
})

test('the app starts in its working directory, whatever its name', { skip: hasLua === false && 'lua is not installed' }, () => {
    const folder = mkdtempSync(join(tmpdir(), 'hypraero it\'s $(x) '))
    try {
        const { shellText } = runDispatch(startOnWorkspace(['pwd'], folder, 1))
        assert.equal(execFileSync('sh', ['-c', shellText], { encoding: 'utf8' }), folder + '\n')
    } finally {
        rmSync(folder, { recursive: true })
    }
})

test('a working directory that is missing starts nothing', { skip: hasLua === false && 'lua is not installed' }, () => {
    const { shellText } = runDispatch(startOnWorkspace(['echo', 'started'], '/nonexistent/hypraero', 1))
    assert.throws(() => execFileSync('sh', ['-c', shellText], { encoding: 'utf8', stdio: 'pipe' }))
})

test('mixer corner: against the bottom right of what the bars leave free', () => {
    const monitor = { x: 1920, y: 0, width: 1920, height: 1080, reserved: [0, 0, 0, 48] }
    assert.deepEqual(cornerPosition(monitor, { width: 480, height: 330 }), { x: 3360, y: 702 })
    assert.deepEqual(cornerPosition({ ...monitor, reserved: [0, 30, 40, 0] }, { width: 480, height: 330 }), { x: 3320, y: 750 })
})

test('mixer corner: a window bigger than the work area keeps its top left corner on it', () => {
    const monitor = { x: 0, y: 0, width: 400, height: 300, reserved: [10, 20, 0, 48] }
    assert.deepEqual(cornerPosition(monitor, { width: 480, height: 330 }), { x: 10, y: 20 })
})

test('mixer corner: no position from numbers that are not numbers', () => {
    assert.equal(cornerPosition({ x: 0, y: 0, width: Number.NaN, height: 10, reserved: [0, 0, 0, 0] }, { width: 1, height: 1 }), null)
    assert.equal(cornerPosition({ x: 0, y: 0, width: 10, height: 10, reserved: [0, 0] }, { width: 1, height: 1 }), null)
    assert.deepEqual(cornerPosition({ x: 0, y: 0, width: 10, height: 10 }, { width: 4, height: 4 }), { x: 6, y: 6 })
})

test('openwindow event: address, workspace, class and a title that may hold commas', () => {
    assert.deepEqual(parseOpenWindow('5593c0f2a1b0,3,org.quickshell,Volume Mixer - Speakers, Front'), {
        address: '0x5593c0f2a1b0',
        workspace: '3',
        className: 'org.quickshell',
        title: 'Volume Mixer - Speakers, Front',
    })
    assert.equal(parseOpenWindow('not an address,3,a,b'), null)
    assert.equal(parseOpenWindow('5593c0f2a1b0,3'), null)
    assert.equal(parseOpenWindow(undefined), null)
})
