FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install base utilities, XFCE desktop, VNC/noVNC, extraction tools (rar/7z), media & document viewers
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify \
    sudo xterm init systemd snapd vim net-tools curl wget git tzdata \
    unrar p7zip-full vlc evince xz-utils libvlc-dev dbus-x11 x11-utils \
    x11-xserver-utils x11-apps software-properties-common

# 2. Add Mozilla PPA and Install Firefox
RUN add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox && \
    apt update -y && apt install -y firefox xubuntu-icon-theme

# 3. Install Official Latest Telegram Desktop (Direct Binary)
RUN wget -O telegram.tar.xz https://telegram.org/dl/desktop/linux && \
    tar -xf telegram.tar.xz -C /opt/ && \
    ln -s /opt/Telegram/Telegram /usr/local/bin/telegram-desktop && \
    rm telegram.tar.xz

# Create Telegram Desktop Shortcut for XFCE Menu
RUN echo '[Desktop Entry]\nVersion=1.0\nName=Telegram Desktop\nComment=Official desktop app for Telegram\nExec=/opt/Telegram/Telegram -- %u\nIcon=telegram\nTerminal=false\nType=Application\nCategories=Network;InstantMessaging;' > /usr/share/applications/telegramdesktop.desktop

# 4. Install Google Chrome
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt install -y ./google-chrome-stable_current_amd64.deb && \
    rm google-chrome-stable_current_amd64.deb

# 5. Set Chrome as Default Browser & Fix Root Sandbox Execution Errors
RUN update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/google-chrome-stable 200 && \
    update-alternatives --set x-www-browser /usr/bin/google-chrome-stable && \
    sed -i 's/Exec=\/usr\/bin\/google-chrome-stable %U/Exec=\/usr\/bin\/google-chrome-stable --no-sandbox --test-type %U/g' /usr/share/applications/google-chrome.desktop

# 6. Fix VLC Execution for Root User
RUN sed -i 's/geteuid/getppid/g' /usr/bin/vlc

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

CMD bash -c "vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && openssl req -new -subj '/C=JP' -x509 -days 365 -nodes -out self.pem -keyout self.pem && websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && tail -f /dev/null"
