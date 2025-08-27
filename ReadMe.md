# ReadMe
Perple_Xのインストール用スクリプトです。簡易的なバージョンマネージャーの機能も持たせています。必要に応じてHomebrew経由でgfortranを導入します。  
手持ちの端末（MacBook Air 2020, M1）で動作することを確認しています。
## 使用方法
```sh
curl -sSL https://raw.githubusercontent.com/Quax-Quax/px-mac-auto-setup/refs/heads/master/px-install-mac.sh | bash -s version
```
versionには、`vX.XX.XX`（vから始まるバージョン番号）ないし`head`を指定してください。
  
ビルドに使用するMakeFile（OSX_makefile2）は、2025年にマージされました。そのため、v7.1.12以前のものをビルドすることはできません。その場合は手動でソースをDLし、OSX_makefile2を移植し、OSX_makefileを参考に適宜修正すれば動くのではないかと思います。  
参考：https://github.com/jadconnolly/Perple_X/  
  
Claude Sonnet 4, Gemini 2.5 Pro Coding Partner を用いて作成しました。  
Author: Quax-Quax  
