# ================================================================
# PORTABLE AI USB SETUP - llama.cpp + Msty Edition
# ================================================================
# Flow:
#   Read config (USB root)
#     -> Ensure llama.cpp exists (download latest release if missing)
#     -> Ensure Msty exists (download latest release if missing)
#     -> Ensure selected model exists (download GGUF from HuggingFace if missing)
#     -> Start llama-server
#     -> Wait for local API to come up
#     -> Launch Msty
# ================================================================

$ErrorActionPreference = "Continue"
$USB_Drive = Split-Path -Parent $MyInvocation.MyCommand.Path

# -----------------------------------------------------------------
# MODEL CATALOG
# -----------------------------------------------------------------
$ModelCatalog = @(
    @{
        Num      = 1
        Name     = "Qwen3 Coder 8B"
        File     = "Qwen3-Coder-8B-Q4_K_M.gguf"
        URL      = "https://huggingface.co/bartowski/Qwen_Qwen3-8B-GGUF/resolve/main/Qwen_Qwen3-8B-Q4_K_M.gguf"
        Size     = "4.9"
        MinBytes = 500000000
        Local    = "qwen3-coder-8b"
        Label    = "STANDARD"
        Badge    = "CODING"
        Prompt   = "You are Qwen3 Coder, an expert software engineering assistant."
    },
    @{
		Num      = 2
		Name     = "Phi-4 Mini Uncensored"
		File     = "phi_4_mini_uncensored.Q4_K_M.gguf"
		URL      = "https://huggingface.co/arzaan789/phi-4-mini-uncensored/resolve/main/phi_4_mini_uncensored.Q4_K_M.gguf"
		Size     = "2.49"
		MinBytes = 2450000000
		Local    = "phi4-mini-uncensored"
		Label    = "UNCENSORED"
		Badge    = "REASONING"
		Prompt   = "You are Phi-4 Mini Uncensored, a helpful, knowledgeable AI assistant. Provide accurate, clear, 
					and well-reasoned responses. Do not fabricate facts. When uncertain, state your uncertainty. 
					Follow the user's instructions while maintaining honesty and factual integrity."
    },
    @{
        Num      = 3
        Name     = "DeepSeek Lite V2"
        File     = "DeepSeek-Lite-V2-Q4_K_M.gguf"
        URL      = "https://huggingface.co/ramagotchi/DeepSeek-Coder-V2-Lite-Instruct-GGUF/resolve/main/DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf"
        Size     = "9.8"
        MinBytes = 1000000000
        Local    = "deepseek-lite-1b"
        Label    = "STANDARD"
        Badge    = "FAST"
        Prompt   = "You are DeepSeek Lite."
    },
    @{
        Num      = 4
        Name     = "Gemma 4 12B"
        File     = "Gemma-4-12B-it-IQ2_M.gguf"
        URL      = "https://huggingface.co/bartowski/gemma-4-12B-it-GGUF/resolve/main/gemma-4-12B-it-IQ2_M.gguf?download=true"
		#URL      = "https://huggingface.co/bartowski/gemma-4-12B-it-GGUF/resolve/main/gemma-4-12B-it-Q4_K_M.gguf"#
        Size     = "4.94 "
        MinBytes = 500000000
        Local    = "gemma4-1b"
        Label    = "STANDARD"
        Badge    = "WRITING / UI"
        Prompt   = "You are Gemma."
    },
    @{
        Num      = 5
        Name     = "Phi-4 Mini 3.8B"
        File     = "Phi-4-mini-Q4_K_M.gguf"
        URL      = "https://huggingface.co/QuantFactory/DeepSeek-Coder-V2-Lite-Instruct-GGUF/resolve/main/DeepSeek-Coder-V2-Lite-Instruct.Q4_K_M.gguf"
        Size     = "2.4"
        MinBytes = 2450000000
        Local    = "phi4-mini"
        Label    = "STANDARD"
        Badge    = "GENERAL"
        Prompt   = "You are Phi-4 Mini."
    }
)

# -----------------------------------------------------------------
# NOTE: Replace every "<HF_DOWNLOAD_URL>" above with the real
# "resolve/main/....gguf" link from the model's HuggingFace page
# before running. The script will refuse to download placeholder
# URLs and will tell you which model needs fixing.
# -----------------------------------------------------------------

# -----------------------------------------------------------------
# CONFIG (read from USB root - config.json)
# -----------------------------------------------------------------
$ConfigPath = Join-Path $USB_Drive "config.json"

function Get-DefaultConfig {
    return [ordered]@{
        SelectedModel = 1
        Host          = "127.0.0.1"
        Port          = 8080
        ContextSize   = 4096
        GpuLayers     = 0
        ExtraServerArgs = ""
    }
}

function Read-Config {
    if (-Not (Test-Path $ConfigPath)) {
        Write-Host "  No config.json found - creating a default one..." -ForegroundColor Yellow
        $default = Get-DefaultConfig
        $default | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
        return [PSCustomObject]$default
    }
    try {
        $raw = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $raw
    } catch {
        Write-Host "  WARNING: config.json is invalid - falling back to defaults." -ForegroundColor Red
        return [PSCustomObject](Get-DefaultConfig)
    }
}

# -----------------------------------------------------------------
# HELPER: Verify a downloaded file is present and large enough
# -----------------------------------------------------------------
function Test-DownloadedFile {
    param([string]$Path, [long]$MinSize = 1000000)
    if (-Not (Test-Path $Path)) { return $false }
    return (Get-Item $Path).Length -gt $MinSize
}

# -----------------------------------------------------------------
# HELPER: Download a file with a couple of retries
# -----------------------------------------------------------------
function Get-FileWithRetry {
    param([string]$Url, [string]$Dest, [long]$MinBytes = 1000000, [int]$Attempts = 2)
    for ($i = 1; $i -le $Attempts; $i++) {
        if ($i -gt 1) { Write-Host "      Retry attempt $i..." -ForegroundColor Yellow }
        curl.exe -L --ssl-no-revoke --progress-bar $Url -o $Dest
        if (Test-DownloadedFile -Path $Dest -MinSize $MinBytes) { return $true }
    }
    return $false
}

# ================================================================
# START
# ================================================================
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   PORTABLE AI USB SETUP - llama.cpp + Msty               " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/6] Reading config from USB root..." -ForegroundColor Yellow
$Config = Read-Config
Write-Host "      SelectedModel : $($Config.SelectedModel)" -ForegroundColor DarkGray
Write-Host "      Host:Port     : $($Config.Host):$($Config.Port)" -ForegroundColor DarkGray
Write-Host ""

New-Item -ItemType Directory -Force -Path "$USB_Drive\llama.cpp" | Out-Null
New-Item -ItemType Directory -Force -Path "$USB_Drive\msty" | Out-Null
New-Item -ItemType Directory -Force -Path "$USB_Drive\models" | Out-Null
New-Item -ItemType Directory -Force -Path "$USB_Drive\installer_data" | Out-Null

# =================================================================
# STEP 2: Ensure llama.cpp exists
# =================================================================
Write-Host "[2/6] Checking for llama.cpp..." -ForegroundColor Yellow

$LlamaDir    = "$USB_Drive\llama.cpp"
$LlamaServer = "$LlamaDir\llama-server.exe"

if (Test-Path $LlamaServer) {
    Write-Host "      llama.cpp found! Skipping download." -ForegroundColor Green
} else {
    Write-Host "      Not found. Fetching latest release info from GitHub..." -ForegroundColor Magenta
    try {
        $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest" -Headers @{ "User-Agent" = "portable-ai-usb-setup" }
        # Prefer a plain CPU x64 Windows build so it runs on any machine without extra drivers
        $asset = $releaseInfo.assets | Where-Object { $_.name -match "bin-win-cpu-x64\.zip$" } | Select-Object -First 1
        if (-Not $asset) {
            # Fallback to any windows x64 zip if naming has changed
            $asset = $releaseInfo.assets | Where-Object { $_.name -match "win.*x64.*\.zip$" } | Select-Object -First 1
        }

        if ($asset) {
            $zipDest = "$LlamaDir\$($asset.name)"
            Write-Host "      Downloading $($asset.name) ($($releaseInfo.tag_name))..." -ForegroundColor Magenta
            if (Get-FileWithRetry -Url $asset.browser_download_url -Dest $zipDest -MinBytes 5000000) {
                Write-Host "      Extracting..." -ForegroundColor Yellow
                Expand-Archive -Path $zipDest -DestinationPath $LlamaDir -Force
                Remove-Item $zipDest -Force -ErrorAction SilentlyContinue
                # Some releases nest files in a subfolder - flatten if needed
                if (-Not (Test-Path $LlamaServer)) {
                    $found = Get-ChildItem -Path $LlamaDir -Filter "llama-server.exe" -Recurse | Select-Object -First 1
                    if ($found) { Copy-Item $found.FullName -Destination $LlamaDir -Force }
                }
                if (Test-Path $LlamaServer) {
                    Write-Host "      llama.cpp installed! ($($releaseInfo.tag_name))" -ForegroundColor Green
                } else {
                    Write-Host "      ERROR: llama-server.exe not found after extraction." -ForegroundColor Red
                }
            } else {
                Write-Host "      ERROR: Download of llama.cpp failed." -ForegroundColor Red
            }
        } else {
            Write-Host "      ERROR: Could not find a matching Windows asset in the latest release." -ForegroundColor Red
            Write-Host "      Check manually: https://github.com/ggml-org/llama.cpp/releases/latest" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "      ERROR: Could not reach GitHub to check llama.cpp releases." -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# =================================================================
# STEP 3: Ensure Msty exists
# =================================================================
Write-Host ""
Write-Host "[3/6] Checking for Msty..." -ForegroundColor Yellow

$MstyDir  = "$USB_Drive\msty"
$MstyExe  = "$MstyDir\Msty.exe"

# Msty does not publish a stable machine-readable "latest release" API like
# GitHub does, so the direct installer URL needs to be supplied here.
# Get the current one from https://msty.ai (or https://msty.ai/studio/download)
# and paste it in below.
$MstyURL = "https://next-assets.msty.studio/app/latest/win/MstyStudio_x64.exe"

if (Test-Path $MstyExe) {
    Write-Host "      Msty found! Skipping download." -ForegroundColor Green
} else {
    if ($MstyURL -eq "<MSTY_WINDOWS_INSTALLER_URL>") {
        Write-Host "      Msty download URL is not configured yet." -ForegroundColor Red
        Write-Host "      Open https://msty.ai/studio/download, copy the Windows link," -ForegroundColor DarkGray
        Write-Host "      and paste it into the `$MstyURL variable near the top of Step 3." -ForegroundColor DarkGray
    } else {
        $InstallerDest = "$USB_Drive\installer_data\MstySetup.exe"
        Write-Host "      Downloading Msty installer..." -ForegroundColor Magenta
        if (Get-FileWithRetry -Url $MstyURL -Dest $InstallerDest -MinBytes 10000000) {
            Write-Host ""
            Write-Host "  **********************************************************" -ForegroundColor Red
            Write-Host "  *  STOP! MANUAL ACTION REQUIRED!                          *" -ForegroundColor Red
            Write-Host "  **********************************************************" -ForegroundColor Red
            Write-Host "  The Msty installer will open now." -ForegroundColor Yellow
            Write-Host "  When prompted for an install location, choose:" -ForegroundColor Yellow
            Write-Host "    $MstyDir" -ForegroundColor White
            Write-Host "  Then close the installer when it finishes." -ForegroundColor Yellow
            Start-Process -FilePath $InstallerDest -Wait

            if (Test-Path $MstyExe) {
                Write-Host "      Msty installed to USB!" -ForegroundColor Green
                Remove-Item $InstallerDest -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host "      WARNING: Msty.exe not found on USB after install." -ForegroundColor Yellow
                Write-Host "      If it installed locally instead, it won't be portable." -ForegroundColor Yellow
            }
        } else {
            Write-Host "      ERROR: Msty installer download failed." -ForegroundColor Red
        }
    }
}

# =================================================================
# STEP 4: Ensure the selected model exists
# =================================================================
Write-Host ""
Write-Host "[4/6] Checking selected model..." -ForegroundColor Yellow

$SelectedNum = [int]$Config.SelectedModel
$Model = $ModelCatalog | Where-Object { $_.Num -eq $SelectedNum } | Select-Object -First 1

if (-Not $Model) {
    Write-Host "      ERROR: config.json SelectedModel=$SelectedNum does not match any catalog entry." -ForegroundColor Red
    Write-Host "      Valid values: $((($ModelCatalog | ForEach-Object { $_.Num }) -join ', '))" -ForegroundColor DarkGray
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit 1
}

Write-Host "      Selected: $($Model.Name) (~$($Model.Size) GB) [$($Model.Label)]" -ForegroundColor White
$ModelPath = "$USB_Drive\models\$($Model.File)"

if (Test-DownloadedFile -Path $ModelPath -MinSize $Model.MinBytes) {
    Write-Host "      Model already downloaded! Skipping." -ForegroundColor Green
} elseif ($Model.URL -eq "<HF_DOWNLOAD_URL>") {
    Write-Host "      ERROR: No download URL set for '$($Model.Name)'." -ForegroundColor Red
    Write-Host "      Edit the `$ModelCatalog entry (Num=$($Model.Num)) and set its URL" -ForegroundColor DarkGray
    Write-Host "      to the GGUF 'resolve/main/...' link from HuggingFace." -ForegroundColor DarkGray
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit 1
} else {
    Write-Host "      Downloading GGUF from Hugging Face... this may take a while." -ForegroundColor Magenta
    if (Get-FileWithRetry -Url $Model.URL -Dest $ModelPath -MinBytes $Model.MinBytes) {
        Write-Host "      Model download complete!" -ForegroundColor Green
    } else {
        Write-Host "      ERROR: Model download failed." -ForegroundColor Red
        Write-Host "      URL: $($Model.URL)" -ForegroundColor DarkGray
        exit 1
    }
}

# =================================================================
# STEP 5: Start llama-server
# =================================================================
Write-Host ""
Write-Host "[5/6] Starting llama-server..." -ForegroundColor Yellow

if (-Not (Test-Path $LlamaServer)) {
    Write-Host "      ERROR: llama-server.exe missing - cannot continue." -ForegroundColor Red
    exit 1
}

$ServerHost = $Config.Host
$ServerPort = $Config.Port
$ApiBase    = "http://${ServerHost}:${ServerPort}"

# If something is already listening on that port and responding, reuse it
$alreadyUp = $false
try {
    $r = Invoke-WebRequest -Uri "$ApiBase/health" -TimeoutSec 2 -UseBasicParsing
    if ($r.StatusCode -eq 200) { $alreadyUp = $true }
} catch {}

if ($alreadyUp) {
    Write-Host "      llama-server already running at $ApiBase - reusing it." -ForegroundColor Green
} else {
    $serverArgs = @(
        "-m", "`"$ModelPath`"",
        "--host", $ServerHost,
        "--port", $ServerPort,
        "-c", $Config.ContextSize,
        "-ngl", $Config.GpuLayers
    )
    if ($Config.ExtraServerArgs) {
        $serverArgs += ($Config.ExtraServerArgs -split "\s+")
    }

    Write-Host "      Launching: llama-server.exe $($serverArgs -join ' ')" -ForegroundColor DarkGray
    Start-Process -FilePath $LlamaServer -ArgumentList $serverArgs -WindowStyle Hidden

    # -------------------------------------------------------------
    # STEP 5b: Wait for the local API to come up
    # -------------------------------------------------------------
    Write-Host "      Waiting for API at $ApiBase ..." -ForegroundColor Yellow
    $maxWaitSeconds = 90
    $waited = 0
    $isUp = $false

    while ($waited -lt $maxWaitSeconds) {
        try {
            $r = Invoke-WebRequest -Uri "$ApiBase/health" -TimeoutSec 2 -UseBasicParsing
            if ($r.StatusCode -eq 200) { $isUp = $true; break }
        } catch {}
        Start-Sleep -Seconds 2
        $waited += 2
        Write-Host "." -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ""

    if ($isUp) {
        Write-Host "      llama-server is up! ($ApiBase)" -ForegroundColor Green
    } else {
        Write-Host "      WARNING: API did not respond within $maxWaitSeconds seconds." -ForegroundColor Red
        Write-Host "      Msty will still launch, but you may need to check the model manually." -ForegroundColor Yellow
    }
}

# =================================================================
# STEP 6: Launch Msty
# =================================================================
Write-Host ""
Write-Host "[6/6] Launching Msty..." -ForegroundColor Yellow

if (Test-Path $MstyExe) {
    Start-Process -FilePath $MstyExe
    Write-Host "      Msty launched." -ForegroundColor Green
    Write-Host "      In Msty, point the model provider to: $ApiBase" -ForegroundColor DarkGray
} else {
    Write-Host "      ERROR: Msty.exe not found - cannot launch." -ForegroundColor Red
    Write-Host "      Re-run this script after completing the Msty install step." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   SETUP COMPLETE                                          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Model   : $($Model.Name)" -ForegroundColor White
Write-Host "  API     : $ApiBase" -ForegroundColor White
Write-Host "  Config  : $ConfigPath" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to close this window..." -ForegroundColor Yellow
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
