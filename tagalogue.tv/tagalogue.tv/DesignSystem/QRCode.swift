//
//  QRCode.swift
//  tagalogue.tv
//
//  A QR code as paper-on-ink, drawn to the same rules as everything else:
//  square corners, no smoothing, no rounded "designer" modules. It has to be
//  read by a phone camera from across a room, so contrast and crisp edges
//  matter more than styling.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRCode {

    /// Generates at the code's native module size; the view scales it up with
    /// `.interpolation(.none)` so the squares stay hard-edged.
    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        // Medium correction: the code is shown clean and undamaged, so the
        // extra redundancy of H would only make the modules smaller.
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        // Left as dark modules on a transparent ground, and the view sets it on
        // a paper plate. Inverting to light-on-ink would suit the palette better
        // and scan far worse — phone cameras expect dark-on-light, and this code
        // has to be read across a room in one try.
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

