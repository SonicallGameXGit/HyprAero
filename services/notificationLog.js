.pragma library

// The log line about a notification that came in. Plain JS, no Quickshell imports, so node can test it.
// It never holds the notification's words: a summary or a body can be a private message or a one-time code,
// and logs must not carry those (.aero/PRINCIPLES.md section 4). Their lengths are enough to see that the
// text arrived.

// Quickshell's NotificationUrgency values, in order.
const urgencyNames = [
    'low',
    'normal',
    'critical',
]

function plural(count, word) {
    return count === 1 ? '1 ' + word : `${count} ${word}s`
}

// `fields`: { id, appName, urgency (a NotificationUrgency value), summaryLength, bodyLength, actionCount,
// hasImage }.
function describe(fields) {
    const urgency = urgencyNames[fields.urgency]
    const parts = [
        fields.appName === '' ? 'an app without a name' : `"${fields.appName}"`,
        urgency === undefined ? 'urgency ' + fields.urgency : urgency,
        `summary of ${plural(fields.summaryLength, 'character')}`,
    ]
    if (fields.bodyLength > 0) {
        parts.push(`body of ${plural(fields.bodyLength, 'character')}`)
    }
    if (fields.actionCount > 0) {
        parts.push(plural(fields.actionCount, 'action'))
    }
    if (fields.hasImage) {
        parts.push('a picture')
    }

    return `#${fields.id} from ` + parts.join(', ')
}
