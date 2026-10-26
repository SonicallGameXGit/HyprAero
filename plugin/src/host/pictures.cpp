#include "host/pictures.hpp"

#include <hyprland/src/render/Renderer.hpp>

#include <bit>
#include <cstring>

#include "core/layout.hpp"

// GCC takes C++26's #embed as standard; clang-tidy's Clang still calls it an extension of C23
#ifdef __clang__
#pragma clang diagnostic ignored "-Wc23-extensions"
#endif

namespace frames::host {

    namespace {

        // Cairo's ARGB32 is a 32-bit value in the machine's order; the icons' pixels are copied as such values
        static_assert(std::endian::native == std::endian::little, "the pictures are prepared for a little-endian machine");

        // In the order of Piece (core/pieces.hpp), each from resources/ (--embed-dir)
        constexpr unsigned char faceMaximizeRest[] = {
#embed "frame/face-maximize-rest.png"
        };
        constexpr unsigned char faceMaximizeHover[] = {
#embed "frame/face-maximize-hover.png"
        };
        constexpr unsigned char faceMaximizePressed[] = {
#embed "frame/face-maximize-pressed.png"
        };
        constexpr unsigned char faceMaximizeInactive[] = {
#embed "frame/face-maximize-inactive.png"
        };
        constexpr unsigned char faceCloseRest[] = {
#embed "frame/face-close-rest.png"
        };
        constexpr unsigned char faceCloseHover[] = {
#embed "frame/face-close-hover.png"
        };
        constexpr unsigned char faceClosePressed[] = {
#embed "frame/face-close-pressed.png"
        };
        constexpr unsigned char faceCloseInactive[] = {
#embed "frame/face-close-inactive.png"
        };
        constexpr unsigned char glyphClose[] = {
#embed "frame/glyph-close.png"
        };
        constexpr unsigned char glyphCloseInactive[] = {
#embed "frame/glyph-close-inactive.png"
        };
        constexpr unsigned char glyphMaximize[] = {
#embed "frame/glyph-maximize.png"
        };
        constexpr unsigned char glyphMaximizeInactive[] = {
#embed "frame/glyph-maximize-inactive.png"
        };
        constexpr unsigned char glyphRestore[] = {
#embed "frame/glyph-restore.png"
        };
        constexpr unsigned char glyphRestoreInactive[] = {
#embed "frame/glyph-restore-inactive.png"
        };
        constexpr unsigned char glowMaximize[] = {
#embed "frame/glow-maximize.png"
        };
        constexpr unsigned char glowClose[] = {
#embed "frame/glow-close.png"
        };
        constexpr unsigned char glowTitle[] = {
#embed "frame/glow-title.png"
        };
        constexpr unsigned char reflection[] = {
#embed "frame/reflection.png"
        };
        constexpr unsigned char application16[] = {
#embed "icons/application-16.png"
        };
        constexpr unsigned char application32[] = {
#embed "icons/application-32.png"
        };

        constexpr std::array<std::span<const unsigned char>, pieceCount> embedded = {{
            faceMaximizeRest,  faceMaximizeHover, faceMaximizePressed, faceMaximizeInactive, faceCloseRest,         faceCloseHover, faceClosePressed,
            faceCloseInactive, glyphClose,        glyphCloseInactive,  glyphMaximize,        glyphMaximizeInactive, glyphRestore,   glyphRestoreInactive,
            glowMaximize,      glowClose,         glowTitle,           reflection,           application16,         application32,
        }};

        struct Reader {
            std::span<const unsigned char> bytes = {};
            std::size_t                    at    = 0;
        };

        // Cairo's PNG reader asks for exactly `length` bytes each time; fewer is an error
        cairo_status_t readBytes(void* closure, unsigned char* data, unsigned int length) noexcept {
            auto* reader = static_cast<Reader*>(closure);
            if (reader == nullptr || length > reader->bytes.size() - reader->at) {
                return CAIRO_STATUS_READ_ERROR;
            }

            std::memcpy(data, reader->bytes.subspan(reader->at, length).data(), length);
            reader->at += length;
            return CAIRO_STATUS_SUCCESS;
        }

        Surface decode(std::span<const unsigned char> bytes, const PieceInfo& info) noexcept {
            Reader  reader  = {.bytes = bytes};
            Surface surface = Surface(cairo_image_surface_create_from_png_stream(readBytes, &reader));
            if (surface == nullptr || cairo_surface_status(surface.get()) != CAIRO_STATUS_SUCCESS) {
                return nullptr;
            }

            const bool expected = cairo_image_surface_get_format(surface.get()) == CAIRO_FORMAT_ARGB32 &&
                                  cairo_image_surface_get_width(surface.get()) == info.width && cairo_image_surface_get_height(surface.get()) == info.height;
            if (!expected) {
                return nullptr;
            }

            return surface;
        }

        // A part of a picture as a picture of its own
        Surface cut(cairo_surface_t* source, const Box& part) {
            const int width  = static_cast<int>(part.width);
            const int height = static_cast<int>(part.height);
            if (width <= 0 || height <= 0) {
                return nullptr;
            }

            Surface piece = Surface(cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height));
            if (cairo_surface_status(piece.get()) != CAIRO_STATUS_SUCCESS) {
                return nullptr;
            }

            cairo_t* const context = cairo_create(piece.get());
            cairo_set_operator(context, CAIRO_OPERATOR_SOURCE);
            cairo_set_source_surface(context, source, -part.x, -part.y);
            cairo_paint(context);
            const bool drawn = cairo_status(context) == CAIRO_STATUS_SUCCESS;
            cairo_destroy(context);
            if (!drawn) {
                return nullptr;
            }

            cairo_surface_flush(piece.get());
            return piece;
        }

        // Hyprland uploads the pixels as rows of exactly width x 4 bytes, which is what cairo makes for ARGB32
        bool uploadable(cairo_surface_t* surface) {
            return cairo_image_surface_get_stride(surface) == cairo_image_surface_get_width(surface) * 4;
        }

    }

    std::size_t decodePictures(Pictures& pictures) noexcept {
        std::size_t failed = 0;
        for (std::size_t index = 0; index < pieceCount; index++) {
            pictures.surfaces.at(index) = decode(embedded.at(index), pieces.at(index));
            if (pictures.surfaces.at(index) == nullptr || !uploadable(pictures.surfaces.at(index).get())) {
                pictures.surfaces.at(index) = nullptr;
                failed += 1;
            }
        }

        return failed;
    }

    SP<Render::ITexture> pictureTexture(Pictures& pictures, Piece piece) {
        const auto index = static_cast<std::size_t>(piece);
        if (pictures.whole.at(index) == nullptr && pictures.surfaces.at(index) != nullptr) {
            pictures.whole.at(index) = g_pHyprRenderer->createTexture(pictures.surfaces.at(index).get());
        }

        return pictures.whole.at(index);
    }

    SP<Render::ITexture> sliceTexture(Pictures& pictures, Piece piece, std::size_t index) {
        const auto pieceIndex = static_cast<std::size_t>(piece);
        if (index >= 9 || pictures.surfaces.at(pieceIndex) == nullptr) {
            return nullptr;
        }

        SP<Render::ITexture>& texture = pictures.slices.at(pieceIndex).at(index);
        if (texture == nullptr) {
            const PieceInfo& info   = pieceInfo(piece);
            const auto       slices = nineSlice(info.width, info.height, info.margins,
                                                {.x = 0, .y = 0, .width = static_cast<double>(info.width), .height = static_cast<double>(info.height)});
            const Surface    part   = cut(pictures.surfaces.at(pieceIndex).get(), slices.at(index).source);
            if (part == nullptr || !uploadable(part.get())) {
                return nullptr;
            }

            texture = g_pHyprRenderer->createTexture(part.get());
        }

        return texture;
    }

    SP<Render::ITexture> makeIconTexture(std::span<const std::uint32_t> pixels, int size) {
        if (size <= 0 || pixels.size() != static_cast<std::size_t>(size) * static_cast<std::size_t>(size)) {
            return nullptr;
        }

        const Surface surface = Surface(cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size));
        if (cairo_surface_status(surface.get()) != CAIRO_STATUS_SUCCESS || !uploadable(surface.get())) {
            return nullptr;
        }

        cairo_surface_flush(surface.get());
        unsigned char* const data = cairo_image_surface_get_data(surface.get());
        if (data == nullptr) {
            return nullptr;
        }

        std::memcpy(data, pixels.data(), pixels.size_bytes());
        cairo_surface_mark_dirty(surface.get());
        return g_pHyprRenderer->createTexture(surface.get());
    }

}
