#!/usr/bin/env python3
from contextlib import closing
import sys
import secretstorage
from secretstorage.collection import get_all_collections

SRC_NAME = "Default"
DST_NAME = "Login"

def find_collection(collections, name):
    matches = [c for c in collections if c.get_label().casefold() == name.casefold()]
    if not matches:
        print(f"Fant ikke keyring/collection med navn: {name}", file=sys.stderr)
        print("Tilgjengelige collections:", file=sys.stderr)
        for c in collections:
            print(f"  - {c.get_label()} ({c.collection_path})", file=sys.stderr)
        sys.exit(1)
    return matches[0]

def unlock_if_needed(collection):
    if collection.is_locked():
        print(f'Låser opp "{collection.get_label()}"...')
        dismissed = collection.unlock()
        if dismissed:
            print(f'Opplåsing av "{collection.get_label()}" ble avbrutt.', file=sys.stderr)
            sys.exit(1)

with closing(secretstorage.dbus_init()) as conn:
    collections = list(get_all_collections(conn))

    src = find_collection(collections, SRC_NAME)
    dst = find_collection(collections, DST_NAME)

    print("Collections:")
    for c in collections:
        print(f"  - {c.get_label()} | locked={c.is_locked()} | {c.collection_path}")

    unlock_if_needed(src)
    unlock_if_needed(dst)

    items = list(src.get_all_items())
    print(f'\nKopierer {len(items)} item(s) fra "{SRC_NAME}" til "{DST_NAME}"...\n')

    copied = 0
    skipped = 0

    for item in items:
        try:
            label = item.get_label()
            attrs = item.get_attributes()
            secret = item.get_secret()
            content_type = item.get_secret_content_type()

            if not attrs:
                print(f'Skipper "{label}" fordi item mangler attributes.')
                skipped += 1
                continue

            dst.create_item(
                label,
                attrs,
                secret,
                replace=True,
                content_type=content_type,
            )

            print(f'Kopiert: {label}')
            copied += 1

        except Exception as e:
            try:
                label = item.get_label()
            except Exception:
                label = "<ukjent>"
            print(f'FEIL ved item "{label}": {e}', file=sys.stderr)
            skipped += 1

    print(f"\nFerdig. Kopiert: {copied}. Skippet/feilet: {skipped}.")
