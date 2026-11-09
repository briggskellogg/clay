# Brand assets

The app includes the Clay artwork supplied in this conversation, unchanged at:

`Resources/Assets.xcassets/ClayMark.imageset/clay.png`

The app-icon build step uses AppKit on the build Mac to place that artwork on an opaque light square and produce Apple's icon sizes. It does not redraw the logo. Generated icon PNGs are build outputs; the original remains the source of truth.

The following font files came from the owner's existing [Bard project](https://github.com/briggskellogg/bard), used here as the requested visual reference:

| File | PostScript name | App use |
| --- | --- | --- |
| PPNeueMontreal-Regular.ttf | PPNeueMontreal-Regular | Navigation and controls |
| PPNeueMontreal-Bold.ttf | PPNeueMontreal-Bold | Headings and emphasized labels |
| PPNeueYork-NormalLight.otf | PPNeueYork-NormalLight | Default writing face |

Original font metadata is preserved. This source package does not add or extend the licensing terms of those assets.

Interface symbols use Apple's system SF Symbols through SwiftUI. No external icon package is required.
