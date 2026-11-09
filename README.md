# SNSバズ系ショート動画作成キット

SNSで話題になった文章投稿を合成音声で読み上げて、最後にツッコミを入れる縦型ショート動画（60秒以内）を、AI に話しかけるだけで作れるキットです。Mac・Windows のどちらでも使えます。

## 使い方（2ステップ）

1. パソコンに入れた **Claude アプリの「Code」** を開く（または、パソコンに入れた Codex アプリを開く）
2. このページの URL を貼って、こう話しかける

```
このURLのキットを入れて、動画作って https://github.com/（このページのURL）
```

あとは AI が、キットのダウンロード・準備（読み上げソフト VOICEVOX など）・ネタ探し・動画の書き出しまで進めます。
途中で「ダウンロードしてよいですか？」などと聞かれたら、内容を見て答えてください。

> Claude アプリの「チャット」や「Cowork」、ブラウザの claude.ai、Web 版の Codex では使えません（AI がパソコンの外で動いていて、パソコンにソフトを入れられないため）。

2回目からは、Claude アプリの「Code」（または Codex）でホームフォルダの「SNSバズ系ショート動画作成キット」フォルダを開いて、「動画作って」と話しかけるだけです。
詳しい使い方は、入ったフォルダの中の「マニュアル.html」を開いてください。

## 公開する前に
- 元の投稿者に、文章を使ってよいか許可を取ってください（お願いの例文：資料/許可依頼文.md）
- 概要欄に VOICEVOX のクレジットを書いてください（動画ごとに自動で書き出されます）

---

## AI（Claude Code / Codex）へ：このキットを入れる手順

ユーザーにこのページの URL を渡されて「キットを入れて」「動画作って」と頼まれたら、次の順に進めてください。ユーザーはプログラミングに詳しくない前提で、専門用語を使わず日本語でやりとりしてください。

1. **パソコンの上で動いているか確かめる。** コマンドを実行できない、または `uname -s` が `Linux` なら、パソコンの外で動いています。作業を進めず、「Claude アプリの『Code』（またはパソコンに入れた Codex アプリ）で、もう一度このURLを貼ってください」と伝えて終わる。
2. **ダウンロードして、ホームフォルダに入れる。** 入れる先は `~/SNSバズ系ショート動画作成キット`（Windows は `%USERPROFILE%\SNSバズ系ショート動画作成キット`）。すでにあれば、上書きせずにユーザーに聞く（中に作った動画や台本が入っているため）。
   ダウンロードするのはこのページの zip（`https://github.com/<持ち主>/<名前>/archive/refs/heads/main.zip`、1MB 未満）。
   - Mac：
     ```bash
     curl -fL -o /tmp/sns-kit.zip "https://github.com/<持ち主>/<名前>/archive/refs/heads/main.zip"
     rm -rf /tmp/sns-kit && mkdir /tmp/sns-kit && ditto -x -k /tmp/sns-kit.zip /tmp/sns-kit
     mv /tmp/sns-kit/*/ ~/SNSバズ系ショート動画作成キット
     chmod +x ~/SNSバズ系ショート動画作成キット/*.command ~/SNSバズ系ショート動画作成キット/tools/*.rb
     ```
   - Windows（PowerShell）：
     ```powershell
     $z = "$env:TEMP\sns-kit.zip"; $t = "$env:TEMP\sns-kit"
     Invoke-WebRequest -Uri "https://github.com/<持ち主>/<名前>/archive/refs/heads/main.zip" -OutFile $z
     Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue; Expand-Archive $z $t
     Move-Item (Get-ChildItem $t | Select-Object -First 1).FullName "$env:USERPROFILE\SNSバズ系ショート動画作成キット"
     ```
3. **入れたフォルダの `AGENTS.md` を読んで、その手順どおりに進める**（セットアップの確認 → ユーザーが「動画作って」と言っていれば、ネタ探しから書き出しまで）。コマンドは、そのフォルダの中で実行する。
   - Windows で Ruby がまだ入っていなければ、ユーザーに `セットアップ（Windows）.bat` をダブルクリックしてもらう（フォルダを開いてあげる：`explorer "%USERPROFILE%\SNSバズ系ショート動画作成キット"`）。終わったら、Claude アプリ（Code）か Codex を開き直して、そのフォルダで続ける。
4. 最後に、「次からは、Claude アプリの『Code』（または Codex）でホームフォルダの『SNSバズ系ショート動画作成キット』フォルダを開いて、『動画作って』と話しかければ作れます」と伝える。
