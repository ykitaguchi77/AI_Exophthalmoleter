//
//  MobileNet_interferenceExtension.swift
//  GravAI_ios
//
//  Created by Yoshiyuki Kitaguchi on 2023/03/24.
//

import SwiftUI
import CoreML

class MobileNetInference: ObservableObject {
    @Published var model = try? mobilenetv3_large_100_1(configuration: MLModelConfiguration())
    @Published var image: UIImage
    @Published var size = CGSize(width: 224, height: 224)
    @Published var eyeProtrusionEstimate: Double = 0.0
    @Published var errorMessage: String?
    
    init(image: UIImage) {
        self.image = image
    }
    
    func regression() {
        guard let resizedImage = self.image.resizeImageTo(size: size),
              let buffer = resizedImage.convertToBuffer() else {
            self.errorMessage = "Error processing image"
            return
        }

        do {
                let output = try model?.prediction(input_1: buffer)
                if let output = output {
                    if let multiArrayOutput = output.featureValue(for: "linear_0")?.multiArrayValue {
                        // 最初の要素にアクセスする
                        let firstValue = multiArrayOutput[0].floatValue
                        self.eyeProtrusionEstimate = Double(firstValue)
                        //print("Eye Protrusion Estimate: \(self.eyeProtrusionEstimate)")
                    } else {
                        self.errorMessage = "Expected 'linear_0' MLMultiArray output from model is not available"
                    }
                } else {
                    self.errorMessage = "Model failed to make a prediction"
                }
            } catch {
                self.errorMessage = "An error occurred during prediction: \(error.localizedDescription)"
            }
    }


    
    

}


