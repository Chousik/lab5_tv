#!/usr/bin/env bash
# Лабораторная работа 5 «Proxmox VE» (Mac M3 Pro, VirtualBox): шпаргалка по шагам.
#
#   ./lab.sh          все части по порядку
#   ./lab.sh 0        подготовка VirtualBox и ISO
#   ./lab.sh 1        часть 1 (и так далее до 5)
#   ./lab.sh 2 3      части 2 и 3
#
# Сценарий ничего не выполняет сам: он печатает блоки команд, которые удобно
# выделить, скопировать и выполнить. Над каждым блоком написано, где его выполнять.
# Когда нужно сделать скриншот, пишет «СКРИН ...» и ждёт Enter.
# Скриншоты сохраняй в virt-lab5/screens/ под указанными именами.

set -u

# ---------- Вспомогательные функции ----------
c_shot=$'\e[1;35m'; c_step=$'\e[1;36m'; c_where=$'\e[1;33m'; c_off=$'\e[0m'

step()  { clear; printf '%s==== %s ====%s\n' "$c_step" "$1" "$c_off"; }
sub()   { printf '\n%s--- %s ---%s\n' "$c_step" "$1" "$c_off"; }
where() { printf '\n%s🖥  %s:%s\n' "$c_where" "$1" "$c_off"; }
shot()  {                    # shot <файл> <что должно быть видно>
    printf '\n%s📸 СКРИН %s%s\n   %s\n' "$c_shot" "screens/$1" "$c_off" "$2"
    read -r -p "   Сделай скриншот и нажми Enter... " _
}
note()  { printf '\n👉 %s\n' "$*"; }
cmds()  { printf '\n'; cat; printf '\n'; }

# ---------- Часть 0 ----------
part0() {
    step "Часть 0. VirtualBox и ISO"
    where "на Mac"
    cmds <<'EOF'
brew install --cask virtualbox
EOF
    note "Разреши расширение Oracle: Системные настройки → Конфиденциальность и безопасность."
    note "Скачай ISO: Proxmox VE 9.2 arm64 (proxmox.com/en/downloads) и Debian 13 arm64 netinst"
    note "(cdimage.debian.org/debian-cd/current/arm64/iso-cd/)."
    note "Файл → Инструменты → Менеджер сетей → Сети хоста → Создать:"
    note "маска 255.255.255.0, нижняя граница 10.10.10.200, верхняя 10.10.10.250."
    note "Создать VM: имя proxmox, ISO Proxmox arm64, Linux / Debian (ARM 64-bit),"
    note "«Пропустить автоматическую установку», 8192 МБ, 4 ЦП, диск 64 ГБ."
    note "Сеть: Адаптер 1 NAT; Адаптер 2 Сеть хоста, Неразборчивый режим: Разрешить всё."
    shot 01-adapters.png "вкладка Сеть: Адаптер 1 NAT и Адаптер 2 Сеть хоста"
    shot 02-system.png "вкладка Система: память и процессоры"
}

# ---------- Часть 1 ----------
part1() {
    step "Часть 1. Установка Proxmox VE и сеть"
    sub "1.1. Установка"
    note "Install Proxmox VE (Graphical). Диск целиком, ext4. Russia / Europe/Moscow."
    note "Management Network: ПЕРВЫЙ интерфейс (NAT): 10.0.2.15/24, шлюз 10.0.2.2, hostname pve.lab.local."
    note "Если после установки снова грузится ISO: выключи VM, Настройки → Носители → убери ISO."
    shot 03-installer-net.png "экран Management Network Configuration"
    where "в консоли Proxmox (root)"
    cmds <<'EOF'

ip -br link
ip route get 77.88.8.8
EOF
    note "Запомни имя второго интерфейса (обычно enp0s6). Если другое, замени enp0s6 ниже."
    shot 04-ip-link.png "интерфейсы и маршрут к 77.88.8.8 через vmbr0"

    sub "1.2. Мост vmbr1"
    where "в консоли Proxmox"
    cmds <<'EOF'
cp /etc/network/interfaces /etc/network/interfaces.bak
nano /etc/network/interfaces
EOF
    note "Допиши в конец файла (Ctrl+O, Enter, Ctrl+X):"
    cmds <<'EOF'
auto enp0s6
iface enp0s6 inet manual

auto vmbr1
iface vmbr1 inet static
        address 10.10.10.1/24
        bridge-ports enp0s6
        bridge-stp off
        bridge-fd 0
        post-up   iptables -t nat -A POSTROUTING -s '10.10.10.0/24' -o vmbr0 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '10.10.10.0/24' -o vmbr0 -j MASQUERADE
EOF
    cmds <<'EOF'
clear
cat /etc/network/interfaces
EOF
    shot 05-interfaces.png "файл interfaces с блоками vmbr0 и vmbr1"

    sub "1.3. Пересылка и NAT"
    where "в консоли Proxmox"
    cmds <<'EOF'
printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-pve-lab.conf
sysctl --system
ifreload -a
clear
ip -br address
ip route
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
EOF
    shot 06-forward-nat.png "vmbr1 10.10.10.1/24, ip_forward = 1, правило MASQUERADE"
    sub "1.4. Адрес 10.10.10.254 на Mac"
    where "на Mac (VM proxmox запущена)"
    cmds <<'EOF'
ifconfig | grep -B6 'inet 10.10.10'
EOF
    note "Возьми имя интерфейса с адресом 10.10.10.200 (обычно bridge100) и подставь ниже."
    cmds <<'EOF'
sudo ifconfig bridge102 alias 10.10.10.254 netmask 255.255.255.0
clear
ifconfig bridge102 | grep inet
ping -c 4 10.10.10.1
EOF
    shot 07-host-ping.png "на Mac адрес 10.10.10.254 и ответы от 10.10.10.1"
    note "В браузере на Mac: https://10.10.10.1:8006, root, Linux PAM."
    shot 08-webui.png "веб-интерфейс Proxmox, в адресной строке 10.10.10.1:8006"
}

# ---------- Часть 2 ----------
part2() {
    step "Часть 2. Виртуальная машина Debian"
    note "local (pve) → ISO Images → Upload → debian-13 arm64 netinst."
    shot 09-iso.png "ISO Debian в ISO Images"
    note "Create VM: ID 100, Name SilaevZahar, ISO debian-13 arm64, BIOS OVMF (UEFI) + EFI disk,"
    note "диск 32 GiB, Sockets 1, Cores 1, Memory 2048, Bridge vmbr1, Model VirtIO."
    shot 10-vm-params.png "вкладка Confirm с параметрами VM"
    note "Start → Console (установка медленная, это эмуляция). Сеть вручную: 10.10.10.10 / 255.255.255.0 / шлюз 10.10.10.1 / DNS 1.1.1.1."
    shot 11-debian-ip.png "установщик Debian: ручной ввод IP"
    note "Создай обычного пользователя (например zahar). Программы: только standard system utilities."
    note "После установки: Hardware → CD/DVD → Do not use any media, затем Start."
    note "ДО ПЕРВОГО ЗАПУСКА: VM 100 → Options → KVM hardware virtualization: No (вложенной виртуализации нет)."
    note "Чёрная консоль: Hardware → Display → Serial terminal 0, Console → xterm.js."
    where "в Debian (root)"
    cmds <<'EOF'
clear
ip -br address
ip route
ping -c 4 10.10.10.1
ping -c 4 77.88.8.8
ping -c 4 ya.ru
EOF
    shot 12-vm-net.png "10.10.10.10/24, default via 10.10.10.1, три ping без потерь"
    cmds <<'EOF'
clear
apt install -y traceroute
traceroute 77.88.8.8
EOF
    shot 13-vm-traceroute.png "трассировка, первый узел 10.10.10.1"
}

# ---------- Часть 3 ----------
part3() {
    step "Часть 3. Контейнер Alpine"
    note "local (pve) → CT Templates → Templates → alpine → Download."
    note "Если Alpine для arm64 в списке нет, скачай его сам:"
    where "в консоли Proxmox"
    cmds <<'EOF'
cd /var/lib/vz/template/cache
f=$(curl -s https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/ | grep -o 'alpine-minirootfs-[0-9.]*-aarch64.tar.gz' | sort -uV | tail -1)
wget https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/$f
ls -l
EOF
    shot 14-template.png "шаблон Alpine в CT Templates"
    note "Create CT: ID 200, ct-test, Unprivileged вкл, шаблон Alpine, диск 2 GiB, 1 ядро, 256 MiB,"
    note "vmbr1, IPv4 10.10.10.20/24, шлюз 10.10.10.1, DNS 1.1.1.1."
    shot 15-ct-params.png "вкладка Confirm с параметрами CT"
    where "в консоли Proxmox"
    cmds <<'EOF'
pct start 200
pct enter 200
EOF
    where "в контейнере"
    cmds <<'EOF'
clear
ip a
ip route
ping -c 4 10.10.10.1
ping -c 4 77.88.8.8
ping -c 4 ya.ru
EOF
    shot 16-ct-net.png "10.10.10.20/24, default via 10.10.10.1, три ping без потерь"
    cmds <<'EOF'
clear
apk add --no-cache traceroute
traceroute 77.88.8.8
EOF
    shot 17-ct-traceroute.png "трассировка из контейнера (звёздочки допустимы)"
}

# ---------- Часть 4 ----------
part4() {
    step "Часть 4. Связь VM и контейнера"
    where "в консоли Proxmox → контейнер"
    cmds <<'EOF'
pct enter 200
clear
ping -c 4 10.10.10.10
EOF
    shot 18-ping-ct-vm.png "контейнер → Debian: 4 ответа, 0% packet loss"
    where "в Debian"
    cmds <<'EOF'
clear
ping -c 4 10.10.10.20
EOF
    shot 19-ping-vm-ct.png "Debian → контейнер: 4 ответа, 0% packet loss"
}

# ---------- Часть 5 ----------
part5() {
    step "Часть 5. SSH в Debian"
    where "в Debian (root)"
    cmds <<'EOF'
apt update
apt install -y openssh-server
systemctl enable --now ssh
clear
systemctl status ssh --no-pager
ss -tlnp | grep ':22'
EOF
    shot 20-ssh-status.png "active (running) и LISTEN на :22"
    where "на Mac"
    cmds <<'EOF'
clear
ssh zahar@10.10.10.10
EOF
    note "Ответь yes на fingerprint, введи пароль пользователя. Внутри:"
    cmds <<'EOF'
hostname; whoami; ip -br address
EOF
    shot 21-ssh-mac.png "терминал Mac с успешным входом в Debian"
}

# ---------- Запуск ----------
if [ $# -eq 0 ]; then set -- 0 1 2 3 4 5; fi
for s in "$@"; do
    case "$s" in
        0) part0 ;; 1) part1 ;; 2) part2 ;; 3) part3 ;; 4) part4 ;; 5) part5 ;;
        *) echo "Нет части $s (используй 0..5)" ;;
    esac
done
echo; echo "Готово. Собери отчёт: ./build-report.sh"
