//
//  DrawBox.swift
//  SwiftUI-CoreMl
//
//  Created by Ho Tin Hung on 2022/6/22.
//

import SwiftUI

struct DrawBox: Shape {
    
    var x : CGFloat
    var y : CGFloat
    var w : CGFloat
    var h : CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: x - w/2 , y: y - h/2))
        
        path.addLine(to: CGPoint(x: x - w/2, y: y + h/2))
        path.addLine(to: CGPoint(x: x + w/2, y: y + h/2))
        path.addLine(to: CGPoint(x: x + w/2, y: y - h/2))
        path.closeSubpath()
//        path.closeSubpath()
        
        return path
    }
    
    init(RandomBox : [CGFloat]){
        self.x = RandomBox[0]
        self.y = RandomBox[2]
        self.w = RandomBox[2]
        self.h = RandomBox[3]
    }
    
}

struct DrawBox_Previews: PreviewProvider {
    static var previews: some View {
//        DrawBox()
        
        let RandomBox1 = [CGFloat.random(in: 0...300), CGFloat.random(in: 0...300), CGFloat.random(in: 0...300), CGFloat.random(in: 0...300)]
        let RandomBox2 = [CGFloat.random(in: 0...300), CGFloat.random(in: 0...300), CGFloat.random(in: 0...300), CGFloat.random(in: 0...300)]
        ZStack{
            Group{
                DrawBox(RandomBox: RandomBox1)
                    .stroke(lineWidth: 5)
                DrawBox(RandomBox: RandomBox2)
                    .stroke(lineWidth: 5)
            }
            
        }
        
    }
}
