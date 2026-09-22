import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let actualURL = URL(fileURLWithPath: CommandLine.arguments[2])
func read(_ url: URL) -> CGImage {
    CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
}
let reference = read(root.appendingPathComponent("figma-reference.png"))
    .cropping(to: CGRect(x: 240, y: 236, width: 520, height: 269))!
let actual = read(actualURL)
let width = 520, height = 269
func pixels(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return bytes
}
func save(_ bytes: [UInt8], _ name: String) {
    let data = Data(bytes)
    let provider = CGDataProvider(data: data as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let destination = CGImageDestinationCreateWithURL(root.appendingPathComponent(name) as CFURL,
        UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
}
let a = pixels(reference), b = pixels(actual)
var diff = [UInt8](repeating: 255, count: a.count)
var total = 0, changed = 0
for i in stride(from: 0, to: a.count, by: 4) {
    var maximum = 0
    for c in 0..<3 {
        let delta = abs(Int(a[i+c]) - Int(b[i+c]))
        total += delta; maximum = max(maximum, delta); diff[i+c] = UInt8(delta)
    }
    if maximum > 16 { changed += 1 }
}
save(a, "reference-window.png"); save(b, "actual-window-1x.png"); save(diff, "pixel-diff.png")
let metrics: [String: Any] = ["width": width, "height": height,
    "referenceCrop": [240, 236, width, height], "actualOriginalPixels": [actual.width, actual.height],
    "meanAbsoluteRGBDifference": Double(total) / Double(width * height * 3),
    "fractionPixelsExceeding16": Double(changed) / Double(width * height),
    "note": "Secondary localization evidence only. Actual 520x288 window resampled to 520x269 reference crop for localization ONLY; height and dark/light appearance differ. No comparable viewport/appearance, no acceptance score. No desktop or OS notification compared."]
try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("pixel-diff.json"))
