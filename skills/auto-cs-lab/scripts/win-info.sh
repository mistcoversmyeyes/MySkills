#!/usr/bin/env bash
# Window info query tool — enumerates windows via Win32 API
# Usage:
#   win-info.sh [--list] [--active] [--find <keyword>] [--scale <percent>]
# --scale is mandatory for correct physical-pixel coordinates on HiDPI screens.
# Get scale from: screen-info.sh (DPI Scale line)

set -euo pipefail

MODE="list"
FIND_KEYWORD=""
SCALE=100

usage() {
    cat <<'EOF'
Window Info Tool (WSL → Windows PowerShell)

Usage: win-info.sh [options]

Options:
  --list             List all visible windows
  --active           Show the currently active window
  --find <keyword>   Search windows by title keyword
  --scale <percent>  DPI scale factor (e.g. 175 for 175%). Get from screen-info.sh
  -h, --help         Show this help

Examples:
  win-info.sh --scale 175 --list
  win-info.sh --scale 175 --find "Chrome"

Output format:
  Index | Title | Width | Height | X | Y | Class | [active]
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)    MODE="list"; shift ;;
        --active)  MODE="active"; shift ;;
        --find)    MODE="find"; FIND_KEYWORD="$2"; shift 2 ;;
        --scale)   SCALE="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Scale factor: logical -> physical pixel conversion
SCALE_NUM="$(echo "$SCALE" | sed 's/%//')"
SCALE_FACTOR="$(echo "scale=4; $SCALE_NUM / 100" | bc 2>/dev/null || echo "1")"

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

PS_TEMP="$(mktemp /tmp/wininfo-XXXXXX.ps1)"
trap 'rm -f "$PS_TEMP"' EXIT

cat > "$PS_TEMP" <<'PS1'
param(
    [string]$Mode,
    [string]$Keyword,
    [double]$ScaleFactor
)

# Force UTF-8 stdout so non-ASCII window titles render correctly in WSL terminals.
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class WinEnum {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int maxCount);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder sb, int maxCount);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public class WindowInfo {
        public int Index;
        public string Title;
        public string Class;
        public int Width;
        public int Height;
        public int X;
        public int Y;
        public bool Active;
    }

    public static List<WindowInfo> GetVisibleWindows() {
        var windows = new List<WindowInfo>();
        IntPtr activeHwnd = GetForegroundWindow();
        EnumWindows((hWnd, lParam) => {
            if (!IsWindowVisible(hWnd)) return true;
            int len = GetWindowTextLength(hWnd);
            if (len == 0) return true;
            var titleBuilder = new StringBuilder(len + 1);
            GetWindowText(hWnd, titleBuilder, titleBuilder.Capacity);
            string title = titleBuilder.ToString();
            if (string.IsNullOrWhiteSpace(title)) return true;

            var rect = new RECT();
            GetWindowRect(hWnd, out rect);
            int w = rect.Right - rect.Left;
            int h = rect.Bottom - rect.Top;
            if (w <= 0 || h <= 0) return true;

            var classBuilder = new StringBuilder(256);
            GetClassName(hWnd, classBuilder, classBuilder.Capacity);

            windows.Add(new WindowInfo {
                Index = 0,
                Title = title,
                Class = classBuilder.ToString(),
                Width = w,
                Height = h,
                X = rect.Left,
                Y = rect.Top,
                Active = (hWnd == activeHwnd)
            });
            return true;
        }, IntPtr.Zero);

        for (int i = 0; i < windows.Count; i++) {
            windows[i].Index = i + 1;
        }
        return windows;
    }

    public static WindowInfo GetActiveWindow() {
        IntPtr hwnd = GetForegroundWindow();
        int len = GetWindowTextLength(hwnd);
        var titleBuilder = new StringBuilder(len + 1);
        GetWindowText(hwnd, titleBuilder, titleBuilder.Capacity);
        var rect = new RECT();
        GetWindowRect(hwnd, out rect);
        var classBuilder = new StringBuilder(256);
        GetClassName(hwnd, classBuilder, classBuilder.Capacity);
        return new WindowInfo {
            Index = 0,
            Title = titleBuilder.ToString(),
            Class = classBuilder.ToString(),
            Width = rect.Right - rect.Left,
            Height = rect.Bottom - rect.Top,
            X = rect.Left,
            Y = rect.Top,
            Active = true
        };
    }
}
"@

$windows = [WinEnum]::GetVisibleWindows()

# Scale logical coordinates to physical pixels
$sf = [double]$ScaleFactor
foreach ($w in $windows) {
    $w.X = [int]($w.X * $sf)
    $w.Y = [int]($w.Y * $sf)
    $w.Width = [int]($w.Width * $sf)
    $w.Height = [int]($w.Height * $sf)
}

if ($Mode -eq "active") {
    $active = [WinEnum]::GetActiveWindow()
    $active.X = [int]($active.X * $sf)
    $active.Y = [int]($active.Y * $sf)
    $active.Width = [int]($active.Width * $sf)
    $active.Height = [int]($active.Height * $sf)
    Write-Output "Active: $($active.Title)|$($active.Width)|$($active.Height)|$($active.X)|$($active.Y)|$($active.Class)"
}
elseif ($Mode -eq "find") {
    $needle = $Keyword.ToLowerInvariant()
    $found = @($windows | Where-Object { $_.Title.ToLowerInvariant().Contains($needle) } | Sort-Object `
        @{ Expression = {
            $title = $_.Title.ToLowerInvariant()
            if ($title -eq $needle) { 1000 }
            elseif ($title.StartsWith($needle)) { 700 }
            else { 400 }
        }; Descending = $true }, `
        @{ Expression = { $_.Active }; Descending = $true }, `
        @{ Expression = { $_.Width * $_.Height }; Descending = $true })
    if ($found.Count -eq 0) {
        Write-Output "NOT_FOUND"
    } else {
        foreach ($w in $found) {
            $marker = if ($w.Active) { "1" } else { "0" }
            Write-Output "$($w.Index)|$($w.Title)|$($w.Width)|$($w.Height)|$($w.X)|$($w.Y)|$($w.Class)|$marker"
        }
    }
}
else {
    Write-Output "COUNT=$($windows.Count)"
    foreach ($w in $windows) {
        $marker = if ($w.Active) { "1" } else { "0" }
        Write-Output "$($w.Index)|$($w.Title)|$($w.Width)|$($w.Height)|$($w.X)|$($w.Y)|$($w.Class)|$marker"
    }
}
PS1

WIN_PS_TEMP="$(wsl_path_to_win "$PS_TEMP")"

RESULT="$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_TEMP" \
    -Mode "$MODE" \
    -Keyword "$FIND_KEYWORD" \
    -ScaleFactor "$SCALE_FACTOR" 2>&1)"
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "Window query failed (exit code: $EXIT_CODE)" >&2
    echo "$RESULT" >&2
    exit 1
fi

echo "$RESULT"
