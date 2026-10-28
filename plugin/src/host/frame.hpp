#pragma once

#include <hyprland/src/render/Texture.hpp>
#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>

#include <any>
#include <cstdint>
#include <optional>
#include <string>

#include "core/buttons.hpp"
#include "core/layout.hpp"
#include "core/tokens.hpp"
#include "core/window.hpp"

namespace frames::host {

    struct Preview;

}

// One window's frame: a decoration Hyprland owns and calls. Every method Hyprland calls is guarded (host/state.hpp)
// and does nothing for a frame of an earlier load (`load`), which Hyprland may delete after the plugin is gone.
namespace frames::host {

    // What the frame needs to know of its window's state, read from Hyprland each time
    struct WindowFacts {
        Placement placement = Placement::Floating;
        bool      fixed     = false;
    };

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

        static WindowFacts factsOf(const PHLWINDOW& window);

        // The frame on the screen (logical, global), and its parts there; nothing while it draws no frame
        std::optional<FrameLayout> layoutNow() const;
        std::optional<Box>         outerNow() const;

        // What is at a point of the screen (logical, global), and which sides a point on its edge resizes. `sides`
        // are those that resize the window (core/layout.hpp partAt).
        Part  partAt(const Vector2D& point, const Edges& sides) const;
        Edges edgesAt(const Vector2D& point) const;

        void   pointerMoved(Button at);
        bool   pointerPressed(Button at);
        Button pointerReleased(Button at);
        void   pointerLeft();
        bool   holding() const;

        void titleChanged();
        void lookChanged();

        // Asks Hyprland to place the frame again when the room it needs changed: the scale, or whether the app now
        // draws its own title bar
        void refresh();

        // Lets go of its textures before the plugin unloads
        void forgetTextures();

      private:
        bool                 mine() const;
        bool                 framed(const PHLWINDOW& window) const;
        std::optional<Box>   outerBox(const PHLWINDOW& window) const;
        void                 drawFrame(const PHLMONITOR& monitor, float alpha);
        void                 drawPreviews(const PHLMONITOR& monitor, float alpha);
        void                 drawPreview(const PHLMONITOR& monitor, float alpha, const Preview& preview);
        void                 damageCaption();
        SP<Render::ITexture> iconFor(const PHLWINDOW& window, double pixels);
        SP<Render::ITexture> titleFor(const PHLWINDOW& window, double pixels, int maxWidth);

        PHLWINDOWREF  owner;
        std::uint64_t load = 0;
        CBox          assigned;
        Pointer       pointer = {};

        // What the last positioning asked Hyprland for, to tell when it must be asked again
        bool   reserved      = false;
        double reservedScale = 0;
        // Where the frame was drawn last, to draw again what it left when it shrank with its app
        std::optional<Box> drawnOuter = std::nullopt;

        bool                 titleDirty   = true;
        SP<Render::ITexture> titleTexture = nullptr;
        double               titlePixels  = 0;
        int                  titleWidth   = 0;
        Theme                titleTheme   = Theme::Aero;

        SP<Render::ITexture> iconTexture = nullptr;
        std::uint64_t        iconChanges = 0;
        int                  iconSize    = 0;
    };

}
