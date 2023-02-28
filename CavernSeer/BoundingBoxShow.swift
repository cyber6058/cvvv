//
//  BoundingBoxShow.swift
//  CavernSeer
//
//  Created by Ho Tin Hung on 2022/6/26.
//  Copyright © 2022 Samuel K. Grush. All rights reserved.
//

import SwiftUI
import AVFoundation

struct BoundingBoxShow: UIViewRepresentable {
    
    private let view = UIView()
    
    var layer: CALayer? { view.layer}
    
    func makeUIView(context: Context) -> UIView{
        view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
    }
}

//struct BoundingBoxShow_Previews: PreviewProvider {
//    static var previews: some View {
//        BoundingBoxShow()
//    }
//}
