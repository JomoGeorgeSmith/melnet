import SwiftUI
import UIKit
import Foundation

struct ContentView: View {
    @State private var isShowingImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var predictionResult: String?
    @State private var confidence: String?
    @State private var superimposedImage: UIImage?
    
    var body: some View {
        VStack {
            if let image = superimposedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("Prediction: \(predictionResult ?? ""), Confidence: \(confidence ?? "")")

            } else if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer()
            
            HStack{
                Button(action: {
                    self.isShowingImagePicker.toggle()
                }) {
                    Image(systemName: "camera.fill")
                        .font(.title)
                        .padding()
                }
                .sheet(isPresented: $isShowingImagePicker) {
                    ImagePickerView(isShown: self.$isShowingImagePicker, image: self.$capturedImage)
                }
                
                if capturedImage != nil {
                    Button(action: {
                        sendImageToAPI()
                    }) {
                        Image(systemName: "waveform") // Replace "yourImageName" with the name of your image asset
                            .resizable()
                            .renderingMode(.template) // Adjust rendering mode as needed
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32) // Adjust size as needed
                            .padding()
                    }
                }
            }

        }
    }
    
    private func sendImageToAPI() {
        guard let image = capturedImage else {
            print("Error: No image captured")
            return
        }

        // Convert the captured image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            print("Error: Failed to convert image to JPEG data")
            return
        }

        // Set up the API endpoint URL
        guard let apiUrl = URL(string: "http://192.168.1.26:5000/predict") else {
            print("Error: Invalid API URL")
            return
        }

        // Create a URLRequest
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"

        // Create boundary for multipart form data
        let boundary = UUID().uuidString
        let contentType = "multipart/form-data; boundary=\(boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        // Create body of the request
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Perform the API request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Not an HTTP response")
                return
            }

            print("HTTP Status Code: \(httpResponse.statusCode)")

            if let data = data,
               let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                // Handle JSON response
                print("Response JSON: \(jsonResponse)")
                
                if let prediction = jsonResponse["prediction"] as? [String: Any],
                   let result = prediction["result"] as? String,
                   let confidence = prediction["confidence"] as? String {
                    DispatchQueue.main.async {
                        self.predictionResult = result
                        self.confidence = confidence
                    }
                }
                
                if let superimposedImageBase64 = jsonResponse["superimposed_image"] as? String,
                   let imageData = Data(base64Encoded: superimposedImageBase64),
                   let image = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        self.superimposedImage = image
                    }
                }
            } else {
                print("Error: Invalid JSON format")
            }
        }

        task.resume()
    }
    
    private func refresh() {
        capturedImage = nil
        predictionResult = nil
        confidence = nil
        superimposedImage = nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var isShown: Bool
    @Binding var image: UIImage?
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(isShown: $isShown, image: $image)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera // You can change this to .photoLibrary if needed
        picker.delegate = context.coordinator
        picker.allowsEditing = true // Enable editing
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding var isShown: Bool
        @Binding var image: UIImage?
        
        init(isShown: Binding<Bool>, image: Binding<UIImage?>) {
            _isShown = isShown
            _image = image
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                image = originalImage
            }
            isShown = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isShown = false
        }
    }
}
