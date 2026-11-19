# Лабораторная 5 «Proxmox VE» на Mac (M3 Pro, Parallels Desktop): порядок действий и скриншоты

## 0. Как это устроено

```
virt-lab5/
├── INSTRUCTION.md      этот файл
├── lab.sh              полуавтомат: печатает команды по шагам, говорит «СКРИН ...»
├── report.typ          отчёт (Typst)
├── build-report.sh     сборка report.pdf
├── configs/vmbr1.conf  блок моста vmbr1 для /etc/network/interfaces
├── Lab-5.pdf           задание
└── screens/            СЮДА кладёшь скрины
```

**Почему не «как в задании».** Официальный Proxmox VE собран под x86, а у тебя Apple M3 Pro
(ARM). Поэтому ставим **Proxmox VE для arm64** (официальная сборка с версии 9.2), гостевую
**Debian 13 arm64** и шаблон **Alpine для aarch64**. Всё остальное (мосты, NAT, адреса,
команды) ровно как в задании. Гипервизор на Mac: **Parallels Desktop** (нужна версия 20 или
новее: в ней есть вложенная виртуализация на M3 + macOS 15). В отчёте Parallels не упоминается.

Порядок работы:
1. Шаги делаешь по этой инструкции или через шпаргалку `./lab.sh` (печатает блоки команд и на
   каждом скриншоте ждёт Enter). Сам он ничего не выполняет.
   ```bash
   cd ~/IdeaProjects/virt-lab5
   ./lab.sh        # все части
   ./lab.sh 1      # только часть 1 (0 = подготовка Parallels, 1..5 = части задания)
   ```
2. Где выполнять команду, написано над блоком: **на Mac**, **в консоли Proxmox**, **в Debian**,
   **в контейнере**.
3. После каждой отметки 📸 сохраняешь скрин в `screens/` **ровно под указанным именем**.
4. `./build-report.sh` собирает `report.pdf`; нет скрина — на его месте пунктирная рамка.

Схема адресов (как в задании):

| Узел | Где | Адрес |
|---|---|---|
| Proxmox, адаптер 1 → vmbr0 | Shared Network (NAT) | выдаёт Parallels, вида 10.211.55.x |
| Proxmox, адаптер 2 → vmbr1 | Host-Only | 10.10.10.1/24 |
| Mac, интерфейс Host-Only | Host-Only | 10.10.10.254/24, без шлюза |
| Debian VM | vmbr1 | 10.10.10.10/24, шлюз 10.10.10.1 |
| Alpine CT 200 | vmbr1 | 10.10.10.20/24, шлюз 10.10.10.1 |

DNS везде 1.1.1.1.

---

## 1. Скриншоты

- Окно: `⌘ Shift 4`, затем `Пробел`, клик по окну. Переименуй и положи в `screens/`.
  Можно сразу сохранять в папку:
  ```bash
  defaults write com.apple.screencapture location ~/IdeaProjects/virt-lab5/screens && killall SystemUIServer
  ```
  (вернуть: `defaults write com.apple.screencapture location ~/Desktop && killall SystemUIServer`)
- Если снимал подряд как попало, просто положи файлы по порядку, я переименую.
- В кадре должны быть **и команда, и вывод**; перед командой `clear`.
- В консоли Proxmox удобнее работать по SSH с Mac (`ssh root@10.10.10.1`), тогда скрины делаются
  из обычного терминала. Консоль Parallels тоже подходит.

---

## Часть 0. Подготовка (Parallels, ISO)

1. Parallels Desktop 20+ установлен (`brew install --cask parallels`, есть пробный период).
2. Скачай ISO:
   - Proxmox VE 9.2 **arm64**: https://www.proxmox.com/en/downloads → Proxmox Virtual
     Environment → ISO Installer (**arm64**);
   - Debian 13 **arm64** netinst: https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/
     (файл `debian-13.*-arm64-netinst.iso`).
3. Parallels → «Создать» → «Установить Windows, Linux или macOS из файла образа» → выбери ISO
   Proxmox. Если тип ОС не определился, укажи **Other Linux**. Имя `proxmox`. Поставь галочку
   **«Настроить параметры перед установкой»**.
4. В настройках VM (Конфигурация):
   - **Оборудование → ЦП и память**: 4 ЦП, 8192 МБ. «Дополнительно» → включи
     **«Включить вложенную виртуализацию»** (Nested virtualization).
   - **Оборудование → Жёсткий диск**: 64 ГБ.
   - **Оборудование → Сеть 1**: «Общая сеть» (Shared Network).
   - **Оборудование → «+» → Сетевой адаптер → Сеть 2**: «Только хост» (Host-Only).
   - Отключи общие папки и прочую интеграцию (Параметры → Общий доступ): Proxmox их не использует.

📸 `01-adapters.png`: окно настроек VM с двумя сетевыми адаптерами (Общая сеть и Только хост),
можно двумя скринами склеить в один или снять второй адаптер.
📸 `02-system.png`: ЦП и память с включённой вложенной виртуализацией.

5. **На Mac** назначь интерфейсу Host-Only адрес 10.10.10.254/24 без шлюза. Найди интерфейс
   Parallels Host-Only (обычно `vnic1`, у него адрес 10.37.129.2):
   ```bash
   ifconfig | grep -B4 '10.37.129'
   sudo ifconfig vnic1 alias 10.10.10.254 netmask 255.255.255.0
   ifconfig vnic1
   ```
   Адрес сбрасывается после перезапуска Parallels или Mac: тогда выполни `ifconfig ... alias`
   ещё раз. Снимешь вместе с проверкой в части 1.

---

## Часть 1. Установка Proxmox VE и сеть

### 1.1. Установка
1. Запусти VM, выбери «Install Proxmox VE (Graphical)».
2. Диск: весь виртуальный диск, ext4 (по умолчанию). Страна/часовой пояс: Russia / Europe/Moscow.
   Пароль root и почта: любые (пароль в отчёт не попадает).
3. **Management Network**: интерфейс **первый** (Общая сеть, обычно `enp0s5`). Адрес, шлюз и DNS
   установщик подставит из DHCP Parallels (вида 10.211.55.x, шлюз 10.211.55.1). **Запиши их.**
   Hostname: `pve.lab.local`.

📸 `03-installer-net.png`: экран Management Network Configuration перед продолжением.

4. После установки и перезагрузки войди в консоли как `root`.
   **В консоли Proxmox:**
   ```bash
   clear
   ip -br link
   ip route get 77.88.8.8
   ```
   Запомни имя **второго** интерфейса (обычно `enp0s6`). Если у тебя другое, замени `enp0s6`
   во всех командах ниже и в `configs/vmbr1.conf`.

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

**На Mac:**
```bash
clear
ifconfig vnic1 | grep inet
ping -c 4 10.10.10.1
```
📸 `07-host-ping.png`: на Mac адрес 10.10.10.254 и ответы от 10.10.10.1.

Открой в браузере на Mac **https://10.10.10.1:8006** (предупреждение о сертификате:
«Дополнительно» → «Перейти»), вход `root`, Realm «Linux PAM». Окно про подписку закрой.
📸 `08-webui.png`: веб-интерфейс, слева узел `pve`, в адресной строке 10.10.10.1:8006.

---

## Часть 2. Виртуальная машина Debian

### 2.1. ISO
Веб-интерфейс: `Datacenter → pve → local (pve) → ISO Images → Upload` → выбери
`debian-13.*-arm64-netinst.iso`.
📸 `09-iso.png`: ISO в списке ISO Images.

### 2.2. Create VM
Кнопка **Create VM** справа вверху:

| Вкладка | Значение |
|---|---|
| General | VM ID 100, Name `SilaevZahar` |
| OS | ISO image: debian-13 arm64, Type Linux |
| System | BIOS **OVMF (UEFI)**, EFI Storage `local-lvm` (на arm64 нужен UEFI; если поле уже стоит, оставь) |
| Disks | Bus VirtIO Block / SCSI, 32 GiB |
| CPU | Sockets 1, Cores 1 |
| Memory | 2048 MiB |
| Network | Bridge **vmbr1**, Model **VirtIO (paravirtualized)** |

На вкладке **Confirm** 📸 `10-vm-params.png` (таблица параметров), затем Finish.

Выбери VM `100 (SilaevZahar)` → Hardware, проверь, что CD/DVD с ISO подключён. **Start** → **Console**.

### 2.3. Установка Debian
1. Install (текстовый). Язык любой.
2. Сеть: когда DHCP не найдёт адрес, выбери **Configure network manually**:
   IP `10.10.10.10`, маска `255.255.255.0`, шлюз `10.10.10.1`, DNS `1.1.1.1`. Hostname `debian`.
   📸 `11-debian-ip.png`: экран ввода IP-адреса (или шлюза).
3. Пароль root, обычный пользователь (например `zahar`) — запомни, он нужен для SSH.
4. Разметка: весь диск, всё в одном разделе. Зеркало: Russia → deb.debian.org.
   Программы: оставь только «standard system utilities». Окружение рабочего стола не нужно,
   «SSH server» тоже сними: его ставим вручную в части 5.
5. После установки выключи VM, в Hardware у CD/DVD выбери **Do not use any media**, запусти снова.

**Если VM не стартует** с ошибкой про KVM, или установщик зависает: VM → Options →
**KVM hardware virtualization: No**. Работать будет в эмуляции (медленнее), это нормально.

**В Debian** (войди как root):
```bash
clear
ip -br address
ip route
ping -c 4 10.10.10.1
ping -c 4 77.88.8.8
ping -c 4 ya.ru
```
📸 `12-vm-net.png`: адрес 10.10.10.10/24, маршрут по умолчанию через 10.10.10.1, три ping без потерь.
```bash
clear
apt install -y traceroute
traceroute 77.88.8.8
```
📸 `13-vm-traceroute.png`: первый узел 10.10.10.1, дальше шлюз Parallels и интернет.

---

## Часть 3. Контейнер Alpine

### 3.1. Шаблон
Веб-интерфейс: `local (pve) → CT Templates → Templates` → найди `alpine` → Download.
📸 `14-template.png`: шаблон Alpine в списке CT Templates.

**Если в списке нет Alpine для arm64**, скачай его в консоли Proxmox сам:
```bash
cd /var/lib/vz/template/cache
f=$(curl -s https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/ | grep -o 'alpine-minirootfs-[0-9.]*-aarch64.tar.gz' | sort -uV | tail -1)
wget https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/$f
ls -l
```
После этого он появится в CT Templates.

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

На **Confirm** 📸 `15-ct-params.png`, затем Finish. Пароль в отчёт не попадает.

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
📸 `16-ct-net.png`: адрес 10.10.10.20/24, маршрут через 10.10.10.1, три ping без потерь.
```bash
clear
apk add --no-cache traceroute
traceroute 77.88.8.8
```
📸 `17-ct-traceroute.png`. Звёздочки `*` у отдельных узлов это нормально.
Выход из контейнера: `exit`.

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

**На Mac** (пользователь, которого создал при установке Debian):
```bash
clear
ssh zahar@10.10.10.10
```
На вопрос про fingerprint ответь `yes`, введи пароль. Внутри:
```bash
hostname; whoami; ip -br address
```
📸 `21-ssh-mac.png`: терминал Mac с успешным входом и выводом команд.

---

## Сборка отчёта
```bash
cd ~/IdeaProjects/virt-lab5
ls screens
./build-report.sh
open report.pdf
```
Перед сборкой открой `report.typ` и проверь раздел «Среда выполнения»: версии Proxmox, Debian и
Alpine поставь фактические (их видно на скринах: `pveversion`, `cat /etc/debian_version`,
`cat /etc/alpine-release`).

## Уборка
- Proxmox: удалить CT 200 и VM 100 (`pct destroy 200`, `qm destroy 100`) или всю VM в Parallels.
- Mac: `sudo ifconfig vnic1 -alias 10.10.10.254`.

## Если что-то не так

| Симптом | Что сделать |
|---|---|
| нет пункта «вложенная виртуализация» | нужен Parallels Desktop 20+, macOS 15+, чип M3 и новее |
| Mac не пингует 10.10.10.1 | проверь alias на `vnic1` и что Сеть 2 в режиме «Только хост»; `ip -br a` в Proxmox: vmbr1 UP |
| Mac пингует 10.10.10.1, но не 10.10.10.10 | обходной путь через NAT-адрес Proxmox: `sudo route -n add -net 10.10.10.0/24 <адрес vmbr0>` |
| VM не стартует, ошибка KVM | Options → KVM hardware virtualization: No |
| консоль VM чёрная | Hardware → Display → Serial terminal 0, затем Console → xterm.js |
| гость не пингует 77.88.8.8 | `sysctl net.ipv4.ip_forward` = 1? правило MASQUERADE есть? шлюз у гостя 10.10.10.1? |
| ping ya.ru не идёт, 77.88.8.8 идёт | DNS: в гостях 1.1.1.1 (`cat /etc/resolv.conf`) |
| после `ifreload -a` пропал доступ | ошибка в `/etc/network/interfaces`: верни `cp /etc/network/interfaces.bak /etc/network/interfaces` и `ifreload -a` |
| `ssh` отказывает root | так и должно быть, входи обычным пользователем |
