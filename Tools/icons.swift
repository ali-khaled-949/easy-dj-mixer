import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S = 1024.0
let deckA = NSColor(srgbRed: 0.15, green: 0.78, blue: 0.98, alpha: 1)
let deckB = NSColor(srgbRed: 1.00, green: 0.42, blue: 0.36, alpha: 1)
let amber = NSColor(srgbRed: 1.00, green: 0.66, blue: 0.11, alpha: 1)

func makeContext() -> CGContext {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    return ctx
}

func backdrop(_ ctx: CGContext, top: NSColor, bottom: NSColor) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [top.cgColor, bottom.cgColor] as CFArray,
                       locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
}

func save(_ ctx: CGContext, _ name: String) {
    let url = URL(fileURLWithPath: "\(CommandLine.arguments[1])/\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(name).png")
}

// MARK: - A. Twin platters

func twinPlatters() {
    let ctx = makeContext()
    backdrop(ctx, top: NSColor(white: 0.13, alpha: 1), bottom: NSColor(white: 0.04, alpha: 1))

    let r = S * 0.255
    let cy = S * 0.5
    let offset = S * 0.135

    ctx.setBlendMode(.plusLighter)
    for (color, cx) in [(deckA, S / 2 - offset), (deckB, S / 2 + offset)] {
        let center = CGPoint(x: cx, y: cy)
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [color.withAlphaComponent(0.95).cgColor,
                                    color.withAlphaComponent(0.30).cgColor] as CFArray,
                           locations: [0.55, 1])!
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.clip()
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: r, options: [])
        ctx.restoreGState()
    }
    ctx.setBlendMode(.normal)

    // Grooves and spindles.
    for cx in [S / 2 - offset, S / 2 + offset] {
        ctx.setStrokeColor(NSColor(white: 0, alpha: 0.22).cgColor)
        ctx.setLineWidth(S * 0.008)
        for step in 1...4 {
            let rr = r * (0.34 + Double(step) * 0.15)
            ctx.strokeEllipse(in: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2))
        }
        ctx.setFillColor(NSColor(white: 0.04, alpha: 1).cgColor)
        let hole = S * 0.020
        ctx.fillEllipse(in: CGRect(x: cx - hole, y: cy - hole, width: hole * 2, height: hole * 2))
    }

    save(ctx, "icon-a-twin-platters")
}

// MARK: - B. Waveform

func waveform() {
    let ctx = makeContext()
    backdrop(ctx, top: NSColor(white: 0.12, alpha: 1), bottom: NSColor(white: 0.035, alpha: 1))

    let bars = 17
    let span = S * 0.68
    let barWidth = span / Double(bars) * 0.56
    let gap = span / Double(bars)
    let startX = (S - span) / 2 + gap / 2
    let cy = S / 2

    // Envelope: a musical-looking shape rather than a plain bell.
    let shape: [Double] = [0.18, 0.32, 0.55, 0.38, 0.72, 0.95, 0.62, 0.85,
                           1.00, 0.80, 0.58, 0.88, 0.66, 0.42, 0.60, 0.30, 0.20]

    for index in 0..<bars {
        let x = startX + Double(index) * gap
        let h = S * 0.36 * shape[index]
        let t = Double(index) / Double(bars - 1)
        let color = NSColor(srgbRed: deckA.redComponent + (deckB.redComponent - deckA.redComponent) * t,
                            green: deckA.greenComponent + (deckB.greenComponent - deckA.greenComponent) * t,
                            blue: deckA.blueComponent + (deckB.blueComponent - deckA.blueComponent) * t,
                            alpha: 1)
        ctx.setFillColor(color.cgColor)
        let rect = CGRect(x: x - barWidth / 2, y: cy - h, width: barWidth, height: h * 2)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        ctx.fillPath()
    }

    // Amber playhead.
    ctx.setFillColor(amber.cgColor)
    let phW = S * 0.014
    ctx.addPath(CGPath(roundedRect: CGRect(x: S / 2 - phW / 2, y: S * 0.12, width: phW, height: S * 0.76),
                       cornerWidth: phW / 2, cornerHeight: phW / 2, transform: nil))
    ctx.fillPath()

    save(ctx, "icon-b-waveform")
}

// MARK: - C. Crossfader

func crossfader() {
    let ctx = makeContext()
    backdrop(ctx, top: NSColor(white: 0.13, alpha: 1), bottom: NSColor(white: 0.04, alpha: 1))

    let cy = S * 0.5
    let trackW = S * 0.62
    let trackH = S * 0.075
    let x0 = (S - trackW) / 2

    // Track, coloured from deck A to deck B.
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [deckA.cgColor, NSColor(white: 0.22, alpha: 1).cgColor, deckB.cgColor] as CFArray,
                       locations: [0, 0.5, 1])!
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: CGRect(x: x0, y: cy - trackH / 2, width: trackW, height: trackH),
                       cornerWidth: trackH / 2, cornerHeight: trackH / 2, transform: nil))
    ctx.clip()
    ctx.drawLinearGradient(g, start: CGPoint(x: x0, y: 0), end: CGPoint(x: x0 + trackW, y: 0), options: [])
    ctx.restoreGState()

    // Fader cap, sitting slightly off centre so it reads as a control.
    let capW = S * 0.155, capH = S * 0.30
    let capX = S / 2 - capW / 2 + S * 0.055
    let capRect = CGRect(x: capX, y: cy - capH / 2, width: capW, height: capH)
    let capG = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor(white: 0.42, alpha: 1).cgColor,
                                   NSColor(white: 0.16, alpha: 1).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: capRect, cornerWidth: S * 0.028, cornerHeight: S * 0.028, transform: nil))
    ctx.clip()
    ctx.drawLinearGradient(capG, start: CGPoint(x: 0, y: capRect.maxY), end: CGPoint(x: 0, y: capRect.minY), options: [])
    ctx.restoreGState()

    ctx.setFillColor(amber.cgColor)
    let lineW = S * 0.016
    ctx.addPath(CGPath(roundedRect: CGRect(x: capX + capW / 2 - lineW / 2, y: cy - capH * 0.32,
                                           width: lineW, height: capH * 0.64),
                       cornerWidth: lineW / 2, cornerHeight: lineW / 2, transform: nil))
    ctx.fillPath()

    // Channel dots above and below, hinting at EQ.
    for (row, alpha) in [(S * 0.775, 0.85), (S * 0.225, 0.85)] {
        for column in 0..<3 {
            let dotR = S * 0.026
            let x = S / 2 + Double(column - 1) * S * 0.10
            ctx.setFillColor(NSColor(white: 1, alpha: alpha * 0.55).cgColor)
            ctx.fillEllipse(in: CGRect(x: x - dotR, y: row - dotR, width: dotR * 2, height: dotR * 2))
        }
    }

    save(ctx, "icon-c-crossfader")
}

// MARK: - D. EQ arcs

func eqArcs() {
    let ctx = makeContext()
    backdrop(ctx, top: NSColor(white: 0.125, alpha: 1), bottom: NSColor(white: 0.035, alpha: 1))

    let center = CGPoint(x: S / 2, y: S / 2)
    let specs: [(Double, NSColor, Double, Double)] = [
        (S * 0.335, deckA,  -0.62,  0.55),
        (S * 0.255, amber,  -0.95,  0.15),
        (S * 0.175, deckB,  -0.40,  0.80)
    ]

    ctx.setLineCap(.round)
    for (radius, color, from, to) in specs {
        // Faint full ring for the track.
        ctx.setStrokeColor(NSColor(white: 1, alpha: 0.07).cgColor)
        ctx.setLineWidth(S * 0.052)
        ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                     width: radius * 2, height: radius * 2))

        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(S * 0.052)
        ctx.addArc(center: center, radius: radius,
                   startAngle: from * .pi, endAngle: to * .pi, clockwise: false)
        ctx.strokePath()
    }

    // Centre spindle.
    ctx.setFillColor(NSColor(white: 0.95, alpha: 1).cgColor)
    let hole = S * 0.038
    ctx.fillEllipse(in: CGRect(x: center.x - hole, y: center.y - hole, width: hole * 2, height: hole * 2))

    save(ctx, "icon-d-eq-arcs")
}

twinPlatters()
waveform()
crossfader()
eqArcs()
