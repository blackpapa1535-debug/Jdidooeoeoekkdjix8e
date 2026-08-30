FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# =========================================================
# ORIGINAL PACKAGES - NOTHING REMOVED
# =========================================================

RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    sudo \
    xterm \
    init \
    systemd \
    snapd \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    openssl

RUN apt install -y software-properties-common

# =========================================================
# FIREFOX REPOSITORY
# =========================================================

RUN add-apt-repository ppa:mozillateam/ppa -y

RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' \
    | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

# =========================================================
# FIREFOX - ORIGINAL
# =========================================================

RUN apt update -y && apt install -y firefox

# =========================================================
# ICON THEME
# =========================================================

RUN apt update -y && apt install -y xubuntu-icon-theme

RUN touch /root/.Xauthority

# =========================================================
# TELEGRAM DESKTOP - OFFICIAL LINUX x64
# =========================================================

RUN mkdir -p /opt/telegram && \
    cd /tmp && \
    wget -q \
        https://telegram.org/dl/desktop/linux \
        -O telegram.tar.xz && \
    tar -xJf telegram.tar.xz \
        -C /opt/telegram \
        --strip-components=1 && \
    rm -f telegram.tar.xz && \
    chmod +x /opt/telegram/Telegram

# =========================================================
# TELEGRAM DESKTOP LAUNCHER
# =========================================================

RUN mkdir -p /usr/share/applications && \
    printf '%s\n' \
    '[Desktop Entry]' \
    'Version=1.0' \
    'Type=Application' \
    'Name=Telegram Desktop' \
    'Comment=Official Telegram Desktop' \
    'Exec=/opt/telegram/Telegram -- %u' \
    'Icon=/opt/telegram/telegram.svg' \
    'Terminal=false' \
    'Categories=Network;InstantMessaging;Chat;' \
    'StartupWMClass=TelegramDesktop' \
    'MimeType=x-scheme-handler/tg;' \
    > /usr/share/applications/telegramdesktop.desktop

RUN if [ -f /opt/telegram/telegram.svg ]; then \
        ln -sf /opt/telegram/telegram.svg /usr/share/icons/telegram.svg; \
    fi

# =========================================================
# LOGIN
# =========================================================

ENV RDP_USER="desktop"
ENV RDP_PASS="Desktop2026"

# =========================================================
# VNC PASSWORD
# =========================================================

ENV VNC_PASS="Desktop2026"

# =========================================================
# WALLPAPER
# =========================================================

ENV WALLPAPER_URL="PASTE_RAW_GITHUB_URL_HERE"

# =========================================================
# TIGERVNC XSTARTUP TEMPLATE
# =========================================================

RUN mkdir -p /etc/vnc && \
    printf '%s\n' \
    '#!/bin/sh' \
    'unset SESSION_MANAGER' \
    'unset DBUS_SESSION_BUS_ADDRESS' \
    'unset XDG_RUNTIME_DIR' \
    'export LANG=C.UTF-8' \
    'export LANGUAGE=C.UTF-8' \
    'export LC_ALL=C.UTF-8' \
    'export LIBGL_ALWAYS_SOFTWARE=1' \
    'xrdb "$HOME/.Xresources" 2>/dev/null || true' \
    'exec startxfce4' \
    > /etc/vnc/xstartup && \
    chmod +x /etc/vnc/xstartup

# =========================================================
# START VNC SCRIPT
# =========================================================

RUN mkdir -p /usr/local/bin && \
    printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    '' \
    'RDP_USER="${RDP_USER:-desktop}"' \
    'RDP_PASS="${RDP_PASS:-Desktop2026}"' \
    'VNC_PASS="${VNC_PASS:-Desktop2026}"' \
    '' \
    'echo "========================================"' \
    'echo "       XFCE + TIGERVNC"' \
    'echo "========================================"' \
    '' \
    '# CREATE USER' \
    'if ! id "$RDP_USER" >/dev/null 2>&1; then' \
    '    useradd -m -s /bin/bash "$RDP_USER"' \
    'fi' \
    '' \
    'printf "%s:%s\n" "$RDP_USER" "$RDP_PASS" | chpasswd' \
    'usermod -aG sudo "$RDP_USER" 2>/dev/null || true' \
    '' \
    'USER_HOME="$(getent passwd "$RDP_USER" | cut -d: -f6)"' \
    '' \
    '# DIRECTORIES' \
    'mkdir -p "$USER_HOME/Pictures"' \
    'mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"' \
    'mkdir -p "$USER_HOME/.config/autostart"' \
    'mkdir -p "$USER_HOME/.vnc"' \
    '' \
    '# VNC PASSWORD' \
    'printf "%s\n" "$VNC_PASS" | su - "$RDP_USER" -c "vncpasswd -f > ~/.vnc/passwd"' \
    'chmod 600 "$USER_HOME/.vnc/passwd"' \
    'chown -R "$RDP_USER:$RDP_USER" "$USER_HOME/.vnc"' \
    '' \
    '# VNC STARTUP FILE' \
    'cp /etc/vnc/xstartup "$USER_HOME/.vnc/xstartup"' \
    'chmod +x "$USER_HOME/.vnc/xstartup"' \
    'chown "$RDP_USER:$RDP_USER" "$USER_HOME/.vnc/xstartup"' \
    '' \
    '# XFCE PERFORMANCE' \
    'echo "Configuring XFCE performance..."' \
    '' \
    'su - "$RDP_USER" -c "xfconf-query -c xfwm4 -p /general/use_compositing -s false" 2>/dev/null || true' \
    'su - "$RDP_USER" -c "xfconf-query -c xfwm4 -p /general/box_move -s false" 2>/dev/null || true' \
    'su - "$RDP_USER" -c "xfconf-query -c xfwm4 -p /general/box_resize -s false" 2>/dev/null || true' \
    '' \
    '# DISABLE XFCE NOTIFICATION POPUPS' \
    'su - "$RDP_USER" -c "xfconf-query -c xfce4-notifyd -p /do-not-disturb -s true" 2>/dev/null || true' \
    '' \
    '# WALLPAPER' \
    'echo "Downloading wallpaper..."' \
    '' \
    'if [ -n "$WALLPAPER_URL" ] && [ "$WALLPAPER_URL" != "PASTE_RAW_GITHUB_URL_HERE" ]; then' \
    '    curl -L --fail --silent --show-error "$WALLPAPER_URL" -o "$USER_HOME/Pictures/kali-wallpaper.jpg" || true' \
    'fi' \
    '' \
    'if [ -f "$USER_HOME/Pictures/kali-wallpaper.jpg" ]; then' \
    '    chown "$RDP_USER:$RDP_USER" "$USER_HOME/Pictures/kali-wallpaper.jpg"' \
    'fi' \
    '' \
    '# XFCE PANEL' \
    'cat > "$USER_HOME/.config/autostart/xfce-panel.desktop" <<EOF' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=XFCE Panel' \
    'Comment=XFCE Desktop Panel' \
    'Exec=xfce4-panel' \
    'OnlyShowIn=XFCE;' \
    'X-GNOME-Autostart-enabled=true' \
    'NoDisplay=false' \
    'Terminal=false' \
    'EOF' \
    '' \
    'chown -R "$RDP_USER:$RDP_USER" "$USER_HOME/.config"' \
    '' \
    '# WALLPAPER CONFIGURATION' \
    'if [ -f "$USER_HOME/Pictures/kali-wallpaper.jpg" ]; then' \
    '    su - "$RDP_USER" -c "xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path -s \"$USER_HOME/Pictures/kali-wallpaper.jpg\"" 2>/dev/null || true' \
    '    su - "$RDP_USER" -c "xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-style -s 5" 2>/dev/null || true' \
    'fi' \
    '' \
    '# REMOVE OLD VNC SESSION' \
    'su - "$RDP_USER" -c "vncserver -kill :1" 2>/dev/null || true' \
    'rm -f "$USER_HOME/.vnc/"*.pid 2>/dev/null || true' \
    '' \
    '# START TIGERVNC' \
    'echo "Starting TigerVNC..."' \
    '' \
    'su - "$RDP_USER" -c "vncserver :1 -geometry 1920x1080 -depth 16 -localhost no -SecurityTypes VncAuth -xstartup $USER_HOME/.vnc/xstartup"' \
    '' \
    'echo "========================================"' \
    'echo "       TIGERVNC SERVER READY"' \
    'echo "========================================"' \
    'echo "USERNAME : $RDP_USER"' \
    'echo "PASSWORD : configured"' \
    'echo "DISPLAY  : :1"' \
    'echo "PORT     : 5901"' \
    'echo "COLOR    : 16-bit"' \
    'echo "COMPOSITOR: OFF"' \
    'echo "FIREFOX  : installed"' \
    'echo "TELEGRAM : OFFICIAL LINUX x64"' \
    'echo "PANEL    : enabled"' \
    'echo "WALLPAPER: configured"' \
    'echo "NOTIFICATIONS: OFF"' \
    'echo "========================================"' \
    '' \
    'while true; do' \
    '    sleep 3600' \
    'done' \
    > /usr/local/bin/start-vnc.sh && \
    chmod +x /usr/local/bin/start-vnc.sh

# =========================================================
# VNC PORT
# =========================================================

EXPOSE 5901

# =========================================================
# START
# =========================================================

CMD ["/usr/local/bin/start-vnc.sh"]