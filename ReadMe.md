# ReadMe
Perple_Xのインストール用スクリプトです。簡易的なバージョンマネージャーの機能も持たせています。必要に応じてHomebrew経由でgfortranを導入します。  
手持ちの端末（MacBook Air 2020 M1, Mac Mini 2024 M4）で動作することを確認しています。
## リリース形式と要求環境について
v7.1.15以降、macOS向けのバイナリがリリースに含まれるようになりました。公式のビルドを落としてきて展開するようにしています。
v7.1.15からv7.1.17までのバージョンは`gcc@12`内のライブラリに依存しているようですので、プログラム起動時にコケるかもしれません。brew経由で導入してください。なお、v7.1.18以降のリリースにはdylibが同梱されるようです。
公式ビルドは、起動要件として macOS 15.0 以降であることを指定しているようです。それ以前のバージョンのOSを利用している場合は手動でビルドする必要がありそうです。 
## 使用方法
```sh
curl -sSL https://raw.githubusercontent.com/Quax-Quax/px-mac-auto-setup/refs/heads/master/px-install-mac.sh | bash -s version
```
versionには、`vX.XX.XX`（vから始まるバージョン番号）ないし`head`を指定してください。
  
ビルドに使用するMakeFile（OSX_makefile2）は、2025年にマージされました。そのため、このスクリプトでv7.1.12以前のものをビルドすることはできません。古いバージョンが必要な場合は、OSX_makefile2を移植し、スクリプトを参考に手動でビルドしてください。  
参考：https://github.com/jadconnolly/Perple_X/  
  
## 署名検証ではねられる場合
同梱のdylibに手が加えられており、起動をcodesignに拒否されることがあります。少々乱暴ですが、ad-hoc署名を強制的に上書きすることで対処できます。コマンドの内容とリスクを理解しないまま実行してはいけません。

cdでlibへ移動し、次のコマンドを実行してください。なお、このコマンドはbin以下の再署名にも活用できます。
```sh
for f in *; do [ -f "$f" ] && file "$f" | grep -q Mach-O && /usr/bin/codesign --force --sign - --timestamp=none "$f"; done
```

署名の検証は以下のコマンドで行えます。
```sh
codesign --verify --verbose=4 target
```

---

このリポジトリ内のコードは Github Copilot を補助的に用いて作成しました。

Author: Quax-Quax  
