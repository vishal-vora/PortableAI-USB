# Portable AI USB — llama.cpp + Msty

Run a local LLM straight off a USB drive on any Windows PC. One script checks for
everything it needs, downloads what's missing, and launches a chat UI wired up to
a local inference server — no installs on the host machine, no internet required
after the first setup.

```
Read config (USB root)
   ↓
Does llama.cpp exist?      → No → download latest release (GitHub)
   ↓
Does Msty exist?           → No → download latest release (one-time manual install step)
   ↓
Does the selected model exist? → No → download GGUF from Hugging Face
   ↓
Start llama-server
   ↓
Wait for the local API to come up
   ↓
Launch Msty
```

## What's in this folder

| File | Purpose |
|---|---|
| `setup.ps1` | The setup/launch script. Run this every time. |
| `config.json` | Your settings — which model to load, host/port, context size, etc. |

Running the script also creates, on first run:

```
USB_ROOT/
├── setup.ps1
├── config.json
├── llama.cpp/          ← llama-server.exe + DLLs
├── msty/                ← Msty.exe (portable install)
├── models/              ← downloaded .gguf model files
└── installer_data/      ← temp installer downloads (auto-cleaned)
```

## Requirements

- Windows 10/11 (x64)
- PowerShell 5+ (built into Windows)
- Internet connection for the *first* run only (to download llama.cpp, Msty, and
  the model). After that, everything runs offline from the USB drive.
- Enough free space on the USB drive for the model you pick (see the catalog
  below) plus roughly 1–2 GB for llama.cpp and Msty themselves.

## Quick start

1. Copy `setup.ps1` and `config.json` to the root of your USB
   drive.
2. Open `config.json` and set `SelectedModel` to the number of the model you
   want (see catalog below).
3. Right-click `setup.ps1` → **Run with PowerShell**
   (or `powershell -ExecutionPolicy Bypass -File setup.ps1` from a terminal , the same exist in lanch.bat ).
4. First run only:
   - llama.cpp downloads and extracts automatically.
   - Msty's installer opens — when it asks for an install location, point it
     at `USB_ROOT\msty` so it stays portable. This step needs the `$MstyURL`
     variable filled in first (see [Setup notes](#setup-notes) below).
   - The selected model downloads from Hugging Face.
5. The script starts `llama-server`, waits for its API to respond, then
   launches Msty pointed at that local server.
6. On future runs, all three checks pass instantly and it just starts the
   server and launches Msty.

## `config.json` reference

```json
{
    "SelectedModel": 1,
    "Host": "127.0.0.1",
    "Port": 8080,
    "ContextSize": 4096,
    "GpuLayers": 0,
    "ExtraServerArgs": ""
}
```

| Key | Meaning |
|---|---|
| `SelectedModel` | Number from the model catalog (below) to load. |
| `Host` / `Port` | Where `llama-server` listens. Msty is pointed at `http://Host:Port`. |
| `ContextSize` | Context window passed to llama-server as `-c`. |
| `GpuLayers` | Layers offloaded to GPU (`-ngl`). Leave at `0` for CPU-only. |
| `ExtraServerArgs` | Any extra flags appended verbatim to the `llama-server` command, e.g. `"--flash-attn"`. |

If `config.json` is missing, the script creates a default one automatically.
If it's malformed, the script falls back to defaults rather than failing.

## Model catalog

| # | Model | Size | Label | Best for |
|---|---|---|---|---|
| 1 | Qwen3 Coder 8B | ~4.9 GB | STANDARD | Coding |
| 2 | Phi-4 Mini Uncensored | ~2.49 GB | UNCENSORED | Reasoning |
| 3 | DeepSeek Lite V2 | ~9.8 GB | STANDARD | Fast/lightweight |
| 4 | Gemma 4 12B | ~4.9 GB | STANDARD | Writing / UI |
| 5 | Phi-4 Mini 3.8B | ~2.4 GB | STANDARD | General use |

To add or edit a model, add an entry to the `$ModelCatalog` array near the
top of the script with a unique `Num`, the exact `.gguf` filename, its
direct Hugging Face `resolve/main/...` URL, and a `MinBytes` sanity-check
value (roughly 80% of the real file size, used to detect truncated
downloads).

## Setup notes

**llama.cpp** downloads automatically — the script queries the GitHub
Releases API for `ggml-org/llama.cpp` and grabs the Windows CPU x64 build.
No configuration needed.

**Msty** downloads automatically and instter verbously installs 
the folder is located inside **Usbroot:\msty\**  names **MstyStudio** 
Run **MstyStudio.exe** ince the Model comletes it's downloading process.
and allocates URL supplied by llama.cpp

**Model URLs**: several catalog entries ship with a `<HF_DOWNLOAD_URL>`
placeholder. Replace each with the model's actual `resolve/main/...gguf`
link from its Hugging Face page before selecting that model — the script
will refuse to download a placeholder and will tell you exactly which
catalog entry needs fixing.

## Msty integration with llama.cpp
Link llama.cpp Into **Msty's** Local Model Hub
Now that **llama.cpp** is hosting an API server on port 8080, tell Msty to grab it
1.	Open Msty and navigate to the **Model Hub** from the sidebar.
2.	Click on the **Local Models** tab.
3.	Look for the **Llama.cpp** configuration section.
4.	Set the **Endpoint URL** to: http://127.0.01:8080/v1 (the OpenAI-compatible local port).
5.	Click **Save/Connect**.

## Troubleshooting

- **"llama-server.exe not found after extraction"** — GitHub's asset naming
  changed. Check <https://github.com/ggml-org/llama.cpp/releases/latest>
  manually and adjust the asset-matching pattern in Step 2.
- **"API did not respond within 90 seconds"** — the model may be too large
  for available RAM, or `GpuLayers` is set higher than your GPU supports.
  Try `GpuLayers: 0` and a smaller model.
- **Msty.exe not found** — the installer likely wrote to the default local
  path instead of the USB. Re-run and manually browse to `USB_ROOT\msty`
  when prompted.
- **Download fails / file too small** — the script retries twice and checks
  file size against `MinBytes`. If it still fails, check the USB has enough
  free space and your connection is stable, then re-run — completed
  downloads are skipped automatically.
## Notes on portability
Everything the script installs — llama.cpp, Msty, and the model — lives
under the USB root, so the same drive works on any Windows PC without
re-downloading anything. Re-running the script on a new machine just starts
the server and launches Msty; nothing is written outside the USB drive.
## - **Special Credit to TechJarves** 
This project was inspired by the **PortableAI on USB** project by **TechJarves** on GitHub.
While exploring that project, I encountered challenges with the complexity of installing and configuring **AnythingLLM**, along with the additional dependency on **Ollama**. These extra layers increased the setup effort and reduced the portability and simplicity of the solution.
This inspired me to develop a streamlined alternative that eliminates the need for both **AnythingLLM** and **Ollama**, allowing GGUF models to run directly through a lightweight, self-contained interface. The result is a truly portable, zero-install AI environment that can be carried on a USB drive, requires minimal configuration, and is designed for ease of use, performance, and offline operation.
