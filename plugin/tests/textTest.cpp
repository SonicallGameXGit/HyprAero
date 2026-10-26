#include <string>

#include "check.hpp"
#include "core/text.hpp"

namespace {

    void plainTitlesStay() {
        check::that(frames::cleanTitle("Windows Media Player") == "Windows Media Player", "plain ASCII");
        check::that(frames::cleanTitle("Привет — 日本語 🎵") == "Привет — 日本語 🎵", "any language and emoji");
        check::that(frames::cleanTitle("").empty(), "empty");
    }

    void controlsBecomeSpaces() {
        check::that(frames::cleanTitle("one\ntwo\tthree\rfour") == "one two three four", "line breaks and tabs");
        check::that(frames::cleanTitle(std::string("a\0b", 3)) == "a b", "a zero byte");
        check::that(frames::cleanTitle("a\u0085!") == "a !", "a C1 control (next line)");
        check::that(frames::cleanTitle("a !") == "a !", "the line separator");
        check::that(frames::cleanTitle("%s%n%x") == "%s%n%x", "format directives are only text");
    }

    void invalidBytesAreReplaced() {
        check::that(frames::cleanTitle("a\xFF!") == "a�!", "a byte that is never UTF-8");
        check::that(frames::cleanTitle("a\xC3") == "a\xEF\xBF\xBD", "a character cut at the end");
        check::that(frames::cleanTitle("\xC0\xAF") == "\xEF\xBF\xBD\xEF\xBF\xBD", "an overlong slash");
        check::that(frames::cleanTitle("\xED\xA0\x80") == "\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD", "a UTF-16 surrogate");
        check::that(frames::cleanTitle("\xF4\x90\x80\x80") == "\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD\xEF\xBF\xBD", "past Unicode's end");
    }

    void longTitlesAreCut() {
        const std::string huge(100000, 'x');
        check::that(frames::cleanTitle(huge).size() == frames::maxTitleBytes, "cut to the limit");

        // 3-byte characters do not divide the limit: the cut falls between two of them
        std::string wide = "";
        for (int index = 0; index < 1000; index++) {
            wide += "日";
        }
        const std::string cut = frames::cleanTitle(wide);
        check::that(cut.size() <= frames::maxTitleBytes && cut.size() % 3 == 0, "never inside a character");
    }

}

int main() {
    plainTitlesStay();
    controlsBecomeSpaces();
    invalidBytesAreReplaced();
    longTitlesAreCut();
    return check::result("text");
}
