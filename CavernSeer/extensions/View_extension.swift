//
//  View_extension.swift
//  CavernSeer
//
//  Created by Ho Tin Hung on 2022/9/28.
//  Copyright © 2022 Samuel K. Grush. All rights reserved.
//

import SwiftUI
import ReplayKit

extension View{
    func startRecording(completion: @escaping (Error?)->()){
        let recorder = RPScreenRecorder.shared()
        recorder.startRecording(handler: completion)
    }

    func stopRecording(save_URL: URL? ) async throws -> URL{
        let name = UUID().uuidString + ".mov"
        
        
        if save_URL != nil {
            let recorder = RPScreenRecorder.shared()
            let url = save_URL!.appendingPathComponent(name)
            try await recorder.stopRecording(withOutput: url)
            return save_URL!
        }
        
        else{
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            let recorder = RPScreenRecorder.shared()
            try await recorder.stopRecording(withOutput: url)
            return url
        }
    }
    
    func cancelRecording(){
        let recorder = RPScreenRecorder.shared()
        recorder.discardRecording {
        }
        print("Cancel recording")
    }

    func shareSheet(Show: Binding<Bool>, items: [Any?]) -> some View{
        
        return self
            .sheet(isPresented: Show) {
                
            } content: {
                let items = items.compactMap { item -> Any? in
                    return item
                }
                
                if !items.isEmpty{
                    ShareSheet(items: items)
                }
            }
    }
}
