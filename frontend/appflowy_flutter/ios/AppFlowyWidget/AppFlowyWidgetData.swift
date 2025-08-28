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
  case quickAccess = "quick_access"

  var displayName: String {
    switch self {
    case .recent:
      return "RECENT"
    case .favorites:
      return "FAVORITES"
    case .quickAccess:
      return "QUICK ACCESS"
    }
  }

  var title: String {
    switch self {
    case .recent:
      return "See recent pages here!"
    case .favorites:
      return "Start Adding Favorites"
    case .quickAccess:
      return "Quick access"
    }
  }

  var subtitle: String {
    switch self {
    case .recent, .favorites, .quickAccess:
      return "Tap and hold the widget to begin"
    }
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
  let quickAccess: QuickAccessPageItem?
  let lastSync: String
  let baseURL: String?
  let authToken: String?

  enum CodingKeys: String, CodingKey {
    case isUserLogin = "is_user_login"
    case currentWorkspaceId = "current_workspace_id"
    case workspaces
    case favorites
    case recent
    case quickAccess = "quick_access"
    case lastSync = "last_sync"
    case baseURL = "base_url"
    case authToken = "auth_token"
  }
}

struct QuickAccessPageItem: Codable {
  let id: String
  let title: String
  let icon: String
  let layout: Int
  let iconType: Int
  let imageUrl: String?
  let coverType: String?
  let coverValue: String?
  let textPreview: String?

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case icon
    case layout
    case iconType
    case imageUrl
    case coverType
    case coverValue
    case textPreview = "text_preview"
  }

  init(
    id: String,
    title: String,
    icon: String,
    layout: Int,
    iconType: Int = 0,
    imageUrl: String? = nil,
    coverType: String? = nil,
    coverValue: String? = nil,
    textPreview: String? = nil
  ) {
    self.id = id
    self.title = title
    self.icon = icon
    self.layout = layout
    self.iconType = iconType
    self.imageUrl = imageUrl
    self.coverType = coverType
    self.coverValue = coverValue
    self.textPreview = textPreview
  }
}

struct PageItem: Codable {
  let id: String
  let title: String
  let icon: String
  let layout: Int
  let iconType: Int
  let imageUrl: String?
  let coverType: String?
  let coverValue: String?

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case icon
    case layout
    case iconType
    case imageUrl
    case coverType
    case coverValue
  }

  init(
    id: String,
    title: String,
    icon: String,
    layout: Int,
    iconType: Int = 0,
    imageUrl: String? = nil,
    coverType: String? = nil,
    coverValue: String? = nil
  ) {
    self.id = id
    self.title = title
    self.icon = icon
    self.layout = layout
    self.iconType = iconType
    self.imageUrl = imageUrl
    self.coverType = coverType
    self.coverValue = coverValue
  }

  static let mockFavoritePages1 = [
    PageItem(
      id: "1",
      title: "AppFlowy Version",
      icon: "📱",
      layout: 0,
      iconType: 0,
      imageUrl:
        "/Users/lucas.xu/Library/Developer/CoreSimulator/Devices/6B529F8E-D87F-4BF7-9E24-E23FC927C29D/data/Containers/Shared/AppGroup/5CE52A26-CD33-49EC-9C5B-0C766356AF8C/home_widget/59335d80-7cc7-11f0-b832-4b3162c5f5e3.png"
    ),
    PageItem(
      id: "2",
      title: "Launch Review",
      icon: "🐭",
      layout: 0,
      iconType: 0,
      imageUrl:
        "/Users/lucas.xu/Library/Developer/CoreSimulator/Devices/6B529F8E-D87F-4BF7-9E24-E23FC927C29D/data/Containers/Shared/AppGroup/5CE52A26-CD33-49EC-9C5B-0C766356AF8C/home_widget/appflowy_home_screen_widget_data_b908809d-d520-450c-86a4-549257e4bdb0_icon.png"
    ),
    PageItem(
      id: "3",
      title: "Design Backlog Design Backlog Design Backlog Design Backlog",
      icon: "🧰",
      layout: 0,
      iconType: 0,
      imageUrl:
        "/Users/lucas.xu/Library/Developer/CoreSimulator/Devices/6B529F8E-D87F-4BF7-9E24-E23FC927C29D/data/Containers/Shared/AppGroup/5CE52A26-CD33-49EC-9C5B-0C766356AF8C/home_widget/appflowy_home_screen_widget_data_2c89e118-0fc6-4d05-a788-f5cf3b14c903_icon.png"
    ),
    PageItem(id: "4", title: "Company Wiki", icon: "🔍", layout: 0, iconType: 0),
    PageItem(id: "5", title: "Company OKRs", icon: "🎯", layout: 0, iconType: 0),
    PageItem(
      id: "6",
      title: "Individual OKRs",
      icon: "👋",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "7",
      title: "Community Resources",
      icon: "👑",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "8",
      title: "Product Resources",
      icon: "🤖",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "9",
      title: "Working Remotely",
      icon: "📧",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "10",
      title: "Feature Specs",
      icon: "⭐",
      layout: 0,
      iconType: 0
    ),
  ]

  static let mockFavoritePages2 = [
    PageItem(
      id: "1",
      title: "AppFlowy Version",
      icon: "📱",
      layout: 0,
      iconType: 0,
      imageUrl:
        "/Users/lucas.xu/Library/Developer/CoreSimulator/Devices/6B529F8E-D87F-4BF7-9E24-E23FC927C29D/data/Containers/Shared/AppGroup/5CE52A26-CD33-49EC-9C5B-0C766356AF8C/home_widget/appflowy_home_screen_widget_data_7203f071-c3bb-4c7d-b838-38b101c1fd07_icon.png"
    )
  ]

  static let mockRecentPages = [
    PageItem(
      id: "1",
      title: "Meeting Notes",
      icon: "📝",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "2",
      title: "Project Roadmap",
      icon: "🗺️",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "3",
      title: "Design System",
      icon: "🎨",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "4",
      title: "Sprint Planning",
      icon: "⚡",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "5",
      title: "User Feedback",
      icon: "💬",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "6",
      title: "Research Notes",
      icon: "🔬",
      layout: 0,
      iconType: 0
    ),
    PageItem(id: "7", title: "Team Updates", icon: "👥", layout: 0, iconType: 0),
    PageItem(id: "8", title: "Bug Reports", icon: "🐛", layout: 0, iconType: 0),
    PageItem(
      id: "9",
      title: "Feature Specs",
      icon: "⭐",
      layout: 0,
      iconType: 0
    ),
    PageItem(
      id: "10",
      title: "Working Remotely",
      icon: "📧",
      layout: 0,
      iconType: 0
    ),
  ]
}

extension QuickAccessPageItem {
  static let mockPage = QuickAccessPageItem(
    id: "qa1",
    title: "Product Requirements",
    icon:
      "{\"color\":\"0xFF409BF8\",\"groupName\":\"interface_essential\",\"iconName\":\"arrow-crossover-left\"}",
    layout: 0,
    iconType: 2,
    imageUrl: nil,
    coverType: "color",
    coverValue: "appflowy_them_color_tint5",
    textPreview:
      "This document outlines the key requirements for our upcoming feature release..."
  )

  static let mockPage2 = QuickAccessPageItem(
    id: "qa1",
    title: "Product",
    icon: "🎞️",
    layout: 0,
    iconType: 0,
    imageUrl: nil,
    coverType: "built_in",
    coverValue: "3",
    textPreview:
      "This document outlines the key requirements for our upcoming feature release..."
  )

  static let mockPage3 = QuickAccessPageItem(
    id: "qa1",
    title: "Product Requirements",
    icon: "😁",
    layout: 0,
    iconType: 0,
    imageUrl: nil,
    coverType: "gradient",
    coverValue: "appflowy_them_color_gradient4",
    textPreview:
      "This document outlines the key requirements for our upcoming feature release..."
  )
  
  static let mockPage4 = QuickAccessPageItem(
    id: "qa1",
    title: "Untitle",
    icon: "",
    layout: 0,
    iconType: 0,
    imageUrl: nil,
    coverType: nil,
    coverValue: nil,
    textPreview:
      "This document outlines the key requirements for our upcoming feature release..."
  )
}
