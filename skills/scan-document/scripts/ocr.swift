// ocr.swift — native macOS OCR for scanned PDFs and images.
// Uses PDFKit to rasterize PDF pages and Vision (VNRecognizeTextRequest) to
// recognize text. Vision is the only OCR engine here — this script never
// shells out to tesseract or poppler.
//
// Usage:  swift ocr.swift <file.pdf|file.png|file.jpg|file.heic>
// Output: page-delimited recognized text on stdout ("===== PAGE n ====="),
//         with the header omitted for any page where nothing was recognized.
//
// Note: callers may optionally try `pdftotext -layout` first when that
// binary happens to be present (poppler; not part of stock macOS, so its
// absence is the common case) — far faster for PDFs with a real text layer.
// This script is the fallback (or sole path) when that isn't available or
// yields nothing.

import Foundation
import PDFKit
import Vision
import AppKit
import ImageIO

func ocr(_ cg: CGImage, orientation: CGImagePropertyOrientation = .up) -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation, options: [:])
    do {
        try handler.perform([request])
    } catch {
        FileHandle.standardError.write("Vision OCR failed: \(error)\n".data(using: .utf8)!)
        return ""
    }
    guard let obs = request.results else { return "" }
    // Reading order: top-to-bottom (Vision's boundingBox origin is bottom-left,
    // normalized, so higher minY is visually higher on the page), then
    // left-to-right, so multi-column layouts (e.g. two-column AVS pages)
    // don't interleave.
    let ordered = obs.sorted { a, b in
        if a.boundingBox.minY != b.boundingBox.minY {
            return a.boundingBox.minY > b.boundingBox.minY
        }
        return a.boundingBox.minX < b.boundingBox.minX
    }
    return ordered.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
}

func renderPDFPage(_ page: PDFPage, scale: CGFloat) -> CGImage? {
    let bounds = page.bounds(for: .mediaBox)
    let rotation = ((page.rotation % 360) + 360) % 360
    let rotated = rotation == 90 || rotation == 270
    let pageWidth = rotated ? bounds.height : bounds.width
    let pageHeight = rotated ? bounds.width : bounds.height
    let w = Int(pageWidth * scale), h = Int(pageHeight * scale)
    guard w > 0, h > 0,
          let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.scaleBy(x: scale, y: scale)
    // page.draw(with:to:) applies the page's /Rotate attribute itself; the
    // context above is sized for the post-rotation (visual) dimensions so
    // rotated pages aren't clipped.
    page.draw(with: .mediaBox, to: ctx)
    return ctx.makeImage()
}

func exifOrientation(of url: URL) -> CGImagePropertyOrientation {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let raw = props[kCGImagePropertyOrientation] as? UInt32,
          let orientation = CGImagePropertyOrientation(rawValue: raw) else {
        return .up
    }
    return orientation
}

let args = CommandLine.arguments
guard args.count > 1 else {
    FileHandle.standardError.write("usage: ocr.swift <file.pdf|image>\n".data(using: .utf8)!)
    exit(2)
}
let path = args[1]
let url = URL(fileURLWithPath: path)
let ext = url.pathExtension.lowercased()
let scale: CGFloat = 3.0  // upscale for sharper OCR on low-DPI scans

if ext == "pdf" {
    guard let doc = PDFDocument(url: url) else {
        FileHandle.standardError.write("cannot open PDF: \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    for i in 0..<doc.pageCount {
        guard let page = doc.page(at: i), let cg = renderPDFPage(page, scale: scale) else { continue }
        let text = ocr(cg)
        // Suppress the header for pages with no recognized text so callers
        // can treat "no header" as "nothing here" (see SKILL.md's
        // empty-OCR rule).
        if !text.isEmpty {
            print("===== PAGE \(i + 1) =====")
            print(text)
        }
    }
} else {
    guard let image = NSImage(contentsOf: url),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        FileHandle.standardError.write("cannot open image: \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    let orientation = exifOrientation(of: url)
    let text = ocr(cg, orientation: orientation)
    if !text.isEmpty {
        print("===== PAGE 1 =====")
        print(text)
    }
}
