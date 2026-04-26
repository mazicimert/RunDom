//
//  RunDomWidgetBundle.swift
//  RunDomWidget
//
//  Created by Mehmet Mert Mazıcı on 25.04.2026.
//

import WidgetKit
import SwiftUI

@main
struct RunDomWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunDomWidget()
        ActivityHeatmapWidget()
    }
}
