#include "host/titleBars.hpp"

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/protocols/XDGDecoration.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>

#include <unordered_map>

namespace frames::host {

    namespace {

        // The two private members read, their types written out: a Hyprland that changed them fails to build here
        // instead of being read wrong
        using Decorations = std::unordered_map<wl_resource*, UP<CXDGDecoration>>;

        // CXDGDecorationProtocol::m_decorations: each toplevel's wire object to what its app asked
        struct DecorationsTag {
            using Member = Decorations CXDGDecorationProtocol::*;
            friend Member              member(DecorationsTag /* tag */);
        };

        // CXDGToplevelResource::m_resource: a toplevel's wire object, the table's key
        struct ToplevelTag {
            using Member = SP<CXdgToplevel> CXDGToplevelResource::*;
            friend Member                   member(ToplevelTag /* tag */);
        };

        // C++ lets an explicit instantiation name a private member; the tag carries the member pointer out of it.
        // Only pointers to the members are taken: nothing of Hyprland's is called or changed this way.
        template <typename Tag, typename Tag::Member Pointer>
        struct Reach {
            friend typename Tag::Member member(Tag /* tag */) {
                return Pointer;
            }
        };

        template struct Reach<DecorationsTag, &CXDGDecorationProtocol::m_decorations>;
        template struct Reach<ToplevelTag, &CXDGToplevelResource::m_resource>;

    }

    DecorationRequest decorationRequestOf(const PHLWINDOW& window) {
        if (window == nullptr || window->m_isX11 || PROTO::xdgDecoration == nullptr) {
            return DecorationRequest::Never;
        }

        const auto surface = window->m_xdgSurface.lock();
        if (surface == nullptr) {
            return DecorationRequest::Never;
        }

        const auto toplevel = surface->m_toplevel.lock();
        if (toplevel == nullptr) {
            return DecorationRequest::Never;
        }

        const SP<CXdgToplevel>& wire = (*toplevel).*member(ToplevelTag{});
        if (wire == nullptr || wire->resource() == nullptr) {
            return DecorationRequest::Never;
        }

        // Keys are only compared, never followed: another app's may already be gone while its client disconnects
        const Decorations& decorations = (*PROTO::xdgDecoration).*member(DecorationsTag{});
        const auto         found       = decorations.find(wire->resource());
        if (found == decorations.end() || found->second == nullptr) {
            return DecorationRequest::Never;
        }

        return decorationRequestFrom(true, found->second->mostRecentlyRequested);
    }

}
