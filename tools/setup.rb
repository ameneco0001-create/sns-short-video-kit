# encoding: utf-8
# 必要な道具がそろっているか確かめて、足りないものを入れる（Mac・Windows 共通）
#
# 使い方（キットのフォルダで）:
#   ruby tools/setup.rb                     … 確かめて、足りないものは「ダウンロードしますか？」と聞いてから入れる（Mac）
#   ruby tools/setup.rb --check             … 確かめるだけ（何もダウンロードしない）
#   ruby tools/setup.rb --install voicevox  … VOICEVOX を公式（GitHub）からダウンロードして入れる（Mac）
#   ruby tools/setup.rb --install chrome    … Google Chrome を公式からダウンロードして入れる（Mac・任意）
#
# Windows で足りないものを入れるときは「セットアップ（Windows）.bat」をダブルクリックする
# （Ruby・VOICEVOX・ffmpeg を、Windows 標準の winget で公式から入れる）
#
# 必要なもの：
#   Mac     … Ruby（最初から入っている）、VOICEVOX、（任意）Google Chrome。動画の変換は Mac 標準の avconvert
#   Windows … Ruby、VOICEVOX、ffmpeg（動画の変換）。ブラウザは最初から入っている Edge を使う
require 'net/http'
require 'json'
require 'uri'
require 'fileutils'
require_relative 'platform'
Encoding.default_external = Encoding::UTF_8
ARCH = RbConfig::CONFIG['host_cpu'] =~ /arm|aarch64/ ? 'arm64' : 'x64'
ROOT = File.expand_path('..', __dir__)

def voicevox_running?
  Net::HTTP.get_response(URI('http://127.0.0.1:50021/version')).is_a?(Net::HTTPSuccess)
rescue StandardError
  false
end
def ask(q)
  print "#{q} [y/N] "; $stdout.flush
  ($stdin.gets || '').strip.downcase.start_with?('y')
end
def size_of(url)
  `curl -sIL -m 20 "#{url}"`.scan(/^content-length:\s*(\d+)/i).flatten.last.to_i
end
def voicevox_asset
  rel = JSON.parse(Net::HTTP.get(URI('https://api.github.com/repos/VOICEVOX/voicevox/releases/latest')))
  a = rel['assets'].find { |x| x['name'] =~ /\AVOICEVOX\.[\d.]+-#{ARCH}\.dmg\z/ } or abort 'VOICEVOX のダウンロードファイルが見つかりませんでした。https://voicevox.hiroshiba.jp/ から手動で入れてください。'
  [a['browser_download_url'], a['size'], rel['tag_name']]
end
CHROME_URL = 'https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg'

# （Mac）dmg をダウンロードして、中のアプリを「アプリケーション」フォルダにコピーする
def install_dmg(url, app_name)
  dl = File.expand_path("~/Downloads/#{File.basename(URI(url).path)}")
  puts "ダウンロード中：#{url}"
  system('curl', '-fL', '--progress-bar', '-o', dl, url) or abort 'ダウンロードに失敗しました。'
  mnt = `hdiutil attach -nobrowse -noautoopen "#{dl}"`[%r{/Volumes/.*$}].to_s.strip
  abort 'dmg を開けませんでした。' if mnt.empty?
  src = Dir.glob(File.join(mnt, '*.app')).first or abort 'dmg の中にアプリが見つかりませんでした。'
  dest = File.writable?('/Applications') ? '/Applications' : File.expand_path('~/Applications')
  FileUtils.mkdir_p(dest)
  puts "#{File.basename(src)} を #{dest} にコピー中…"
  system('ditto', src, File.join(dest, "#{app_name}.app")) or abort 'コピーに失敗しました。'
  system('hdiutil', 'detach', '-quiet', mnt)
  File.delete(dl)
  puts "入れました：#{File.join(dest, "#{app_name}.app")}"
end

def install(what)
  if Platform.windows?
    abort 'Windows では「セットアップ（Windows）.bat」をダブルクリックして入れてください（ユーザー本人が操作します）。'
  end
  case what
  when 'voicevox'
    url, size, tag = voicevox_asset
    puts "VOICEVOX #{tag}（#{File.basename(url)}、約#{(size / 1e6).round} MB、配布元：github.com/VOICEVOX/voicevox 公式）"
    install_dmg(url, 'VOICEVOX')
    puts '→ VOICEVOX を起動します。初回は利用規約が表示されるので、読んで同意してください。'
    Platform.start_voicevox
  when 'chrome'
    puts "Google Chrome（googlechrome.dmg、約#{(size_of(CHROME_URL) / 1e6).round} MB、配布元：dl.google.com 公式）"
    install_dmg(CHROME_URL, 'Google Chrome')
  else abort "入れられるのは voicevox か chrome です：#{what}"
  end
end

if (i = ARGV.index('--install'))
  install(ARGV[i + 1].to_s)
  exit
end
check_only = ARGV.include?('--check') || Platform.windows?

ok = true
puts '== 必要な道具の確認 =='
if Platform.mac?
  puts "OK  macOS #{`sw_vers -productVersion`.strip}"
  if File.exist?('/usr/bin/avconvert') then puts 'OK  avconvert（動画の変換）'
  else puts 'NG  avconvert がありません（macOS 13 以降が必要です）'; ok = false end
elsif Platform.windows?
  puts 'OK  Windows'
  if (ff = Platform.which('ffmpeg')) then puts "OK  ffmpeg（動画の変換）#{ff}"
  else puts 'NG  ffmpeg がありません（動画の変換に必要）→「セットアップ（Windows）.bat」で入ります'; ok = false end
else
  puts 'NG  このキットは、利用者の Mac か Windows の上で直接動かす必要があります。'
  puts "    ここは利用者のパソコンではなく、AI 用に別の場所で動いている作業環境です（Claude アプリの「チャット」や「Cowork」、claude.ai、Web 版の Codex など）。"
  puts '    ここからは、パソコンにアプリを入れたり、VOICEVOX を使ったり、動画を書き出したりできません。'
  puts '    → Claude アプリの「Code」タブ（Claude Code）か、Codex アプリ（ローカルで動かすもの）で、キットのフォルダを開いてください。'
  exit 2
end
# iCloud（Mac）や OneDrive（Windows）で同期しているフォルダに置くと、ファイルがクラウドに移されて読めなくなったり、遅くなったりする
home = File.expand_path('~')
synced = if Platform.mac?
  ROOT.include?('/Library/Mobile Documents/') || ROOT.start_with?("#{home}/Desktop/", "#{home}/Documents/")
else
  ROOT =~ /OneDrive/i
end
if synced
  puts "--  キットが同期されるフォルダにあります（#{ROOT}）"
  puts '    デスクトップや書類（iCloud・OneDrive で同期）に置くと、ファイルがクラウドに移されて読めなくなったり、できた動画を送れなくなったりします。'
  dest = File.join(home, File.basename(ROOT))
  if Platform.mac? && !check_only && !File.exist?(dest) && ask("ホームフォルダ（#{dest}）にコピーしますか？")
    puts 'コピー中…（クラウドにあるファイルは、ここでダウンロードされます）'
    FileUtils.cp_r(ROOT, dest)
    puts "コピーしました：#{dest}"
    puts '→ これからは、こちらのフォルダを使ってください。AI のアプリでも、このフォルダを開き直してください。'
    puts '  （前の場所のフォルダは、確認できたらゴミ箱に入れてかまいません）'
    Platform.open(dest)
    exec(RbConfig.ruby, File.join(dest, 'tools', 'setup.rb'), *ARGV)
  else
    puts "    → フォルダごとホームフォルダ（#{home}）に移すのがおすすめです。移したら、AI のアプリでそのフォルダを開き直してください。"
  end
end
puts "OK  Ruby #{RUBY_VERSION}"
begin
  require 'webrick'
  puts 'OK  webrick（書き出し画面のサーバー）'
rescue LoadError
  puts 'NG  webrick がありません → gem install webrick を実行してください'; ok = false
end

if (vv = Platform.voicevox)
  puts "OK  VOICEVOX（#{vv}）#{voicevox_running? ? '起動中' : '※ 声を作る前に起動してください'}"
elsif Platform.windows?
  puts 'NG  VOICEVOX がありません（必須）→「セットアップ（Windows）.bat」で入ります'; ok = false
else
  url, size, = voicevox_asset
  puts "NG  VOICEVOX がありません（必須）：#{File.basename(url)} 約#{(size / 1e6).round} MB、github.com/VOICEVOX/voicevox 公式"
  if !check_only && ask('VOICEVOX をダウンロードして入れますか？') then install('voicevox') else ok = false end
end

if (b = Platform.chromium)
  puts "OK  自動書き出し用のブラウザ（#{b}）→ 書き出しは全自動"
elsif Platform.mac?
  puts "--  Google Chrome がありません（任意）：なくても Safari でボタンを押せば書き出せます。入れると全自動になります（約#{(size_of(CHROME_URL) / 1e6).round} MB、dl.google.com 公式）"
  install('chrome') if !check_only && ask('Google Chrome をダウンロードして入れますか？')
else
  puts '--  Edge / Chrome が見つかりません：ブラウザで画面を開いてボタンを押せば書き出せます'
end

themes = Dir.glob(File.join(ROOT, 'bg', 'themes', '*')).select { |d| File.directory?(d) }
n = themes.sum { |d| Dir.children(d).count { |f| f.end_with?('.mp4') } }
puts n > 0 ? "OK  背景の動画 #{n} 本（#{themes.map { |d| File.basename(d) }.join('、')}）" : '--  背景の動画がまだありません（動画を作るときに、話に合うものを tools/bg_add.rb で追加します）'
puts ok ? "\nそろっています。" : "\n足りないものがあります。上の NG を確認してください。"
exit(ok ? 0 : 1)
