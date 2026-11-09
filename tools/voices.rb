# encoding: utf-8
# VOICEVOX で、台本（作品/<名前>/script.json）のセリフごとの声（wav）を作る
#
# 準備：VOICEVOX アプリを起動しておく（起動している間だけ使えます）
# 使い方（キットのフォルダで）:
#   ruby tools/voices.rb <作品名>          … 声を作る（前回から変わっていないセリフは作り直さない）
#   ruby tools/voices.rb <作品名> --all    … 全部作り直す
#   ruby tools/voices.rb --list            … 使えるキャラクターとスタイルの一覧
#
# できた声は 作品/<名前>/audio/ に入り、render.html が自動で使います。
# 概要欄に書く VOICEVOX のクレジットは 作品/<名前>/クレジット.txt に書き出します。
require 'net/http'
require 'json'
require 'uri'
require 'fileutils'
require_relative 'platform'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
HOST = URI('http://127.0.0.1:50021')
ROOT = File.expand_path('..', __dir__).dup.force_encoding('UTF-8')
DEFAULT_VOICE = '青山龍星/ノーマル'
DEFAULT_TSUKKOMI = 'ずんだもん/ノーマル'

def http
  Net::HTTP.start(HOST.host, HOST.port, read_timeout: 120) { |h| yield h }
rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
  abort 'VOICEVOX に接続できません。VOICEVOX アプリを起動してから、もう一度実行してください（起動に30秒ほどかかることがあります）。' +
        (Platform.voicevox ? "（場所：#{Platform.voicevox}）" : '（VOICEVOX が入っていません。セットアップをしてください）')
end

speakers = http { |h| JSON.parse(h.get('/speakers').body) }
styles = {}
speakers.each { |sp| sp['styles'].each { |st| styles["#{sp['name']}/#{st['name']}"] = st['id'] } }
if ARGV.first == '--list'
  speakers.each { |sp| puts "#{sp['name']}：#{sp['styles'].map { |s| s['name'] }.join('、')}" }
  exit
end

job = ARGV.reject { |a| a.start_with?('--') }.first or abort '使い方：ruby tools/voices.rb <作品名>'
job = Platform.arg(job)
dir = File.join(ROOT, '作品', job)
script = JSON.parse(File.read(File.join(dir, 'script.json'), encoding: 'UTF-8'))
pace = (script['pace'] || 11).to_f
out_dir = File.join(dir, 'audio')
FileUtils.mkdir_p(out_dir)

# 読み上げ用の文字：yomi があればそれを使う。なければ表示する文字から、絵文字・改行などを除いて作る
def tts_text(l)
  return l['yomi'] if l['yomi'] && !l['yomi'].strip.empty?
  t = l['parts'] ? l['parts'].each_with_index.map { |p, i| i < l['parts'].size - 1 && p !~ /[、。！？!?…」]\z/ ? "#{p}、" : p }.join : l['text'].to_s
  t.gsub(/[‼]/, '！').gsub(/[⁉]/, '！？').gsub(/\n/, '').gsub(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]/, '').strip
end

jobs = []
voice_of = ->(who) { (script.dig('speakers', who, 'voice') || DEFAULT_VOICE) }
script['posts'].each_with_index do |p, pi|
  p['lines'].each_with_index do |l, li|
    next if l['silent']
    jobs << ["p#{pi}_l#{li}", l['voice'] || voice_of.(l['who'] || 'reader'), tts_text(l)]
  end
  (p['tsukkomi'] || []).each_with_index do |t, ti|
    jobs << ["p#{pi}_t#{ti}", t['voice'] || script['tsukkomi_voice'] || DEFAULT_TSUKKOMI, tts_text(t)]
  end
end

all = ARGV.include?('--all')
made = 0
jobs.each do |name, voice, text|
  id = styles[voice] or abort "声「#{voice}」が見つかりません（「キャラクター名/スタイル名」で書きます）。ruby tools/voices.rb --list で確認してください。"
  key = [voice, text, pace].join("\t")
  meta = File.join(out_dir, "#{name}.json")
  if !all && File.exist?(meta) && File.exist?(File.join(out_dir, "#{name}.wav")) && JSON.parse(File.read(meta))['key'] == key
    next
  end
  http do |h|
    q = h.post("/audio_query?#{URI.encode_www_form(text: text, speaker: id)}", '')
    abort "audio_query 失敗：#{q.code} #{q.body[0, 200]}" unless q.is_a?(Net::HTTPSuccess)
    query = JSON.parse(q.body)
    # 声ごとの元の速さの違いを打ち消して、全員を同じ速さ（1秒あたり pace 個の音）にそろえる
    moras = query['accent_phrases'].flat_map { |a| a['moras'] }
    len = moras.sum { |m| (m['consonant_length'] || 0) + m['vowel_length'] }
    query['speedScale'] = (pace / (moras.size / len)).clamp(0.5, 2.0).round(3) if len > 0 && moras.size > 0
    query['prePhonemeLength']  = 0.03   # 前後の無音を短めにして、テンポよくつなげる
    query['postPhonemeLength'] = 0.05
    s = h.post("/synthesis?speaker=#{id}", JSON.generate(query), 'Content-Type' => 'application/json')
    abort "synthesis 失敗：#{s.code} #{s.body[0, 200]}" unless s.is_a?(Net::HTTPSuccess)
    File.binwrite(File.join(out_dir, "#{name}.wav"), s.body)
    # 区切り（読点などの間）のあと、次の言葉を話し始める時刻（秒）。画面の表示を声に合わせるため
    sp = query['speedScale'].to_f
    t = query['prePhonemeLength'].to_f
    breaks = []
    query['accent_phrases'].each do |a|
      a['moras'].each { |m| t += ((m['consonant_length'] || 0) + m['vowel_length']) / sp }
      if a['pause_mora']
        t += a['pause_mora']['vowel_length'] / sp * (query['pauseLengthScale'] || 1)
        breaks << t.round(3)
      end
    end
    File.write(meta, JSON.generate({ breaks: breaks, key: key }))
    made += 1
    puts "OK  #{name}（#{voice}）#{text}"
  end
end
# 区切り（parts）の数と、声の間の数が合っているか確認する
script['posts'].each_with_index do |p, pi|
  p['lines'].each_with_index do |l, li|
    next unless l['parts'] && !l['silent']
    b = JSON.parse(File.read(File.join(out_dir, "p#{pi}_l#{li}.json")))['breaks']
    warn "※ p#{pi}_l#{li}：parts は#{l['parts'].size}個ですが、声の区切りは#{b.size + 1}個です。yomi に「、」を入れて区切りを合わせてください" if b.size != l['parts'].size - 1
  end
end
names = jobs.map { |_, v, _| v.split('/').first }.uniq
File.write(File.join(dir, 'クレジット.txt'), names.map { |n| "VOICEVOX:#{n}" }.join('、') + "\n")
puts "完了（作り直し #{made} 本 / 全 #{jobs.size} 本）。クレジット：#{names.map { |n| "VOICEVOX:#{n}" }.join('、')}"
