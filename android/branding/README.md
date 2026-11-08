# Android SELAH branding

The original open-book-and-sun logo uses forest green (#244B3E), cream
(#FAF7EF), and gold (#D8BB79). This directory is Android-only; web branding
and GitHub Pages assets are separate and unchanged.

- Legacy launcher/installer icons: `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}`,
  respectively 48, 72, 96, 144, and 192 pixels, including circular variants.
- Android 8+: adaptive foreground/background layers in `mipmap-anydpi-v26`.
- Android 13+: monochrome themed layer in `mipmap-anydpi-v33`.
- Android 12+: system launch-screen styling in `values-v31` and
  `values-night-v31`; the foreground artwork stays within the icon safe zone.
- Earlier Android: centered logo on a forest-green launch background.

The Android manifest uses `ic_launcher` and `ic_launcher_round`; installation,
the launcher, app information, and supported task switchers use those resources.
Install a rebuilt APK over the current app to receive new native icons.
Hot reload and a web/PWA update do not replace APK resources.

Regenerate the committed legacy PNGs with Node 22+ and Chrome:

```powershell
node tools/generate-android-icons.cjs
```

Set `CHROME_EXECUTABLE` if Chrome is not installed at the standard Windows path.
The tool reads only `android/branding/selah-mark.svg` and writes only Android
launcher PNGs. The native adaptive/monochrome layers are vector resources with
matching geometry. No package dependency or network font is required.
