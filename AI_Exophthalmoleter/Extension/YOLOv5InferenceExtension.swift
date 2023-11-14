import SwiftUI
import CoreML

class Yolov5Inference: ObservableObject {
    @Published var model = try? yolov5_periocular(configuration: MLModelConfiguration())
    @Published var image: UIImage
    @Published var size = CGSize(width: 640, height: 640)
    @Published var classes = ["L", "R"]
    @Published var message = ""
    
    init(image: UIImage) {
        self.image = image
    }
    
    func classifyAndOverlay() -> UIImage {
        let (sides, boundingBoxes) = classify()
        // Convert bounding boxes from [[Double]] to [[CGFloat]]
        let cgBoundingBoxes = boundingBoxes.map { $0.map { CGFloat($0) } }
        
        // Now call the overlayBoundingBoxes function with all necessary parameters
        return overlayBoundingBoxes(on: image, using: cgBoundingBoxes, classes: sides)
    }

    
    func classify() -> ([String], [[Double]]) {
        let resizedImage = self.image.resizeImageTo(size: size)
        let buffer = resizedImage?.convertToBuffer()
        
        guard let prediction = try? model?.prediction(image: buffer!, iouThreshold: 0.45, confidenceThreshold: 0.3) else {
            // Return empty arrays in case of error
            return ([], [])
        }
        
        // Check if the number of confidences exceeds 4, if so return empty arrays
        if prediction.confidence.count > 4 {
            print("Too many detections")
            return ([], [])
        }
        
        // Process confidences to get classes
        let sides = processConfidences(from: prediction.confidence)
        
        // Process coordinates
        let boundingBoxes = processCoordinates(from: prediction.coordinates)
        
        print("classConfidences: \(sides)")
        print("boundingBoxes: \(boundingBoxes)")
        
        return (sides, boundingBoxes)
    }
    
    func processConfidences(from mlMultiArray: MLMultiArray) -> [String] {
        var results: [String] = []
        let count = mlMultiArray.count / 2 // Assuming each class has two values in mlMultiArray
        
        for i in 0..<count {
            let index = i * 2
            let classValue = Double(truncating: mlMultiArray[index])
            let classLabel = classValue > 0.5 ? classes[1] : classes[0] // Assuming 0 is "R" and 1 is "L"
            results.append(classLabel)
        }
        
        return results
    }
    
    func processCoordinates(from mlMultiArray: MLMultiArray) -> [[Double]] {
        var results: [[Double]] = []
        let count = mlMultiArray.count / 4 // Assuming each bounding box has four values
        
        for i in 0..<count {
            let startIndex = i * 4
            var box: [Double] = []
            for j in startIndex..<(startIndex + 4) {
                box.append(Double(truncating: mlMultiArray[j]))
            }
            results.append(box)
        }
        
        return results
    }

    func overlayBoundingBoxes(on image: UIImage, using detections: [[CGFloat]], classes: [String]) -> UIImage {
        let imageSize = image.size
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)
        image.draw(at: .zero)
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        for (index, detection) in detections.enumerated() {
            let x_center = detection[0] * imageSize.width
            let y_center = detection[1] * imageSize.height
            let width = detection[2] * imageSize.width
            let height = detection[3] * imageSize.height
                
            let x_topLeft = x_center - (width / 2)
            let y_topLeft = y_center - (height / 2)
                
            let rect = CGRect(x: x_topLeft, y: y_topLeft, width: width, height: height)
                
            context.setStrokeColor(UIColor.red.cgColor)
            context.setLineWidth(width/20) // Increase the bounding box line thickness
            context.addRect(rect)
            context.strokePath()
                
            if index < classes.count {
                let label = classes[index]
                
                // Calculate font size based on bounding box width
                let fontSize = width / 5  // Adjust font size proportionally
                let font = UIFont.boldSystemFont(ofSize: fontSize)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.red
                ]
                
                let string = NSAttributedString(string: label, attributes: attributes)
                let textSize = string.size()
                
                // Draw text at the top-left corner of the bounding box
                string.draw(at: CGPoint(x: x_topLeft, y: y_topLeft - textSize.height))
            }
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage ?? image
    }

}
