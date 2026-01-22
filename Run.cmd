<# :
@echo off
REM ================================================================
REM 【重要】このブロックは「おまじない」です。書き換えないでください。
REM  これはバッチファイル(.cmd)ですが、内部でPowerShellを呼び出して
REM  自分自身を読み込ませることで、PowerShellスクリプトとして動作させます。
REM ================================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression -Command ((Get-Content -Path '%~f0' -Encoding Default) -join \"`n\")"
exit /b
#>

# ==================================================================
#  ここから下は PowerShell として動きます
#  (バッチファイルの書き方ではなく、PowerShellの書き方で記述できます)
# ==================================================================

# エラーが起きたら、その場で処理をストップする設定
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------------
#  STEP 0 : Windows Sandbox が有効か確認する
# ------------------------------------------------------------------
$SandboxExe = "$env:SystemRoot\System32\WindowsSandbox.exe"

if (-not (Test-Path $SandboxExe)) {
    Write-Host "`n[エラー] Windows Sandbox が有効化されていません。" -ForegroundColor Red
    Write-Host ""
    Write-Host "有効化するには、enable-sandbox.cmd を右クリックして"
    Write-Host "「管理者として実行」してください。（要再起動）"
    Write-Host ""
    Write-Host "[Enterキーを押して終了]"
    Read-Host
    exit
}
# ------------------------------------------------------------------
#  STEP 1 : 自分の居場所（フォルダパス）を確認する
# ------------------------------------------------------------------
$CurrentDir = $PWD.Path

# パスの最後が「\」で終わっていたら取り除く（トラブル防止）
if ($CurrentDir.EndsWith("\")) {
    $CurrentDir = $CurrentDir.TrimEnd("\")
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Windows Sandbox 起動ランチャー"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "現在地: $CurrentDir"

# ------------------------------------------------------------------
#  STEP 2 : 必要なファイルがあるかチェックする
# ------------------------------------------------------------------
# 実行したいPowerShellスクリプトの名前
$InstallScript = "install_winget.ps1"

# ファイルが存在しない場合
if (-not (Test-Path "$CurrentDir\$InstallScript")) {
    Write-Host "`n[エラー] $InstallScript が見つかりません。" -ForegroundColor Red
    Write-Host "このランチャーと同じフォルダに置いてください。"
    Write-Host "`n[Enterキーを押して終了]"
    Read-Host # 入力待ちで止める
    exit
}

# ------------------------------------------------------------------
#  STEP 3 : Sandbox用の設定ファイル(.wsb)を作る
# ------------------------------------------------------------------
# 生成するファイルの名前
$WsbFile = "$CurrentDir\launch.wsb"

Write-Host "設定ファイル(.wsb)を生成中..."

# @" ～ "@ の間は、文字をそのまま書き込める（ヒアドキュメント機能）
# XMLという形式で、Sandboxの設定を書きます
$WsbContent = @"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$CurrentDir</HostFolder>
      <SandboxFolder>C:\Scripts</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>

  <LogonCommand>
    <Command>cmd.exe /c start powershell.exe -NoExit -ExecutionPolicy Bypass -File C:\Scripts\$InstallScript</Command>
  </LogonCommand>
</Configuration>
"@

# 設定内容をファイルに書き出す (文字コードは UTF-8)
$WsbContent | Set-Content -Path $WsbFile -Encoding UTF8

Write-Host "生成完了: $WsbFile"

# ------------------------------------------------------------------
#  STEP 4 : Windows Sandbox を起動する
# ------------------------------------------------------------------
Write-Host "Windows Sandbox を起動します..."

# 作成した .wsb ファイルを実行（＝Sandboxが立ち上がる）
Start-Process -FilePath "$WsbFile"

Write-Host "`n処理完了。このウィンドウは自動的に閉じます..."
# 2秒待ってから閉じる
Start-Sleep -Seconds 2
