#!/usr/bin/env python3

"""
This is a Python script that uses the Unifi cloud API to return a list of all clients.
Useful if you need to get a list of IP addresses or attached MAC addresses for any sort of parsing.
"""

import argparse
import csv
import json
import os
import sys
import urllib.request
import urllib.error
import ssl


CLOUD_API_BASE = "https://api.ui.com"


def api_request(url, api_key, verify_ssl=True):
    ctx = None
    if not verify_ssl:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    req = urllib.request.Request(url)
    req.add_header("Accept", "application/json")
    req.add_header("X-API-Key", api_key)

    try:
        response = urllib.request.urlopen(req, context=ctx)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code} from {url}: {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Connection error: {e.reason}", file=sys.stderr)
        sys.exit(1)

    return json.loads(response.read().decode("utf-8"))


def fetch_all_pages(url, api_key):
    results = []
    next_token = None
    while True:
        page_url = url
        if next_token:
            sep = "&" if "?" in url else "?"
            page_url = f"{url}{sep}nextToken={next_token}"
        data = api_request(page_url, api_key)
        results.extend(data.get("data", []))
        next_token = data.get("nextToken")
        if not next_token:
            break
    return results


def fetch_host_names(api_key):
    devices_data = fetch_all_pages(f"{CLOUD_API_BASE}/v1/devices", api_key)
    host_names = {}
    for entry in devices_data:
        host_id = entry.get("hostId", "")
        host_name = entry.get("hostName", "")
        if host_id and host_name:
            host_names[host_id] = host_name
    return host_names


def get_network_site_id(api_key, host_id):
    url = (
        f"{CLOUD_API_BASE}/v1/connector/consoles/{host_id}"
        f"/network/integration/v1/sites"
    )
    data = api_request(url, api_key)
    sites = data.get("data", [])
    if sites:
        return sites[0]["id"]
    return None


def resolve_site(api_key, site_name):
    sites = fetch_all_pages(f"{CLOUD_API_BASE}/v1/sites", api_key)
    host_names = fetch_host_names(api_key)

    search = site_name.lower()
    for site in sites:
        meta = site.get("meta", {})
        name = (meta.get("name") or "").lower()
        desc = (meta.get("desc") or "").lower()
        host_id = site.get("hostId", "")
        console_name = host_names.get(host_id, "").lower()

        if search in (name, desc, console_name):
            network_site_id = get_network_site_id(api_key, host_id)
            if network_site_id:
                return network_site_id, host_id
        if search in console_name or search in desc:
            network_site_id = get_network_site_id(api_key, host_id)
            if network_site_id:
                return network_site_id, host_id

    print(f"Site '{site_name}' not found.", file=sys.stderr)
    print("Available sites:", file=sys.stderr)
    for site in sites:
        meta = site.get("meta", {})
        name = meta.get("name") or "?"
        desc = meta.get("desc") or ""
        host_id = site.get("hostId", "")
        console = host_names.get(host_id, "")
        if console:
            print(f"  - {console} (site: {name}, desc: {desc})", file=sys.stderr)
        else:
            print(f"  - {name} ({desc})", file=sys.stderr)
    sys.exit(1)


def fetch_clients_cloud(api_key, host_id, site_id):
    clients = []
    offset = 0
    limit = 200

    while True:
        url = (
            f"{CLOUD_API_BASE}/v1/connector/consoles/{host_id}"
            f"/network/integration/v1/sites/{site_id}/clients"
            f"?offset={offset}&limit={limit}"
        )
        data = api_request(url, api_key)
        page = data.get("data", [])
        clients.extend(page)

        total = data.get("totalCount", 0)
        if offset + limit < total:
            offset += limit
        else:
            break

    return clients


def fetch_clients_local(base_url, site_id, api_key, verify_ssl=True):
    clients = []
    offset = 0
    limit = 200

    while True:
        url = (
            f"{base_url}/proxy/network/integration"
            f"/v1/sites/{site_id}/clients"
            f"?offset={offset}&limit={limit}"
        )
        data = api_request(url, api_key, verify_ssl)
        page = data.get("data", [])
        clients.extend(page)

        total = data.get("totalCount", 0)
        if offset + limit < total:
            offset += limit
        else:
            break

    return clients


def write_csv(clients, output):
    fields = [
        "id",
        "name",
        "macAddress",
        "ipAddress",
        "type",
        "connectedAt",
    ]

    writer = csv.DictWriter(output, fieldnames=fields, extrasaction="ignore")
    writer.writeheader()
    for client in clients:
        writer.writerow(client)


def main():
    parser = argparse.ArgumentParser(
        description="Fetch UniFi clients for a site and output as CSV.",
        epilog=(
            "By default, uses the UniFi cloud API (api.ui.com). "
            "Use --local-url to connect directly to a local controller instead."
        ),
    )
    parser.add_argument(
        "site",
        help="Console or site name to match (e.g. 'default', 'My Office'). "
        "Matched against console name, site name, and site description.",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("UNIFI_API_KEY", ""),
        help="API key for the UniFi controller. "
        "Can also be set via UNIFI_API_KEY env var.",
    )
    parser.add_argument(
        "--local-url",
        default=os.environ.get("UNIFI_LOCAL_URL", ""),
        help="Connect directly to a local controller URL instead of the cloud API "
        "(e.g. https://192.168.1.1). Can also be set via UNIFI_LOCAL_URL env var. "
        "When using this, the site argument must be the site UUID.",
    )
    parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        help="Disable SSL certificate verification (only relevant with --local-url).",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="-",
        help="Output file path. Defaults to stdout.",
    )

    args = parser.parse_args()

    if not args.api_key:
        parser.error("API key is required (--api-key or UNIFI_API_KEY env var)")

    if args.local_url:
        base_url = args.local_url.rstrip("/")
        clients = fetch_clients_local(
            base_url, args.site, args.api_key, not args.no_verify_ssl
        )
    else:
        site_id, host_id = resolve_site(args.api_key, args.site)
        clients = fetch_clients_cloud(args.api_key, host_id, site_id)

    if args.output == "-":
        write_csv(clients, sys.stdout)
    else:
        with open(args.output, "w", newline="") as f:
            write_csv(clients, f)


if __name__ == "__main__":
    main()
