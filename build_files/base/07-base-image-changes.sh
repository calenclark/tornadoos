#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -ouex pipefail

# Remove desktop entries
if [[ -f /usr/share/applications/gnome-system-monitor.desktop ]]; then
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/gnome-system-monitor.desktop
fi
if [[ -f /usr/share/applications/org.gnome.SystemMonitor.desktop ]]; then
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/org.gnome.SystemMonitor.desktop
fi

# Add Mutter experimental-features
MUTTER_EXP_FEATS="'scale-monitor-framebuffer', 'xwayland-native-scaling'"
if [[ "${IMAGE_NAME}" =~ nvidia ]]; then
    MUTTER_EXP_FEATS="'kms-modifiers', ${MUTTER_EXP_FEATS}"
fi
tee /usr/share/glib-2.0/schemas/zz1-bluefin-modifications-mutter-exp-feats.gschema.override << EOF
[org.gnome.mutter]
experimental-features=[${MUTTER_EXP_FEATS}]
EOF

# GNOME Terminal is replaced with Ptyxis in F41+
# Make schema valid on GNOME <47 which do not contain the accent-color key or xwayland-native-scaling mutter feature
if [[ "${FEDORA_MAJOR_VERSION}" -lt "41" ]]; then
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/org.gnome.Terminal.desktop
    sed -i 's@accent-color="slate"@@g' /usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override
    sed -i 's@'", "\''xwayland-native-scaling'\''@@g' /usr/share/glib-2.0/schemas/zz1-bluefin-modifications-mutter-exp-feats.gschema.override
fi

# Bazaar isn't ready on fedora 41, so for now, set logomenu to still use gnome-software
# This way the software center option isn't broken for regular users
# This should be removed as soon as bazaar is ready
if [[ "${FEDORA_MAJOR_VERSION}" -lt "42" ]]; then
    sed -i 's/\/usr\/bin\/bazaar window --auto-service/gnome-software/' /etc/dconf/db/distro.d/04-bluefin-logomenu-extension
fi

# Test bluefin gschema override for errors. If there are no errors, proceed with compiling bluefin gschema, which includes setting overrides.
mkdir -p /tmp/bluefin-schema-test
find /usr/share/glib-2.0/schemas/ -type f ! -name "*.gschema.override" -exec cp {} /tmp/bluefin-schema-test/ \;
cp /usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override /tmp/bluefin-schema-test/
cp /usr/share/glib-2.0/schemas/zz1-bluefin-modifications-mutter-exp-feats.gschema.override /tmp/bluefin-schema-test/
echo "Running error test for bluefin gschema override. Aborting if failed."
# We should ideally refactor this to handle multiple GNOME version schemas better
glib-compile-schemas --strict /tmp/bluefin-schema-test
echo "Compiling gschema to include bluefin setting overrides"
glib-compile-schemas /usr/share/glib-2.0/schemas &>/dev/null

echo "::endgroup::"
