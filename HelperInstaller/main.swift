import Foundation
import Darwin

do { try run() }
catch {
    let message = """
    WattHelperInstaller refused: \(error)
    Usage:
      --preflight --source /absolute/path/Watt.app
      --bootstrap-reviewed|--rotate-reviewed --source /absolute/path/Watt.app --approval <SHA256>
      --provision-release-key --installation <UUID> --identity <bundle ID> --public-key <base64>
      --rotate-release --installation <UUID> --manifest /absolute/path/manifest.json --archive /absolute/path/release.tar [--request /absolute/path/request.json]
      --remove-helper|--uninstall|--recover --installation <UUID> --generation <N>
      --uninstall --request /absolute/path/request.json
      --rotate-release --request /absolute/path/request.json --manifest /absolute/path/manifest.json --archive /absolute/path/release.tar
      --discard-release-stage --installation <UUID>

    """
    fputs(message, stderr)
    exit(78)
}
