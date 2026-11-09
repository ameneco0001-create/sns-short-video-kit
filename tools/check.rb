# encoding: utf-8
# できた動画（完パケ/*.mp4）が正しく書き出せているか確かめる
# 使い方：ruby tools/check.rb 完パケ/<名前>.mp4
#   長さ・1秒あたりのコマ数・普通のmp4か（どのアプリでも再生できるか）・60秒以内か を表示する
Encoding.default_external = Encoding::UTF_8

def boxes(data, from, to)
  out = []; i = from
  while i + 8 <= to
    size = data[i, 4].unpack1('N'); type = data[i + 4, 4]; hdr = 8
    size = data[i + 8, 8].unpack1('Q>') and hdr = 16 if size == 1
    size = to - i if size == 0
    break if size < hdr
    out << [type, i + hdr, i + size]; i += size
  end
  out
end
def find(data, s, e, *path)
  return [s, e] if path.empty?
  boxes(data, s, e).select { |t, _, _| t == path.first }.map { |_, a, b| find(data, a, b, *path[1..]) }.compact.first
end

def mp4_info(path)
  data = File.binread(path)
  top = boxes(data, 0, data.size)
  moov = top.find { |t, _, _| t == 'moov' } or return { error: 'moov がありません（壊れたファイル）' }
  mvhd = find(data, moov[1], moov[2], 'mvhd')
  v = data[mvhd[0]].ord
  scale, dur = v == 1 ? [data[mvhd[0] + 20, 4].unpack1('N'), data[mvhd[0] + 24, 8].unpack1('Q>')] : data[mvhd[0] + 12, 8].unpack('NN')
  frames = nil
  boxes(data, moov[1], moov[2]).select { |t, _, _| t == 'trak' }.each do |_, a, b|
    hdlr = find(data, a, b, 'mdia', 'hdlr') or next
    next unless data[hdlr[0] + 8, 4] == 'vide'
    stsz = find(data, a, b, 'mdia', 'minf', 'stbl', 'stsz') or next
    frames = data[stsz[0] + 8, 4].unpack1('N')
  end
  { duration: dur.to_f / scale, frames: frames, fragmented: top.any? { |t, _, _| t == 'moof' } }
end

if __FILE__ == $0
  path = ARGV[0] or abort '使い方：ruby tools/check.rb 完パケ/<名前>.mp4'
  i = mp4_info(path)
  abort "NG：#{i[:error]}" if i[:error]
  fps = i[:frames] ? i[:frames] / i[:duration] : 0
  puts "長さ #{i[:duration].round(2)} 秒 / 映像 #{i[:frames]} コマ（1秒あたり約 #{fps.round(1)} コマ）"
  ng = []
  ng << '1秒あたりのコマ数が少なすぎます（書き出し中に画面が隠れていた可能性）' if fps < 20
  ng << '普通のmp4になっていません（アプリによっては再生できません）' if i[:fragmented]
  ng << '60秒を超えています' if i[:duration] > 60
  if ng.empty? then puts 'OK：問題ありません'
  else ng.each { |m| puts "NG：#{m}" }; exit 1
  end
end
