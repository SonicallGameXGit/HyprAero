.pragma library

// How much each app is used, by "frecency": every use adds 1 to the app's score, and the score halves
// every `halfLife` without use. Recent use counts most and old habits fade on their own, so an app used
// daily this week ranks above one used hundreds of times last year, and no number grows without bound.
// A record is `{ score, time }`: the score as it was at `time` (ms since the epoch), decayed on read.

const day = 24 * 60 * 60 * 1000

// Two weeks: a habit of a few weeks outweighs a burst of one afternoon.
const halfLife = 14 * day
// A use counts at most once in this long per app, so flicking between windows is not "using" anything.
const useGap = 10 * 60 * 1000
// A record decayed below this is dropped when the file is read: about one use, two months ago.
const forgetBelow = 0.05

// The record's score now. A clock that went back in time does not raise it.
function scoreAt(record, now) {
    if (record === undefined || record === null) {
        return 0
    }

    const elapsed = Math.max(now - record.time, 0)
    return record.score * Math.pow(0.5, elapsed / halfLife)
}

// The record after one more use now.
function addUse(record, now) {
    return { score: scoreAt(record, now) + 1, time: now }
}

// Whether a use now counts: the last counted one (the record's time) is at least `useGap` ago.
function useDue(record, now) {
    if (record === undefined || record === null) {
        return true
    }

    return now - record.time >= useGap || now < record.time
}

// Every app's score now, by id.
function scoresAt(usage, now) {
    const result = {}
    for (const id of Object.keys(usage)) {
        result[id] = scoreAt(usage[id], now)
    }

    return result
}

function isRecord(value) {
    return typeof value === 'object'
        && value !== null
        && typeof value.score === 'number'
        && Number.isFinite(value.score)
        && value.score > 0
        && typeof value.time === 'number'
        && Number.isFinite(value.time)
}

// Reads the start menu's state file: `{ "version": 1, "featured": [ids], "usage": { id: record } }`.
// Whatever is wrong is left out and described in `problems`; an empty or missing file is a fresh start.
function parseState(text, now) {
    const result = { featured: [], usage: {}, problems: [] }
    if (text.trim() === '') {
        return result
    }

    let data = null
    try {
        data = JSON.parse(text)
    } catch (error) {
        result.problems.push('not valid JSON, starting fresh')
        return result
    }

    if (typeof data !== 'object' || data === null || Array.isArray(data)) {
        result.problems.push('not a JSON object, starting fresh')
        return result
    }

    if (Array.isArray(data.featured)) {
        for (const id of data.featured) {
            if (typeof id === 'string' && id !== '' && result.featured.includes(id) === false) {
                result.featured.push(id)
            } else {
                result.problems.push('featured: skipped ' + JSON.stringify(id))
            }
        }
    } else if (data.featured !== undefined) {
        result.problems.push('featured: not a list, ignored')
    }

    if (typeof data.usage === 'object' && data.usage !== null && Array.isArray(data.usage) === false) {
        for (const id of Object.keys(data.usage)) {
            const record = data.usage[id]
            if (id === '' || isRecord(record) === false) {
                result.problems.push('usage: skipped ' + JSON.stringify(id))
                continue
            }

            if (scoreAt(record, now) >= forgetBelow) {
                result.usage[id] = { score: record.score, time: record.time }
            }
        }
    } else if (data.usage !== undefined) {
        result.problems.push('usage: not an object, ignored')
    }

    return result
}

function serializeState(featured, usage) {
    return JSON.stringify({ version: 1, featured: featured, usage: usage }, null, 4) + '\n'
}
