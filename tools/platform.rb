# encoding: utf-8
# Mac と Windows の違いをまとめたところ（ほかの道具はここを使う）
require 'rbconfig'

module Platform
  module_function

  def windows?
    RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/ ? true : false
  end

  def mac?
    RbConfig::CONFIG['host_os'] =~ /darwin/ ? true : false
  end

  # コマンドに渡された文字（作品名など）を、文字化けしない形（UTF-8）にそろえる
  # Windows では Shift_JIS で渡されることがあるため
  def arg(s)
    u = s.dup.force_encoding('UTF-8')
    u = s.encode('UTF-8', invalid: :replace, undef: :replace) unless u.valid_encoding?
    u.unicode_normalize(:nfc)
  end

  # コマンドがあるか（PATH から探す）
  def which(cmd)
    exts = windows? ? ENV.fetch('PATHEXT', '.EXE;.BAT;.CMD').split(';') : ['']
    ENV['PATH'].to_s.split(File::PATH_SEPARATOR).each do |dir|
      exts.each do |ext|
        p = File.join(dir, "#{cmd}#{ext}")
        return p if File.file?(p) && File.executable?(p)
      end
    end
    nil
  end

  # 自動書き出しに使うブラウザ（Chrome か Edge）。見つからなければ nil
  def chromium
    list = if windows?
             pf = [ENV['ProgramFiles'], ENV['ProgramFiles(x86)'], ENV['LOCALAPPDATA']].compact
             pf.map { |d| File.join(d, 'Google', 'Chrome', 'Application', 'chrome.exe') } +
               pf.map { |d| File.join(d, 'Microsoft', 'Edge', 'Application', 'msedge.exe') }
           else
             ['/Applications', File.expand_path('~/Applications')].flat_map do |d|
               [File.join(d, 'Google Chrome.app', 'Contents', 'MacOS', 'Google Chrome'),
                File.join(d, 'Microsoft Edge.app', 'Contents', 'MacOS', 'Microsoft Edge')]
             end
           end
    list.find { |p| File.exist?(p) }
  end

  # VOICEVOX のアプリの場所。見つからなければ nil
  def voicevox
    if windows?
      la = ENV['LOCALAPPDATA'].to_s.tr('\\', '/')
      pf = ENV['ProgramFiles'].to_s.tr('\\', '/')
      (["#{la}/Programs/VOICEVOX/VOICEVOX.exe", "#{pf}/VOICEVOX/VOICEVOX.exe"] +
        Dir.glob("#{la}/Microsoft/WinGet/Packages/HiroshibaKazuyuki.VOICEVOX*/**/VOICEVOX.exe")).find { |p| File.exist?(p) }
    else
      ['/Applications', File.expand_path('~/Applications')].map { |d| File.join(d, 'VOICEVOX.app') }.find { |p| Dir.exist?(p) }
    end
  end

  def start_voicevox
    v = voicevox or return false
    windows? ? Process.detach(spawn(v)) : system('open', '-a', v)
    true
  end

  # URL やファイルを、いつものアプリで開く
  def open(target)
    windows? ? system('cmd', '/c', 'start', '', target) : system('open', target)
  end

  # 完成を音と通知で知らせる
  def notify(msg)
    if windows?
      ps = "Add-Type -AssemblyName System.Windows.Forms; [System.Media.SystemSounds]::Asterisk.Play(); " \
           "$n=New-Object System.Windows.Forms.NotifyIcon; $n.Icon=[System.Drawing.SystemIcons]::Information; $n.Visible=$true; " \
           "$n.ShowBalloonTip(8000,'ショート動画ができました','#{msg.gsub("'", "''")}',0); Start-Sleep 9; $n.Dispose()"
      Process.detach(spawn('powershell', '-NoProfile', '-WindowStyle', 'Hidden', '-Command', ps))
    elsif mac?
      Process.detach(spawn('osascript', '-e', %(display notification "#{msg}" with title "ショート動画ができました" sound name "Glass")))
      Process.detach(spawn('say', '-v', 'Kyoko', '動画ができました。完パケに入れました'))
    end
  end

  # ブラウザで録画したデータを、どのアプリでも再生できる普通の mp4 にする（画質はそのまま）
  # Mac は標準の avconvert、Windows（や avconvert がないとき）は ffmpeg を使う
  def to_mp4(raw, out)
    null = windows? ? 'NUL' : '/dev/null'
    if File.exist?('/usr/bin/avconvert')
      return true if system('avconvert', '--preset', 'PresetPassthrough', '--source', raw, '--output', out, '--replace', out: null, err: null)
      return true if system('avconvert', '--preset', 'Preset1920x1080', '--source', raw, '--output', out, '--replace', out: null, err: null)
    end
    ff = which('ffmpeg') or return false
    # mp4 で録画できていれば作り直さずに入れ替えるだけ。webm のときは H.264 に作り直す
    return true if raw.end_with?('.mp4') &&
                   system(ff, '-y', '-loglevel', 'error', '-i', raw, '-c', 'copy', '-movflags', '+faststart', out, out: null, err: null)
    system(ff, '-y', '-loglevel', 'error', '-i', raw, '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
           '-r', '30', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', out, out: null, err: null)
  end
end
