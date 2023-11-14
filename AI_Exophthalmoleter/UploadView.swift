//
//  UploadView.swift
//  AI-Exophthalmometry
//
//  Created by Yoshiyuki Kitaguchi on 2023/01/01.
//

import SwiftUI
import CoreML

struct UploadView: View {
    @ObservedObject var user: User
    @State private var image: UIImage?
    @State private var processedImage: UIImage? // State for processed image
    @State var showingImagePicker = false
    @State var sourceType:  UIImagePickerController.SourceType = .camera
    @State var currentIndex: Int = 0
    @State var samplePhotos = ["22_R22L22", "62_R17L18",
                               "72_R16L15", "1001_L"]
    @State private var result_YOLO: ([String], [[Double]]) = ([], [])
    @State var result_MobileNet: (String) = ("")
    @State var rightEyeProtrusion = 0.0
    @State var leftEyeProtrusion = 0.0


    let model = try? yolov5_periocular(configuration: MLModelConfiguration())
    
    @State private var rect: CGRect = .zero //スクリーンショット用
    @State var screenImage: UIImage? = nil //スクリーンショット用
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Display processedImage if available, otherwise image or sample photo
                if let uiImage = processedImage ?? image {
                    let targetSize = CGSize(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                    let letterboxedImage = uiImage.letterboxImage(targetSize: targetSize)
                    Image(uiImage: letterboxedImage)
                        .resizable()
                        .frame(width: geometry.size.width*0.9, height: geometry.size.width*0.9)
                } else if let uiImage = image {
                        Image(uiImage: image!.cropSquare(image: uiImage))
                            .resizable()
                            .frame(width: geometry.size.width*0.9, height: geometry.size.width*0.9)
                } else {
                    Image(user.samplePhotos[currentIndex], bundle: .main)
                        .resizable()
                        .frame(width: geometry.size.width*0.9, height: geometry.size.width*0.9)
                }
                Spacer().frame(height: 32)
                
                
                
                
                HStack{
                    Button(action: {
                        self.processedImage = nil
                        sourceType = .camera
                        showingImagePicker = true /*またはself.show.toggle() */
                    }) {
                        HStack{
                            Image(systemName: "camera")
                            Text("Take Photo")
                        }
                        .foregroundColor(Color.white)
                        .font(Font.largeTitle)
                    }
                    .frame(minWidth:0, maxWidth:CGFloat.infinity, minHeight: 50)
                    .background(Color.black)
                    .padding()
                    
                    Button(action: {
                        self.processedImage = nil
                        sourceType = .photoLibrary
                        showingImagePicker = true /*またはself.show.toggle() */
                        
                    }) {
                        HStack{
                            Image(systemName: "folder")
                            Text("Up")
                        }
                        .foregroundColor(Color.white)
                        .font(Font.largeTitle)
                    }
                    .frame(minWidth:0, maxWidth:200, minHeight: 50)
                    .background(Color.black)
                    .padding()
                }
                
                HStack{
                    Button(action: {
                        if self.currentIndex < self.user.samplePhotos.count - 1 {
                            self.currentIndex = self.currentIndex + 1
                            self.processedImage = nil
                        } else {
                            self.currentIndex = 0
                        }
                    }){
                        Text("sample")
                    }
                    .padding()
                    .foregroundColor(Color.white)
                    .background(Color.gray)
                    
                    //Inference
                    Button(action: {
                        DispatchQueue.global(qos: .userInitiated).async {
                            let yolov5Inference = Yolov5Inference(image: image ?? UIImage(imageLiteralResourceName: samplePhotos[currentIndex]))
                            let (detectedClasses, boundingBoxes) = yolov5Inference.classify()
                            let cgBoundingBoxes = boundingBoxes.map { $0.map { CGFloat($0) } }
                            let originalImage = image ?? UIImage(imageLiteralResourceName: samplePhotos[currentIndex])
                            let imageWithBoxesAndLabels = yolov5Inference.overlayBoundingBoxes(on: originalImage, using: cgBoundingBoxes, classes: detectedClasses)

                            // UI更新はメインスレッドで行う
                            DispatchQueue.main.async {
                                self.processedImage = imageWithBoxesAndLabels
                            }

                            for (index, detectedClass) in detectedClasses.enumerated() {
                                if detectedClass == "R" || detectedClass == "L" {
                                    let yoloBBox = boundingBoxes[index].map { CGFloat($0) }
                                    let imageSize = originalImage.size
                                    let x = yoloBBox[0] * imageSize.width - yoloBBox[2] * imageSize.width / 2
                                    let y = yoloBBox[1] * imageSize.height - yoloBBox[3] * imageSize.height / 2
                                    let width = yoloBBox[2] * imageSize.width
                                    let height = yoloBBox[3] * imageSize.height
                                    let cropRect = CGRect(x: x, y: y, width: width, height: height)
                                    let croppedImage = originalImage.crop(to: cropRect)
                                    
                                    // 画像保存処理を追加（今回は保存不要なのでコメントアウトしておく）
    //                                if let croppedImage = croppedImage {
    //                                    if let pngData = croppedImage.pngData() {
    //                                        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    //                                        let imageName = detectedClass + String(index)
    //                                        let fileURL = documentsURL.appendingPathComponent("\(imageName).png")
    //
    //                                        do {
    //                                            if let pngData = croppedImage.pngData() {
    //                                                try pngData.write(to: fileURL)
    //                                                print("画像を保存しました: \(fileURL.absoluteString)")
    //                                            } else {
    //                                                print("画像データを取得できませんでした。")
    //                                            }
    //                                        } catch {
    //                                            print("画像の保存に失敗しました: \(error.localizedDescription)")
    //                                        }
    //                                    } else {
    //                                        print("画像データを取得できませんでした。")
    //                                    }
    //                                } else {
    //                                    print("クロップされた画像が存在しません。")
    //                                }

                                    let mobileNetInference = MobileNetInference(image: croppedImage!)
                                    mobileNetInference.regression()

                                    DispatchQueue.main.async {
                                        if detectedClass == "R" {
                                            rightEyeProtrusion = mobileNetInference.eyeProtrusionEstimate
                                        } else if detectedClass == "L" {
                                            leftEyeProtrusion = mobileNetInference.eyeProtrusionEstimate
                                        }
                                    }
                                }
                            }
                        }
                    }) {
                        Text("classify")
                    }
                    .padding()
                    .foregroundColor(Color.white)
                    .background(Color.green)

                    

                    Button(action: {
                        if image != nil{
                            let rotatedImage = image!.rotatedBy(degree: 270)
                            image = rotatedImage
                            print("rotated!")
                            //countUp(rotate: rotate)
                        }
                    }
                    ) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color.white)
                            .font(Font.largeTitle)
                    }
                    .frame(minWidth:0, maxWidth:geometry.size.width*0.25, minHeight: 50)
                    .background(Color.black)
                    .padding()
                    
                }
                
                //show results
                Text("Right: \(rightEyeProtrusion, specifier: "%.1f")mm, Left: \(leftEyeProtrusion, specifier: "%.1f")mm")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                //screenshot button
                if image != nil {
                    Button("screenshot"){
                        //classifyImage(image: image!)
                        self.screenImage = UIApplication.shared.windows[0].rootViewController?.view!.getImage(rect: self.rect) //ここがうまくいっていない
                        UIImageWriteToSavedPhotosAlbum(screenImage!, nil, nil, nil)
                        //print("screenshot done!")
                    }
                }
                
                
            }.sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: self.$sourceType, selectedImage: $image)
        }
        }
        .background(RectangleGetter(rect: $rect))
    }
}
