#include "check.hpp"
#include "core/safety.hpp"
#include "core/status.hpp"

namespace {

    void jsonStringsAreEscaped() {
        check::that(frames::jsonString("plain") == "\"plain\"", "plain text is only quoted");
        check::that(frames::jsonString("a\"b\\c") == "\"a\\\"b\\\\c\"", "quotes and backslashes are escaped");
        check::that(frames::jsonString("a\nb") == "\"a\\u000ab\"", "control characters are escaped");
        check::that(frames::jsonString("") == "\"\"", "empty is two quotes");
    }

    void onAsText() {
        const frames::Safety safety = {};
        check::that(frames::statusText(safety, "0.1.0", false) == "hypraero-frames 0.1.0: on\n", "on");
    }

    void offAsText() {
        frames::Safety safety = {};
        frames::turnOff(safety, "draw", "broken");
        check::that(frames::statusText(safety, "0.1.0", false) ==
                        "hypraero-frames 0.1.0: off since an error in draw: broken. Reload the plugin to turn it on again.\n",
                    "off, with where and why");
    }

    void asJson() {
        const frames::Safety on = {};
        check::that(frames::statusText(on, "0.1.0", true) ==
                        "{\"name\": \"hypraero-frames\", \"version\": \"0.1.0\", \"on\": true, \"where\": \"\", \"reason\": \"\"}",
                    "on as JSON");

        frames::Safety off = {};
        frames::turnOff(off, "draw", "say \"no\"");
        check::that(frames::statusText(off, "0.1.0", true) ==
                        "{\"name\": \"hypraero-frames\", \"version\": \"0.1.0\", \"on\": false, \"where\": \"draw\", \"reason\": \"say \\\"no\\\"\"}",
                    "off as JSON, the reason escaped");
    }

}

int main() {
    jsonStringsAreEscaped();
    onAsText();
    offAsText();
    asJson();
    return check::result("status");
}
