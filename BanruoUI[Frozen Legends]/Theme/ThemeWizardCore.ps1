param(
  [string]$TitleZhInput = '',
  [string]$TitleEnInput = '',
  [string]$AuthorInput = '',
  [string]$VersionInput = ''
)

[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$ErrorActionPreference = 'Stop'

function Clean([string]$s) {
  if ($null -eq $s) { return '' }
  return $s.Replace("`r", ' ').Replace("`n", ' ').Trim()
}

function LuaEsc([string]$s) {
  $v = Clean $s
  $v = $v.Replace('\\', '\\\\')
  $v = $v.Replace('"', '\\"')
  return $v
}

function GetMetaValue([string]$raw, [string]$key) {
  if ([string]::IsNullOrEmpty($raw)) { return '' }
  $pat = '(?m)^\s*' + [regex]::Escape($key) + '\s*=\s*"((?:\\.|[^"])*)"\s*,?\s*$'
  $m = [regex]::Match($raw, $pat)
  if (-not $m.Success) { return '' }
  $v = $m.Groups[1].Value
  $v = $v -replace '\\\\', '\'
  $v = $v -replace '\\"', '"'
  return $v
}

function NewLuaLongWrap([string]$s) {
  $n = 3
  while ($s.Contains(']' + ('=' * $n) + ']')) { $n++ }
  return @{ Open = '[' + ('=' * $n) + '['; Close = ']' + ('=' * $n) + ']' }
}

$themeDir = Split-Path -Parent $PSScriptRoot
$addonDir = Split-Path -Leaf $themeDir
$metaPath = Join-Path $themeDir 'Theme\ThemeMeta.lua'
$tocPath = Get-ChildItem -LiteralPath $themeDir -File -Filter '*.toc' | Select-Object -First 1 -ExpandProperty FullName
if (-not $tocPath) { throw 'No .toc file found.' }
$expectedTocName = $addonDir + '.toc'
$expectedTocPath = Join-Path $themeDir $expectedTocName
if ((Split-Path -Leaf $tocPath) -ne $expectedTocName) {
  if (Test-Path -LiteralPath $expectedTocPath) {
    throw ('Target TOC already exists: ' + $expectedTocName)
  }
  Rename-Item -LiteralPath $tocPath -NewName $expectedTocName
  $tocPath = $expectedTocPath
}
if (-not (Test-Path -LiteralPath $metaPath)) { throw 'Theme\\ThemeMeta.lua not found.' }

$sysLocale = [System.Globalization.CultureInfo]::InstalledUICulture.Name
$locMode = 'en'
$breFile = 'Data_Bre_en.lua'
$breVar = 'BRE_EN'

$suffix = ''
if ($addonDir -match '\[(.+)\]') { $suffix = $Matches[1] }
if ($suffix -eq '') { $suffix = $addonDir }
$themeId = ([regex]::Replace($suffix.ToLowerInvariant(), '[^a-z0-9]+', '_')).Trim('_')
if ($themeId -eq '') { $themeId = 'theme' }

$rawMeta = [System.IO.File]::ReadAllText($metaPath, [System.Text.Encoding]::UTF8)
$exTitleZh = GetMetaValue $rawMeta 'titleZhCN'
$exTitleEn = GetMetaValue $rawMeta 'titleEnUS'
$exAuthor = GetMetaValue $rawMeta 'author'
$exVersion = GetMetaValue $rawMeta 'version'

$enFallback = 'BanruoUI [' + $suffix + ']'
$zhFallback = $suffix

Write-Host ''
Write-Host '=== BanruoUI Theme Pack Wizard ==='
Write-Host ('Addon folder : ' + $addonDir)
Write-Host ('Theme id     : ' + $themeId)
Write-Host ('Locale mode  : ' + $locMode + ' (' + $sysLocale + ')')
Write-Host ''
Write-Host 'String import files:'
Write-Host '  Bre_string.txt'
Write-Host '  Elvui_string.txt'
Write-Host '  (empty file = skip)'
Write-Host ''

$curTitleZh = if ($exTitleZh -ne '') { $exTitleZh } else { $zhFallback }
$curTitleEn = if ($exTitleEn -ne '') { $exTitleEn } else { $enFallback }
$curAuthor = if ($exAuthor -ne '') { $exAuthor } else { 'BanruoUI' }
$curVersion = if ($exVersion -ne '') { $exVersion } else { '1.0.0' }

if ($locMode -eq 'zh' -and [string]::IsNullOrWhiteSpace($TitleZhInput)) {
  $TitleZhInput = Read-Host ('中文标题（留空保留当前） [当前: ' + $curTitleZh + ']')
}
if ($locMode -eq 'en' -and [string]::IsNullOrWhiteSpace($TitleEnInput)) {
  $TitleEnInput = Read-Host ('En title (blank keep current) [current: ' + $curTitleEn + ']')
}
if ([string]::IsNullOrWhiteSpace($AuthorInput)) {
  if ($locMode -eq 'zh') {
    $AuthorInput = Read-Host ('作者（留空保留当前） [当前: ' + $curAuthor + ']')
  } else {
    $AuthorInput = Read-Host ('Author (blank keep current) [current: ' + $curAuthor + ']')
  }
}
if ([string]::IsNullOrWhiteSpace($VersionInput)) {
  if ($locMode -eq 'zh') {
    $VersionInput = Read-Host ('版本号（留空保留当前） [当前: ' + $curVersion + ']')
  } else {
    $VersionInput = Read-Host ('Version (blank keep current) [current: ' + $curVersion + ']')
  }
}

$titleZh = if (-not [string]::IsNullOrWhiteSpace($TitleZhInput)) { Clean $TitleZhInput } elseif ($exTitleZh -ne '') { $exTitleZh } else { $zhFallback }
$titleEn = if (-not [string]::IsNullOrWhiteSpace($TitleEnInput)) { Clean $TitleEnInput } elseif ($exTitleEn -ne '') { $exTitleEn } else { $enFallback }
if ($locMode -eq 'zh' -and $titleEn -eq '') { $titleEn = $enFallback }
if ($locMode -eq 'en' -and $titleZh -eq '') { $titleZh = $zhFallback }
$author = if (-not [string]::IsNullOrWhiteSpace($AuthorInput)) { Clean $AuthorInput } elseif ($exAuthor -ne '') { $exAuthor } else { 'BanruoUI' }
$version = if (-not [string]::IsNullOrWhiteSpace($VersionInput)) { Clean $VersionInput } elseif ($exVersion -ne '') { $exVersion } else { '1.0.0' }

$themeName = $addonDir
$breId = 'banruoui_' + $themeId + '_bre_main'
$elvId = 'banruoui_' + $themeId + '_elv_profile'
$preview = 'Interface\\AddOns\\' + $addonDir + '\\Media\\Previews\\preview.tga'
$q = [char]34

$metaLines = @(
  'local _, ns = ...',
  'ns = ns or _G',
  '',
  '-- Theme pack metadata.',
  '-- Future packs only need to edit this file (plus data/media files).',
  'ns.ThemeMeta = {',
  ('  themeId = {0}{1}{0},' -f $q, (LuaEsc $themeId)),
  ('  themeName = {0}{1}{0},' -f $q, (LuaEsc $themeName)),
  ('  titleZhCN = {0}{1}{0},' -f $q, (LuaEsc $titleZh)),
  ('  titleEnUS = {0}{1}{0},' -f $q, (LuaEsc $titleEn)),
  '',
  ('  author = {0}{1}{0},' -f $q, (LuaEsc $author)),
  ('  version = {0}{1}{0},' -f $q, (LuaEsc $version)),
  ('  preview = {0}{1}{0},' -f $q, (LuaEsc $preview)),
  '',
  ('  breId = {0}{1}{0},' -f $q, (LuaEsc $breId)),
  ('  elvProfileId = {0}{1}{0},' -f $q, (LuaEsc $elvId)),
  '}'
)
[System.IO.File]::WriteAllText($metaPath, ($metaLines -join "`r`n"), [System.Text.UTF8Encoding]::new($false))

$tocRaw = [System.IO.File]::ReadAllText($tocPath, [System.Text.Encoding]::UTF8)
$map = [ordered]@{
  'Title' = $addonDir
  'Title-zhCN' = $titleZh
  'Title-enUS' = $titleEn
  'Notes' = $themeName
  'Author' = $author
  'Version' = $version
}
foreach ($k in $map.Keys) {
  $v = [string]$map[$k]
  $line = '## ' + $k + ': ' + $v
  $pat = '(?m)^##\s*' + [regex]::Escape($k) + '\s*:.*$'
  $tocRaw = [regex]::Replace($tocRaw, $pat, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $line }, 1)
}
if (-not $tocRaw.EndsWith("`r`n")) { $tocRaw += "`r`n" }
[System.IO.File]::WriteAllText($tocPath, $tocRaw, [System.Text.UTF8Encoding]::new($false))

$breTxtPath = Join-Path $themeDir 'Bre_string.txt'
$elvTxtPath = Join-Path $themeDir 'Elvui_string.txt'
$breDataPath = Join-Path $themeDir ('Data\' + $breFile)
$elvDataPath = Join-Path $themeDir 'Data\Data_ElvUI.lua'

$breStatus = 'kept'
$elvStatus = 'kept'

if (Test-Path -LiteralPath $breTxtPath) {
  $breText = [System.IO.File]::ReadAllText($breTxtPath, [System.Text.Encoding]::UTF8).Trim()
  if ($breText -ne '') {
    $w = NewLuaLongWrap $breText
    $breOut = @(
      'local _, ns = ...',
      'ns = ns or _G',
      ('ns.' + $breVar + '=' + $w.Open),
      $breText,
      $w.Close
    ) -join "`r`n"
    [System.IO.File]::WriteAllText($breDataPath, $breOut, [System.Text.UTF8Encoding]::new($false))
    $breStatus = 'updated'
  }
}

if (Test-Path -LiteralPath $elvTxtPath) {
  $elvText = [System.IO.File]::ReadAllText($elvTxtPath, [System.Text.Encoding]::UTF8).Trim()
  if ($elvText -ne '' -and (Test-Path -LiteralPath $elvDataPath)) {
    $rawElv = [System.IO.File]::ReadAllText($elvDataPath, [System.Text.Encoding]::UTF8)
    $pattern = '(?s)(data\s*=\s*)\[(=*)\[(.*?)\]\2\](\s*,)'
    if ([regex]::IsMatch($rawElv, $pattern)) {
      $w = NewLuaLongWrap $elvText
      $newRaw = [regex]::Replace($rawElv, $pattern, { param($m) $m.Groups[1].Value + $w.Open + $elvText + $w.Close + $m.Groups[4].Value }, 1)
      [System.IO.File]::WriteAllText($elvDataPath, $newRaw, [System.Text.UTF8Encoding]::new($false))
      $elvStatus = 'updated'
    }
  }
}

Write-Host ''
Write-Host '=== Update Summary ==='
Write-Host ('ThemeMeta : ' + $metaPath)
Write-Host ('TOC       : ' + $tocPath)
Write-Host ('BRE       : ' + $breStatus + ' (' + $breFile + ')')
Write-Host ('ElvUI     : ' + $elvStatus + ' (Data_ElvUI.lua)')



