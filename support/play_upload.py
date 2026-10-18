"""Upload an Android App Bundle to a Google Play testing track.

The Play counterpart of `make upload_ios`: the internal testing track is
what TestFlight is to iOS. Run through `make upload_android`, which builds
and signs the bundle on this machine first (signing is local by design,
see android/app/build.gradle.kts).

    python3 support/play_upload.py installers/ARCHIVE/radiopod-2.0.12.aab

Needs a Google Cloud service account with release rights for the app in
Play Console (Users and permissions). Its JSON key is read from
$PLAY_SERVICE_ACCOUNT, else ~/.config/radiopod/play-service-account.json.
NEVER put that key in the repository.

Uses only `requests` and `cryptography`, signing the OAuth JWT itself, so
google-api-python-client is not needed. The API refuses an app that has
never had a bundle uploaded by hand in Play Console, so the first release
is always manual.

20261018 gjw Created.
"""

import argparse
import base64
import json
import os
import pathlib
import re
import sys
import time

import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

PACKAGE = "com.togaware.radiopod"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}"
DEFAULT_KEY = "~/.config/radiopod/play-service-account.json"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def access_token(key_path: pathlib.Path) -> str:
    """Exchange a self-signed JWT for an OAuth access token."""

    account = json.loads(key_path.read_text())
    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {
        "iss": account["client_email"],
        "scope": SCOPE,
        "aud": account["token_uri"],
        "iat": now,
        "exp": now + 3600,
    }
    unsigned = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(claims).encode())}"
    key = serialization.load_pem_private_key(account["private_key"].encode(), password=None)
    signature = key.sign(unsigned.encode(), padding.PKCS1v15(), hashes.SHA256())

    r = requests.post(
        account["token_uri"],
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": f"{unsigned}.{b64url(signature)}",
        },
        timeout=30,
    )
    check(r, "authenticate")
    return r.json()["access_token"]


def check(r: requests.Response, what: str) -> None:
    if not r.ok:
        sys.exit(f"Error: could not {what}: HTTP {r.status_code}\n{r.text}")


def pubspec_version() -> tuple[str, int]:
    """The version name and build number (the version code) from pubspec."""

    text = pathlib.Path("pubspec.yaml").read_text()
    m = re.search(r"^version:\s*([^+\s]+)\+(\d+)", text, re.MULTILINE)
    if not m:
        sys.exit("Error: pubspec.yaml has no `version: x.y.z+N`.")
    return m.group(1), int(m.group(2))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("aab", type=pathlib.Path, help="the signed .aab to upload")
    parser.add_argument("--track", default="internal", help="internal (default), alpha, beta or production")
    parser.add_argument(
        "--status",
        default="completed",
        help="completed (default) rolls it out to the track's testers; use "
        "draft while the app itself is still a draft in Play Console",
    )
    args = parser.parse_args()

    if not args.aab.is_file():
        sys.exit(f"Error: {args.aab} not found.")
    key_path = pathlib.Path(os.environ.get("PLAY_SERVICE_ACCOUNT", DEFAULT_KEY)).expanduser()
    if not key_path.is_file():
        sys.exit(f"Error: no service account key at {key_path}. Set PLAY_SERVICE_ACCOUNT.")

    name, code = pubspec_version()
    session = requests.Session()
    session.headers["Authorization"] = f"Bearer {access_token(key_path)}"

    r = session.post(f"{API}/edits", timeout=30)
    check(r, "open an edit")
    edit = r.json()["id"]

    # Play refuses a version code it has seen before. Say so plainly, as
    # `make snapstore` does for a version already published, rather than
    # uploading 50 MB to be told.

    r = session.get(f"{API}/edits/{edit}/bundles", timeout=30)
    check(r, "list bundles")
    seen = {b["versionCode"] for b in r.json().get("bundles", [])}
    if code in seen:
        session.delete(f"{API}/edits/{edit}", timeout=30)
        print(f"Google Play already has {PACKAGE} version code {code} ({name}). Bump first.")
        return

    print(f"Uploading {args.aab} ({args.aab.stat().st_size // 1_000_000} MB)...")
    with args.aab.open("rb") as f:
        r = session.post(
            f"{UPLOAD}/edits/{edit}/bundles",
            params={"uploadType": "media"},
            headers={"Content-Type": "application/octet-stream"},
            data=f,
            timeout=900,
        )
    check(r, "upload the bundle")
    uploaded = r.json()["versionCode"]
    if uploaded != code:
        session.delete(f"{API}/edits/{edit}", timeout=30)
        sys.exit(f"Error: the bundle is version code {uploaded} but pubspec says {code}. Rebuild it.")

    release = {"name": name, "versionCodes": [str(code)], "status": args.status}
    r = session.put(
        f"{API}/edits/{edit}/tracks/{args.track}",
        json={"track": args.track, "releases": [release]},
        timeout=30,
    )
    check(r, f"assign it to the {args.track} track")

    r = session.post(f"{API}/edits/{edit}:commit", timeout=60)
    check(r, "commit the edit")
    print(f"Google Play {args.track}: {name} (version code {code}), {args.status}.")


if __name__ == "__main__":
    main()
