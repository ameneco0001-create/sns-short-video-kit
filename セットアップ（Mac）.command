#!/bin/bash
# ダブルクリックで、必要な道具がそろっているか確かめて、足りないものを入れます
cd "$(dirname "$0")" && /usr/bin/ruby tools/setup.rb
echo; read -n 1 -s -r -p "終わりました。何かキーを押すと閉じます"
