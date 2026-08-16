#!/usr/bin/env bash
# ==============================================================================
# get-essential-runtimes.sh
# Descargador nativo para Arch Linux (curl + 7z)
# Descarga los Runtimes oficiales de Microsoft en scripts/Runtimes/
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/Runtimes"
DIRECTX_DIR="${TARGET_DIR}/DirectX"

mkdir -p "${TARGET_DIR}"
mkdir -p "${DIRECTX_DIR}"

echo -e "\e[1;36m╔══════════════════════════════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;36m║     DESCARGADOR DE RUNTIMES ESENCIALES (NATIVO ARCH LINUX)           ║\e[0m"
echo -e "\e[1;36m╚══════════════════════════════════════════════════════════════════════╝\e[0m"
echo -e "\e[90mDestino: ${TARGET_DIR}\e[0m\n"

download_file() {
    local name="$1"
    local filename="$2"
    local url="$3"
    local dest="${TARGET_DIR}/${filename}"

    if [ -f "${dest}" ]; then
        local size_mb
        size_mb=$(du -m "${dest}" | cut -f1)
        echo -e "  \e[32m[OK]\e[0m ${name}: Ya existe (${size_mb} MB). Omitiendo."
    else
        echo -ne "  \e[33m[..]\e[0m Descargando ${name}..."
        curl -sSL -o "${dest}" "${url}"
        local size_mb
        size_mb=$(du -m "${dest}" | cut -f1)
        echo -e "\r  \e[32m[OK]\e[0m ${name} descargado (${size_mb} MB)."
    fi
}

# 1. Visual C++ 2015-2022
download_file "Visual C++ 2015-2022 (x64)" "vc_redist.x64.exe" "https://aka.ms/vs/17/release/vc_redist.x64.exe"
download_file "Visual C++ 2015-2022 (x86)" "vc_redist.x86.exe" "https://aka.ms/vs/17/release/vc_redist.x86.exe"

# 2. Visual C++ 2013
download_file "Visual C++ 2013 (x64)" "vcredist_2013_x64.exe" "https://download.microsoft.com/download/2/E/6/2E61C7AB-2E19-482F-B0F0-087940B04246/vcredist_x64.exe"
download_file "Visual C++ 2013 (x86)" "vcredist_2013_x86.exe" "https://download.microsoft.com/download/2/E/6/2E61C7AB-2E19-482F-B0F0-087940B04246/vcredist_x86.exe"

# 3. Visual C++ 2012
download_file "Visual C++ 2012 (x64)" "vcredist_2012_x64.exe" "https://download.microsoft.com/download/1/6/B/16B06F60-3CA2-4533-82F9-F016B074FAA4/vcredist_x64.exe"
download_file "Visual C++ 2012 (x86)" "vcredist_2012_x86.exe" "https://download.microsoft.com/download/1/6/B/16B06F60-3CA2-4533-82F9-F016B074FAA4/vcredist_x86.exe"

# 4. DirectX End-User Runtimes (Junio 2010)
DX_SETUP="${DIRECTX_DIR}/dxsetup.exe"
DX_INSTALLER="${TARGET_DIR}/directx_Jun2010_redist.exe"

if [ -f "${DX_SETUP}" ]; then
    echo -e "  \e[32m[OK]\e[0m DirectX End-User (Junio 2010): Ya extraído en DirectX/. Omitiendo."
else
    echo -ne "  \e[33m[..]\e[0m Descargando DirectX End-User Runtimes (96 MB)..."
    curl -sSL -o "${DX_INSTALLER}" "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe"
    echo -e "\r  \e[32m[OK]\e[0m DirectX End-User Runtimes descargado."

    echo -ne "  \e[33m[..]\e[0m Extrayendo DirectX con 7z en '${DIRECTX_DIR}'..."
    7z x -y "${DX_INSTALLER}" -o"${DIRECTX_DIR}" > /dev/null
    rm -f "${DX_INSTALLER}"
    echo -e "\r  \e[32m[OK]\e[0m DirectX extraído exitosamente y contenedor temporal eliminado."
fi

echo -e "\n\e[1;32m══════════════════════════════════════════════════════════════════════\e[0m"
echo -e "\e[1;32m  Descargas completadas con éxito en Arch Linux.\e[0m"
echo -e "\e[90m  Ruta: ${TARGET_DIR}\e[0m"
echo -e "\e[1;32m══════════════════════════════════════════════════════════════════════\e[0m"
