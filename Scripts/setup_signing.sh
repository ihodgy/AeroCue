#!/bin/bash
# One-time setup: create a stable self-signed code-signing identity for AeroCue.
#
# Why this exists: without a signing identity, build_app.sh falls back to ad-hoc
# signing ("codesign -s -"), whose signature hash changes on every rebuild. macOS
# ties the Accessibility (TCC) grant to that signature, so every rebuild silently
# revokes the permission and the ⌥-hold stops working until you re-grant it.
#
# Signing with a fixed certificate keeps the app's identity stable across
# rebuilds, so you grant Accessibility once and it sticks.
#
# Run this once:  ./Scripts/setup_signing.sh
# Then rebuild:   ./Scripts/build_app.sh
set -euo pipefail

IDENTITY="AeroCue Local Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "==> '$IDENTITY' already exists and is valid. Nothing to do."
    exit 0
fi

echo "==> Generating a self-signed code-signing certificate"
openssl req -x509 -newkey rsa:2048 \
    -keyout "$WORKDIR/key.pem" -out "$WORKDIR/cert.pem" \
    -days 3650 -nodes -subj "/CN=$IDENTITY" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" 2>/dev/null

openssl pkcs12 -export -legacy -macalg sha1 \
    -out "$WORKDIR/identity.p12" \
    -inkey "$WORKDIR/key.pem" -in "$WORKDIR/cert.pem" \
    -passout pass:aerocue 2>/dev/null

echo "==> Importing it into your login keychain"
security import "$WORKDIR/identity.p12" -k "$KEYCHAIN" -P aerocue \
    -T /usr/bin/codesign -A >/dev/null

# codesign only accepts an identity that is trusted for code signing, so mark it
# so. This touches your login keychain only -- not system-wide trust settings.
echo "==> Marking it trusted for code signing (may prompt for your password)"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORKDIR/cert.pem"

echo
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "==> Done. '$IDENTITY' is ready."
    echo "    Now run: ./Scripts/build_app.sh"
    echo "    Grant Accessibility once more, and it will persist across rebuilds."
else
    echo "!! Identity was created but is still not listed as valid."
    echo "   Check: security find-identity -v -p codesigning"
    exit 1
fi
