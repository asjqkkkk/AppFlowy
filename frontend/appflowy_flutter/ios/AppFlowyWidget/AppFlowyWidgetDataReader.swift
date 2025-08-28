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

  static func getQuickAccessPage(for workspaceId: String)
    -> QuickAccessPageItem?
  {
    guard let widgetData = readWidgetData(for: workspaceId) else {
      return nil
    }

    if !widgetData.isUserLogin {
      return nil
    }

    return widgetData.quickAccess
  }

  static func isUserLoggedIn(for workspaceId: String) -> Bool {
    return readWidgetData(for: workspaceId)?.isUserLogin ?? false
  }

  static func getWorkspaces() -> [Workspace] {
    guard
      let userDefaults = UserDefaults(suiteName: "group.com.appflowy.widget"),
      let jsonString = userDefaults.string(
        forKey: "appflowy_home_screen_widget_data_workspaces"
      ),
      let data = jsonString.data(using: .utf8)
    else {
      return []
    }

    do {
      if let jsonObject = try JSONSerialization.jsonObject(with: data)
        as? [String: Any],
        let workspacesArray = jsonObject["workspaces"] as? [[String: Any]]
      {
        let workspaces = workspacesArray.compactMap {
          workspaceDict -> Workspace? in
          guard let id = workspaceDict["id"] as? String,
            let name = workspaceDict["name"] as? String,
            let icon = workspaceDict["icon"] as? String
          else {
            return nil
          }

          let email = workspaceDict["email"] as? String ?? ""

          return Workspace(
            id: id,
            name: name,
            email: email,
            icon: icon
          )
        }

        if !workspaces.isEmpty {
          return workspaces
        }
      }
    } catch {
    }

    return []
  }

  static func saveQuickAccessPage(
    _ pageItem: QuickAccessPageItem,
    for workspaceId: String
  ) {
    guard let widgetData = readWidgetData(for: workspaceId) else {

      return
    }

    let updatedWidgetData = WidgetData(
      isUserLogin: widgetData.isUserLogin,
      currentWorkspaceId: widgetData.currentWorkspaceId,
      workspaces: widgetData.workspaces,
      favorites: widgetData.favorites,
      recent: widgetData.recent,
      quickAccess: pageItem,
      lastSync: widgetData.lastSync,
      baseURL: widgetData.baseURL,
      authToken: widgetData.authToken
    )

    let workspaceKey = "\(widgetDataKey)_\(workspaceId)"

    guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
      return
    }

    do {
      let data = try JSONEncoder().encode(updatedWidgetData)
      if let jsonString = String(data: data, encoding: .utf8) {
        userDefaults.set(jsonString, forKey: workspaceKey)
      }
    } catch {

    }
  }

  private static var folderCache:
    [String: (data: [PageItem], timestamp: Date)] = [:]
  private static let cacheExpiryInterval: TimeInterval = 300

  static func getAllPages(for workspaceId: String) async -> [PageItem] {
    //    if let cached = folderCache[workspaceId] {
    //      let now = Date()
    //      if now.timeIntervalSince(cached.timestamp) < cacheExpiryInterval {
    //
    //        return cached.data
    //      }
    //    }

    let pages = await fetchWorkspaceFolder(workspaceId: workspaceId)

    folderCache[workspaceId] = (data: pages, timestamp: Date())

    return pages
  }

  static func searchPages(for workspaceId: String, query: String) async
    -> [PageItem]
  {
    let allPages = await getAllPages(for: workspaceId)

    let filteredPages = allPages.filter { page in
      page.title.localizedCaseInsensitiveContains(query)
    }

    return filteredPages
  }

  private static func fetchWorkspaceFolder(workspaceId: String) async
    -> [PageItem]
  {

    guard let widgetData = readWidgetData(for: workspaceId),
      let baseURL = widgetData.baseURL,
      let authToken = widgetData.authToken
    else {
      return []
    }

    let urlString = "\(baseURL)/api/workspace/\(workspaceId)/folder?depth=10"

    guard let url = URL(string: urlString) else {
      return []
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.setValue(
      "application/json, text/plain, */*",
      forHTTPHeaderField: "Accept"
    )

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {

        return []
      }

      guard httpResponse.statusCode == 200 else {

        return []
      }

      return parseFolderData(data: data)

    } catch {

      return []
    }
  }

  private static func parseFolderData(data: Data) -> [PageItem] {
    do {
      if let jsonObject = try JSONSerialization.jsonObject(with: data)
        as? [String: Any],
        let responseData = jsonObject["data"] as? [String: Any]
      {

        var pages: [PageItem] = []

        extractPages(from: responseData, pages: &pages)

        return pages
      }
    } catch {

    }

    return []
  }

  private static func extractPages(
    from viewData: [String: Any],
    pages: inout [PageItem]
  ) {
    if let viewId = viewData["view_id"] as? String,
      let name = viewData["name"] as? String,
      let isSpace = viewData["is_space"] as? Bool,
      !isSpace && !name.isEmpty && name != "Workspace"
    {

      let (iconType, icon) = extractIcon(from: viewData)
      let layout = viewData["layout"] as? Int ?? 0

      var coverType: String? = nil
      var coverValue: String? = nil
      if let extra = viewData["extra"] as? [String: Any],
        let cover = extra["cover"] as? [String: Any]
      {
        coverType = cover["type"] as? String
        coverValue = cover["value"] as? String
      }

      let page = PageItem(
        id: viewId,
        title: name,
        icon: icon,
        layout: layout,
        iconType: iconType,
        imageUrl: nil,
        coverType: coverType,
        coverValue: coverValue
      )
      pages.append(page)
    }

    if let children = viewData["children"] as? [[String: Any]] {
      for child in children {
        extractPages(from: child, pages: &pages)
      }
    }
  }

  private static func extractIcon(from viewData: [String: Any]) -> (Int, String)
  {
    if let iconData = viewData["icon"] as? [String: Any] {
      if let ty = iconData["ty"] as? Int,
        let value = iconData["value"] as? String
      {
        return (ty, value)
      }
    }

    return (0, "")
  }
}
