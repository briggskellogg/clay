# Clay: first native version

## Product distinction

Scratchpads hold thinking, fragments, rough drafts and private notes. They are useful as they are; they do not need to become a Piece. Pieces hold writing the author has deliberately chosen to treat as composed or finished. Moving between these destinations changes one document's section; it does not duplicate, freeze, publish or export the writing.

Both destinations use the same editor, preserving a consistent writing experience. Pieces remain editable. The workflow adds the distinction the owner wanted without adding a project-management pipeline.

## Visual language

The design follows the supplied Bard/Wisp/Notes/Tasks references: quiet gray navigation, white writing space, restrained separators, broad margins, clear headings, and few controls near the text. The supplied Clay symbol provides the red brand signature, with its handwritten wordmark removed. The symbol and the app name in PP Neue Montreal appear at the top; the owner's gold maker's signature appears near a bottom corner. PP Neue Montreal supplies navigation and headings; PP Neue York supplies the default writing face. System monospace and sans serif alternatives are available. Appearance can follow the system or remain Light or Dark.

| Element | Treatment | Meaning |
| --- | --- | --- |
| Scratchpads | Filled document, amber | Primary writing destination |
| Pieces | Filled closed book, blue | Primary writing destination |
| Selected destination | Neutral highlight and stronger label | Current location |
| Collection | Gray outline folder | User organization |
| Search, import, export, focus | Neutral outline symbols | Utility actions |
| Pin off / on | Outline / amber fill | Persistent pin state |
| Move action | Labeled button | Explicit section change |

Primary icons remain colored and filled when inactive. Selection is communicated independently with background and label weight. Labels and distinct shapes carry meaning alongside color. Pin state also changes shape. The colors adapt to dark appearance.

## Platform behavior

The Mac uses a sidebar, document list and editor in resizable split panes. Focus mode hides the first two panes. Native commands cover creating, importing, saving, exporting, searching, pinning, moving and opening recovery locations. Quit waits for pending saves and offers retry or cancellation if writing could not be saved.

The phone uses a library list with bottom Scratchpads/Pieces navigation. Opening a document pushes a full editor with native Back navigation. Search and creation stay near the library; editing options, pinning and export stay in the editor. Larger text uses an alternate destination layout. The writing area adapts to the keyboard, and a Done action dismisses it.

## Scope boundaries for 0.1

Local writing, saving, navigation and Markdown portability form the first version. The owner's later request adds optional private folder synchronization through personal iCloud Drive, with offline revision history, recoverable conflict copies, and Windows-readable Markdown exports. Private writing stays outside GitHub and the Proton source mirror. Exports are reading copies; editing them does not import into Clay. Collaboration, publishing, rich document attachments, advanced Markdown rendering, and iA Writer feature parity remain outside this implementation. See TEST_REPORT.md and Release/project-destinations.json for live-device verification limits.
