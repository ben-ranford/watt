import AppKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
}
func bitmap(_ path: String) throws -> NSBitmapImageRep {
    guard let image = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: path))) else { fail("Invalid image") }
    return image
}
func save(_ image: NSBitmapImageRep, _ path: String) throws {
    guard let png = image.representation(using: .png, properties: [:]) else { fail("Cannot encode PNG") }
    try png.write(to: URL(fileURLWithPath: path))
}
func blank(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)!
}
let a = CommandLine.arguments
// Never resample. Coordinates are integral source pixels; explicit scale is required for diff.
if a.count == 8, a[1] == "crop", let x = Int(a[4]), let y = Int(a[5]), let w = Int(a[6]), let h = Int(a[7]) {
    let source = try bitmap(a[2])
    guard x >= 0, y >= 0, w > 0, h > 0, x+w <= source.pixelsWide, y+h <= source.pixelsHigh else { fail("Crop outside image") }
    let target = blank(w,h)
    for j in 0..<h { for i in 0..<w { target.setColor(source.colorAt(x:x+i,y:y+j)!,atX:i,y:j) } }
    try save(target,a[3])
    let metadata: [String:Any] = ["source":a[2], "coordinateSpace":"source pixels", "x":x,"y":y,"width":w,"height":h,"resampled":false,"masks":"none"]
    try JSONSerialization.data(withJSONObject:metadata,options:[.sortedKeys,.prettyPrinted]).write(to:URL(fileURLWithPath:a[3]+".json"))
} else if a.count == 8, a[1] == "diff", let scaleA = Double(a[5]), let scaleB = Double(a[6]), let tolerance = Double(a[7]) {
    guard scaleA > 0, scaleA.isFinite, scaleA == scaleB, (0...1).contains(tolerance) else { fail("Scale mismatch or invalid tolerance") }
    let lhs = try bitmap(a[2]), rhs = try bitmap(a[3])
    guard lhs.pixelsWide == rhs.pixelsWide, lhs.pixelsHigh == rhs.pixelsHigh else { fail("Geometry mismatch; resizing is forbidden") }
    let diff = blank(lhs.pixelsWide,lhs.pixelsHigh), overlay = blank(lhs.pixelsWide,lhs.pixelsHigh)
    var changed = 0
    for y in 0..<lhs.pixelsHigh { for x in 0..<lhs.pixelsWide {
        let l = lhs.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
        let r = rhs.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
        let delta = max(abs(l.redComponent-r.redComponent),abs(l.greenComponent-r.greenComponent),abs(l.blueComponent-r.blueComponent),abs(l.alphaComponent-r.alphaComponent))
        if delta > 1.0/255.0 { changed += 1 }
        diff.setColor(NSColor(deviceRed:delta,green:0,blue:0,alpha:1),atX:x,y:y)
        overlay.setColor(NSColor(deviceRed:(l.redComponent+r.redComponent)/2, green:(l.greenComponent+r.greenComponent)/2, blue:(l.blueComponent+r.blueComponent)/2, alpha:1),atX:x,y:y)
    } }
    try save(diff,a[4]+"-diff.png"); try save(overlay,a[4]+"-overlay.png")
    let ratio = Double(changed)/Double(lhs.pixelsWide*lhs.pixelsHigh)
    let record: [String:Any] = ["changedPixels":changed,"changedFraction":ratio,"tolerance":tolerance,"pixelsPerPoint":scaleA,"width":lhs.pixelsWide,"height":lhs.pixelsHigh,"pass":ratio <= tolerance,"storyDone":false,"review":"pixel check only; independent visual/accessibility/service review required","mask":"none"]
    try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:a[4]+".json"))
    if ratio > tolerance { exit(2) }
} else if a.count == 4, a[1] == "perturb" {
    let source = try bitmap(a[2]), target = blank(source.pixelsWide,source.pixelsHigh)
    // A one-point-at-2x translation detects geometry drift without hiding app-owned pixels.
    for y in 0..<source.pixelsHigh { for x in 0..<source.pixelsWide {
        target.setColor(x >= 2 ? source.colorAt(x:x-2,y:y)! : NSColor(deviceRed:1,green:0,blue:1,alpha:1),atX:x,y:y)
    } }
    try save(target,a[3])
} else { fail("crop input output x y width height | diff reference render prefix referenceScale renderScale tolerance | perturb input output") }
