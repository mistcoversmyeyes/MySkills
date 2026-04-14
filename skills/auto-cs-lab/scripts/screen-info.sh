#!/usr/bin/env bash
# Screen info tool — queries physical/logical resolution and DPI scale via PowerShell
# Usage: screen-info.sh

set -euo pipefail

usage() {
    cat <<'EOF'
Screen Info Tool (WSL → Windows PowerShell)

Usage: screen-info.sh [-h|--help]

Outputs:
  Screen: <physical_width>x<physical_height> @ (0,0)
  DPI Scale: <percent>%
  Resolution: <physical_width>x<physical_height> (physical), <logical_width>x<logical_height> (logical)

Examples:
  screen-info.sh            # Show screen resolution and DPI
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

wsl_path_to_win() {
    local wsl_path="$1"
    if [[ "$wsl_path" =~ ^[A-Za-z]: ]]; then
        echo "$wsl_path"
        return
    fi
    if command -v wslpath &>/dev/null; then
        wslpath -w "$wsl_path"
    else
        local abs_path="$(cd "$(dirname "$wsl_path")" 2>/dev/null && pwd)/$(basename "$wsl_path")"
        echo "$abs_path" | sed 's|/|\\|g' | sed 's|^\\|C:\\|'
    fi
}

PS_TEMP="$(mktemp /tmp/screeninfo-XXXXXX.ps1)"
trap 'rm -f "$PS_TEMP"' EXIT

# Must set DPI awareness BEFORE loading System.Windows.Forms
cat > "$PS_TEMP" <<'PS1'
# Force UTF-8 stdout so terminal output stays readable under WSL.
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

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
using System.Runtime.InteropServices;
public class ScreenDpi {
    [DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int index);
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hwnd, IntPtr hdc);
    public static int GetDpi() {
        IntPtr hdc = GetDC(IntPtr.Zero);
        int dpi = GetDeviceCaps(hdc, 88);
        ReleaseDC(IntPtr.Zero, hdc);
        return dpi;
    }
}
"@

$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$physW = $screen.Bounds.Width
$physH = $screen.Bounds.Height
$dpi = [ScreenDpi]::GetDpi()
$scalePct = [Math]::Round(($dpi / 96.0) * 100)
$logicW = [Math]::Round($physW / ($dpi / 96.0))
$logicH = [Math]::Round($physH / ($dpi / 96.0))

Write-Output "Screen: ${physW}x${physH} @ (0,0)"
Write-Output "DPI Scale: ${scalePct}%"
Write-Output "Resolution: ${physW}x${physH} (physical), ${logicW}x${logicH} (logical)"
PS1

WIN_PS_TEMP="$(wsl_path_to_win "$PS_TEMP")"

RESULT="$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_TEMP" 2>&1)"
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "Screen info query failed (exit code: $EXIT_CODE)" >&2
    echo "$RESULT" >&2
    exit 1
fi

echo "$RESULT"
