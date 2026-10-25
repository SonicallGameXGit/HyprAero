#include <stdexcept>
#include <string>

#include "check.hpp"
#include "core/safety.hpp"

namespace {

    void bodyRunsWhileOn() {
        frames::Safety safety = {};
        int            runs   = 0;

        const bool ran = frames::guarded(safety, "test", [&] { runs += 1; });

        check::that(ran, "guarded says the body ran");
        check::that(runs == 1, "the body ran once");
        check::that(!safety.off, "a body that returns leaves the plugin on");
    }

    void anExceptionTurnsItOff() {
        frames::Safety safety = {};

        const bool ran = frames::guarded(safety, "draw", [] { throw std::runtime_error("broken"); });

        check::that(!ran, "guarded says the body did not finish");
        check::that(safety.off, "the plugin is off");
        check::that(safety.where == "draw", "it remembers where");
        check::that(safety.reason == "broken", "it remembers the exception's words");
    }

    void anExceptionOfAnyTypeTurnsItOff() {
        frames::Safety safety = {};

        frames::guarded(safety, "input", [] { throw 42; });

        check::that(safety.off, "an int thrown is caught too");
        check::that(safety.reason == "an exception of an unknown type", "and named as unknown");
    }

    void nothingRunsOnceOff() {
        frames::Safety safety = {};
        frames::turnOff(safety, "draw", "broken");
        int runs = 0;

        const bool ran = frames::guarded(safety, "input", [&] { runs += 1; });

        check::that(!ran, "guarded says the body did not run");
        check::that(runs == 0, "the body did not run");
    }

    void guardedAlwaysRunsOnceOff() {
        frames::Safety safety = {};
        frames::turnOff(safety, "draw", "broken");
        int runs = 0;

        const bool ran = frames::guardedAlways(safety, "status", [&] { runs += 1; });

        check::that(ran, "guardedAlways ran the body");
        check::that(runs == 1, "once");
    }

    void onlyTheFirstErrorIsKept() {
        frames::Safety safety = {};

        frames::guardedAlways(safety, "draw", [] { throw std::runtime_error("first"); });
        frames::guardedAlways(safety, "exit", [] { throw std::runtime_error("second"); });

        check::that(safety.where == "draw" && safety.reason == "first", "the first error is the one kept");
    }

    void wordsArePlainAndShort() {
        const std::string controls = std::string("a\nb\0c", 5) + "\xc3\xa9";
        check::that(frames::plainText(controls, 100) == "a?b?c??", "control characters and other bytes become ?");
        check::that(frames::plainText(std::string(500, 'x'), 200).size() == 200, "cut to the longest allowed");
        check::that(frames::plainText("", 10).empty(), "empty stays empty");

        frames::Safety safety = {};
        frames::guarded(safety, "draw", [] { throw std::runtime_error(std::string(1000, 'y')); });
        check::that(safety.reason.size() == frames::maxReasonLength, "a long reason is cut");
    }

}

int main() {
    bodyRunsWhileOn();
    anExceptionTurnsItOff();
    anExceptionOfAnyTypeTurnsItOff();
    nothingRunsOnceOff();
    guardedAlwaysRunsOnceOff();
    onlyTheFirstErrorIsKept();
    wordsArePlainAndShort();
    return check::result("safety");
}
