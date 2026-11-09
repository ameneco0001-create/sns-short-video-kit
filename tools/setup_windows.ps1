# SNSバズ系ショート動画作成キット：Windows 用のセットアップ
# 足りない道具（Ruby・ffmpeg・VOICEVOX）を、公式の配布元から入れる。入れる前に、1つずつ確認する
# 「セットアップ（Windows）.bat」をダブルクリックすると、これが動く
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}
function Ask($q) {
  $a = Read-Host "$q [y/N]"
  return ($a -match '^[yY]')
}
function Find-Ruby {
  $c = Get-Command ruby -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $g = Get-ChildItem 'C:\Ruby*\bin\ruby.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
  if ($g) { $env:Path = (Split-Path $g.FullName) + ';' + $env:Path; return $g.FullName }
  return $null
}
function Find-VoiceVox {
  $list = @("$env:LOCALAPPDATA\Programs\VOICEVOX\VOICEVOX.exe", "$env:ProgramFiles\VOICEVOX\VOICEVOX.exe")
  foreach ($p in $list) { if (Test-Path $p) { return $p } }
  $g = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\HiroshibaKazuyuki.VOICEVOX*" -Recurse -Filter VOICEVOX.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($g) { return $g.FullName }
  return $null
}

Write-Host '== SNSバズ系ショート動画作成キット セットアップ（Windows） ==' -ForegroundColor Cyan
Write-Host ''
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
if (-not $hasWinget) {
  Write-Host 'winget（Windows 標準のアプリの入れ方）が見つかりません。' -ForegroundColor Yellow
  Write-Host 'Microsoft Store で「アプリ インストーラー」を入れて（更新して）から、もう一度実行してください。'
}

# ---- 1. Ruby（動画を作る道具を動かすのに使う）----
if (Find-Ruby) {
  Write-Host "OK  Ruby" -ForegroundColor Green
} elseif ($hasWinget) {
  Write-Host 'Ruby がありません（必須）：RubyInstaller 3.4（約50MB、配布元：rubyinstaller.org 公式、winget で入れます）'
  if (Ask 'Ruby を入れますか？') {
    winget install -e --id RubyInstallerTeam.Ruby.3.4
    Refresh-Path
  }
}
$ruby = Find-Ruby
if ($ruby) {
  # 書き出し画面のサーバーに使う部品（Ruby 3 からは別に入れる必要がある）
  & $ruby -e "require 'webrick'" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'webrick（書き出し画面のサーバーに使う部品、数百KB、rubygems.org 公式）を入れます…'
    $gem = Join-Path (Split-Path $ruby) 'gem.cmd'
    if (-not (Test-Path $gem)) { $gem = 'gem' }
    & $gem install webrick --no-document
  }
}

# ---- 2. ffmpeg（録画した動画を、どのアプリでも再生できる mp4 に変換する）----
if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
  Write-Host 'OK  ffmpeg' -ForegroundColor Green
} elseif ($hasWinget) {
  Write-Host 'ffmpeg がありません（必須）：FFmpeg Essentials（約100MB、配布元：gyan.dev、winget で入れます）'
  if (Ask 'ffmpeg を入れますか？') {
    winget install -e --id Gyan.FFmpeg.Essentials
    Refresh-Path
  }
}

# ---- 3. VOICEVOX（声を作る）----
if (Find-VoiceVox) {
  Write-Host 'OK  VOICEVOX' -ForegroundColor Green
} else {
  try {
    $rel = Invoke-RestMethod 'https://api.github.com/repos/VOICEVOX/voicevox/releases/latest'
    $asset = $rel.assets | Where-Object { $_.name -match '^VOICEVOX\.Web\.Setup\.[\d.]+\.exe$' } | Select-Object -First 1
  } catch { $asset = $null }
  if ($asset) {
    Write-Host "VOICEVOX がありません（必須）：$($asset.name)（配布元：github.com/VOICEVOX/voicevox 公式。インストール中に本体を追加でダウンロードします。目安 数百MB）"
    if (Ask 'VOICEVOX を入れますか？') {
      $dl = Join-Path $env:TEMP $asset.name
      Invoke-WebRequest $asset.browser_download_url -OutFile $dl
      Write-Host 'VOICEVOX のインストーラーを開きます。画面の案内に従って進めてください（利用規約はご自身で読んで同意してください）。'
      Start-Process $dl -Wait
    }
  } else {
    Write-Host 'VOICEVOX を自動で入れられませんでした。https://voicevox.hiroshiba.jp/ から入れてください。' -ForegroundColor Yellow
  }
}
$vv = Find-VoiceVox
if ($vv -and -not (Get-Process VOICEVOX -ErrorAction SilentlyContinue)) {
  Write-Host 'VOICEVOX を起動します（声を作るときは、起動したままにしておいてください）。'
  Start-Process $vv
}

# ---- 4. 最後に全部そろったか確認する ----
Write-Host ''
$ruby = Find-Ruby
if ($ruby) { & $ruby tools\setup.rb --check }
else { Write-Host 'Ruby が入っていないため、確認できませんでした。' -ForegroundColor Yellow }
