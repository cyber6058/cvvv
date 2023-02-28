//
//  shareSheet.swift
//  CavernSeer
//
//  Created by Ho Tin Hung on 2022/9/28.
//  Copyright © 2022 Samuel K. Grush. All rights reserved.
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable{
    
    var items: [Any]
    func makeUIViewController(context: Context) -> some UIViewController {
        let view = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return view
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    
}
