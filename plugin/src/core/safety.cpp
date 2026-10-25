#include "core/safety.hpp"

namespace frames {

    std::string plainText(std::string_view text, std::size_t maxLength) noexcept {
        try {
            std::string plain = "";
            plain.reserve(text.size() < maxLength ? text.size() : maxLength);
            for (const char character : text) {
                if (plain.size() == maxLength) {
                    break;
                }

                const bool printable = character >= ' ' && character <= '~';
                plain.push_back(printable ? character : '?');
            }

            return plain;
        } catch (...) {
            // Only running out of memory gets here; an empty text is still an answer
            return {};
        }
    }

    void turnOff(Safety& safety, std::string_view where, std::string_view reason) noexcept {
        if (safety.off) {
            return;
        }

        // Off first, so the switch holds even if keeping the words fails
        safety.off    = true;
        safety.where  = plainText(where, maxReasonLength);
        safety.reason = plainText(reason, maxReasonLength);
    }

}
