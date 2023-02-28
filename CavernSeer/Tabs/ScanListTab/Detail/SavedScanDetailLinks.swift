//
//  SavedScanDetailLinks.swift
//  CavernSeer
//
//  Created by Samuel Grush on 12/3/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//

import SwiftUI

struct SavedScanDetailLinks: View {

    var model: SavedScanModel
    
//    var model_for_3D: SavedScanModel {
//        get{
//            let ori_model = self.model
//            let ori_stations = ori_model.scan.stations
//
//            let new_model = self.model
//
//            //###########################################################################
//            print("#DEBUG 3D view are generating, Ori station: \(ori_stations.count)")
//
//
//            var new_stations: [SurveyStation] = []
//
//            for index in 0..<ori_stations.count where index%2 == 0
//            {
//                new_stations.append(ori_stations[index])
//            }
//
//            new_model.scan.stations = new_stations
//
//            print("#DEBUG 3D view are generated, Ori station: \(new_model.scan.stations.count)")
//
//
//            //###########################################################################
//
////            new_model.scan.lines = []
//
//
//
//            return new_model
//        }
//    }

    @EnvironmentObject
    var settings: SettingsStore

    private var meshColor: UIColor? {
        let cgColor = settings.ColorMesh?.cgColor
        if cgColor != nil && cgColor!.alpha > 0.05 {
            return UIColor(cgColor: cgColor!)
        }
        return nil
    }

    var body: some View {
        List {
            NavigationLink(
                destination: SavedScanDetailAdvanced(
                    model: self.model,
                    unitLength: settings.UnitsLength,
                    formatter: settings.formatter,
                    measureFormatter: settings.measureFormatter,
                    dateFormatter: settings.dateFormatter
                )
            ) {
                HStack {
                    Text("Advanced")
                }
            }
            NavigationLink(
                destination: MiniWorldRender(
//                    scan: self.model.scan,
                    scan: self.model.scan,
                    settings: settings,
                    render_mode_for_renderer: "3D"
                )
            ) {
                HStack {
                    Text("3D Render")
                }
            }
            NavigationLink(
                destination: PlanProjectedMiniWorldRender(
                    scan: self.model.scan,
                    settings: settings
                )
            ) {
                HStack {
                    Text("Plan Projected Render")
                }
            }
            NavigationLink(
                destination: ElevationProjectedMiniWorldRender(
                    scan: self.model.scan,
                    settings: settings
                )
            ) {
                HStack {
                    Text("Elevation Projected Render")
                }
            }
            NavigationLink(
            destination: ElevationCrossSectionRender(
                scan: self.model.scan,
                settings: settings
            )
            ) {
                HStack {
                    Text("Cross Section Render")
                }
            }
            NavigationLink(
            destination: ScannerTabView(
                isSelected: true,
                reloc_map: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(model.id).appendingPathComponent("\(model.id)_map.arexperience")
            )
            ) {
                HStack {
//                    Text(model.id)
                    if FileManager.default.fileExists(atPath: (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(model.id).appendingPathComponent("\(model.id)_map.arexperience")).path)
                    {
                        Text("Start Relocalization")
                    }
                    else{
                        Text("Reloc file not found")
                    }
//
//                    } else {
//                        print("File does not exist" + model.id)
//                    }
//

                    // H Stack end below
                }
            }
        }
    }
}

//#if DEBUG
//struct SavedScanDetailLinks_Previews: PreviewProvider {
//    static var previews: some View {
//        SavedScanDetailLinks()
//    }
//}
//#endif
