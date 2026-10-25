#pragma once

#include <format>
#include <print>
#include <source_location>
#include <string_view>

// The whole test harness: a failed check prints its line and the test goes on; main returns the result. Kept this
// small so the tests need no library (AGENTS.md section 3).
namespace check {

    inline int failures = 0;

    inline void that(bool condition, std::string_view what, const std::source_location where = std::source_location::current()) {
        if (condition) {
            return;
        }

        failures += 1;
        std::println(stderr, "{}:{}: failed: {}", where.file_name(), where.line(), what);
    }

    inline int result(std::string_view suite) {
        if (failures == 0) {
            std::println("{}: all passed", suite);
            return 0;
        }

        std::println(stderr, "{}: {} failed", suite, failures);
        return 1;
    }

}
