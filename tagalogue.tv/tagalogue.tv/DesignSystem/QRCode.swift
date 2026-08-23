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

    /// Generates at a whole-number multiple of the code's own module size.
    ///
    /// The generator emits one pixel per module — around 27 across for a short
    /// URL. Scaling that to an arbitrary 360pt box divides to 13.33 pixels a
    /// module, so some modules land 13 wide and their neighbours 14: the grid
    /// visibly wobbles, and a camera reading it across a room has to work
    /// harder than it should. Rounding the factor down to a whole number makes
    /// every module identical, at the cost of a few points of size.
    static func image(for text: String, fitting target: CGFloat = 360) -> UIImage? {
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
        let modules = max(output.extent.width, 1)
        let factor = max(1, (target / modules).rounded(.down))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: factor, y: factor))

        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        // Scale 1, so the image's point size is its pixel size and the view can
        // draw it 1:1 without resampling it back into the same problem.
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}

