//
//  ContentView.swift
//  CoreMLwithSwiftUI
//
//  Created by Moritz Philip Recke for Create with Swift on 24 May 2021.
//  https://github.com/create-with-swift/coreml-with-swiftui
//


import SwiftUI
import CoreML

class User : ObservableObject {
    @Published var sourceType: UIImagePickerController.SourceType = .camera
    @Published var image: UIImage?
    @Published var samplePhotos = ["22_R22L22", "62_R17L18",
                                   "72_R16L15", "1001_L"]
    //撮影モードがデフォルト
    }

struct ContentView: View {
    @ObservedObject var user = User()
    @State private var goTakePhoto: Bool = false //判定スタートボタン
    var body: some View {
        
        NavigationStack {
            VStack(spacing:60) {
                Text("AI\nExophthalmometer")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .padding(.bottom)
                    .multilineTextAlignment(.center)
                
                Image("1001_L")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 192)
                    .padding(.bottom)
            }
            
//            VStack(spacing: 50) {
//                NavigationLink {
//                    StreamingView(user:user)
//                } label: {
//                    Image(systemName: "video")
//                    Text("Real-time classification")
//                }
//                .foregroundColor(Color.white)
//                .font(Font.largeTitle)
//                .frame(minWidth:0, maxWidth: CGFloat.infinity, minHeight:75)
//                .background(Color.blue)
//                .padding()
                
                    NavigationLink {
                        UploadView(user:user)
                    } label: {
                        Image(systemName: "camera")
                        Text("Photographic")
                    }
                    .foregroundColor(Color.white)
                    .font(Font.largeTitle)            .frame(minWidth:0, maxWidth: CGFloat.infinity, minHeight:75)
                    .background(Color.blue)
                    .padding()
                
                
                    NavigationLink {
                        RealTimeView(user:user)
                    } label: {
                        Image(systemName: "video")
                        Text("Real-time")
                    }
                    .foregroundColor(Color.white)
                    .font(Font.largeTitle)            .frame(minWidth:0, maxWidth: CGFloat.infinity, minHeight:75)
                    .background(Color.blue)
                    .padding()

            }
        }
}
