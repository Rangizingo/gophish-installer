"""Retry OCI ARM instance launch until capacity is available."""

import subprocess, json, time, sys

OCI = "C:/Users/pblanco/AppData/Roaming/Python/Python313/Scripts/oci.exe"
TENANCY = (
    "ocid1.tenancy.oc1..aaaaaaaa7rwt3mfwgbdkwybt3yiff7bxevkqy355ivy3wdfczffuv2fwns3a"
)
SUBNET = "ocid1.subnet.oc1.us-chicago-1.aaaaaaaav36ecv63gpgkiymg3owp33treaakjqdf52k425sxjt2xz3xsmxaa"
IMAGE = "ocid1.image.oc1.us-chicago-1.aaaaaaaadazmy3sate6nkn3saac47bwj35sxlaqkf2pubj6ygqsiqd6gs72a"
SSH_KEY = "C:/Users/pblanco/.oci/gophish-vm-key.pub"

ADS = [
    "Ptls:US-CHICAGO-1-AD-1",
    "Ptls:US-CHICAGO-1-AD-2",
    "Ptls:US-CHICAGO-1-AD-3",
]

RETRY_INTERVAL = 60  # seconds between attempts


def try_launch(ad: str) -> dict | None:
    cmd = [
        OCI,
        "compute",
        "instance",
        "launch",
        "--compartment-id",
        TENANCY,
        "--availability-domain",
        ad,
        "--shape",
        "VM.Standard.A1.Flex",
        "--shape-config",
        json.dumps({"ocpus": 1, "memoryInGBs": 6}),
        "--image-id",
        IMAGE,
        "--subnet-id",
        SUBNET,
        "--assign-public-ip",
        "true",
        "--display-name",
        "gophish",
        "--ssh-authorized-keys-file",
        SSH_KEY,
        "--output",
        "json",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        try:
            return json.loads(result.stdout)["data"]
        except (json.JSONDecodeError, KeyError):
            pass
    return None


def main():
    attempt = 0
    print("Retrying OCI ARM instance launch across all ADs...")
    print(f"Interval: {RETRY_INTERVAL}s between full cycles")
    print("Press Ctrl+C to stop\n")

    while True:
        for ad in ADS:
            attempt += 1
            ad_short = ad.split("-")[-1]
            print(f"[Attempt {attempt}] Trying {ad_short}...", end=" ", flush=True)

            data = try_launch(ad)
            if data:
                print("SUCCESS!")
                print(f"\nInstance ID: {data['id']}")
                print(f"State: {data['lifecycle-state']}")
                print(f"AD: {ad}")
                print("\nWaiting for public IP (check OCI console or run):")
                print(f'  oci compute instance list-vnics --instance-id "{data["id"]}"')
                sys.exit(0)
            else:
                print("Out of capacity")

        print(f"\nAll ADs exhausted. Retrying in {RETRY_INTERVAL}s...\n")
        time.sleep(RETRY_INTERVAL)


if __name__ == "__main__":
    main()
