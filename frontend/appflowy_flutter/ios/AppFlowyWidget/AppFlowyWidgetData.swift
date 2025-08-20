//
//  AppFlowyWidgetData.swift
//  Runner
//
//  Created by Lucas Xu on 2025/8/18.
//

let appGroupID = "group.com.appflowy.widget"
let widgetDataKey = "appflowy_home_screen_widget_data"
let workspacesDataKey = "appflowy_home_screen_widget_data_workspaces"
let clearDataKey = "appflowy_home_screen_widget_clear_data"

enum SimpleWidgetType: String {
  case recent = "recent"
  case favorites = "favorites"

  var displayName: String {
    switch self {
    case .recent:
      return "RECENT"
    case .favorites:
      return "FAVORITE"
    }
  }

  var title: String {
    switch self {
    case .recent:
      return "See recent pages here!"
    case .favorites:
      return "Start Adding Favorites"
    }
  }

  var subtitle: String {
    return "Tap and hold the widget to begin"
  }
}

struct SimpleWorkspace {
  let id: String
  let name: String
  let email: String
  let icon: String
}

struct WorkspaceInfo: Codable {
  let id: String
  let name: String
  let icon: String
  let email: String
}

struct WidgetData: Codable {
  let isUserLogin: Bool
  let currentWorkspaceId: String?
  let workspaces: [WorkspaceInfo]
  let favorites: [PageItem]
  let recent: [PageItem]
  let lastSync: String

  enum CodingKeys: String, CodingKey {
    case isUserLogin = "is_user_login"
    case currentWorkspaceId = "current_workspace_id"
    case workspaces
    case favorites
    case recent
    case lastSync = "last_sync"
  }
}

struct PageItem: Codable {
  let id: String
  let title: String
  let icon: String
  let layout: Int
  let iconType: Int
  let imageUrl: String?
  
  enum CodingKeys: String, CodingKey {
    case id
    case title
    case icon
    case layout
    case iconType
    case imageUrl
  }
  
  init(id: String, title: String, icon: String, layout: Int, iconType: Int = 0, imageUrl: String? = nil) {
    self.id = id
    self.title = title
    self.icon = icon
    self.layout = layout
    self.iconType = iconType
    self.imageUrl = imageUrl
  }

  static let mockFavoritePages1 = [
    PageItem(id: "1", title: "AppFlowy Version", icon: "📱", layout: 0, iconType: 0, imageUrl: "/Users/lucas.xu/Library/Developer/CoreSimulator/Devices/6B529F8E-D87F-4BF7-9E24-E23FC927C29D/data/Containers/Shared/AppGroup/5CE52A26-CD33-49EC-9C5B-0C766356AF8C/home_widget/59335d80-7cc7-11f0-b832-4b3162c5f5e3.png"),
    PageItem(id: "2", title: "Launch Review", icon: "🐭", layout: 0, iconType: 0, imageUrl: "/Users/lucas.xu/Library/Developer/CoreSimulator/Devices/6B529F8E-D87F-4BF7-9E24-E23FC927C29D/data/Containers/Shared/AppGroup/5CE52A26-CD33-49EC-9C5B-0C766356AF8C/home_widget/appflowy_home_screen_widget_data_b908809d-d520-450c-86a4-549257e4bdb0_icon.png"),
    PageItem(id: "3", title: "Design Backlog Design Backlog Design Backlog Design Backlog", icon: "🧰", layout: 0, iconType: 0, imageUrl: "/Users/lucas.xu/Library/Developer/CoreSimulator/Devices/6B529F8E-D87F-4BF7-9E24-E23FC927C29D/data/Containers/Shared/AppGroup/5CE52A26-CD33-49EC-9C5B-0C766356AF8C/home_widget/appflowy_home_screen_widget_data_2c89e118-0fc6-4d05-a788-f5cf3b14c903_icon.png"),
    PageItem(id: "4", title: "Company Wiki", icon: "🔍", layout: 0, iconType: 0),
    PageItem(id: "5", title: "Company OKRs", icon: "🎯", layout: 0, iconType: 0),
    PageItem(id: "6", title: "Individual OKRs", icon: "👋", layout: 0, iconType: 0),
    PageItem(id: "7", title: "Community Resources", icon: "👑", layout: 0, iconType: 0),
    PageItem(id: "8", title: "Product Resources", icon: "🤖", layout: 0, iconType: 0),
    PageItem(id: "9", title: "Working Remotely", icon: "📧", layout: 0, iconType: 0),
    PageItem(id: "10", title: "Feature Specs", icon: "⭐", layout: 0, iconType: 0),
  ]

  static let mockFavoritePages2 = [
    PageItem(id: "1", title: "AppFlowy Version", icon: "📱", layout: 0, iconType: 0, imageUrl: "/Users/lucas.xu/Library/Developer/CoreSimulator/Devices/6B529F8E-D87F-4BF7-9E24-E23FC927C29D/data/Containers/Shared/AppGroup/5CE52A26-CD33-49EC-9C5B-0C766356AF8C/home_widget/appflowy_home_screen_widget_data_7203f071-c3bb-4c7d-b838-38b101c1fd07_icon.png")
  ]

  static let mockRecentPages = [
    PageItem(id: "1", title: "Meeting Notes", icon: "📝", layout: 0, iconType: 0),
    PageItem(id: "2", title: "Project Roadmap", icon: "🗺️", layout: 0, iconType: 0),
    PageItem(id: "3", title: "Design System", icon: "🎨", layout: 0, iconType: 0),
    PageItem(id: "4", title: "Sprint Planning", icon: "⚡", layout: 0, iconType: 0),
    PageItem(id: "5", title: "User Feedback", icon: "💬", layout: 0, iconType: 0),
    PageItem(id: "6", title: "Research Notes", icon: "🔬", layout: 0, iconType: 0),
    PageItem(id: "7", title: "Team Updates", icon: "👥", layout: 0, iconType: 0),
    PageItem(id: "8", title: "Bug Reports", icon: "🐛", layout: 0, iconType: 0),
    PageItem(id: "9", title: "Feature Specs", icon: "⭐", layout: 0, iconType: 0),
    PageItem(id: "10", title: "Working Remotely", icon: "📧", layout: 0, iconType: 0),
  ]
}
