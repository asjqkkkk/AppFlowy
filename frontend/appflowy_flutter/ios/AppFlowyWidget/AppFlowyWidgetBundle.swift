//
//  AppFlowyWidgetBundle.swift
//  AppFlowyWidget
//
//  Created by Lucas Xu on 2025/8/14.
//

import WidgetKit
import SwiftUI

@main
struct AppFlowyWidgetBundle: WidgetBundle {
  var body: some Widget {
    FavoritesWidget()
    RecentWidget()
    AppFlowyWidgetLiveActivity()
  }
}
