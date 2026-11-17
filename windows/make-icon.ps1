param([string]$OutIco, [string]$PreviewPng)
Add-Type -AssemblyName System.Drawing

# Runway seen from the approach: dark tile, asphalt in perspective, white markings, a yellow taxiway exit (the app's theme).
function Draw-Icon([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.Clear([System.Drawing.Color]::Transparent)
  $s = $size / 256.0
  $small = $size -le 32

  # tile
  $r = 52 * $s; $tile = New-Object System.Drawing.Drawing2D.GraphicsPath
  $tile.AddArc(0, 0, 2*$r, 2*$r, 180, 90); $tile.AddArc($size-2*$r, 0, 2*$r, 2*$r, 270, 90)
  $tile.AddArc($size-2*$r, $size-2*$r, 2*$r, 2*$r, 0, 90); $tile.AddArc(0, $size-2*$r, 2*$r, 2*$r, 90, 90); $tile.CloseFigure()
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush ([System.Drawing.PointF]::new(0,0)), ([System.Drawing.PointF]::new(0,$size)), ([System.Drawing.Color]::FromArgb(255,0x1f,0x34,0x4a)), ([System.Drawing.Color]::FromArgb(255,0x0b,0x10,0x14))
  $g.FillPath($bg, $tile)
  $g.SetClip($tile)

  # runway geometry: t = 0 at the near end (bottom), 1 at the far end; u = -1..1 across
  $cx = 128; $yb = 262; $yt = 34; $hb = 82; $ht = 15
  $P = { param([double]$u, [double]$t) $y = $yb + ($yt - $yb) * $t; $h = $hb + ($ht - $hb) * $t; [System.Drawing.PointF]::new(($cx + $u * $h) * $s, $y * $s) }
  $quad = { param([double]$u1, [double]$u2, [double]$t1, [double]$t2) [System.Drawing.PointF[]]@((& $P $u1 $t1), (& $P $u2 $t1), (& $P $u2 $t2), (& $P $u1 $t2)) }

  $asphalt = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,0x4a,0x55,0x61))
  $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,0xf4,0xf6,0xf8))
  $g.FillPolygon($asphalt, (& $quad -1 1 0 1))

  # yellow taxiway exit, curving off to the right
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255,0xf2,0xc2,0x00)), ([single]([Math]::Max(1.6, ($(if ($small) { 13 } else { 9 })) * $s)))
  $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $a = & $P 0.05 0.36; $b = & $P 0.55 0.47; $c = [System.Drawing.PointF]::new(196*$s, 112*$s); $d = [System.Drawing.PointF]::new(262*$s, 96*$s)
  $g.DrawBezier($pen, $a, $b, $c, $d)

  if (-not $small) {
    # edge lines
    $g.FillPolygon($white, (& $quad -0.97 -0.91 0 1)); $g.FillPolygon($white, (& $quad 0.91 0.97 0 1))
    # threshold "piano keys"
    foreach ($side in -1, 1) { for ($k = 0; $k -lt 4; $k++) { $u1 = 0.14 + $k * 0.2; $g.FillPolygon($white, (& $quad ($side*$u1) ($side*($u1+0.12)) 0.08 0.2)) } }
  }
  # centreline dashes, shrinking with distance
  $dashes = if ($small) { @(@(0.12,0.3), @(0.42,0.56), @(0.68,0.78), @(0.87,0.94)) } else { @(@(0.27,0.36), @(0.44,0.52), @(0.59,0.66), @(0.72,0.77), @(0.82,0.86), @(0.9,0.93)) }
  $wu = if ($small) { 0.1 } else { 0.05 }
  foreach ($dd in $dashes) { $g.FillPolygon($white, (& $quad (-$wu) $wu $dd[0] $dd[1])) }

  $g.ResetClip()
  # subtle rim so the tile reads on light backgrounds too
  $rim = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(70,255,255,255)), ([single][Math]::Max(1, 3*$s))
  $g.DrawPath($rim, $tile)
  $g.Dispose()
  return $bmp
}

$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256
$pngs = foreach ($sz in $sizes) { $bmp = Draw-Icon $sz; $ms = New-Object System.IO.MemoryStream; $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); ,$ms.ToArray() }

# .ico with PNG entries (supported since Windows Vista)
$fs = [System.IO.File]::Create($OutIco); $w = New-Object System.IO.BinaryWriter $fs
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $sz = $sizes[$i]; $len = $pngs[$i].Length
  $w.Write([byte]($sz % 256)); $w.Write([byte]($sz % 256)); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$len); $w.Write([uint32]$offset); $offset += $len
}
foreach ($p in $pngs) { $w.Write($p) }
$w.Dispose()

# preview sheet: every size side by side on dark and light backgrounds
$sheet = New-Object System.Drawing.Bitmap 760, 620
$g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::FromArgb(255,0x20,0x20,0x20))
$g.FillRectangle([System.Drawing.Brushes]::WhiteSmoke, 0, 310, 760, 310)
foreach ($row in 0, 1) {
  $x = 10
  foreach ($sz in $sizes) { $bmp = Draw-Icon $sz; $y = 10 + $row * 310 + (256 - [Math]::Min($sz,256)); $g.DrawImage($bmp, $x, $y, $sz, $sz); $bmp.Dispose(); $x += [Math]::Max($sz, 16) + 12; if ($sz -eq 128) { $x += 0 } }
}
$g.Dispose(); $sheet.Save($PreviewPng, [System.Drawing.Imaging.ImageFormat]::Png); $sheet.Dispose()
"wrote $OutIco ($((Get-Item $OutIco).Length) bytes) and $PreviewPng"
