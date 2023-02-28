//
//  SavedScanDetailAdvanced.swift
//  CavernSeer
//
//  Created by Samuel Grush on 7/7/20.
//  Copyright © 2021 Samuel K. Grush. All rights reserved.
//

import SwiftUI /// View
import ARKit /// ARMeshAnchor

struct SavedScanDetailAdvanced: View {
    var model: SavedScanModel

    var unitLength: LengthPreference

    var formatter: NumberFormatter
    var measureFormatter: MeasurementFormatter

    var dateFormatter: DateFormatter

    private var totalVertices: Int {
        model.scan.meshAnchors.map {
            anchor in anchor.vertices.count
        }.reduce(0, { acc, next in acc + next })
    }

    private var totalFaces: Int {
        model.scan.meshAnchors.map {
            anchor in anchor.faces.count
        }.reduce(0, { acc, next in acc + next })
    }

    private var totalNormals: Int {
        model.scan.meshAnchors.map {
            anchor in anchor.normals.count
        }.reduce(0, { acc, next in acc + next })
    }

    private let columns2: [GridItem] = [
        .init(.flexible()),
        .init(.flexible())
    ]

    var body: some View {
        ScrollView(.vertical) {

            metaGroup
            worldMapAttributeGroup
            GroupBox(label: Text("Anchors")) {
                List(model.scan.meshAnchors, id: \.identifier) {
                    anchor in
                    NavigationLink(
                        destination: MeshAnchorDetail(
                            anchor: anchor,
                            xyzView: xyzView
                        )
                    ) {
                        HStack {
                            Text(anchor.description)
                            Spacer()
                        }
                    }
                }
            }
            .frame(minHeight: 200)

            GroupBox(label: Text("Stations")) {
                List(model.scan.stations, id: \.identifier) {
                    station in
                    
//                    NavigationLink(
//                        destination: StaionDetail(cap_img: station.cap_img))
//                        {
                    if station.name == "Center" {
                    HStack {
                        Text(station.name)
                        xyzView(model.scan.stationPositionDict[station.identifier]!)
                        }
                    }
                }
            }
            .frame(minHeight: 200)

            GroupBox(label: Text("Lines")) {
                List(model.scan.lines, id: \.identifier) {
                    line in
                    HStack {
                        if (!line.name.contains("center")){
                            Text("No." + line.name.split(separator: "_")[0])
                            Text(line.name.split(separator: "_")[1])
//                            Text(line.name)
                            if (line.name.contains("pt1_to")){Text("Top edge")}
                            if (line.name.contains("pt2_to")){Text("Right edge")}
                            if (line.name.contains("pt3_to")){Text("Bottom edge")}
                            if (line.name.contains("pt4_to")){Text("Left edge")}
                        
//                        Text(line.startIdentifier.uuidString)
//                        Text(line.endIdentifier.uuidString)
                        Text(model.scan.getDistance(
                            line: line,
                            lengthPref: unitLength
                            ))
                        }
                    }
                }
            }
            .frame(minHeight: 1000)
        }
    }

    private var metaGroup: some View {
        VStack {
            GroupBox(label: Text("Metadata")) {
                ForEach(metaGroupPairs, id: \.0) {
                    (label, value) in
                    HStack {
                        Text(label).frame(width: 100)
                        Text(value).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            RenameAndUpgradeView(scan: model.scan)
        }
    }

    private var metaGroupPairs: [(String, String)] {
        [
            ("id", model.id),
            ("name", model.scan.name),
            ("date", dateFormatter.string(from: model.scan.timestamp)),
            ("file version", String(model.scan.encodingVersion)),
            ("url", model.url.absoluteString),
            ("file size", showMegabytes(amount: model.fileSize)),
        ]
    }

    private var worldMapAttributeGroup: some View {
        GroupBox(label: Text("WorldMap Attributes")) {
            ForEach(worldMapAttributesPairs, id: \.0) {
                (txt, view) in
                HStack {
                    Text(txt).frame(width: 100)
                    view.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.top, 2)
            }
        }
    }

    private var worldMapAttributesPairs: [(String,AnyView)] {
        [
            ("Center", xyzView(model.scan.center)),
            ("Extent", xyzView(model.scan.extent)),
            ("anchor count", AnyView(Text(format(model.scan.meshAnchors.count)))),
            ("vertex count", AnyView(Text(format(totalVertices)))),
            ("normal count", AnyView(Text(format(totalNormals)))),
            ("triangle count", AnyView(Text(format(totalFaces)))),
        ]
    }

    private func xyzView(_ triple: simd_float3) -> AnyView {
        let x = self.unitLength.fromMetric(Double(triple.x))
        let y = self.unitLength.fromMetric(Double(triple.y))
        let z = self.unitLength.fromMetric(Double(triple.z))

        return AnyView(VStack {
            Text("x: \(self.measureFormatter.string(from: x))")
            Text("y: \(self.measureFormatter.string(from: y))")
            Text("z: \(self.measureFormatter.string(from: z))")
        })
    }

    private func showMegabytes(amount: Int64)-> String {
        let byteFormatter = ByteCountFormatter()
        byteFormatter.allowedUnits = [.useMB, .useKB]
        byteFormatter.countStyle = .file

        return byteFormatter.string(fromByteCount: amount)
    }

    private func format(_ value: Int) -> String {
        return self.formatter.string(
            from: NSNumber(value: value)
        ) ?? "??"
    }
}


struct MeshAnchorDetail: View {
    var anchor: CSMeshSlice
    var xyzView: (simd_float3) -> AnyView

    var body: some View {
        VStack {
            Text(anchor.description)
                .font(.title)
            VStack {
                Text("transform: \(anchor.transform.debugDescription)")
                HStack {
                    Text("position:")
                    xyzView(anchor.transform.toPosition())
                }
                Text("Vertex count: \(anchor.vertices.count)")
                Text("Normal count: \(anchor.normals.count)")
                Text("Face count: \(anchor.faces.count)")
            }
        }
    }
}
    
struct StaionDetail: View {
    var cap_img: CVImageBuffer?
    var body: some View {
        if cap_img != nil {
            Image(uiImage: UIImage(pixelBuffer: cap_img!)!)
        }
        else {Image(systemName: "pencil")}
    }
}


//#if DEBUG
//struct SavedScanDetailAdvanced_Previews: PreviewProvider {
//    static var previews: some View {
//        SavedScanDetailAdvanced(
//            model: dummySavedScans[1],
//            unitLength: .MetricMeter,
//            formatter: NumberFormatter(),
//            measureFormatter: MeasurementFormatter(),
//            dateFormatter: DateFormatter()
//        )
//        .previewInterfaceOrientation(.landscapeLeft)
//    }
//}
//#endif
