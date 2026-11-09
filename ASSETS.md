# Brand assets

The app uses an exact pixel crop of the supplied Clay artwork at:

`Resources/Assets.xcassets/ClayMark.imageset/clay.png`

At the owner's request, build 5 removes the handwritten wordmark. The 880 × 605 crop starts at (200, 175) in the original 1254 × 1254 PNG; it preserves the symbol pixels without tracing, recoloring, or resampling. The original full artwork remains in Git history. Image-generation experiments were discarded; they are not shipped.

`Resources/Assets.xcassets/MakerMark.imageset/maker-mark.png` is the exact transparent 416 × 512 gold maker's signature used by Bard, in `#D1A13A`. It is not the separate BK monogram. The source SHA-256 is `28fdbed18575b99104c7a0c745fc9099ce86462744f0b01bfea2308876d03fe6`.

The AppKit build step composes the symbol and a small maker's mark at the lower right. Mac icons retain transparency; iOS supplies a transparent Dark variant and an opaque default/store fallback required by the platform. Apple may apply its own icon mask or background. Generated icon PNGs are build outputs. Inside the app, the symbol and the app name in PP Neue Montreal occupy a top corner, and the gold maker's signature sits near a bottom corner.

The following font files came from the owner's existing [Bard project](https://github.com/briggskellogg/bard), used here as the requested visual reference:

| File | PostScript name | App use |
| --- | --- | --- |
| PPNeueMontreal-Regular.ttf | PPNeueMontreal-Regular | Navigation and controls |
| PPNeueMontreal-Bold.ttf | PPNeueMontreal-Bold | Headings and emphasized labels |
| PPNeueYork-NormalLight.otf | PPNeueYork-NormalLight | Default writing face |

Original font metadata is preserved. This source package does not add or extend the licensing terms of those assets.

Interface symbols use Apple's system SF Symbols through SwiftUI. No external icon package is required.
