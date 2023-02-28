//
//  ScannerTabView.swift
//  CavernSeer
//
//  Created by Samuel Grush on 6/27/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//

import CoreML
import SwiftUI /// AnyView, View, Image, EnvironmentObject
import VideoToolbox
import Vision
import ReplayKit

import RealityKit /// ARView, SceneEvents
import ARKit /// other AR*, UIView, UIGestureRecognizer, NSLayoutConstraint

final class ScannerTab : TabProtocol {
    var isSupported: Bool { ScannerModel.supportsScan }

    var tab: Tabs = Tabs.ScanTab
    var tabName = "Scanner"
    var tabImage: Image { Image(systemName: "camera.viewfinder") }

    func getTabPanelView(selected: Bool) -> AnyView {
        AnyView(ScannerTabView(isSelected: selected, reloc_map: nil))
    }
}

struct ScannerTabView: View {
    init(isSelected: Bool, reloc_map: URL?){
        print("ScannerTabView inited!!")
        self.isSelected = isSelected
        
//        if(reloc_map != nil){
//            self.reloc_map_url = reloc_map!
//            print("Relocing!!!")
//            print(reloc_map!)
////            print(self.reloc_map_url!)
//        }
//        else{
//        }
        
        self.control = ScannerControlModel(reloc_map: nil)
        
        guard let map = reloc_map else { return }
        print("Relocing!!!")
        self.reloc_map_url = map
        print(self.reloc_map_url)
        
        self.control = ScannerControlModel(reloc_map: self.reloc_map_url)
        
    }
    
//    let timer5_0 = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let controlFrameHeight: CGFloat = 80

    var isSelected: Bool
    var reloc_map_url: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    @State var isRecording: Bool = false
    @State var showPanel: Bool = true
    @State var url: URL?
    @State var shareVideo: Bool = false
    
    
    
//    let DetectionModel : _3cls_detect_b16_TL_Iteration_1000
//    let visionModel : VNCoreMLModel

    @EnvironmentObject
    private var scanStore: ScanStore

    @Environment(\.fakeScan)
    private var fakeScan: Bool

    @ObservedObject
    private var control : ScannerControlModel
    
    @State
    var count : Int = 0
    
    @AppStorage("iouThreshold") var iouThreshold = 0.3
    @AppStorage("confidenceThreshold") var confidenceThreshold = 0.4
    
    
    @State private var image: Image?
    @State private var showingImagepicker = false
    
    var body: some View {
        
        ZStack(alignment: .top){
            ZStack(alignment: .bottom) {
                if isSelected {
                    ScannerContainerView(control: self.control, visionModel: self.control.visionModel)
                        .edgesIgnoringSafeArea(.all)
                }
                
                control_panel
                    .background(Color(UIColor.systemGray6).opacity(0.4).ignoresSafeArea())
                }

            VStack{
                Group{ Text("Map: ") + Text(control.Mapping_status ).font(Font.headline.weight(.bold)) + Text(" || Track: ") + Text(control.Tracking_status).font(Font.headline.weight(.bold))}
                Group{ Text("Location: ") + Text(control.Cam_Loc        ).font(Font.headline.weight(.bold))}
            }
                .frame(width: 250, height: 100, alignment: .center)
                .background(.ultraThinMaterial, in : RoundedRectangle(cornerRadius: 16.0))
            
            VStack(alignment: .trailing){
                Text("\(self.control.Last_defect_name)")
                Text("\(self.control.Last_edge_1)")
                Text("\(self.control.Last_edge_2)")
                Text("\(self.control.Last_edge_3)")
                Text("\(self.control.Last_edge_4)")
                 }
                .frame(width: 200, height: 100, alignment: .center)
                .background(.ultraThinMaterial, in : RoundedRectangle(cornerRadius: 16.0))
                .offset(x: +500)
        }
    }

    private var scanEnabled: Bool {
        return self.control.scanEnabled || self.fakeScan
    }
    
    private var control_panel: some View {
        VStack {
            if !self.control.message.isEmpty {
                HStack {
                    Text(self.control.message)
                }
            }
            
            
            HStack{
                Toggle("Panel", isOn: $showPanel)
                    .labelsHidden()
                    .padding()
                
                VStack{
                    captureButton_for_yolo
                    Text("Capture for yolo")
                }
                
                VStack{
                    Remove_Button
                    Text("Remove")
                }
            }
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: .trailing, vertical: .center))
            
            if self.showPanel{
            
                HStack(alignment: .bottom) {
                    debugButtons.frame(width: 80, height: controlFrameHeight)
                    
                    Spacer()
                    
                    if scanEnabled {
                        saveOrCancel
                    } else {
                        captureButton
                        Toggle("Enable frame capture", isOn: self.$control.frameCaptureEnabled) .frame(width: UIScreen.main.bounds.height / 5)
                        Toggle("Enable screen recording", isOn: self.$control.screenRecordEnabled) .frame(width: UIScreen.main.bounds.height / 5)
                    }

                    if scanEnabled{
                        HStack{

                            VStack{
                                HStack{
                                Button(action: {self.control.Change_defectname_yolo(to: "concrete crack")})  { Text("C-cracks") }.foregroundColor(.white).background(Color.blue) .padding(5)
                                Button(action: {self.control.Change_defectname_yolo(to: "exposed rebar")})    { Text("rebar") }.foregroundColor(.white).background(Color.blue) .padding(5)
                                Button(action: {self.control.Change_defectname_yolo(to: "paint bubble")})    { Text("Bubbles") }.foregroundColor(.white).background(Color.blue) .padding(5)
                                }
                                HStack{
                                Button(action: {self.control.Change_defectname_yolo(to: "paint crack")})     { Text("P-cracks") }.foregroundColor(.white).background(Color.blue) .padding(5)
                                Button(action: {self.control.Change_defectname_yolo(to: "paint peeling")})    { Text("Peeling") }.foregroundColor(.white).background(Color.blue) .padding(5)
                                
                                    
                                }
    //                            }
                                Text(self.control.defectname_yolo).background(Rectangle().fill(Color.clear).shadow(radius: 3))
                            }
                            .padding()
                            .background(Rectangle().fill(Color.clear).shadow(radius: 3)).border(Color.blue, width: 3)
                            .frame(width: 300)
                            
                            
                            VStack {
                                Slider(value: $iouThreshold, in: 0...0.4)
                                Text("IoU threshold: \(String(format: "%.2f", iouThreshold))")
                                    .font(.body)
                                
                                Slider(value: $confidenceThreshold, in: 0...0.6)
                                    Text("Confidence threshold: \(String(format: "%.2f", confidenceThreshold))")
                                    .font(.body)
                            }
                            
                            
                            VStack{
                                VStack {
    //                                Text("X:\(control.Boundingbox_ind_x)")
                                    
                                    Text(String(format:"X:%.0f, Y:%.0f", arguments:[control.Boundingbox_ind_x, control.Boundingbox_ind_y]))
                                         
                                    Slider(value: $control.Boundingbox_ind_x, in: 50...600, step: 10) {
                                        Text("X")
                                    }
                                    Slider(value: $control.Boundingbox_ind_y, in: 50...400, step: 10) {
                                        Text("Y")
                                    }
                                }
                                
                                
                                Stepper(
                                    onIncrement: {
                                        control.allow_dist += 0.05
                                    },
                                    onDecrement: {
                                        control.allow_dist -= 0.05
                                        if control.allow_dist < 0.05 { control.allow_dist = 0.05 }
                                    },
                                    label: { Text("Allow dist(m): \(String(format: "%.1f", control.allow_dist))") }
                                )
                            }
                            
                            VStack{
                            Toggle("Detection", isOn: self.$control.DetectEnabled) .frame(width: UIScreen.main.bounds.height / 6)
                                    .onChange(of: self.control.DetectEnabled) { newValue in
                                        self.control.model!.cleanBbox()
                                    }
                            Toggle("Bounding box", isOn: self.$control.BboxEnabled) .frame(width: UIScreen.main.bounds.height / 6)
                            Toggle("Ray Cast", isOn: self.$control.SphereEnabled) .frame(width: UIScreen.main.bounds.height / 6)
                            }.padding()
                            
                        }
                        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: .trailing, vertical: .center))
                    }

                        
                    if scanEnabled {
                        flashButton.frame(width: 100, height: controlFrameHeight)
                    } else {
                        Spacer().frame(width: 100, height: controlFrameHeight)
                    }
            
                }
                .padding(.init(top: 5, leading: 10, bottom: 5, trailing: 5))
                
            }
        }
    }
    
    func getDocumentsDirectory() -> URL {
        // find all possible documents directories for this user
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

        // just send back the first one, which ought to be the only one
        return paths[0]
    }

    private var captureButton: some View {

        let color: Color = .primary

        /// the standard start-capture button
        return Button(
            action: {
                self.control.startScan()
                
                if control.screenRecordEnabled{
                    startRecording { error in
                        if let error = error {
                            print(error.localizedDescription)
                            return
                        }
                    }
                }
                
            },
            label: {
                Circle()
                    .foregroundColor(color)
                    .frame(width: 70, height: 70, alignment: .center)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .frame(width: 80, height: 80, alignment: .center)
                    )
            }
        )
    }
    
    private var RecordButton: some View {

        return Button(
            action: {

                if isRecording{
                    //Stopping
                    Task{
                        do {
                            self.url = try await stopRecording(save_URL: nil)
                            isRecording = false
                            shareVideo.toggle()
                            }
                        catch {
                            print(error.localizedDescription)
                        }
                    }

                }
                else{
                    startRecording { error in
                        if let error = error {
                            print(error.localizedDescription)
                            return
                        }
                    }
                }
            },
            label: {
                Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                    .font(.largeTitle)
                    .foregroundColor(isRecording ? .red : .black)
            }
        )
    }
    
    
    private var StopRecordButton: some View {

        let color: Color = .primary

        /// the standard start-capture button
        return Button(
            action: {
                
                RPScreenRecorder.shared().stopRecording { previewViewController, error in
                    if error == nil {
                        // There isn't an error and recording stops successfully. Present the view controller.
                        print("Presenting Preview View Controller")
                    }
                }
                
            },
            label: {
                Circle()
                    .foregroundColor(.green)
                    .frame(width: 70, height: 70, alignment: .center)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .frame(width: 80, height: 80, alignment: .center)
                    )
            }
        )
    }
    
    
    private var captureButton_during_scan: some View {

        let color: Color = .primary

        /// the standard start-capture button
        return Button(
            action: {
                count += 1
                
                var out_txt = """
                            ####################################################################################
                            Camera position: \(self.control.model?.arView?.cameraTransform.matrix.toPosition()), \n
                            Camera matrix: \(self.control.model?.arView?.cameraTransform.matrix), \n
                            Time: \(Date.now)
                            \n
                            """
                
                let url_txt = self.control.save_folder.appendingPathComponent("Manual_capture_\(self.control.Captured_image_id).txt")
                    
                do { try out_txt.write(to: url_txt, atomically: true, encoding: String.Encoding.utf8) } catch {}
                
                let url = self.control.save_folder.appendingPathComponent("Manual_capture_\(self.control.Captured_image_id).png")
                
                do {
                    try self.control.Captured_image!.pngData()!.write(to: url)
                } catch {
                    print(error.localizedDescription)
                }
                
                self.control.Captured_image_id += 1
                
            },
            label: {
                Circle()
                    .foregroundColor(color)
                    .frame(width: 30, height: 30, alignment: .center)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .frame(width: 40, height: 40, alignment: .center)
                    )
            }
        )
    }
    
    private var DeleteButton: some View {


        /// the standard start-capture button
        return Button(
            action: {
//                self.control.model!.surveyLines! = self.control.model!.surveyLines!.drawables.dropLast(5)
//                self.control.model!.surveyStations = self.control.model!.surveyStations.dropLast(6)
            },
            label: {
                Image(systemName: "trash.fill")
            }
        )
    }
    
    private var Remove_Button: some View {

        let color: Color = .red

        return Button(
            action: {
                guard
                    let last_anchor = self.control.model!.Anchors_list.last,
                    var lines = self.control.model!.surveyLines?.drawables,
                    var stations = self.control.model?.surveyStations,
                    var lineModel = self.control.model?.lineModel
                        
                else {return}
                
//                for _ in 0...3 {
//                    self.control.model!.arView!.scene.removeAnchor(lineModel.last!)
//                    lineModel.removeLast()
//                }
                
                print("Removed!!!")
                
                self.control.model!.arView!.scene.removeAnchor(last_anchor)
                self.control.model!.Anchors_list.removeLast()
                
                self.control.model!.surveyLines!.drawables.removeLast(5)
                self.control.model!.surveyStations.removeLast(6)
                
//                print("DEBUG line model count \(self.control.model!.lineModel.count)")
                
                
                
                
//                control.model?.drawView.cl
                
//                if (lines.count >= 5) {lines.removeLast(5)}
//                if (stations.count >= 6) {stations.removeLast(6)}
//
            },
            label: {
                Circle()
                    .foregroundColor(color)
                    .frame(width: 30, height: 30, alignment: .center)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .frame(width: 40, height: 40, alignment: .center)
                    )
            }
        )
    }

    
    private var captureButton_for_yolo: some View {

        let color: Color = .brown
        
        /// the standard start-capture button
        return Button(
            action: {
                
                let x0 = 700 - Int(control.Boundingbox_ind_x/2)
                let y0 = 450 - Int(control.Boundingbox_ind_y/2)
                let w  = Int(control.Boundingbox_ind_x)
                let h  = Int(control.Boundingbox_ind_y)

                
                if (self.control.Mapping_status == "Mapped") && (self.control.Tracking_status == "Normal") {
                    self.control.model?.handleTap_for_yolo_4_pts(
                        [CGPoint(x: x0    , y: y0),  //Top left
                         CGPoint(x: x0 + w, y: y0),  //Top right
                         CGPoint(x: x0 + w, y: y0 + h),  //Bottom right
                         CGPoint(x: x0    , y: y0 + h)   //Bottom left
                        ], defectname: String(self.control.defectname_yolo))
                }
            },
            label: {
                Circle()
                    .foregroundColor(color)
                    .frame(width: 30, height: 30, alignment: .center)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .frame(width: 40, height: 40, alignment: .center)
                    )
            }
        )
    }

    private var saveOrCancel: some View {
        VStack(alignment: .center) {
            /// cancel button
            Button(
                action: { self.control.cancelScan()
                    cancelRecording()
                    
                },
                label: {
                    Text("Cancel Scan")
                        .foregroundColor(.red)
                        .padding(5)
                }
            )

            /// save-capture button
            Button(
                action: {
                    self.control.saveScan(scanStore: self.scanStore)
                    Task{
                        do {
                            self.url = try await stopRecording(save_URL: self.control.model!.Vid_folder)
                            isRecording = false
                            }
                        catch {
                            print(error.localizedDescription)
                        }
                    }
                },
                label: {
                    Circle()
                        .foregroundColor(.secondary)
                        .frame(width: 70, height: 70, alignment: .center)
                }
            )
        }
    }

    private var flashButton: some View {
        let enabled = self.control.torchEnabled

        return Button(
            action: { self.control.toggleTorch(!enabled) },
            label: {
                Image(systemName: enabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 20, weight: .medium, design: .default))
                    .padding(10)
            }
        )
        .accentColor(enabled ? .yellow : .primary)
    }

    private var debugButtons: some View {
        let debug = self.control.debugEnabled
        let mesh = self.control.meshEnabled
        let Anchor = self.control.AnchorEnabled

        return VStack {
            Button(
                action: { self.control.toggleDebug(!debug) },
                label: { Text("Debug").accentColor(debug ? .primary : .secondary) }
            )
            .padding(.bottom, 5)
            Button(
                action: { self.control.toggleMesh(!mesh) },
                label: { Text("Mesh").accentColor(mesh ? .primary : .secondary) }
            ).padding(.bottom, 5)
            
            Button(
                action: { self.control.toggleAnchor(!Anchor) },
                label: { Text("Anchor").accentColor(Anchor ? .primary : .secondary) }
            ).padding(.bottom, 5)
            
        }
    }
}


//#if DEBUG
//
//struct ScannerTabView_Previews: PreviewProvider {
//    private static let settings = SettingsStore()
//    private static let store = ScanStore(settings: settings)
//
//    private static let tab = ScannerTab()
//
//    static var previews: some View {
//        Group {
//            view
//                .previewDevice(PreviewDevice(rawValue: "iPhone 12 Pro"))
//                .environment(\.colorScheme, .dark)
//                .environment(\.fakeScan, true)
//
//            view
//                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (5th generation)"))
//                .environment(\.colorScheme, .light)
//
//        }.environmentObject(store)
//    }
//
//    private static var view: some View {
//        TabView {
//            tab.getTabPanelView(selected: true)
//                .tabItem {
//                    VStack {
//                        tab.tabImage
//                        Text(tab.tabName)
//                    }
//                }
//        }
//    }
//}
//
//#endif

fileprivate struct FakeScanEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

fileprivate extension EnvironmentValues {
    var fakeScan: Bool {
        get {
            return self[FakeScanEnvironmentKey.self]
        }
        set {
            self[FakeScanEnvironmentKey.self] = newValue
        }
    }
}

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        guard let cgImage = cgImage else {
            return nil
        }

        self.init(cgImage: cgImage)
    }
}
