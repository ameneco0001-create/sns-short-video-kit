# encoding: utf-8
# 背景の実写動画を、Pexels（商用利用OK・クレジット不要の無料素材サイト）からダウンロードして追加する
#
# 使い方（キットのフォルダで）:
#   ruby tools/bg_add.rb --info <PexelsのページURL> ...           … ダウンロードせずに、大きさだけ調べる
#   ruby tools/bg_add.rb <種類> <PexelsのページURL> ...           … bg/themes/<種類>/ にダウンロードする
#   例：ruby tools/bg_add.rb cooking https://www.pexels.com/video/chef-cooking-in-a-kitchen-1234567/
#
# ・ページURLは https://www.pexels.com/video/<説明>-<番号>/ の形。縦長（portrait）の動画がおすすめ
# ・どこから取ったかは bg/themes/<種類>/SOURCES.txt に記録する
# ・自分で用意した動画（mp4）を bg/themes/<種類>/ に入れても使えます
require 'fileutils'
require 'net/http'
require 'uri'
Encoding.default_external = Encoding::UTF_8
ROOT = File.expand_path('..', __dir__).dup.force_encoding('UTF-8')
UA = { 'User-Agent' => 'Mozilla/5.0 (short-video-kit)' }

def parse(url)
  m = url.match(%r{pexels\.com/(?:[a-z-]+/)?video/(?:([a-z0-9-]+)-)?(\d+)/?}) or abort "PexelsのページURLではありません：#{url}"
  [m[2], (m[1] || 'clip')[0, 60]]
end

# 転送先をたどって、動画ファイルの本当の場所と大きさを調べる
def resolve(id)
  uri = URI("https://www.pexels.com/download/video/#{id}/")
  8.times do
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 60) { |h| h.head(uri.request_uri, UA) }
    if res.is_a?(Net::HTTPRedirection)
      uri = URI.join(uri.to_s, res['location'])
    elsif res.is_a?(Net::HTTPSuccess)
      return [uri, res['content-length'].to_i]
    else
      return [nil, 0]
    end
  end
  [nil, 0]
end

def download(uri, path)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 120) do |h|
    h.request(Net::HTTP::Get.new(uri, UA)) do |res|
      return false unless res.is_a?(Net::HTTPSuccess)
      File.open(path, 'wb') { |f| res.read_body { |c| f.write(c) } }
    end
  end
  true
rescue StandardError
  false
end

if ARGV.first == '--info'
  ARGV[1..-1].each do |u|
    id, slug = parse(u); file, len = resolve(id)
    puts file ? "#{id}_#{slug}.mp4  約#{(len / 1e6).round(1)} MB  #{u}" : "調べられませんでした：#{u}"
  end
  exit
end

theme = ARGV.shift or abort '使い方：ruby tools/bg_add.rb <種類> <PexelsのページURL> ...'
abort '種類の名前は英数字とハイフンで書いてください（例：cooking、office）' unless theme =~ /\A[a-z0-9-]+\z/
abort 'PexelsのページURLを1つ以上書いてください' if ARGV.empty?
dir = File.join(ROOT, 'bg', 'themes', theme)
FileUtils.mkdir_p(dir)
ARGV.each do |u|
  id, slug = parse(u)
  name = "#{id}_#{slug}.mp4"
  path = File.join(dir, name)
  if File.exist?(path) then puts "もうあります：#{name}"; next end
  file, = resolve(id)
  ok = file && download(file, path)
  if !ok || !File.exist?(path) || File.size(path) < 100_000 || File.binread(path, 12)[4, 4] != 'ftyp'
    File.delete(path) if File.exist?(path)
    warn "ダウンロードできませんでした：#{u}（ブラウザで開いて手動でダウンロードし、#{dir} に入れても使えます）"
    next
  end
  File.open(File.join(dir, 'SOURCES.txt'), 'a') { |f| f.puts "#{name}\t#{u}" }
  puts "追加しました：bg/themes/#{theme}/#{name}（#{(File.size(path) / 1e6).round(1)} MB）"
end
puts "この種類の素材：#{Dir.children(dir).count { |f| f.end_with?('.mp4') }} 本"
