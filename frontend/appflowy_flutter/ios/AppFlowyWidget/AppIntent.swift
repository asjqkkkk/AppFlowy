//
//  AppIntent.swift
//  AppFlowyWidget
//
//  Created by Lucas Xu on 2025/8/14.
//

import AppIntents
import WidgetKit
import home_widget
import Flutter

@available(iOS 16.0, *)
struct Workspace: AppEntity {
  let id: String
  let name: String
  let email: String
  let icon: String
  
  var displayRepresentation: DisplayRepresentation {
    let title = icon.isEmpty ? name : "\(icon) \(name)"
    return DisplayRepresentation(title: "\(title)", subtitle: "\(email)")
  }
  
  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    "Select a workspace"
  }
  
  static var defaultQuery = WorkspaceQuery()
}

@available(iOS 16.0, *)
struct WorkspaceQuery: EntityStringQuery {
  static let mockWorkspaces = [
    Workspace(id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻"),
    Workspace(
      id: "2", name: "Gift for Fellow Jellybeans", email: "lucas.xu@appflowy.io", icon: "🎁"),
    Workspace(
      id: "3", name: "Giggle Sound Collection", email: "lucas.xu@appflowy.io", icon: "🎵"),
    Workspace(id: "4", name: "Personal Projects", email: "lucas.xu@appflowy.io", icon: "📝"),
    Workspace(id: "5", name: "Team Collaboration", email: "lucas.xu@appflowy.io", icon: "👥"),
    Workspace(id: "6", name: "Research Notes", email: "lucas.xu@appflowy.io", icon: "🔬"),
    Workspace(
      id: "7", name: "Marketing Campaign 2024", email: "lucas.xu@appflowy.io", icon: "📈"),
    Workspace(id: "8", name: "Book Writing Project", email: "lucas.xu@appflowy.io", icon: "📚"),
    Workspace(id: "9", name: "Home Renovation Plans", email: "lucas.xu@appflowy.io", icon: "🏠"),
    Workspace(id: "10", name: "Travel Itinerary", email: "lucas.xu@appflowy.io", icon: "✈️"),
    Workspace(id: "11", name: "Fitness Journey 2024", email: "lucas.xu@appflowy.io", icon: "💪"),
    Workspace(id: "12", name: "Recipe Collection", email: "lucas.xu@appflowy.io", icon: "👨‍🍳"),
    Workspace(id: "13", name: "Investment Portfolio", email: "lucas.xu@appflowy.io", icon: "💰"),
    Workspace(id: "14", name: "Garden Planning", email: "lucas.xu@appflowy.io", icon: "🌱"),
    Workspace(
      id: "15", name: "Photography Portfolio", email: "lucas.xu@appflowy.io", icon: "📸"),
    Workspace(id: "16", name: "Wedding Planning", email: "lucas.xu@appflowy.io", icon: "💒"),
    Workspace(
      id: "17", name: "Startup Business Plan", email: "lucas.xu@appflowy.io", icon: "🚀"),
    Workspace(id: "18", name: "Learning Spanish", email: "lucas.xu@appflowy.io", icon: "🇪🇸"),
    Workspace(id: "19", name: "Movie Review Blog", email: "lucas.xu@appflowy.io", icon: "🎬"),
    Workspace(
      id: "20", name: "Music Production Studio", email: "lucas.xu@appflowy.io", icon: "🎵"),
  ]
  
  func entities(for identifiers: [Workspace.ID]) async throws -> [Workspace] {
    let workspaces = getWorkspaces()
    return workspaces.filter { identifiers.contains($0.id) }
  }
  
  func suggestedEntities() async throws -> [Workspace] {
    return getWorkspaces()
  }
  
  func entities(matching string: String) async throws -> [Workspace] {
    let workspaces = getWorkspaces()
    if string.isEmpty {
      return workspaces
    }
    return workspaces.filter { workspace in
      workspace.name.localizedCaseInsensitiveContains(string)
      || workspace.email.localizedCaseInsensitiveContains(string)
    }
  }
  
  private func getWorkspaces() -> [Workspace] {
    
    guard let userDefaults = UserDefaults(suiteName: "group.com.appflowy.widget"),
          let jsonString = userDefaults.string(forKey: "appflowy_home_screen_widget_data_workspaces"),
          let data = jsonString.data(using: .utf8)
    else {
      print("unable to get the worksapces")
      return []
    }
    
    do {
      
      if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
         let workspacesArray = jsonObject["workspaces"] as? [[String: Any]]
      {
        
        let workspaces = workspacesArray.compactMap { workspaceDict -> Workspace? in
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
    
    return Self.mockWorkspaces
  }
}

@available(iOS 16.0, *)
enum WidgetType: String, CaseIterable, AppEnum {
  case recent = "recent"
  case favorites = "favorites"
  
  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    "Widget Type"
  }
  
  static var caseDisplayRepresentations: [WidgetType: DisplayRepresentation] {
    [
      .recent: "Recent Pages",
      .favorites: "Favorite Pages",
    ]
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
  
  var displayName: String {
    switch self {
    case .recent:
      return "RECENT"
    case .favorites:
      return "FAVORITE"
    }
  }
}

@available(iOS 16.0, *)
struct FavoritesConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Select a workspace" }
  static var description: IntentDescription {
    "Choose which workspace to display favorites from."
  }
  
  @Parameter(title: "Workspace")
  var workspace: Workspace?
  
  func perform() async throws -> some IntentResult {
    return .result()
  }
}

@available(iOS 16.0, *)
struct RecentConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Select a workspace" }
  static var description: IntentDescription {
    "Choose which workspace to display recent pages from."
  }
  
  @Parameter(title: "Workspace")
  var workspace: Workspace?
  
  func perform() async throws -> some IntentResult {
    return .result()
  }
}

@available(iOS 16, *)
public struct BackgroundIntent: AppIntent {
   static public var title: LocalizedStringResource = "HomeWidget Background Intent"

   @Parameter(title: "Widget URI")
   var url: URL?

   @Parameter(title: "AppGroup")
   var appGroup: String?

   public init() {}

   public init(url: URL?, appGroup: String?) {
      self.url = url
      self.appGroup = appGroup
   }

   public func perform() async throws -> some IntentResult {
      if #available(iOS 17.0, *) {
         await HomeWidgetBackgroundWorker.run(url: url, appGroup: appGroup!)
      }

      return .result()
   }
}

@available(iOS 16, *)
@available(iOSApplicationExtension, unavailable)
extension BackgroundIntent: ForegroundContinuableIntent {}
