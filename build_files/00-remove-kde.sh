#!/usr/bin/env bash
set -xeuo pipefail

# Remove KDE Plasma core desktop environment
dnf5 remove -y \
    plasma-desktop \
    plasma-workspace \
    plasma-workspace-wallpapers \
    kwin \
    kwin-common \
    kscreen \
    kscreenlocker \
    sddm \
    kde-settings \
    kde-settings-plasma \
    plasma-login-manager \
    plasma-welcome \
    plasma-welcome-fedora \
    || true

# Remove Plasma system components
dnf5 remove -y \
    plasma-breeze \
    plasma-breeze-common \
    plasma-breeze-qt5 \
    plasma-breeze-qt6 \
    plasma-nm \
    plasma-nm-openconnect \
    plasma-nm-openvpn \
    plasma-nm-vpnc \
    plasma-pa \
    plasma-systemmonitor \
    plasma-systemsettings \
    plasma-discover \
    plasma-discover-notifier \
    plasma-discover-rpm-ostree \
    plasma-discover-libs \
    plasma-drkonqi \
    plasma-milou \
    plasma-vault \
    plasma-disks \
    plasma-thunderbolt \
    plasma-browser-integration \
    kdeplasma-addons \
    plasma-activities \
    plasma-activities-stats \
    plasma5support \
    plasma-integration \
    plasma-integration-qt5 \
    plasma-lookandfeel-fedora \
    || true

# Remove KDE applications
dnf5 remove -y \
    konsole \
    dolphin \
    kate \
    kwrite \
    ark \
    spectacle \
    kfind \
    filelight \
    kinfocenter \
    kmenuedit \
    khelpcenter \
    kjournald \
    kdebugsettings \
    kde-connect \
    kdeconnectd \
    kde-connect-libs \
    kwalletmanager5 \
    pam-kwallet \
    polkit-kde \
    pinentry-qt \
    || true

# Remove Bazzite-specific KDE packages
dnf5 remove -y \
    steamdeck-kde-presets-desktop \
    steamdeck-kde-presets \
    krunner-bazaar \
    rom-properties-kf6 \
    kcm-fcitx5 \
    xwaylandvideobridge \
    || true

# Remove IBus input method framework (auto-starts and shows KDE-specific notifications)
# Users needing non-English input can reinstall ibus manually
dnf5 remove -y \
    ibus-xinit \
    ibus-setup \
    ibus-anthy \
    ibus-anthy-python \
    ibus-hangul \
    ibus-libpinyin \
    ibus-pinyin \
    ibus-m17n \
    ibus-typing-booster \
    ibus-chewing \
    ibus-table \
    ibus-table-chinese \
    ibus-table-chinese-cangjie \
    ibus-table-chinese-quick \
    ibus-qt \
    || true

# Remove KDE I/O and framework packages (not needed for COSMIC)
dnf5 remove -y \
    kio-admin \
    kio-extras \
    kio-gdrive \
    kdenetwork-filesharing \
    kf6-baloo-file \
    kdecoration \
    kdesu \
    kde-cli-tools \
    kde-gtk-config \
    kde-inotify-survey \
    kdegraphics-mobipocket \
    kdegraphics-thumbnailers \
    || true

# Remove leftover Plasma session files
rm -f /usr/share/wayland-sessions/plasma-steamos-wayland-oneshot.desktop
rm -f /usr/share/xsessions/plasma-steamos-oneshot.desktop

# Remove handheld-specific packages (not needed for desktop)
# hhd = Handheld Daemon (crashes on desktop, only for Steam Deck/ROG Ally/etc)
# steamdeck-dsp = Steam Deck audio DSP
dnf5 remove -y \
    hhd \
    hhd-ui \
    steamdeck-dsp \
    || true

# Skip autoremove - it may remove dependencies needed by COSMIC
# dnf5 autoremove -y || true
