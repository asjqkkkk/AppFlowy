//
//  AppFlowyWidgetDataReader.swift
//  Runner
//
//  Created by Lucas Xu on 2025/8/18.
//

import SwiftUI
import WidgetKit

struct WidgetDataReader {
  static func shouldClearData() -> Bool {
    guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
      return false
    }
    
    if userDefaults.string(forKey: clearDataKey) != nil {
      return true
    }
    
    return false
  }
  
  static func checkAndClearData() {
    guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
      return
    }
    
    if userDefaults.string(forKey: clearDataKey) != nil {
      userDefaults.removeObject(forKey: clearDataKey)
      clearAllWidgetData()
    }
  }
  
  private static func clearAllWidgetData() {
    guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
      return
    }
    
    let allKeys = userDefaults.dictionaryRepresentation().keys
    for key in allKeys {
      if key.hasPrefix(widgetDataKey) || key == workspacesDataKey {
        userDefaults.removeObject(forKey: key)
      }
    }
    
    WidgetCenter.shared.reloadAllTimelines()
  }

  static func readWidgetData(for workspaceId: String) -> WidgetData? {
    let workspaceKey = "\(widgetDataKey)_\(workspaceId)"

    guard let userDefaults = UserDefaults(suiteName: appGroupID),
      let jsonString = userDefaults.string(forKey: workspaceKey),
      let data = jsonString.data(using: .utf8)
    else {
      return nil
    }

    do {
      let widgetData = try JSONDecoder().decode(WidgetData.self, from: data)
      return widgetData
    } catch {
      return nil
    }
  }

  static func getFavoritePages(for workspaceId: String) -> [PageItem] {
    guard let widgetData = readWidgetData(for: workspaceId) else {
      return []
    }

    if !widgetData.isUserLogin {
      return []
    }

    return widgetData.favorites
  }

  static func getRecentPages(for workspaceId: String) -> [PageItem] {
    guard let widgetData = readWidgetData(for: workspaceId) else {
      return []
    }

    if !widgetData.isUserLogin {
      return []
    }

    return widgetData.recent
  }

  static func isUserLoggedIn(for workspaceId: String) -> Bool {
    return readWidgetData(for: workspaceId)?.isUserLogin ?? false
  }
}
