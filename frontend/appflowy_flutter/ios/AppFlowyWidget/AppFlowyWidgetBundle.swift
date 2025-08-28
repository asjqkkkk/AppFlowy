//
//  AppFlowyWidgetBundle.swift
//  AppFlowyWidget
//
//  Created by Lucas Xu on 2025/8/14.
//

import SwiftUI
import WidgetKit

@main
struct AppFlowyWidgetBundle: WidgetBundle {
  var body: some Widget {
    QuickAccessWidget()
    FavoritesWidget()
    RecentWidget()
    AppFlowyWidgetLiveActivity()
  }
}
