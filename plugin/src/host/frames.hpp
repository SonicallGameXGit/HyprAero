#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

#include <string>

// Puts a frame on every window that leaves its decoration to Hyprland, follows the pointer over them, and answers
// the companion (core/command.hpp)
namespace frames::host {

    // Called from pluginInit, after the state is made: listens to Hyprland and frames the windows already open
    void startFrames();

    // Called from pluginExit: stops listening, lets the frames go (Hyprland removes them itself after pluginExit)
    void stopFrames() noexcept;

    // `hyprctl hypraero-frames ...`
    std::string answerRequest(eHyprCtlOutputFormat format, const std::string& request) noexcept;

}
