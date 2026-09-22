"""Verify both Release architectures exclude fixture-only implementation symbols."""
import re
import subprocess

for build in ("release-app", "release-after"):
    binary = f"/tmp/watt-g082-{build}/Build/Products/Release/Watt.app/Contents/MacOS/Watt"
    for arch in ("arm64", "x86_64"):
        symbols = subprocess.check_output(["nm", "-arch", arch, binary], text=True)
        forbidden = re.findall(r"^.*(?:ScenarioRegistry|FixtureLaunchSelection|WattFixtureLaunchGate|J\d+FixtureLaunch|J25FixtureSession|C0410PanelSelection|sample(?:InsufficientCharger|FullOnAdapter|ChargingHold|PerComponent|DesktopSystemDraw|UnpluggedCharger|ChargerInput|ChargedOnAdapter|OnBattery)).*$", symbols, re.M)
        assert not forbidden, "\n".join(forbidden)
        print(f"PASS: {build} {arch} excludes fixture-only symbols")
