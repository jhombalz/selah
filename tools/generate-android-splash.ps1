$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $projectRoot 'assets/fonts/source-serif-4/SourceSerif4-Bold.ttf'))
$outline = New-Object System.Drawing.Drawing2D.GraphicsPath
$outline.AddString('SELAH', $fonts.Families[0], [int][System.Drawing.FontStyle]::Bold,
    14, [System.Drawing.PointF]::new(0, 0), [System.Drawing.StringFormat]::GenericTypographic)
$bounds = $outline.GetBounds()
$scale = 42 / $bounds.Width
$matrix = New-Object System.Drawing.Drawing2D.Matrix
$matrix.Translate(-$bounds.X, -$bounds.Y)
$outline.Transform($matrix)
$matrix.Reset()
$matrix.Scale($scale, $scale)
$outline.Transform($matrix)
$matrix.Reset()
$matrix.Translate(33, 73)
$outline.Transform($matrix)
function Number($value) { $value.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture) }
$points = $outline.PathPoints
$types = $outline.PathTypes
$commands = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $points.Length; $i++) {
    $kind = $types[$i] -band 7
    switch ($kind) {
        0 { $commands.Add("M$(Number $points[$i].X),$(Number $points[$i].Y)") }
        1 { $commands.Add("L$(Number $points[$i].X),$(Number $points[$i].Y)") }
        3 {
            $commands.Add("C$(Number $points[$i].X),$(Number $points[$i].Y) $(Number $points[$i+1].X),$(Number $points[$i+1].Y) $(Number $points[$i+2].X),$(Number $points[$i+2].Y)")
            $i += 2
        }
        default { throw 'Unexpected font outline segment' }
    }
    if ($types[$i] -band 128) { $commands.Add('Z') }
}
$foreground = Join-Path $projectRoot 'android/app/src/main/res/drawable/ic_launcher_foreground.xml'
$splash = [System.IO.File]::ReadAllText($foreground).Replace('android:translateY="18"', 'android:translateY="8"')
$splash = $splash.Replace('Keep the book and sun within the adaptive icon''s central safe area.',
    'Splash-only logo and Source Serif 4 label, inside the Android 12 circular safe area.')
$label = '    <path android:fillColor="#FAF7EF" android:pathData="' + ($commands -join ' ') + '" />'
$splash = $splash.Replace('</vector>', "$label`n</vector>")
[System.IO.File]::WriteAllText((Join-Path $projectRoot 'android/app/src/main/res/drawable/selah_splash_icon.xml'),
    $splash, [System.Text.UTF8Encoding]::new($false))
$outline.Dispose()
$matrix.Dispose()
$fonts.Dispose()
Write-Output 'Generated Android splash icon with SELAH label. Launcher and web icons unchanged.'
