#include "core/status.hpp"

#include <format>

namespace frames {

    std::string jsonString(std::string_view text) {
        std::string quoted = "\"";
        for (const char character : text) {
            if (character == '"' || character == '\\') {
                quoted.push_back('\\');
                quoted.push_back(character);
            } else if (character >= '\0' && character < ' ') {
                quoted += std::format("\\u{:04x}", static_cast<unsigned char>(character));
            } else {
                quoted.push_back(character);
            }
        }

        return quoted + "\"";
    }

    std::string statusText(const Safety& safety, std::string_view version, bool json) {
        if (json) {
            return std::format("{{\"name\": \"hypraero-frames\", \"version\": {}, \"on\": {}, \"where\": {}, \"reason\": {}}}", jsonString(version),
                               safety.off ? "false" : "true", jsonString(safety.where), jsonString(safety.reason));
        }

        if (safety.off) {
            return std::format("hypraero-frames {}: off since an error in {}: {}. Reload the plugin to turn it on again.\n", version, safety.where,
                               safety.reason);
        }

        return std::format("hypraero-frames {}: on\n", version);
    }

}
