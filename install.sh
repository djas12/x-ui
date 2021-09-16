#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Kesalahan：${plain} Kamu harus masuk root untuk menjalankan perintah ini, sampai di sini faham.?！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}versi ini tidak bisa，silahkan hubungi pembuat script！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}Gagal mendeteksi arsitektur, gunakan arsitektur default: ${arch}${plain}"
fi

echo "Arsitektur: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "Software ini tidak mendukung sistem 32-bit (x86), silakan gunakan sistem 64-bit (x86_64), jika deteksi salah, silakan hubungi penulis"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Silahkan gunakan CentOS 7 Atau di atasnya！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Silahkan gunakan Ubuntu 16 Atau di atasnya！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Silahkan gunakan Debian 8 Atau di atasnya！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Deteksi x-ui Versi gagal, mungkin lebih dari itu Github API Batasan, silakan coba lagi nanti, atau tentukan secara manual x-ui Instalasi versi${plain}"
            exit 1
        fi
        echo -e "terdeteksi x-ui Versi terbaru dari：${last_version}，mulai instalasi"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/djas12/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}unduh x-ui gagal，Pastikan server Anda dapat mengunduh Github dokumen${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/djas12/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "mulai instalasi x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}unduh x-ui v$1 gagal，Pastikan versi ini ada${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/djas12/x-ui/main/x-ui.sh
    chmod +x /usr/bin/x-ui
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Instalasi selesai dan panel telah dimulai，"
    echo -e ""
    echo -e "Jika ini adalah instalasi baru, port web default adalah ${green}54321${plain}，Nama pengguna dan kata sandi keduanya secara default ${green}admin${plain}"
    echo -e "Pastikan port ini tidak ditempati oleh program lain，${yellow}Dan pastikan 54321 telah di buka agar bisa di akses${plain}"
#    echo -e "Jika kamu ingin 54321 di ubah ke port lain，masuk x-ui lalu cari pengaturan，dan pastikan port yang kalian ubah sudah di buka agar bisa di akses dan tidak eror"
    echo -e ""
    echo -e "Jika ingin memperbarui panel, akses panel seperti yang Anda lakukan sebelumnya"
    echo -e ""
    echo "x-ui Cara menggunakan skrip manajemen: "
    echo "------------------------------------------"
    echo "x-ui              - Tampilan menu manajemen (fungsi lainnya)"
    echo "x-ui start        - Luncurkan panel x-ui"
    echo "x-ui stop         - Hentikan panel x-ui"
    echo "x-ui restart      - Mulai ulang panel x-ui"
    echo "x-ui status       - Lihat status x-ui"
    echo "x-ui enable       - Atur x-ui untuk memulai secara otomatis setelah boot"
    echo "x-ui disable      - Batalkan boot x-ui dari awal"
    echo "x-ui log          - Lihat log x-ui"
    echo "x-ui v2-ui        - Migrasikan data akun v2-ui mesin ini ke x-ui"
    echo "x-ui update       - Perbarui panel x-ui"
    echo "x-ui install      - Instal panel x-ui"
    echo "x-ui uninstall    - Copot pemasangan panel x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}mulai instalasi${plain}"
install_base
install_x-ui $1
