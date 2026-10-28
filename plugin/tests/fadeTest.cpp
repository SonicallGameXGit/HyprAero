#include <limits>

#include "check.hpp"
#include "core/fade.hpp"

namespace {

    constexpr double duration = 220;

    void fadingIn() {
        const frames::Fade fade = frames::fadeFrom(0, true, 1000);
        check::that(frames::opacityAt(fade, 1000, duration) == 0, "it starts unseen");
        check::that(frames::opacityAt(fade, 1110, duration) == 0.75, "eased out: three quarters there halfway");
        check::that(frames::opacityAt(fade, 1220, duration) == 1, "fully there after motion-soft");
        check::that(frames::opacityAt(fade, 5000, duration) == 1, "and stays");
        check::that(!frames::settled(fade, 1100, duration), "not settled on the way");
        check::that(frames::settled(fade, 1220, duration), "settled at the end");
        check::that(frames::opacityAt(fade, 900, duration) == 0, "a clock that went back shows its start");
    }

    void fadingOut() {
        const frames::Fade fade = frames::fadeFrom(1, false, 0);
        check::that(frames::opacityAt(fade, 110, duration) == 0.25, "halfway out");
        check::that(frames::opacityAt(fade, 220, duration) == 0, "gone");
        check::that(frames::settled(fade, 220, duration), "settled when gone");

        // Turned back halfway: only the half left to go, in half the time
        const frames::Fade back = frames::fadeFrom(0.5, false, 0);
        check::that(frames::opacityAt(back, 110, duration) == 0, "from halfway, out in half the time");
        check::that(frames::settled(back, 110, duration), "and settled then");
    }

    void oddValues() {
        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        check::that(frames::opacityAt(frames::fadeFrom(notANumber, true, 0), 10, duration) >= 0, "an opacity that is not a number starts from none");
        check::that(frames::opacityAt(frames::fadeFrom(3, false, 0), 0, duration) == 1, "more than fully there counts as fully");
        check::that(frames::opacityAt(frames::fadeFrom(0, true, 0), 10, 0) == 1, "no time to fade: there at once");
        check::that(frames::opacityAt(frames::fadeFrom(0, true, 0), notANumber, duration) == 1, "a time that is not a number ends it");
        check::that(frames::settled(frames::fadeFrom(1, true, 0), 0, duration), "nothing to do is settled");
    }

}

int main() {
    fadingIn();
    fadingOut();
    oddValues();
    return check::result("fade");
}
