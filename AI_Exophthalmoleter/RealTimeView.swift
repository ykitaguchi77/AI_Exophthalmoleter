//
//  RealTimeView.swift
//  CorneAI_ios_ver2
//
//  Created by Yoshiyuki Kitaguchi on 2023/01/01.
//

import SwiftUI
import CoreML
import AVFoundation


struct RealTimeView: View {

    @ObservedObject var user: User
    @State private var image: UIImage?
    @State private var displayedImage: UIImage?
    @State private var isStreaming: Bool = true
    @State var showAlert = false
    @State private var result_YOLO: ([String], [[Double]]) = ([], [])
    @State var result_MobileNet: (String) = ("")
    @State var rightEyeProtrusion = 0.0
    @State var leftEyeProtrusion = 0.0
    let videoCapture = VideoCapture()
    
    @State private var rect: CGRect = .zero //スクリーンショット用
    @State var screenImage: UIImage? = nil //スクリーンショット用
    @State var timer: Timer? //結果を0.5秒間隔で出力するためのタイマー
    @State var inferenceResult: String = ""

    
    var body: some View {
        VStack {
            if let displayedImage = displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFit()
            }

            if image != nil {
                Text("\(inferenceResult)")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom)
                    .onAppear(perform: startInferenceTimer)
            }

            if image != nil {
                Button("Screenshot") {
                    takeScreenshot()
                }
                .font(.largeTitle)
            }
        }
        .onAppear {
            setupVideoCapture()
        }
        .onDisappear(perform: videoCapture.stop)
        .background(RectangleGetter(rect: $rect))
    }
    
    // Function to set up video capture
    private func setupVideoCapture() {
        videoCapture.run { sampleBuffer in
            if let convertImage = self.UIImageFromSampleBuffer(sampleBuffer) {
                DispatchQueue.main.async {
                    self.image = convertImage
                }
            }
        }
    }

    
    // Function to take a screenshot
    private func takeScreenshot() {
        DispatchQueue.global(qos: .userInitiated).async {
            let screenshot = UIApplication.shared.windows.first?.rootViewController?.view?.getImage(rect: self.rect)
            DispatchQueue.main.async {
                self.screenImage = screenshot
                UIImageWriteToSavedPhotosAlbum(screenshot!, nil, nil, nil)
            }
        }
    }

    func UIImageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            let context = CIContext()
            if let image = context.createCGImage(ciImage, from: imageRect) {
                let cropped = image.cropToSquare()
                //classifyImage(image: UIImage(cgImage: cropped))
                return UIImage(cgImage: cropped)
            }
        }
        return nil
    }
    

    // タイマーによる推論関数
    // Timer-based inference function
    func startInferenceTimer() {
        // Invalidate any existing timer to prevent multiple timers running simultaneously
        timer?.invalidate()

        // Set up a new timer that triggers the inference function every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Call the performInference function on each timer tick
            self.performInference()
        }
    }

    
    // Function to perform inference
    private func performInference() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = self.image else { return }
         
            let yolov5Inference = Yolov5Inference(image: image)
            let (detectedClasses, boundingBoxes) = yolov5Inference.classify()
            
            // Check if the detection is valid
            if isValidDetection(detectedClasses) {
                let cgBoundingBoxes = boundingBoxes.map { $0.map { CGFloat($0) } }
                let imageWithBoxesAndLabels = yolov5Inference.overlayBoundingBoxes(on: image, using: cgBoundingBoxes, classes: detectedClasses)
                
                DispatchQueue.main.async {
                    self.displayedImage = imageWithBoxesAndLabels
                }
            
                // 検出された各クラスに対して処理
                for (index, detectedClass) in detectedClasses.enumerated() {
                    if detectedClass == "R" || detectedClass == "L" {
                        // YOLOのバウンディングボックスを取得
                        let boundingBox = boundingBoxes[index]
                        
                        // バウンディングボックスに基づいて目の領域を切り出し
                        let xCenter = boundingBox[0]
                        let yCenter = boundingBox[1]
                        let width = boundingBox[2]
                        let height = boundingBox[3]

                        let imageSize = image.size

                        // YOLOモデルは中心座標と幅/高さを使用してバウンディングボックスを定義するので、
                        // これをUIImageの座標系に変換する必要があります。
                        let x = (xCenter - width / 2.0) * imageSize.width
                        let y = (yCenter - height / 2.0) * imageSize.height
                        let cropWidth = width * imageSize.width
                        let cropHeight = height * imageSize.height

                        let cropRect = CGRect(x: x, y: y, width: cropWidth, height: cropHeight)
                        let croppedImage = image.crop(to: cropRect)
                        
                        // MobileNetを用いて目の突出度を計算
                        let mobileNetInference = MobileNetInference(image: croppedImage!)
                        mobileNetInference.regression()
                        let eyeProtrusion = mobileNetInference.eyeProtrusionEstimate
                        print("eyeProtrusion: \(eyeProtrusion)")
                        // 右目または左目の突出度を更新
                        if detectedClass == "R" {
                            rightEyeProtrusion = eyeProtrusion
                        } else if detectedClass == "L" {
                            leftEyeProtrusion = eyeProtrusion
                        }
                    }
                }
            } else {
                // If invalid detection, display the original sample buffer image
                DispatchQueue.main.async {
                    self.displayedImage = image
                }
            }
            // 推論結果を更新
            inferenceResult = "Right: \(String(format: "%.1f", rightEyeProtrusion))mm, Left: \(String(format: "%.1f", leftEyeProtrusion))mm"

        }
    }
    
    func isValidDetection(_ detectedClasses: [String]) -> Bool {
        let rCount = detectedClasses.filter { $0 == "R" }.count
        let lCount = detectedClasses.filter { $0 == "L" }.count

        // Check conditions: only one 'R' and 'L', and at least one detection
        return rCount <= 1 && lCount <= 1 && (rCount + lCount) > 0
    }

}






