FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y && apt install --no-install-recommends -y xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify sudo xterm init systemd snapd vim net-tools curl wget git tzdata
RUN apt update -y && apt install -y dbus-x11 x11-utils x11-xserver-utils x11-apps
RUN apt install software-properties-common -y
RUN add-apt-repository ppa:mozillateam/ppa -y
RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox
RUN apt update -y && apt install -y firefox
RUN apt update -y && apt install -y xubuntu-icon-theme
RUN touch /root/.Xauthority
EXPOSE 5901
EXPOSE 6080
CMD bash -c "vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && openssl req -new -subj "/C=JP" -x509 -days 365 -nodes -out self.pem -keyout self.pem && websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && tail -f /dev/null"

# --- Automatic GitHub wallpaper support (Dockerfile-only addition) ---
# Set WALLPAPER_REPO at runtime to any public GitHub repository containing
# PNG/JPG/JPEG/WEBP files (files in subdirectories are supported too).
ENV WALLPAPER_REPO=""
ENV WALLPAPER_BRANCH=""
ENV WALLPAPER_DIR="/root/.wallpapers"

RUN apt update -y && apt install -y xdotool xinput yad

RUN mkdir -p /root/.wallpapers/library /root/.config/autostart /root/.vnc && \
    cat > /usr/local/bin/wallpaper-manager <<'WALLPAPER_MANAGER'
#!/bin/sh
set -u

WALLPAPER_DIR="${WALLPAPER_DIR:-/root/.wallpapers}"
LIBRARY_DIR="${WALLPAPER_DIR}/library"
REPO_DIR="${WALLPAPER_DIR}/repo"
LOCK_DIR="/tmp/wallpaper-chooser.lock"

image_files() {
    find "$1" -type f \( \
        -iname '*.png' -o \
        -iname '*.jpg' -o \
        -iname '*.jpeg' -o \
        -iname '*.webp' \
    \) -print 2>/dev/null
}

populate_library() {
    source_dir="$1"
    target_dir="$2"
    mkdir -p "$target_dir"

    image_files "$source_dir" | while IFS= read -r file; do
        hash="$(printf '%s' "$file" | sha256sum | cut -c1-12)"
        name="$(basename "$file")"
        cp -f "$file" "$target_dir/${hash}_${name}" 2>/dev/null || true
    done
}

prepare_repo() {
    mkdir -p "$WALLPAPER_DIR" "$LIBRARY_DIR"

    if [ -z "${WALLPAPER_REPO:-}" ]; then
        return 0
    fi

    tmp_dir="$(mktemp -d "${WALLPAPER_DIR}/.repo.XXXXXX")"

    if [ -n "${WALLPAPER_BRANCH:-}" ]; then
        git clone --depth 1 --branch "$WALLPAPER_BRANCH" "$WALLPAPER_REPO" "$tmp_dir/repo" >/tmp/wallpaper-git.log 2>&1
    else
        git clone --depth 1 "$WALLPAPER_REPO" "$tmp_dir/repo" >/tmp/wallpaper-git.log 2>&1
    fi

    if [ "$?" -ne 0 ]; then
        rm -rf "$tmp_dir"
        return 0
    fi

    new_library="$tmp_dir/library"
    mkdir -p "$new_library"
    populate_library "$tmp_dir/repo" "$new_library"

    if image_files "$new_library" | grep -q .; then
        rm -rf "$REPO_DIR" "$LIBRARY_DIR"
        mv "$tmp_dir/repo" "$REPO_DIR"
        mv "$new_library" "$LIBRARY_DIR"
        rmdir "$tmp_dir" 2>/dev/null || rm -rf "$tmp_dir"
    else
        rm -rf "$tmp_dir"
    fi
}

wait_for_desktop() {
    i=0
    while [ "$i" -lt 60 ]; do
        if pgrep -x xfdesktop >/dev/null 2>&1; then
            return 0
        fi
        i=$((i + 1))
        sleep 1
    done
    return 1
}

set_wallpaper() {
    file="$1"

    [ -f "$file" ] || return 1
    wait_for_desktop || true

    props="$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/backdrop/.*/image-path$' || true)"

    if [ -n "$props" ]; then
        printf '%s\n' "$props" | while IFS= read -r prop; do
            [ -n "$prop" ] && xfconf-query -c xfce4-desktop -p "$prop" -s "$file" >/dev/null 2>&1 || true
        done
    else
        xfconf-query -c xfce4-desktop \
            -p /backdrop/screen0/monitor0/image-path \
            -n -t string -s "$file" >/dev/null 2>&1 || true
    fi
}

random_wallpaper() {
    file="$(image_files "$LIBRARY_DIR" | shuf -n 1 2>/dev/null || true)"

    if [ -z "$file" ]; then
        file="$(image_files /usr/share/backgrounds | shuf -n 1 2>/dev/null || true)"
    fi

    if [ -n "$file" ]; then
        set_wallpaper "$file"
    fi
}

choose_wallpaper() {
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        return 0
    fi

    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

    start_dir="$LIBRARY_DIR"
    if ! image_files "$LIBRARY_DIR" | grep -q .; then
        start_dir="/usr/share/backgrounds"
    fi

    file="$(yad \
        --file-selection \
        --title="Choose Wallpaper" \
        --filename="${start_dir}/" \
        --add-preview \
        --width=1000 \
        --height=700 \
        --file-filter="Images | *.png *.jpg *.jpeg *.webp" \
        2>/dev/null || true)"

    if [ -n "$file" ] && [ -f "$file" ]; then
        set_wallpaper "$file"
    fi

    trap - EXIT INT TERM
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

desktop_left_click_monitor() {
    wait_for_desktop || true

    pointer_id="$(xinput list --id-only 'Virtual core pointer' 2>/dev/null | head -n 1 || true)"
    [ -n "$pointer_id" ] || return 0

    root_id="$(xwininfo -root 2>/dev/null | awk '/Window id:/{print $4; exit}' || true)"

    xinput test "$pointer_id" 2>/dev/null | while IFS= read -r event; do
        case "$event" in
            *"button press   1"*)
                location="$(xdotool getmouselocation --shell 2>/dev/null || true)"
                window_id="$(printf '%s\n' "$location" | awk -F= '$1=="WINDOW"{print $2; exit}')"

                [ -n "$window_id" ] || continue

                if [ "$window_id" = "$root_id" ]; then
                    choose_wallpaper
                    continue
                fi

                window_class="$(xprop -id "$window_id" WM_CLASS 2>/dev/null || true)"
                case "$window_class" in
                    *xfdesktop*|*XFDesktop*)
                        choose_wallpaper
                        ;;
                esac
                ;;
        esac
    done
}

case "${1:-session}" in
    prepare)
        prepare_repo
        ;;
    session)
        wait_for_desktop || true
        random_wallpaper &
        desktop_left_click_monitor &
        wait
        ;;
    choose)
        choose_wallpaper
        ;;
    *)
        echo "Usage: wallpaper-manager {prepare|session|choose}" >&2
        exit 2
        ;;
esac
WALLPAPER_MANAGER
    chmod +x /usr/local/bin/wallpaper-manager

RUN cat > /root/.vnc/xstartup <<'VNCSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/root/.config}"

exec dbus-launch --exit-with-session sh -c '/usr/local/bin/wallpaper-manager prepare; exec startxfce4'
VNCSTARTUP
    chmod +x /root/.vnc/xstartup

RUN cat > /root/.config/autostart/wallpaper-manager.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Wallpaper Manager
Comment=Load GitHub wallpapers and open the chooser with a left click on the desktop
Exec=/usr/local/bin/wallpaper-manager session
Terminal=false
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
DESKTOP
# --- End automatic GitHub wallpaper support ---
