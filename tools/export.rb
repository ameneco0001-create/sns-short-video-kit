# encoding: utf-8
# 動画を書き出す（作品/<名前>/script.json と、tools/voices.rb で作った声を使う）
#
# 使い方（キットのフォルダで）:
#   ruby tools/export.rb <作品名>             … Chrome か Edge があれば、自動で録画して 完パケ に保存する
#                                              （Windows は Edge が最初から入っているので、いつも自動）
#                                              どちらもない Mac では Safari で画面を開くので、「● 動画を書き出す」を押す
#   ruby tools/export.rb <作品名> --no-open   … 画面は開かずに、書き出しが終わるのを待つだけ
#                                              （Claude のアプリ内ブラウザなど、自分で画面を開いてボタンを押すとき）
#
# 録画は実時間で行います（30秒の動画なら約30秒）。録画中は画面を隠さないでください。
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require_relative 'check'
require_relative 'platform'
Encoding.default_external = Encoding::UTF_8
ROOT = File.expand_path('..', __dir__).dup.force_encoding('UTF-8')

job = ARGV.reject { |a| a.start_with?('--') }.first or abort '使い方：ruby tools/export.rb <作品名>'
job = Platform.arg(job)
dir = File.join(ROOT, '作品', job)
script = JSON.parse(File.read(File.join(dir, 'script.json'), encoding: 'UTF-8'))
out_name = (script['out'] || "文章ネタ_#{job}.mp4").sub(/\.(mp4|webm)\z/, '') + '.mp4'

# ---- サーバーが動いていなければ起動する ----
def alive?
  Net::HTTP.get_response(URI('http://127.0.0.1:8765/ping')).body == 'ok'
rescue StandardError
  false
end
unless alive?
  log = File.join(ROOT, '.work', 'server.log'); FileUtils.mkdir_p(File.dirname(log))
  opts = { chdir: ROOT, out: log, err: log }
  Platform.windows? ? opts[:new_pgroup] = true : opts[:pgroup] = true
  Process.detach(spawn(RbConfig.ruby, File.join(ROOT, 'tools', 'server.rb'), **opts))
  60.times { break if alive?; sleep 0.25 }
  abort "サーバーを起動できませんでした（#{log} を確認してください。ポート8765を他のアプリが使っている可能性があります）" unless alive?
end

result = File.join(dir, '書き出し結果.txt')
File.delete(result) if File.exist?(result)
url = "http://localhost:8765/render.html?job=#{URI.encode_www_form_component(job)}"
profile = File.join(ROOT, '.work', 'browser-profile')
browser = Platform.chromium
pid = nil

if ARGV.include?('--no-open')
  puts "この画面を開いて「● 動画を書き出す」を押してください：#{url}"
elsif browser
  # 書き出し専用のブラウザ（Chrome か Edge）を開く。普段使いのブラウザとは別で、
  # 音の自動再生を許可し、裏に回っても録画が止まらないようにする
  pid = spawn(browser, "--user-data-dir=#{profile}", '--no-first-run', '--no-default-browser-check',
              '--autoplay-policy=no-user-gesture-required', '--disable-background-timer-throttling',
              '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows',
              '--window-size=520,1000', "--app=#{url}&auto=1", out: (Platform.windows? ? 'NUL' : '/dev/null'), err: (Platform.windows? ? 'NUL' : '/dev/null'))
  Process.detach(pid)
  puts "書き出し専用の #{File.basename(browser, '.exe')} で録画しています（実時間で再生しながら録画します）…"
elsif Platform.mac?
  system('open', '-a', 'Safari', url)
  puts "Safari で書き出し画面を開きました。「準備OK」と出たら「● 動画を書き出す」を押してください。録画中は画面を隠さないでください：#{url}"
else
  Platform.open(url)
  puts "ブラウザで書き出し画面を開きました。「準備OK」と出たら「● 動画を書き出す」を押してください：#{url}"
end

# ---- 書き出しが終わるのを待つ（最大15分）----
msg = nil
(15 * 60 * 2).times do
  break if File.exist?(result) && !(msg = File.read(result, encoding: 'UTF-8')).empty?
  sleep 0.5
end
# 書き出し専用のブラウザを閉じる
if pid
  if Platform.windows? then system('taskkill', '/PID', pid.to_s, '/T', '/F', out: 'NUL', err: 'NUL')
  else system('pkill', '-f', "user-data-dir=#{profile}")
  end
end
abort '15分たっても書き出しが終わりませんでした。画面を確認してください。' unless msg
puts msg
exit 1 if msg.start_with?('エラー')

out = Dir.glob(File.join(ROOT, '完パケ', '*.mp4')).find { |f| File.basename(f).unicode_normalize(:nfc) == out_name.unicode_normalize(:nfc) }
abort "完パケに #{out_name} が見つかりません" unless out
i = mp4_info(out)
fps = i[:frames].to_f / i[:duration]
puts "確認：長さ #{i[:duration].round(2)} 秒 / 1秒あたり約 #{fps.round(1)} コマ / #{i[:fragmented] ? '普通のmp4ではありません' : '普通のmp4'} / #{(File.size(out) / 1e6).round(1)} MB"
warn 'NG：コマ数が少なすぎます。画面を隠さずに、もう一度書き出してください' if fps < 20
warn '※ 60秒を超えています' if i[:duration] > 60
