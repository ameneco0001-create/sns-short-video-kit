# encoding: utf-8
# 書き出し画面の表示と、書き出した動画の保存を行う小さなサーバー（http://localhost:8765）
# 使い方：ruby tools/server.rb （キットのフォルダで。tools/export.rb が自動で起動します）
#
# 保存の流れ：
#   1. ブラウザで録画したそのままのデータを .work/ に保存
#   2. どのアプリでも再生できる普通のmp4に変換（画質はそのまま 1080×1920。Mac は avconvert、Windows は ffmpeg）
#   3. 「完パケ」フォルダに保存し、通知と音で知らせる
begin
  require 'webrick'
rescue LoadError
  abort 'webrick がありません。次を実行してから、やり直してください：gem install webrick'
end
require_relative 'platform'
require 'fileutils'
require 'json'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

root  = File.expand_path('..', __dir__).dup.force_encoding('UTF-8')
work  = File.join(root, '.work')
final = File.join(root, '完パケ')
[work, final].each { |d| FileUtils.mkdir_p(d) }
used_file = File.join(root, 'bg', 'used.json')
read_used = -> { File.exist?(used_file) ? JSON.parse(File.read(used_file, encoding: 'UTF-8')) : { 'used' => [] } }
nfc = ->(s) { s.to_s.dup.force_encoding('UTF-8').unicode_normalize(:nfc) }
result_file = ->(job) { File.join(root, '作品', File.basename(nfc.(job)), '書き出し結果.txt') }

server = WEBrick::HTTPServer.new(Port: 8765, BindAddress: '127.0.0.1', DocumentRoot: root, AccessLog: [],
                                 Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN))
server.mount_proc('/ping') { |_req, res| res.body = 'ok' }

# 背景：その種類（bg/themes/<名前>）の素材一覧と、まだ使っていないもの（同じ動画の書き出し直しで使ったものは使ってよい）
server.mount_proc('/bg_theme') do |req, res|
  q = WEBrick::HTTPUtils.parse_query(req.query_string.to_s)
  name = File.basename(nfc.(q['name']))
  tdir = File.join(root, 'bg', 'themes', name)
  files = Dir.exist?(tdir) ? Dir.children(tdir).select { |f| f.end_with?('.mp4') }.sort.map { |f| "themes/#{name}/#{nfc.(f)}" } : []
  used = read_used.call['used'].reject { |u| nfc.(u['video']) == nfc.(q['video']) }.map { |u| nfc.(u['file']) }
  res['Content-Type'] = 'application/json; charset=utf-8'
  res.body = JSON.generate({ files: files, unused: files - used })
end

# 書き出しの結果（エラーなど）を、作品フォルダの「書き出し結果.txt」に残す（tools/export.rb が読む）
server.mount_proc('/status') do |req, res|
  q = WEBrick::HTTPUtils.parse_query(req.query_string.to_s)
  File.write(result_file.(q['job']), req.body.to_s.force_encoding('UTF-8'))
  res.body = 'ok'
end

server.mount_proc('/save') do |req, res|
  q = WEBrick::HTTPUtils.parse_query(req.query_string.to_s)
  name = File.basename(nfc.(q['name'])).sub(/\.(mp4|webm)\z/, '')
  name = 'video' if name.empty?
  raw = File.join(work, "#{name}.#{q['ext'] == 'webm' ? 'webm' : 'mp4'}")
  File.binwrite(raw, req.body.to_s)
  out = File.join(final, "#{name}.mp4")
  # Mac では、ファイル名を Finder と同じ文字の形（NFD）にする。違う形だと AirDrop で送れないことがあるため
  out = out.unicode_normalize(:nfd) if Platform.mac?
  ok = Platform.to_mp4(raw, out)
  if ok && File.exist?(out)
    # 使った背景を記録する（次の動画では使わない）
    data = read_used.call
    data['used'].reject! { |u| nfc.(u['video']) == "#{name}.mp4" }
    JSON.parse(q['clips'] || '[]').each { |f| data['used'] << { 'file' => nfc.(f), 'video' => "#{name}.mp4", 'date' => Time.now.strftime('%Y-%m-%d %H:%M') } }
    File.write(used_file, JSON.pretty_generate(data))
    msg = "完パケ/#{name}.mp4"
    File.write(result_file.(q['job']), "保存しました：#{msg}") if q['job']
    res.body = msg
    Platform.notify("#{msg} ができました")
  else
    res.status = 500
    res.body = "mp4への変換に失敗しました（録画データは .work/#{File.basename(raw)} にあります）" +
               (Platform.windows? && !Platform.which('ffmpeg') ? '。ffmpeg が入っていません。セットアップをやり直してください' : '')
    File.write(result_file.(q['job']), "エラー：#{res.body}") if q['job']
  end
end
trap('INT') { server.shutdown }
trap('TERM') { server.shutdown }
server.start
