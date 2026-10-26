#pragma once

#include <hyprland/src/render/Texture.hpp>
#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>

#include <any>
#include <cstdint>
#include <string>

#include "core/buttons.hpp"
#include "core/layout.hpp"
#include "core/tokens.hpp"

// One window's frame: a decoration Hyprland owns and calls. Every method Hyprland calls is guarded (host/state.hpp)
// and does nothing for a frame of an earlier load (`load`), which Hyprland may delete after the plugin is gone.
namespace frames::host {

    class Frame : public IHyprWindowDecoration {
      public:
        Frame(const PHLWINDOW& window, std::uint64_t loadNumber);
        ~Frame() override = default;

        Frame(const Frame&)            = delete;
        Frame(Frame&&)                 = delete;
        Frame& operator=(const Frame&) = delete;
        Frame& operator=(Frame&&)      = delete;

        SDecorationPositioningInfo getPositioningInfo() noexcept override;
        void                       onPositioningReply(const SDecorationPositioningReply& reply) noexcept override;
        void                       draw(PHLMONITOR monitor, float const& alpha) noexcept override;
        eDecorationType            getDecorationType() noexcept override;
        void                       updateWindow(PHLWINDOW window) noexcept override;
        void                       damageEntire() noexcept override;
        bool                       onInputOnDeco(eInputType type, const Vector2D& coords, std::any data) noexcept override;
        eDecorationLayer           getDecorationLayer() noexcept override;
        uint64_t                   getDecorationFlags() noexcept override;
        std::string                getDisplayName() noexcept override;

        // The rest is for host/frames.cpp, called inside its own guarded calls

        // The window, or nullptr once it is gone; used inside the current call only
        PHLWINDOW window() const;
        bool      belongsTo(const PHLWINDOW& window) const;

        // What is at a point of the screen (logical, global)
        Part partAt(const Vector2D& point) const;

        void   pointerMoved(Button at);
        bool   pointerPressed(Button at);
        Button pointerReleased(Button at);
        void   pointerLeft();
        bool   holding() const;

        void titleChanged();
        void lookChanged();

        // Lets go of its textures before the plugin unloads
        void forgetTextures();

      private:
        bool                 mine() const;
        bool                 wantsFrame(const PHLWINDOW& window) const;
        CBox                 outerBox(const PHLWINDOW& window) const;
        void                 drawFrame(const PHLMONITOR& monitor, float alpha);
        void                 damageCaption();
        SP<Render::ITexture> iconFor(const PHLWINDOW& window, double scale);
        SP<Render::ITexture> titleFor(const PHLWINDOW& window, double scale, int maxWidth);

        PHLWINDOWREF  owner;
        std::uint64_t load = 0;
        CBox          assigned;
        Pointer       pointer = {};

        bool                 titleDirty   = true;
        SP<Render::ITexture> titleTexture = nullptr;
        double               titleScale   = 0;
        int                  titleWidth   = 0;
        Theme                titleTheme   = Theme::Aero;

        SP<Render::ITexture> iconTexture = nullptr;
        std::uint64_t        iconChanges = 0;
        int                  iconSize    = 0;
    };

}
