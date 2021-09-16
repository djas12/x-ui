#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Kesalahan: ${plain} Kamu harus masuk root untuk menjalankan perintah ini, sampai di sini faham.?！\n" && exit 1

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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Apakah akan me-restart panel, restart panel juga akan restart xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Silahkan tekan enter untuk ke Menu utama: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/djas12/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Fungsi ini akan secara paksa menginstal ulang versi terbaru saat ini, dan data tidak akan hilang. Apakah Anda ingin melanjutkan?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}已取消${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/djas12/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}Pembaruan selesai dan panel telah dimulai ulang secara otomatis${plain}"
        exit 0
    fi
}

uninstall() {
    confirm "Apakah Anda yakin ingin mencopot pemasangan panel?，xray Juga akan menghapus?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Penghapusan instalasi berhasil. Jika Anda ingin menghapus skrip ini, keluar dari skrip dan jalankan ${green}rm /usr/bin/x-ui -f${plain} Menghapus"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Apakah Anda yakin ingin mengatur ulang nama pengguna dan kata sandi Anda ke admin 吗" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Nama pengguna dan kata sandi telah disetel ulang ke ${green}admin${plain}，Silakan restart panel sekarang"
    confirm_restart
}

reset_config() {
    confirm "Apakah Anda yakin ingin mengatur ulang semua pengaturan panel? Data akun tidak akan hilang, nama pengguna dan kata sandi tidak akan diubah" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Semua pengaturan panel telah diatur ulang ke nilai default, sekarang silakan restart panel dan gunakan default ${green}54321${plain} Panel akses port"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Masukkan nomor port[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}Dibatalkan${plain}"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "Setelah mengatur port, silakan restart panel dan gunakan port yang baru disetel ${green}${port}${plain} Panel akses"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Panel sudah berjalan, tidak perlu memulai lagi, jika perlu memulai ulang, silakan pilih mulai ulang${plain}"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}x-ui Berhasil memulai${plain}"
        else
            echo -e "${red}Panel gagal memulai. Mungkin karena waktu mulai lebih dari dua detik. Harap periksa informasi log nanti${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}Panel sudah berhenti, tidak perlu berhenti lagi${plain}"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}x-ui 与 xray Berhasil dihentikan${plain}"
        else
            echo -e "${red}Panel gagal berhenti. Mungkin karena waktu berhenti lebih dari dua detik. Harap periksa informasi log nanti${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui 与 xray Restart berhasil${plain}"
    else
        echo -e "${red}Restart panel gagal, mungkin karena waktu startup melebihi dua detik, silakan periksa informasi log nanti${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui Atur power-on auto-start dengan sukses${plain}"
    else
        echo -e "${red}x-ui Gagal mengatur self-start setelah power-on${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui Batalkan power-on auto-start dengan sukses${plain}"
    else
        echo -e "${red}x-ui Batalkan kegagalan startup${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/djas12/x-ui/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Gagal mengunduh skrip, periksa apakah vps terhubung Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        echo -e "${green}Skrip pemutakhiran berhasil, jalankan kembali skrip${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Panel telah dipasang, mohon jangan dipasang berulang kali${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Silakan instal panelnya terlebih dahulu${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Status panel: ${green}Sudah berjalan${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Status panel: ${yellow}Tidak jalan${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Status panel: ${red}Tak terpasang${plain}"
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Apakah akan memulai secara otomatis setelah boot: ${green}Ya${plain}"
    else
        echo -e "Apakah akan memulai secara otomatis setelah boot: ${red}tidak${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray status: ${green}Jalan${plain}"
    else
        echo -e "xray status: ${red}Tidak jalan${plain}"
    fi
}

show_usage() {
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
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}x-ui Skrip manajemen panel${plain}
  ${green}0.${plain} Keluar dari skrip
————————————————
  ${green}1.${plain} Instal x-ui
  ${green}2.${plain} Perbarui x-ui
  ${green}3.${plain} Copot pemasangan x-ui
————————————————
  ${green}4.${plain} Setel ulang nama pengguna dan kata sandi
  ${green}5.${plain} Setel ulang pengaturan panel
  ${green}6.${plain} Setel port panel
————————————————
  ${green}7.${plain} Mulai x-ui
  ${green}8.${plain} Hentikan x-ui
  ${green}9.${plain} Mulai ulang x-ui
 ${green}10.${plain} Lihat status x-ui
 ${green}11.${plain} Lihat log x-ui
————————————————
 ${green}12.${plain} Atur x-ui untuk memulai secara otomatis setelah boot
 ${green}13.${plain} batalkan boot x-ui dari awal
————————————————
 ${green}14.${plain} 一Pemasangan kunci bbr (最新内核)
 "
    show_status
    echo && read -p "Silakan masukkan pilihan [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
        11) check_install && show_log
        ;;
        12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "${red}Silakan masukkan nomor yang benar [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "v2-ui") check_install 0 && migrate_v2_ui 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
