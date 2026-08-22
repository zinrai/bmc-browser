#!/bin/bash
set -eu

BMC_URL="${BMC_URL:?BMC_URL is required}"
SCREEN_GEOMETRY="${SCREEN_GEOMETRY:-1280x1024}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"

# Xvnc is the X server and the VNC server in one process. It writes the display
# number to fd 3 once it accepts clients, so the read below is the readiness
# barrier and also picks whichever display is free.
DISPLAYFD="$(mktemp -u /tmp/xvnc-displayfd.XXXXXX)"
mkfifo "${DISPLAYFD}"
Xvnc -displayfd 3 \
    -geometry "${SCREEN_GEOMETRY}" \
    -depth "${SCREEN_DEPTH}" \
    -rfbport 5900 \
    -localhost \
    -SecurityTypes None \
    -AlwaysShared \
    -desktop bmc 3>"${DISPLAYFD}" &
read -r DISPLAY_NUM < "${DISPLAYFD}"
rm -f "${DISPLAYFD}"
export DISPLAY=":${DISPLAY_NUM}"

# A window manager that leaves the KVM viewer's own windows alone, and a task
# bar so there is a way back to the browser once the viewer covers it.
openbox &
tint2 &

websockify --web /usr/share/novnc 8080 localhost:5900 &
echo "noVNC available at http://localhost:8080/vnc.html"

# Firefox profile (throwaway, one per container)
PROFILE="$(mktemp -d /tmp/ff-profile.XXXXXX)"
cat > "${PROFILE}/user.js" <<'PREFS'
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.folderList", 2);
user_pref("browser.download.dir", "/tmp");
user_pref("browser.download.always_ask_before_handling_new_types", false);
user_pref("security.tls.version.min", 1);
user_pref("security.tls.version.enable-deprecated", true);
user_pref("network.http.spdy.enabled", false);
user_pref("security.sandbox.warn_unprivileged_namespaces", false);
PREFS

# Launch Firefox pointed at the BMC Web UI
exec firefox-esr --no-remote --profile "${PROFILE}" "${BMC_URL}"
