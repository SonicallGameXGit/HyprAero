#pragma once

// A picture that fades in when it appears and out when it goes (motion-soft, eased out), as Windows 7's preview of
// where a moved window will go. A fade that turns back starts from where it was, and takes only the time it needs
// from there. Times are in milliseconds, from any fixed start.
namespace frames {

    struct Fade {
        // The opacity when it began, from 0 to 1, and which way it goes
        double from    = 0;
        bool   in      = true;
        double startMs = 0;
    };

    Fade fadeFrom(double opacity, bool in, double nowMs) noexcept;

    double opacityAt(const Fade& fade, double nowMs, double durationMs) noexcept;

    // Whether it reached its end: fully shown, or gone
    bool settled(const Fade& fade, double nowMs, double durationMs) noexcept;

}
