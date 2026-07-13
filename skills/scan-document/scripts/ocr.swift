// ocr.swift — native macOS OCR for scanned PDFs and images.
// Uses PDFKit to rasterize PDF pages and Vision (VNRecognizeTextRequest) to
// recognize text. No third-party dependencies (no tesseract/poppler).
//
// Usage:  swift ocr.swift <file.pdf|file.png|file.jpg|file.heic>
// Output: page-delimited recognized text on stdout ("===== PAGE n =====").
//
// Note: for PDFs that already carry a text layer, prefer `pdftotext -layout`
// first (far faster); fall back to this script only when that yields nothing.

import Foundation
import PDFKit
import Vision
import AppKit

func ocr(_ cg: CGImage) -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([request])
    guard let obs = request.results else { return "" }
    return obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
}

func renderPDFPage(_ page: PDFPage, scale: CGFloat) -> CGImage? {
    let bounds = page.bounds(for: .mediaBox)
    let w = Int(bounds.width * scale), h = Int(bounds.height * scale)
    guard w > 0, h > 0,
          let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: ctx)
    return ctx.makeImage()
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
        print("===== PAGE \(i + 1) =====")
        print(ocr(cg))
    }
} else {
    guard let image = NSImage(contentsOf: url),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        FileHandle.standardError.write("cannot open image: \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    print("===== PAGE 1 =====")
    print(ocr(cg))
}
