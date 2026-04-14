#!/usr/bin/env bash
# Desktop screenshot tool — captures screen/window/region via PowerShell
# Usage:
#   screenshot.sh [--output <path>] [--window] [--find <keyword>] [--region x,y,w,h] [--delay <seconds>]

set -euo pipefail

OUTPUT=""
MODE="fullscreen"
REGION=""
FIND_KEYWORD=""
DELAY=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'EOF'
Desktop Screenshot Tool (WSL → Windows PowerShell)

Usage: screenshot.sh [options]

Options:
  --output <path>       Output file path (auto-generated if omitted)
  --window              Capture the active window
  --find <keyword>      Find window by title and capture it
  --region x,y,w,h     Capture a specific region
  --delay <seconds>     Wait N seconds before capturing
  -h, --help            Show this help

Examples:
  screenshot.sh                                    # Fullscreen, auto-named
  screenshot.sh --output /tmp/test.png           # Fullscreen to path
  screenshot.sh --window                          # Active window
  screenshot.sh --find "IDEA" --output /tmp/ide.png   # Find and capture window
  screenshot.sh --region 100,200,800,600          # Region capture
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)  OUTPUT="$2"; shift 2 ;;
        --window) MODE="window"; shift ;;
        --find)   MODE="find"; FIND_KEYWORD="$2"; shift 2 ;;
        --region) REGION="$2"; shift 2 ;;
        --delay)  DELAY="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$OUTPUT" ]]; then
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    OUTPUT="screenshots/auto/${TIMESTAMP}.png"
fi

mkdir -p "$(dirname "$OUTPUT")"

wsl_path_to_win() {
    local wsl_path="$1"
    if [[ "$wsl_path" =~ ^[A-Za-z]: ]]; then
        echo "$wsl_path"
        return
    fi
    # Prefer wslpath if available, fallback to manual conversion
    if command -v wslpath &>/dev/null; then
        wslpath -w "$wsl_path"
    else
        local abs_path="$(cd "$(dirname "$wsl_path")" 2>/dev/null && pwd)/$(basename "$wsl_path")"
        echo "$abs_path" | sed 's|/|\\|g' | sed 's|^\\|C:\\|'
    fi
}

# For fullscreen mode, get physical resolution
SCREEN_W="1920" SCREEN_H="1080"
if [[ "$MODE" == "fullscreen" ]]; then
    SCREEN_INFO="$("$SCRIPT_DIR/screen-info.sh" 2>&1)"
    PHYS_LINE="$(echo "$SCREEN_INFO" | grep -m1 '^Screen:')"
    SCREEN_W="$(echo "$PHYS_LINE" | grep -oP 'Screen:\s*\K\d+' || echo 1920)"
    SCREEN_H="$(echo "$PHYS_LINE" | grep -oP 'Screen:\s*\d+x\K\d+' || echo 1080)"
fi

PS_TEMP="$(mktemp /tmp/screenshot-XXXXXX.ps1)"

# For output, convert to Windows path if in WSL
WIN_OUTPUT="$OUTPUT"
if command -v wslpath &>/dev/null; then
    WIN_OUTPUT="$(wslpath -w "$OUTPUT")"
fi

cat > "$PS_TEMP" <<'PS1'
param(
    [string]$OutputPath,
    [string]$Mode,
    [string]$FindKeyword,
    [string]$Region,
    [int]$Delay,
    [int]$ScreenW,
    [int]$ScreenH
)

# Force UTF-8 stdout/stderr behavior when called from WSL terminals.
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

# Enable per-monitor DPI awareness so window bounds match actual pixels.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiAw {
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
    [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int awareness);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    public static void Enable() {
        try {
            if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return;
        } catch {}
        try {
            if (SetProcessDpiAwareness(2) == 0) return;
        } catch {}
        try { SetProcessDPIAware(); } catch {}
    }
}
"@
[DpiAw]::Enable()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public class WinAPI {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int maxCount);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder sb, int maxCount);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}

public class WindowInfo {
    public long Hwnd;
    public uint ProcessId;
    public string Title;
    public string ClassName;
    public int X;
    public int Y;
    public int Width;
    public int Height;
    public bool Active;
}

public class WindowFinder {
    public static List<WindowInfo> GetVisibleWindows() {
        var windows = new List<WindowInfo>();
        IntPtr activeHwnd = WinAPI.GetForegroundWindow();
        WinAPI.EnumWindows((hWnd, lParam) => {
            if (!WinAPI.IsWindowVisible(hWnd)) return true;
            int len = WinAPI.GetWindowTextLength(hWnd);
            if (len <= 0) return true;

            var titleBuilder = new StringBuilder(len + 1);
            WinAPI.GetWindowText(hWnd, titleBuilder, titleBuilder.Capacity);
            string title = titleBuilder.ToString();
            if (string.IsNullOrWhiteSpace(title)) return true;

            var rect = new WinAPI.RECT();
            if (!WinAPI.GetWindowRect(hWnd, out rect)) return true;
            int width = rect.Right - rect.Left;
            int height = rect.Bottom - rect.Top;
            if (width <= 0 || height <= 0) return true;

            var classBuilder = new StringBuilder(256);
            WinAPI.GetClassName(hWnd, classBuilder, classBuilder.Capacity);
            uint processId;
            WinAPI.GetWindowThreadProcessId(hWnd, out processId);

            windows.Add(new WindowInfo {
                Hwnd = hWnd.ToInt64(),
                ProcessId = processId,
                Title = title,
                ClassName = classBuilder.ToString(),
                X = rect.Left,
                Y = rect.Top,
                Width = width,
                Height = height,
                Active = (hWnd == activeHwnd)
            });
            return true;
        }, IntPtr.Zero);

        return windows;
    }
}
"@

if ($Delay -gt 0) {
    Start-Sleep -Seconds $Delay
}

function Test-ScreenBlack {
    param([System.Drawing.Bitmap]$bmp)
    $totalPixels = 0
    $blackPixels = 0
    $step = 50
    for ($x = 0; $x -lt $bmp.Width; $x += $step) {
        for ($y = 0; $y -lt $bmp.Height; $y += $step) {
            $totalPixels++
            $pixel = $bmp.GetPixel($x, $y)
            if ($pixel.R -lt 5 -and $pixel.G -lt 5 -and $pixel.B -lt 5) {
                $blackPixels++
            }
        }
    }
    return ($blackPixels / $totalPixels) -gt 0.95
}

function Capture-Bitmap {
    param([int]$X, [int]$Y, [int]$W, [int]$H)
    if ($W -le 0 -or $H -le 0) {
        Write-Error "Invalid dimensions: ${W}x${H}"
        exit 1
    }

    $virtual = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $minX = $virtual.Left
    $minY = $virtual.Top
    $maxX = $virtual.Right
    $maxY = $virtual.Bottom

    if ($X -lt $minX) {
        $W = $W - ($minX - $X)
        $X = $minX
    }
    if ($Y -lt $minY) {
        $H = $H - ($minY - $Y)
        $Y = $minY
    }
    if (($X + $W) -gt $maxX) {
        $W = $maxX - $X
    }
    if (($Y + $H) -gt $maxY) {
        $H = $maxY - $Y
    }

    if ($W -le 0 -or $H -le 0) {
        Write-Error "Window is off-screen: ${W}x${H}"
        exit 1
    }
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $size = New-Object System.Drawing.Size($W, $H)
    $graphics.CopyFromScreen($X, $Y, 0, 0, $size)
    $graphics.Dispose()
    return $bmp
}

function Get-WindowScore {
    param(
        [WindowInfo]$Window,
        [string]$Keyword
    )

    $title = $Window.Title.ToLowerInvariant()
    $needle = $Keyword.ToLowerInvariant()
    $score = 0

    if ($title -eq $needle) {
        $score += 1000
    } elseif ($title.StartsWith($needle)) {
        $score += 700
    } elseif ($title.Contains($needle)) {
        $score += 400
    }

    if ($Window.Active) {
        $score += 80
    }

    $score += [Math]::Min([int](($Window.Width * $Window.Height) / 50000), 120)
    return $score
}

function Find-BestWindow {
    param([string]$Keyword)

    $matches = @([WindowFinder]::GetVisibleWindows() | Where-Object {
        $_.Title -and $_.Title.ToLowerInvariant().Contains($Keyword.ToLowerInvariant())
    })

    if ($matches.Count -eq 0) {
        return $null
    }

    return $matches |
        Sort-Object `
            @{ Expression = { Get-WindowScore $_ $Keyword }; Descending = $true }, `
            @{ Expression = { $_.Active }; Descending = $true }, `
            @{ Expression = { $_.Width * $_.Height }; Descending = $true } |
        Select-Object -First 1
}

function Activate-Window {
    param([WindowInfo]$Window)

    $hwnd = [IntPtr]::new($Window.Hwnd)
    if ([WinAPI]::IsIconic($hwnd)) {
        [WinAPI]::ShowWindowAsync($hwnd, 9) | Out-Null
    } else {
        [WinAPI]::ShowWindowAsync($hwnd, 5) | Out-Null
    }

    $shell = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
    } catch {}

    for ($i = 0; $i -lt 8; $i++) {
        [WinAPI]::BringWindowToTop($hwnd) | Out-Null
        try { [WinAPI]::SwitchToThisWindow($hwnd, $true) } catch {}
        if ($shell) {
            try { $shell.SendKeys('%') } catch {}
        }
        [WinAPI]::SetForegroundWindow($hwnd) | Out-Null
        if ($shell) {
            try { $shell.AppActivate([int]$Window.ProcessId) | Out-Null } catch {}
            try { $shell.AppActivate($Window.Title) | Out-Null } catch {}
        }
        Start-Sleep -Milliseconds 180
        $foreground = [WinAPI]::GetForegroundWindow()
        if ($foreground.ToInt64() -eq $Window.Hwnd) {
            return $true
        }
    }

    return ([WinAPI]::GetForegroundWindow().ToInt64() -eq $Window.Hwnd)
}

function Get-WindowRectStable {
    param([long]$HwndValue)

    $hwnd = [IntPtr]::new($HwndValue)
    $last = $null
    for ($i = 0; $i -lt 6; $i++) {
        $rect = New-Object WinAPI+RECT
        [WinAPI]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
        $current = [PSCustomObject]@{
            X = $rect.Left
            Y = $rect.Top
            Width = $rect.Right - $rect.Left
            Height = $rect.Bottom - $rect.Top
        }

        if ($current.Width -gt 0 -and $current.Height -gt 0) {
            if ($last -and
                $last.X -eq $current.X -and
                $last.Y -eq $current.Y -and
                $last.Width -eq $current.Width -and
                $last.Height -eq $current.Height) {
                return $current
            }
            $last = $current
        }

        Start-Sleep -Milliseconds 120
    }

    return $last
}

try {
    $bmp = $null

    if ($Mode -eq "fullscreen") {
        $bmp = Capture-Bitmap 0 0 $ScreenW $ScreenH
    }
    elseif ($Mode -eq "window") {
        $hwnd = [WinAPI]::GetForegroundWindow()
        $rect = Get-WindowRectStable $hwnd.ToInt64()
        if (-not $rect -or $rect.Width -le 0 -or $rect.Height -le 0) {
            Write-Error "Invalid active window dimensions"
            exit 1
        }
        $bmp = Capture-Bitmap $rect.X $rect.Y $rect.Width $rect.Height
    }
    elseif ($Mode -eq "find") {
        $target = Find-BestWindow $FindKeyword
        if (-not $target) {
            Write-Error "Window not found: $FindKeyword"
            exit 1
        }

        if (-not (Activate-Window $target)) {
            Write-Error "Failed to activate window: $($target.Title)"
            exit 1
        }

        Start-Sleep -Milliseconds 250
        $rect = Get-WindowRectStable $target.Hwnd
        if (-not $rect -or $rect.Width -le 0 -or $rect.Height -le 0) {
            Write-Error "Invalid window dimensions after activation: $($target.Title)"
            exit 1
        }

        $bmp = Capture-Bitmap $rect.X $rect.Y $rect.Width $rect.Height
    }
    elseif ($Mode -eq "region") {
        $parts = $Region.Split(",")
        if ($parts.Length -ne 4) {
            Write-Error "Region format error, expected x,y,w,h"
            exit 1
        }
        $rx = [int]$parts[0]
        $ry = [int]$parts[1]
        $rw = [int]$parts[2]
        $rh = [int]$parts[3]
        $bmp = Capture-Bitmap $rx $ry $rw $rh
    }

    if (Test-ScreenBlack $bmp) {
        Write-Error "Black screen detected (screen may be locked)"
        $bmp.Dispose()
        exit 1
    }

    $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output $OutputPath
}
catch {
    Write-Error "Screenshot failed: $_"
    exit 1
}
PS1

WIN_PS_TEMP="$(wsl_path_to_win "$PS_TEMP")"

RESULT="$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_TEMP" \
    -OutputPath "$WIN_OUTPUT" \
    -Mode "$MODE" \
    -FindKeyword "$FIND_KEYWORD" \
    -Region "$REGION" \
    -Delay "$DELAY" \
    -ScreenW "$SCREEN_W" \
    -ScreenH "$SCREEN_H" 2>&1)"
EXIT_CODE=$?
rm -f "$PS_TEMP"

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "Screenshot failed (exit code: $EXIT_CODE)" >&2
    echo "$RESULT" >&2
    exit 1
fi

# Wait a moment for file sync
sleep 0.5

if [[ ! -f "$OUTPUT" ]]; then
    echo "Screenshot file not generated: $OUTPUT" >&2
    exit 1
fi

FILE_SIZE="$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null || echo 0)"
if [[ "$FILE_SIZE" -lt 1000 ]]; then
    echo "Screenshot file too small (${FILE_SIZE} bytes), likely failed" >&2
    rm -f "$OUTPUT"
    exit 1
fi

echo "$OUTPUT"
