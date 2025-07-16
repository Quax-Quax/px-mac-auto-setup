#!/bin/bash

# Homebrew自動インストールスクリプト（curl実行最適化版）
# 使用方法: curl -sSL https://raw.githubusercontent.com/Quax-Quax/px-mac-auto-setup/refs/heads/master/px-install-mac.sh | bash
# Claude Sonnet 4 を用いて作成しました
# Author: Quax-Quax

set -e  # エラーが発生したら停止

# 実行環境の検証
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ このスクリプトはmacOSでのみ動作します"
    exit 1
fi

# 管理者権限での実行を防止
if [[ $EUID -eq 0 ]]; then
    echo "❌ このスクリプトはroot権限で実行しないでください"
    exit 1
fi

# 進捗表示用の関数
print_status() {
    echo "🔄 $1"
}

print_success() {
    echo "✅ $1"
}

print_warning() {
    echo "⚠️  $1"
}

print_error() {
    echo "❌ $1"
}

# メイン処理開始
echo "=================================================="
echo "🍺 Homebrew自動インストールスクリプト"
echo "=================================================="

# Homebrewが既にインストールされているかチェック
if command -v brew >/dev/null 2>&1; then
    print_success "Homebrewは既にインストールされています"
    echo "   バージョン: $(brew --version | head -n 1)"
else
    print_status "Homebrewをインストールしています..."
    
    # Homebrewのインストール（非対話モード）
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    print_success "Homebrewのインストールが完了しました"
fi

# アーキテクチャの確認
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    # Apple Silicon Mac
    BREW_PATH="/opt/homebrew/bin/brew"
    BREW_PREFIX="/opt/homebrew"
else
    # Intel Mac
    BREW_PATH="/usr/local/bin/brew"
    BREW_PREFIX="/usr/local"
fi

echo "   アーキテクチャ: $ARCH"
echo "   Homebrewパス: $BREW_PATH"

# Homebrewが正しくインストールされているかチェック
if [[ ! -x "$BREW_PATH" ]]; then
    print_error "Homebrewのインストールに失敗しました"
    exit 1
fi

# 現在のセッションにHomebrewのパスを追加
if [[ ":$PATH:" != *":$BREW_PREFIX/bin:"* ]]; then
    export PATH="$BREW_PREFIX/bin:$PATH"
    print_success "現在のセッションにHomebrewのパスを追加しました"
fi

# シェル設定ファイルの更新関数
update_shell_config() {
    local config_file="$1"
    local brew_path="$2"
    
    # 設定ファイルが存在しない場合は作成
    if [[ ! -f "$config_file" ]]; then
        touch "$config_file"
    fi
    
    # 既にHomebrewの設定が存在するかチェック（重複防止）
    if ! grep -q "eval.*$brew_path.*shellenv" "$config_file" 2>/dev/null; then
        echo "" >> "$config_file"
        echo "# Homebrew (added by homebrew installer)" >> "$config_file"
        echo "eval \"\$($brew_path shellenv)\"" >> "$config_file"
        print_success "$(basename "$config_file") にHomebrew設定を追加しました"
        return 0
    else
        echo "   $(basename "$config_file") には既にHomebrew設定が存在します"
        return 1
    fi
}

# zshの設定ファイルを更新
print_status "zshの設定ファイルを更新しています..."
ZSHRC_UPDATED=false
if update_shell_config "$HOME/.zshrc" "$BREW_PATH"; then
    ZSHRC_UPDATED=true
fi

# Homebrewの環境変数を現在のセッションに適用
eval "$($BREW_PATH shellenv)"

# 設定ファイルを更新した場合のみ、新しいzshセッションで環境変数を再読み込み
# 無限ループを防ぐため、環境変数でフラグを設定
if [[ "$ZSHRC_UPDATED" == "true" && -z "$HOMEBREW_INSTALLER_EXECUTED" ]]; then
    print_status "zsh設定を反映しています..."
    export HOMEBREW_INSTALLER_EXECUTED=1
    # 新しいzshセッションで環境変数のみ再読み込み
    zsh -c "source ~/.zshrc; env | grep -E '^(PATH|HOMEBREW)'"
    print_success "zsh設定を現在のセッションに反映しました"
fi

# Homebrewの動作確認
print_status "Homebrewの動作確認をしています..."
if ! brew --version >/dev/null 2>&1; then
    print_error "Homebrewが正しく動作していません"
    exit 1
fi

# Homebrewのアップデート
print_status "Homebrewを更新しています..."
brew update --quiet

# gfortranのインストールチェック
print_status "gfortranの状態を確認しています..."
if brew list gfortran >/dev/null 2>&1; then
    print_success "gfortranは既にインストールされています"
    echo "   バージョン: $(gfortran --version 2>/dev/null | head -n 1 || echo 'バージョン取得失敗')"
else
    print_status "gfortranをインストールしています..."
    brew install gfortran
    print_success "gfortranのインストールが完了しました"
fi

# gfortranの動作確認
print_status "gfortranの動作確認をしています..."
if ! command -v gfortran >/dev/null 2>&1; then
    print_error "gfortranが正しくインストールされていません"
    exit 1
fi

# PerpleXのバージョン取得とセットアップ
print_status "PerpleXのバージョン情報を設定しています..."

# スクリプト独自のバージョン管理
SCRIPT_VERSION="7"
BASE_VERSION="7.1.13"
PERPLEX_VERSION="${BASE_VERSION}-script${SCRIPT_VERSION}"
PERPLEX_DIR="$HOME/PerpleX_$PERPLEX_VERSION"

print_success "PerpleXバージョン: $PERPLEX_VERSION"
echo "   ベースバージョン: $BASE_VERSION"
echo "   スクリプトバージョン: $SCRIPT_VERSION"
echo "   インストール先: $PERPLEX_DIR"
echo "   ソース: mainブランチ（OSX_makefile2を含む最新版）"

# PerpleXディレクトリの作成と移動
print_status "PerpleXディレクトリを作成しています..."
mkdir -p "$PERPLEX_DIR/bin_backup"
cd "$PERPLEX_DIR"

# GitHubからPerpleXをクローン（mainブランチ）
print_status "PerpleXソースコード（mainブランチ）をダウンロードしています..."
if [[ -d ".git" ]]; then
    print_warning "既存のPerpleXリポジトリが見つかりました。更新しています..."
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
    git pull origin main || git pull origin master || {
        print_warning "git pullに失敗しました。リポジトリを再クローンします..."
        cd "$HOME"
        rm -rf "$PERPLEX_DIR"
        mkdir -p "$PERPLEX_DIR/bin_backup"
        cd "$PERPLEX_DIR"
        git clone https://github.com/jadconnolly/Perple_X.git .
    }
else
    git clone https://github.com/jadconnolly/Perple_X.git .
fi

# mainブランチであることを確認
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
print_success "PerpleXソースコードのダウンロードが完了しました"
echo "   使用ブランチ: $CURRENT_BRANCH"

# 最新のコミット情報を表示
LATEST_COMMIT=$(git log --oneline -1 2>/dev/null || echo "コミット情報取得失敗")
echo "   最新コミット: $LATEST_COMMIT"

# srcディレクトリに移動してビルド
print_status "PerpleXをビルドしています..."
cd "$PERPLEX_DIR/src"

# makeファイルの存在確認
if [[ ! -f "OSX_makefile2" ]]; then
    print_error "OSX_makefile2が見つかりません"
    exit 1
fi

# ビルドの実行
print_status "Fortranコンパイルを実行しています（時間がかかる場合があります）..."
if ! make -f OSX_makefile2; then
    print_error "PerpleXのビルドに失敗しました"
    exit 1
fi

print_success "PerpleXのビルドが完了しました"

# 実行ファイルのコピー
print_status "実行ファイルをバックアップディレクトリにコピーしています..."
EXECUTABLES="actcor convex fluids MC_fit pspts pstable pt2curv werami build ctransf frendly meemum pssect psvdraw vertex"

# 実行ファイルの存在確認とコピー
COPIED_FILES=()
MISSING_FILES=()

for exe in $EXECUTABLES; do
    if [[ -f "$exe" ]]; then
        cp "$exe" "$PERPLEX_DIR/bin_backup/"
        COPIED_FILES+=("$exe")
    else
        MISSING_FILES+=("$exe")
    fi
done

# binディレクトリにもコピー
print_status "実行ファイルをbinディレクトリにコピーしています..."
cp -r "$PERPLEX_DIR/bin_backup" "$PERPLEX_DIR/bin"

print_success "実行ファイルのコピーが完了しました"

# 結果の表示
echo "   コピー済み実行ファイル (${#COPIED_FILES[@]}個):"
for file in "${COPIED_FILES[@]}"; do
    echo "     ✅ $file"
done

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    print_warning "見つからなかった実行ファイル (${#MISSING_FILES[@]}個):"
    for file in "${MISSING_FILES[@]}"; do
        echo "     ❌ $file"
    done
fi

print_success "PerpleXのセットアップが完了しました"
echo "   インストール場所: $PERPLEX_DIR"
echo "   実行ファイル: $PERPLEX_DIR/bin/"

# 最終確認
echo ""
echo "=================================================="
echo "🎉 インストール完了！"
echo "=================================================="

# インストール結果の表示
echo "📋 インストール結果:"
echo "   Homebrew: $(brew --version | head -n 1)"
if command -v gfortran >/dev/null 2>&1; then
    echo "   gfortran: $(gfortran --version 2>/dev/null | head -n 1 || echo 'インストール済み')"
else
    echo "   gfortran: インストール済み（パス設定確認が必要）"
fi
echo "   PerpleX: $PERPLEX_DIR"

echo ""
echo "🔧 次の手順:"
echo "1. 新しいターミナルセッションを開く、または"
echo "2. 現在のセッションで: source ~/.zshrc"
echo ""
echo "📝 確認コマンド:"
echo "   brew --version"
echo "   gfortran --version"
echo "   ls ~/PerpleX_7.1.13/bin/"
echo ""
echo "🧪 PerpleXの使用方法:"
echo "   cd ~/PerpleX_7.1.13"
echo "   ./bin/werami"
echo ""
echo "✨ 今後のターミナルセッションでは自動的にHomebrewが利用可能です"

# 実行環境のクリーンアップ
unset HOMEBREW_INSTALLER_EXECUTED
