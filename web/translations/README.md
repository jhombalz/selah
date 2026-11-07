# Optional offline translation packages

These original eBible VPL ZIP packages are served from the web app's own origin
when a user chooses Download. They are not Flutter assets and are not included
in the Android/iOS installation or the initial web reader asset download.
Native apps fetch the identical packages directly from the source URLs.

- `web.zip`: https://ebible.org/Scriptures/engwebp_vpl.zip
  World English Bible, 66-book Protestant edition, public domain.
  Notice: https://ebible.org/engwebp/copyright.htm
- `asv.zip`: https://ebible.org/Scriptures/eng-asv_vpl.zip
  American Standard Version (1901), public domain.
  Notice: https://ebible.org/eng-asv/copyright.htm
- `bsb.zip`: https://ebible.org/Scriptures/engbsb_vpl.zip
  Berean Standard Bible, public domain. Contributor: BSB Publishing, LLC.
  Notice: https://ebible.org/engbsb/copyright.htm
- `tglulb.zip`: https://ebible.org/Scriptures/tglulb_vpl.zip
  Tagalog Unlocked Literal Bible, © 2018 Door43 World Missions Community.
  CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/
  Full attribution: https://ebible.org/tglulb/copyright.htm
  Upstream notice is retained in `tglulb-copyright.html` and bundled offline as
  `assets/bible/tglulb-LICENSE.txt`, also included in the installed text's license.

Verified 2026-11-07. The archives retain their upstream notices and other
formats. Only the VPL text is installed; Scripture wording is not edited.
VPL source formatting, footnotes, and noncanonical headings are not included.
Empty verse placeholders represent verses absent in that edition and are not
rendered as Scripture. The app keeps annotations for those references.

Expected VPL SHA-256 hashes are recorded in `lib/data/translations.dart`.
Downloads require ZIP CRC verification, a matching VPL hash, and a complete
book/chapter catalog before a database row is installed. Package text changes
require reviewing and updating the pinned hash. Installed JSON has a separate
checksum checked before it is opened.

Same-origin delivery is required because the upstream download endpoint did
not provide Access-Control-Allow-Origin in the checked browser request. Keep
this directory in the web deployment; no proxy or CDN is required.
