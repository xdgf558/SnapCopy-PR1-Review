import CoreImage
import UIKit

final class ImageEnhancementService {
    private let context = CIContext()

    func enhance(_ image: UIImage, preset: ImageEnhancementPreset) -> UIImage {
        guard let inputImage = CIImage(image: image) else {
            return image
        }

        let outputImage: CIImage
        switch preset {
        case .natural:
            outputImage = sharpen(colorControls(inputImage, brightness: 0.03, contrast: 1.04, saturation: 1.03), amount: 0.18)
        case .warm:
            let warmedImage = temperature(colorControls(inputImage, brightness: 0.04, contrast: 1.04, saturation: 1.08))
            outputImage = sharpen(warmedImage, amount: 0.14)
        case .clean:
            let cleanImage = noiseReduction(colorControls(inputImage, brightness: 0.06, contrast: 1.08, saturation: 0.98))
            outputImage = sharpen(cleanImage, amount: 0.12)
        }

        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func colorControls(
        _ image: CIImage,
        brightness: Double,
        contrast: Double,
        saturation: Double
    ) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        return filter.outputImage ?? image
    }

    private func temperature(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
        filter.setValue(CIVector(x: 5600, y: 0), forKey: "inputTargetNeutral")
        return filter.outputImage ?? image
    }

    private func noiseReduction(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CINoiseReduction") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.02, forKey: "inputNoiseLevel")
        filter.setValue(0.4, forKey: "inputSharpness")
        return filter.outputImage ?? image
    }

    private func sharpen(_ image: CIImage, amount: Double) -> CIImage {
        guard let filter = CIFilter(name: "CISharpenLuminance") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(amount, forKey: kCIInputSharpnessKey)
        return filter.outputImage ?? image
    }
}
