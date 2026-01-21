# ==================================================================
#  Windows Sandbox Winget インストーラー
#
#  役割:
#    Sandbox環境内で実行され、Winget(アプリ管理ツール)を導入します。
#    このファイルは Run.cmd によって自動的に呼び出されます。
# ==================================================================

# エラーが起きたら、その場で処理をストップする設定
$ErrorActionPreference = "Stop"

try {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "   Windows Sandbox Winget インストーラー" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    # ------------------------------------------------------------------
    #  STEP 1 : ダウンロード先の設定
    # ------------------------------------------------------------------
    # Microsoft公式サイトから取得するインストーラーのURL
    $wingetUrl = "https://github.com/microsoft/winget-cli/releases/download/v1.12.440/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $depUrl = "https://github.com/microsoft/winget-cli/releases/download/v1.12.440/DesktopAppInstaller_Dependencies.zip"

    # 作業用フォルダの場所（ダウンロードフォルダの中に作ります）
    $workDir = "$env:USERPROFILE\Downloads\WingetInstall"
    $depZipPath = "$workDir\dependencies.zip"
    $wingetPath = "$workDir\winget.msixbundle"

    # ------------------------------------------------------------------
    #  STEP 2 : パソコンの種類（アーキテクチャ）を確認する
    # ------------------------------------------------------------------
    # Windows Sandbox は基本的に x64 ですが、念のため確認します
    $arch = $env:PROCESSOR_ARCHITECTURE

    if ([string]::IsNullOrWhiteSpace($arch)) { $targetDir = "x64" }
    elseif ($arch -eq "AMD64") { $targetDir = "x64" }
    elseif ($arch -eq "x86")   { $targetDir = "x86" }
    elseif ($arch -eq "ARM64") { $targetDir = "arm64" }
    else { $targetDir = "x64" }

    Write-Host "対象アーキテクチャ: $targetDir" -ForegroundColor Gray

    # ------------------------------------------------------------------
    #  STEP 3 : 準備（フォルダ作成）
    # ------------------------------------------------------------------
    Write-Host "`n[1/5] 作業ディレクトリを作成中..." -ForegroundColor Green

    # 作業用フォルダがまだなければ作る
    if (!(Test-Path $workDir)) {
        New-Item -ItemType Directory -Force -Path $workDir | Out-Null
    }

    # ------------------------------------------------------------------
    #  STEP 4 : 必要なファイルをダウンロードする
    # ------------------------------------------------------------------
    Write-Host "[2/5] ファイルをダウンロード中 (BITS)..." -ForegroundColor Green

    # Start-BitsTransfer は Windows標準の高速ダウンロード機能です
    Write-Host "  - 依存関係ファイル..." -NoNewline
    Start-BitsTransfer -Source $depUrl -Destination $depZipPath
    Write-Host " 完了"

    Write-Host "  - Winget 本体..." -NoNewline
    Start-BitsTransfer -Source $wingetUrl -Destination $wingetPath
    Write-Host " 完了"

    # ------------------------------------------------------------------
    #  STEP 5 : 依存ファイルを解凍・インストールする
    # ------------------------------------------------------------------
    Write-Host "[3/5] 依存ファイルを展開中..." -ForegroundColor Green
    # ダウンロードしたZipファイルを解凍します
    Expand-Archive -Path $depZipPath -DestinationPath "$workDir\deps" -Force

    Write-Host "[4/5] 依存パッケージをインストール中..." -ForegroundColor Green

    # 解凍したフォルダの中から、このPCに合ったフォルダを探す
    $depPathFull = "$workDir\deps\$targetDir"

    # 万が一パスが見つからない場合の保険
    if (!(Test-Path $depPathFull)) { $depPathFull = "$workDir\deps" }

    # フォルダ内の .appx ファイルをすべて探してインストール
    $depFiles = Get-ChildItem -Path "$depPathFull" -Filter "*.appx" -Recurse
    foreach ($file in $depFiles) {
        Write-Host "  -> インストール中: $($file.Name)" -ForegroundColor Gray
        Add-AppxPackage -Path $file.FullName
    }

    # ------------------------------------------------------------------
    #  STEP 6 : Winget 本体をインストールする
    # ------------------------------------------------------------------
    Write-Host "[5/5] Winget をインストール中..." -ForegroundColor Green
    Add-AppxPackage -Path $wingetPath

    # ------------------------------------------------------------------
    #  STEP 7 : 完了チェック
    # ------------------------------------------------------------------
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "   セットアップ完了" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    Write-Host "バージョン確認中..." -ForegroundColor Yellow

    # winget コマンドが正しく動くかテスト
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget --version
        Write-Host "`n準備が整いました。このままコマンドを入力して作業できます。" -ForegroundColor Green
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
    } else {
        Write-Warning "インストールされましたが、パスの反映待ちです。"
    }

} catch {
    # ------------------------------------------------------------------
    #  エラー処理（何か問題が起きた場合）
    # ------------------------------------------------------------------
    Write-Host "`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "   エラーが発生しました" -ForegroundColor Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "エラー内容: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "発生場所: $($_.ScriptStackTrace)" -ForegroundColor Red

    # エラー時はウィンドウを閉じずに、ユーザーが読めるように止める
    Write-Host "`n[Enterキーを押して終了...]"
    $null = Read-Host
}
# 正常に終わった場合は、そのまま入力画面（プロンプト）になります
