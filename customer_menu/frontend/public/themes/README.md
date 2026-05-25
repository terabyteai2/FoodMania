# Customer-menu theme assets

One subfolder per theme slug, matching the keys in
`src/themes/index.jsx` / backend `ALLOWED_MENU_THEMES`. Each folder is the
fallback media used by that theme's Hero when the outlet itself has not
uploaded a banner / gallery / video.

Drop these files into each `<slug>/`:

- `hero-placeholder.jpg` — still image, used as poster + when video is unavailable
- `hero-placeholder.mp4` — short looping clip, lazy-loaded with `preload="metadata"`

Files are optional. If absent, the Hero falls back to a generated pattern
using the theme's palette.

The outlet's own uploaded `videoUrl` / `galleryImages` / `bannerUrl` always
takes priority over these per-theme placeholders.
