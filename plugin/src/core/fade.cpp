#include "core/fade.hpp"

#include <algorithm>
#include <cmath>

namespace frames {

    namespace {

        double opacityOf(double value) {
            return std::isfinite(value) ? std::clamp(value, 0.0, 1.0) : 0;
        }

        // How far through it is, from 0 to 1; 1 when there is nothing left to do or a value is not a number
        double progress(const Fade& fade, double nowMs, double durationMs) {
            const double end      = fade.in ? 1 : 0;
            const double distance = std::abs(end - opacityOf(fade.from));
            const double span     = durationMs * distance;
            if (!std::isfinite(span) || span <= 0) {
                return 1;
            }

            const double done = (nowMs - fade.startMs) / span;
            return std::isfinite(done) ? std::clamp(done, 0.0, 1.0) : 1;
        }

    }

    Fade fadeFrom(double opacity, bool in, double nowMs) noexcept {
        return {.from = opacityOf(opacity), .in = in, .startMs = nowMs};
    }

    double opacityAt(const Fade& fade, double nowMs, double durationMs) noexcept {
        const double from  = opacityOf(fade.from);
        const double end   = fade.in ? 1 : 0;
        const double left  = 1 - progress(fade, nowMs, durationMs);
        const double eased = 1 - left * left;
        return from + (end - from) * eased;
    }

    bool settled(const Fade& fade, double nowMs, double durationMs) noexcept {
        return progress(fade, nowMs, durationMs) >= 1;
    }

}
