# Лабораторная 5 «Proxmox VE» на Mac (M3 Pro, VirtualBox): порядок действий и скриншоты

## 0. Как это устроено

```
virt-lab5/
├── INSTRUCTION.md            этот файл (VirtualBox)
├── INSTRUCTION-parallels.md  тот же порядок через Parallels Desktop
├── lab.sh                    полуавтомат: печатает команды по шагам, говорит «СКРИН ...»
├── report.typ                отчёт (Typst)
├── build-report.sh           сборка report.pdf
├── configs/vmbr1.conf        блок моста vmbr1 для /etc/network/interfaces
├── Lab-5.pdf                 задание
└── screens/                  СЮДА кладёшь скрины
```

**Что отличается от задания и почему.**
- Mac на M3 Pro это ARM, а официальный Proxmox VE собран под x86. Поэтому ставим **Proxmox VE
  9.2 для arm64**, гостевую **Debian 13 arm64** и **Alpine для aarch64**. VirtualBox на Mac с
  Apple Silicon запускает только ARM-гостей, так что иначе нельзя.
- **Вложенной виртуализации для ARM в VirtualBox нет.** Proxmox поставится и будет работать,
  контейнер LXC тоже (ему вложенная виртуализация не нужна). А виртуальную машину Debian внутри
  Proxmox нужно запускать с **выключенным KVM** (программная эмуляция): она работает, но
  медленнее, установка Debian займёт 30–60 минут. Это нормально.
- Сеть NAT в VirtualBox с Mac не видна, поэтому весь доступ с Mac (веб-интерфейс, ping, SSH)
  идёт через сеть **Host-only**, как и требует задание.

Порядок работы:
1. Шаги делаешь по этой инструкции или через шпаргалку `./lab.sh` (печатает блоки команд и на
   каждом скриншоте ждёт Enter). Сам он ничего не выполняет.
   ```bash
   cd ~/IdeaProjects/virt-lab5
   ./lab.sh        # все части
   ./lab.sh 1      # только часть 1 (0 = подготовка VirtualBox, 1..5 = части задания)
   ```
2. Где выполнять команду, написано над блоком: **на Mac**, **в консоли Proxmox**, **в Debian**,
   **в контейнере**.
3. После каждой отметки 📸 сохраняешь скрин в `screens/` **ровно под указанным именем**
   (или как попало по порядку, я переименую).
4. `./build-report.sh` собирает `report.pdf`; нет скрина — на его месте пунктирная рамка.

Схема адресов (как в задании):

| Узел | Где | Адрес |
|---|---|---|
| Proxmox, адаптер 1 → vmbr0 | NAT VirtualBox | 10.0.2.15/24, шлюз 10.0.2.2, DNS 10.0.2.3 |
| Proxmox, адаптер 2 → vmbr1 | Host-only | 10.10.10.1/24 |
| Mac, интерфейс Host-only | Host-only | 10.10.10.254/24, без шлюза |
| Debian VM | vmbr1 | 10.10.10.10/24, шлюз 10.10.10.1 |
| Alpine CT 200 | vmbr1 | 10.10.10.20/24, шлюз 10.10.10.1 |

DNS гостей 1.1.1.1.

---

## 1. Скриншоты

- Окно: `⌘ Shift 4`, затем `Пробел`, клик по окну. Можно сразу сохранять в папку:
  ```bash
  defaults write com.apple.screencapture location ~/IdeaProjects/virt-lab5/screens && killall SystemUIServer
  ```
  (вернуть: `defaults write com.apple.screencapture location ~/Desktop && killall SystemUIServer`)
- В кадре **и команда, и вывод**; перед командой `clear`.
- В консоли Proxmox удобнее работать по SSH с Mac (`ssh root@10.10.10.1`, после части 1):
  копировать команды и снимать скрины из обычного терминала проще, чем из окна VirtualBox.

---

## Часть 0. Подготовка (VirtualBox, ISO)

1. VirtualBox 7.2 или новее для Apple Silicon:
   ```bash
   brew install --cask virtualbox
   ```
   При первом запуске разреши системное расширение: «Системные настройки» → «Конфиденциальность
   и безопасность» → «Разрешить», затем перезапусти VirtualBox.
2. Скачай ISO:
   - Proxmox VE 9.2 **arm64**: https://www.proxmox.com/en/downloads → Proxmox Virtual
     Environment → ISO Installer (**arm64**);
   - Debian 13 **arm64** netinst: https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/
     (файл `debian-13.*-arm64-netinst.iso`).
3. **Сеть Host-only.** VirtualBox → «Файл» → «Инструменты» → «Менеджер сетей» → вкладка
   «Сети хоста» (Host-only Networks) → «Создать»:
   - Имя: `HostNetwork` (или как предложит);
   - Маска: `255.255.255.0`;
   - Нижняя граница: `10.10.10.200`, верхняя граница: `10.10.10.250`.

   Так сеть Host-only оказывается в той же подсети 10.10.10.0/24, а её служебные адреса
   (.200–.250) не пересекаются с нашими .1, .10, .20 и .254.
4. **Создай VM**: «Создать»:
   - Имя `proxmox`, ISO-образ Proxmox arm64, тип **Linux**, версия **Debian (ARM 64-bit)**;
   - галочку **«Пропустить автоматическую установку»** поставь;
   - Память **8192 МБ**, процессоры **4**;
   - Диск **64 ГБ** (VDI, динамический).
5. **Настройки VM → Сеть**:
   - **Адаптер 1**: включён, тип подключения **NAT**;
   - **Адаптер 2**: включён, тип подключения **Сеть хоста** (Host-only Network), имя
     `HostNetwork`. «Дополнительно» → **Неразборчивый режим: Разрешить всё** (Promiscuous Mode:
     Allow All). Без этого Mac не увидит гостей за мостом vmbr1.
6. **Настройки VM → Система → Процессор**: 4 процессора. Пункт «Включить вложенную
   VT-x/AMD-V» на Apple Silicon недоступен, это ожидаемо.

📸 `01-adapters.png`: вкладка «Сеть» (можно два скрина склеить: Адаптер 1 NAT и Адаптер 2 Сеть
хоста с неразборчивым режимом).
📸 `02-system.png`: вкладка «Система» (память и процессоры).

---

## Часть 1. Установка Proxmox VE и сеть

### 1.1. Установка
1. Запусти VM, выбери «Install Proxmox VE (Graphical)». Если графика не стартует, выбери
   «Install Proxmox VE (Terminal UI)».
2. Диск: весь, ext4. Страна/часовой пояс: Russia / Europe/Moscow. Пароль root и почта любые
   (пароль в отчёт не попадает).
3. **Management Network**: интерфейс **первый** (NAT). Установщик подставит адрес 10.0.2.15/24,
   шлюз 10.0.2.2, DNS 10.0.2.3. **Запиши их.** Hostname: `pve.lab.local`.

📸 `03-installer-net.png`: экран Management Network Configuration.

4. После установки и перезагрузки войди в консоли VirtualBox как `root`.
   Если VM снова грузится с ISO: выключи её, «Настройки» → «Носители» → убери ISO.
   **В консоли Proxmox:**
   ```bash
   clear
   ip -br link
   ip route get 77.88.8.8
   ```
   Запомни имя **второго** интерфейса (это порт без адреса, не тот, что в vmbr0). В примерах
   ниже он назван `enp0s6`; если у тебя другое имя (например `enp0s9` или `ens4`), подставляй
   своё везде и **напиши мне**, я поправлю `configs/vmbr1.conf` для отчёта.

📸 `04-ip-link.png`: список интерфейсов и маршрут к 77.88.8.8 через vmbr0.

### 1.2. Мост vmbr1
**В консоли Proxmox:**
```bash
cp /etc/network/interfaces /etc/network/interfaces.bak
nano /etc/network/interfaces
```
Допиши в конец (если блок `iface enp0s6 inet manual` уже есть, второй не добавляй):
```
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
```
Сохранить: `Ctrl+O`, `Enter`, `Ctrl+X`. Затем:
```bash
clear
cat /etc/network/interfaces
```
📸 `05-interfaces.png`: файл с блоками vmbr0 и vmbr1.

### 1.3. Пересылка и применение
**В консоли Proxmox:**
```bash
printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/99-pve-lab.conf
sysctl --system
ifreload -a
clear
ip -br address
ip route
sysctl net.ipv4.ip_forward
iptables -t nat -S POSTROUTING
```
📸 `06-forward-nat.png`: vmbr1 с 10.10.10.1/24 (UP), `net.ipv4.ip_forward = 1`, правило
`-A POSTROUTING -s 10.10.10.0/24 -o vmbr0 -j MASQUERADE`.

### 1.4. Адрес 10.10.10.254 на Mac
Интерфейс сети Host-only на Mac появляется, пока VM запущена. **На Mac:**
```bash
ifconfig | grep -B6 'inet 10.10.10'
```
Найди имя интерфейса с адресом 10.10.10.200 (обычно `bridge100`/`bridge101`) и добавь адрес
из задания (подставь своё имя интерфейса):
```bash
sudo ifconfig bridge100 alias 10.10.10.254 netmask 255.255.255.0
clear
ifconfig bridge100 | grep inet
ping -c 4 10.10.10.1
```
📸 `07-host-ping.png`: на Mac адрес 10.10.10.254 и ответы от 10.10.10.1.

Адрес-псевдоним сбрасывается после перезапуска VM или Mac: тогда повтори `sudo ifconfig ... alias`.

В браузере на Mac открой **https://10.10.10.1:8006** (предупреждение о сертификате:
«Дополнительно» → «Перейти»), вход `root`, Realm «Linux PAM». Окно про подписку закрой.
📸 `08-webui.png`: веб-интерфейс, слева узел `pve`, в адресной строке 10.10.10.1:8006.

---

## Часть 2. Виртуальная машина Debian

### 2.1. ISO
Веб-интерфейс: `Datacenter → pve → local (pve) → ISO Images → Upload` → выбери
`debian-13.*-arm64-netinst.iso`.
📸 `09-iso.png`: ISO в списке ISO Images.

### 2.2. Create VM
Кнопка **Create VM** справа вверху (поставь галочку **Advanced** внизу окна):

| Вкладка | Значение |
|---|---|
| General | VM ID 100, Name `SilaevZahar` |
| OS | ISO image: debian-13 arm64, Type Linux |
| System | BIOS **OVMF (UEFI)**, EFI Storage `local-lvm` (на arm64 нужен UEFI; если уже стоит, оставь) |
| Disks | 32 GiB |
| CPU | Sockets 1, Cores 1 |
| Memory | 2048 MiB |
| Network | Bridge **vmbr1**, Model **VirtIO (paravirtualized)** |

На вкладке **Confirm** 📸 `10-vm-params.png`, затем Finish.

**Обязательно до первого запуска:** VM 100 → **Options → KVM hardware virtualization → No**.
Без вложенной виртуализации VM с включённым KVM не запустится («KVM virtualisation configured,
but not available»).

VM 100 → Hardware: проверь, что CD/DVD с ISO подключён. **Start** → **Console**.
Если консоль чёрная: VM выключить, Hardware → Display → **Serial terminal 0**, снова Start,
Console → **xterm.js**.

### 2.3. Установка Debian
Всё работает в эмуляции, поэтому медленно: установщик может думать по несколько минут на шаге.
1. Install (текстовый). Язык любой.
2. Сеть: когда DHCP не найдёт адрес, **Configure network manually**:
   IP `10.10.10.10`, маска `255.255.255.0`, шлюз `10.10.10.1`, DNS `1.1.1.1`. Hostname `debian`.
   📸 `11-debian-ip.png`: экран ввода IP-адреса (или шлюза).
3. Пароль root, обычный пользователь `zahar` (если другой, скажи мне, поправлю в отчёте).
4. Разметка: весь диск, всё в одном разделе. Зеркало: Russia → deb.debian.org.
   Программы: оставь только «standard system utilities» (без рабочего стола и SSH-сервера).
5. После установки выключи VM, Hardware → CD/DVD → **Do not use any media**, запусти снова.

**В Debian** (root):
```bash
clear
ip -br address
ip route
ping -c 4 10.10.10.1
ping -c 4 77.88.8.8
ping -c 4 ya.ru
```
📸 `12-vm-net.png`: 10.10.10.10/24, маршрут по умолчанию через 10.10.10.1, три ping без потерь.
```bash
clear
apt install -y traceroute
traceroute 77.88.8.8
```
📸 `13-vm-traceroute.png`: первый узел 10.10.10.1, затем 10.0.2.2 и дальше интернет.

---

## Часть 3. Контейнер Alpine

### 3.1. Шаблон
Веб-интерфейс: `local (pve) → CT Templates → Templates` → найди `alpine` → Download.

**Если в списке нет Alpine для arm64**, скачай его сам. **В консоли Proxmox:**
```bash
cd /var/lib/vz/template/cache
f=$(curl -s https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/ | grep -o 'alpine-minirootfs-[0-9.]*-aarch64.tar.gz' | sort -uV | tail -1)
wget https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/$f
ls -l
```
📸 `14-template.png`: шаблон Alpine в CT Templates.

### 3.2. Create CT
Кнопка **Create CT**:

| Вкладка | Значение |
|---|---|
| General | CT ID **200**, Hostname `ct-test`, Unprivileged container **вкл**, пароль root |
| Template | шаблон Alpine |
| Disks | 2 GiB |
| CPU | Cores 1 |
| Memory | 256 MiB, Swap 256 MiB |
| Network | Bridge **vmbr1**, IPv4 Static `10.10.10.20/24`, Gateway `10.10.10.1` |
| DNS | DNS servers `1.1.1.1` |

На **Confirm** 📸 `15-ct-params.png`, затем Finish. Контейнер работает с нормальной скоростью:
ему KVM не нужен.

### 3.3. Запуск и проверка
**В консоли Proxmox:**
```bash
pct start 200
pct enter 200
```
**В контейнере:**
```bash
clear
ip a
ip route
ping -c 4 10.10.10.1
ping -c 4 77.88.8.8
ping -c 4 ya.ru
```
📸 `16-ct-net.png`: 10.10.10.20/24, маршрут через 10.10.10.1, три ping без потерь.
```bash
clear
apk add --no-cache traceroute
traceroute 77.88.8.8
```
📸 `17-ct-traceroute.png`. Звёздочки `*` у части узлов это нормально (NAT VirtualBox не всегда
отвечает на трассировку). Выход из контейнера: `exit`.

---

## Часть 4. Связь VM ↔ контейнер
Debian и CT 200 должны быть запущены.

**В консоли Proxmox:**
```bash
pct enter 200
clear
ping -c 4 10.10.10.10
```
📸 `18-ping-ct-vm.png`: 4 ответа от 10.10.10.10, 0% packet loss.

**В Debian:**
```bash
clear
ping -c 4 10.10.10.20
```
📸 `19-ping-vm-ct.png`: 4 ответа от 10.10.10.20, 0% packet loss.

---

## Часть 5. SSH в Debian
**В Debian (root):**
```bash
apt update
apt install -y openssh-server
systemctl enable --now ssh
clear
systemctl status ssh --no-pager
ss -tlnp | grep ':22'
```
📸 `20-ssh-status.png`: `active (running)` и `LISTEN ... :22`.

**На Mac:**
```bash
clear
ssh zahar@10.10.10.10
```
`yes` на fingerprint, пароль пользователя. Внутри:
```bash
hostname; whoami; ip -br address
```
📸 `21-ssh-mac.png`: терминал Mac с успешным входом.

Если Mac не достаёт до 10.10.10.10 напрямую (см. таблицу ниже), подключись через Proxmox как
через промежуточный узел: `ssh -J root@10.10.10.1 zahar@10.10.10.10`.

---

## Сборка отчёта
```bash
cd ~/IdeaProjects/virt-lab5
ls screens
./build-report.sh
open report.pdf
```
Перед сдачей проверь версии в разделе «Среда выполнения» `report.typ` (на скринах или командами
`pveversion`, `cat /etc/debian_version`, `cat /etc/alpine-release`).

## Уборка
- Proxmox: `pct destroy 200`, `qm destroy 100` или удалить всю VM `proxmox` в VirtualBox.
- Mac: `sudo ifconfig bridge100 -alias 10.10.10.254`.

## Если что-то не так

| Симптом | Что сделать |
|---|---|
| VirtualBox не запускает VM, ошибка про драйвер | разреши расширение Oracle в «Конфиденциальность и безопасность», перезапусти Mac |
| «x86_64 VMs are not supported» | выбран не тот ISO: нужен Proxmox **arm64**, тип VM Debian (ARM 64-bit) |
| установщик Proxmox показывает чёрный экран | при загрузке выбери «Terminal UI» |
| VM 100: «KVM virtualisation configured, but not available» | Options → KVM hardware virtualization: No |
| консоль VM 100 чёрная | Hardware → Display → Serial terminal 0, Console → xterm.js |
| установка Debian очень долгая | это эмуляция без KVM; можно временно дать VM 2 ядра, по заданию верни 1 |
| Mac не пингует 10.10.10.1 | VM запущена? адрес-псевдоним на нужном bridge? Адаптер 2 «Сеть хоста»? в Proxmox `ip -br a`: vmbr1 UP |
| Mac пингует 10.10.10.1, но не 10.10.10.10 | Адаптер 2 → Неразборчивый режим: Разрешить всё; иначе SSH через `-J root@10.10.10.1` |
| гость не пингует 77.88.8.8 | `sysctl net.ipv4.ip_forward` = 1? правило MASQUERADE? шлюз гостя 10.10.10.1? |
| ping ya.ru не идёт, 77.88.8.8 идёт | DNS гостя 1.1.1.1 (`cat /etc/resolv.conf`) |
| после `ifreload -a` пропала сеть | `cp /etc/network/interfaces.bak /etc/network/interfaces` и `ifreload -a` |
| `ssh` не пускает root | так и должно быть, входи обычным пользователем |
