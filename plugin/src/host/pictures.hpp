#pragma once

#include <hyprland/src/render/Texture.hpp>

#include <cairo.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <span>

#include "core/pieces.hpp"

// Windows 7's pictures, built into the plugin (resources/README.md), and the textures made from them
namespace frames::host {

    struct SurfaceRelease {
        void operator()(cairo_surface_t* surface) const noexcept {
            cairo_surface_destroy(surface);
        }
    };

    using Surface = std::unique_ptr<cairo_surface_t, SurfaceRelease>;

    struct Pictures {
        // Decoded once, at load
        std::array<Surface, pieceCount> surfaces = {};
        // Made the first time they are drawn, inside Hyprland's drawing (a texture needs its GL context)
        std::array<SP<Render::ITexture>, pieceCount>                whole  = {};
        std::array<std::array<SP<Render::ITexture>, 9>, pieceCount> slices = {};
    };

    // Returns how many pictures could not be decoded or are not the size the layout counts with; those are left out
    // of the drawing
    std::size_t decodePictures(Pictures& pictures) noexcept;

    // nullptr for a picture that could not be decoded
    SP<Render::ITexture> pictureTexture(Pictures& pictures, Piece piece);

    // One of the nine slices of a stretched picture (core/layout.hpp, nineSlice with the piece's own margins)
    SP<Render::ITexture> sliceTexture(Pictures& pictures, Piece piece, std::size_t index);

    // A texture of size x size premultiplied pixels (core/icons.hpp); nullptr when they are not that many
    SP<Render::ITexture> makeIconTexture(std::span<const std::uint32_t> pixels, int size);

}
