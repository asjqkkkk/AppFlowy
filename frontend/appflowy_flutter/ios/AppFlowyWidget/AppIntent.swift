//
//  AppIntent.swift
//  AppFlowyWidget
//
//  Created by Lucas Xu on 2025/8/14.
//

import AppIntents
import SwiftUI
import UIKit
import WidgetKit
import home_widget

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
    Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    Workspace(
      id: "2",
      name: "Gift for Fellow Jellybeans",
      email: "lucas.xu@appflowy.io",
      icon: "🎁"
    ),
    Workspace(
      id: "3",
      name: "Giggle Sound Collection",
      email: "lucas.xu@appflowy.io",
      icon: "🎵"
    ),
    Workspace(
      id: "4",
      name: "Personal Projects",
      email: "lucas.xu@appflowy.io",
      icon: "📝"
    ),
    Workspace(
      id: "5",
      name: "Team Collaboration",
      email: "lucas.xu@appflowy.io",
      icon: "👥"
    ),
    Workspace(
      id: "6",
      name: "Research Notes",
      email: "lucas.xu@appflowy.io",
      icon: "🔬"
    ),
    Workspace(
      id: "7",
      name: "Marketing Campaign 2024",
      email: "lucas.xu@appflowy.io",
      icon: "📈"
    ),
    Workspace(
      id: "8",
      name: "Book Writing Project",
      email: "lucas.xu@appflowy.io",
      icon: "📚"
    ),
    Workspace(
      id: "9",
      name: "Home Renovation Plans",
      email: "lucas.xu@appflowy.io",
      icon: "🏠"
    ),
    Workspace(
      id: "10",
      name: "Travel Itinerary",
      email: "lucas.xu@appflowy.io",
      icon: "✈️"
    ),
    Workspace(
      id: "11",
      name: "Fitness Journey 2024",
      email: "lucas.xu@appflowy.io",
      icon: "💪"
    ),
    Workspace(
      id: "12",
      name: "Recipe Collection",
      email: "lucas.xu@appflowy.io",
      icon: "👨‍🍳"
    ),
    Workspace(
      id: "13",
      name: "Investment Portfolio",
      email: "lucas.xu@appflowy.io",
      icon: "💰"
    ),
    Workspace(
      id: "14",
      name: "Garden Planning",
      email: "lucas.xu@appflowy.io",
      icon: "🌱"
    ),
    Workspace(
      id: "15",
      name: "Photography Portfolio",
      email: "lucas.xu@appflowy.io",
      icon: "📸"
    ),
    Workspace(
      id: "16",
      name: "Wedding Planning",
      email: "lucas.xu@appflowy.io",
      icon: "💒"
    ),
    Workspace(
      id: "17",
      name: "Startup Business Plan",
      email: "lucas.xu@appflowy.io",
      icon: "🚀"
    ),
    Workspace(
      id: "18",
      name: "Learning Spanish",
      email: "lucas.xu@appflowy.io",
      icon: "🇪🇸"
    ),
    Workspace(
      id: "19",
      name: "Movie Review Blog",
      email: "lucas.xu@appflowy.io",
      icon: "🎬"
    ),
    Workspace(
      id: "20",
      name: "Music Production Studio",
      email: "lucas.xu@appflowy.io",
      icon: "🎵"
    ),
  ]

  func entities(for identifiers: [Workspace.ID]) async throws -> [Workspace] {
    let workspaces = WidgetDataReader.getWorkspaces()
    return workspaces.filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [Workspace] {
    return WidgetDataReader.getWorkspaces()
  }

  func entities(matching string: String) async throws -> [Workspace] {
    let workspaces = WidgetDataReader.getWorkspaces()
    
    if string.isEmpty {
      return workspaces
    }
    return workspaces.filter { workspace in
      workspace.name.localizedCaseInsensitiveContains(string)
        || workspace.email.localizedCaseInsensitiveContains(string)
    }
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

@available(iOS 17.0, *)
struct QuickAccessConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Quick Access Configuration" }
  static var description: IntentDescription {
    "Configure your quick access page"
  }

  @Parameter(title: "Workspace")
  var workspace: Workspace?

  @Parameter(title: "Select a page")
  var selectedPage: PageEntity?

  func perform() async throws -> some IntentResult {
    if let workspace = workspace,
      let selectedPage = selectedPage
    {

      let quickAccessItem = QuickAccessPageItem(
        id: selectedPage.id,
        title: selectedPage.title,
        icon: selectedPage.icon,
        layout: selectedPage.layout,
        iconType: selectedPage.iconType,
        imageUrl: nil,
        coverType: selectedPage.coverType,
        coverValue: selectedPage.coverValue
      )

      WidgetDataReader.saveQuickAccessPage(quickAccessItem, for: workspace.id)
    }

    return .result()
  }
}

@available(iOS 17.0, *)
struct PageEntity: AppEntity {
  let id: String
  let title: String
  let icon: String
  let iconType: Int
  let layout: Int
  let coverType: String?
  let coverValue: String?
  let workspaceId: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Page"
  static var defaultQuery = PageEntityQuery()

  var displayRepresentation: DisplayRepresentation {
    switch iconType {
    case 0:
      let title = icon.isEmpty ? title : "\(icon.first!) \(title)"
      return DisplayRepresentation(title: "\(title)")
    default:
      return DisplayRepresentation(title: "\(title)")
    }
  }
}

@available(iOS 17.0, *)
struct PageEntityQuery: EntityStringQuery {

  typealias Entity = PageEntity

  @IntentParameterDependency<QuickAccessConfigurationAppIntent>(
    \.$workspace
  )
  var quickAccessIntent

  func entities(for identifiers: [PageEntity.ID]) async throws -> [PageEntity] {
    let pages = await getAllPages()
    return pages.filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [PageEntity] {
    return await getAllPages()
  }

  func entities(matching string: String) async throws -> [PageEntity] {
    if string.isEmpty {

      return await getRecentPages()
    } else {

      return await searchPages(query: string)
    }
  }

  private func getAllPages() async -> [PageEntity] {
    guard let workspaceId = getWorkspaceId() else {
      return []
    }

    let pageItems = await WidgetDataReader.getAllPages(for: workspaceId)

    return pageItems.map { pageItem in
      PageEntity(
        id: pageItem.id,
        title: pageItem.title,
        icon: pageItem.icon,
        iconType: pageItem.iconType,
        layout: pageItem.layout,
        coverType: pageItem.coverType,
        coverValue: pageItem.coverValue,
        workspaceId: workspaceId
      )
    }
  }

  private func getRecentPages() async -> [PageEntity] {

    guard let workspaceId = getWorkspaceId() else {
      return []
    }

    let recentPageItems = WidgetDataReader.getRecentPages(for: workspaceId)

    let recentPages = recentPageItems.compactMap { pageItem -> PageEntity? in
      return PageEntity(
        id: pageItem.id,
        title: pageItem.title,
        icon: pageItem.icon,
        iconType: pageItem.iconType,
        layout: pageItem.layout,
        coverType: pageItem.coverType,
        coverValue: pageItem.coverValue,
        workspaceId: workspaceId
      )
    }

    return recentPages
  }

  private func searchPages(query: String) async -> [PageEntity] {
    guard let workspaceId = getWorkspaceId() else {
      return await getRecentPages()
    }

    let pageItems = await WidgetDataReader.searchPages(
      for: workspaceId,
      query: query
    )

    let filteredPages = pageItems.map { pageItem in
      PageEntity(
        id: pageItem.id,
        title: pageItem.title,
        icon: pageItem.icon,
        iconType: pageItem.iconType,
        layout: pageItem.layout,
        coverType: pageItem.coverType,
        coverValue: pageItem.coverValue,
        workspaceId: workspaceId
      )
    }

    return filteredPages.isEmpty ? await getRecentPages() : filteredPages
  }

  private func getWorkspaceId() -> String? {
    quickAccessIntent?.workspace.id
  }

  static let mockPages = [
    PageEntity(
      id: "qa1",
      title: "Product Requirements",
      icon: "📋",
      iconType: 0,
      layout: 0,
      coverType: nil,
      coverValue: nil,
      workspaceId: "1"
    ),
    PageEntity(
      id: "qa2",
      title: "Team Calendar",
      icon: "📅",
      iconType: 0,
      layout: 0,
      coverType: nil,
      coverValue: nil,
      workspaceId: "1"
    ),
    PageEntity(
      id: "qa3",
      title: "Sprint Board",
      icon: "🏃",
      iconType: 0,
      layout: 1,
      coverType: "built_in",
      coverValue: "1",
      workspaceId: "1"
    ),
    PageEntity(
      id: "qa4",
      title: "Design Specs",
      icon: "🎨",
      iconType: 0,
      layout: 0,
      coverType: nil,
      coverValue: nil,
      workspaceId: "1"
    ),
    PageEntity(
      id: "qa5",
      title: "API Documentation",
      icon: "📚",
      iconType: 0,
      layout: 0,
      coverType: nil,
      coverValue: nil,
      workspaceId: "1"
    ),
    PageEntity(
      id: "qa6",
      title: "Meeting Notes",
      icon: "📝",
      iconType: 0,
      layout: 0,
      coverType: nil,
      coverValue: nil,
      workspaceId: "1"
    ),
    PageEntity(
      id: "qa7",
      title: "Budget Tracker",
      icon: "💰",
      iconType: 0,
      layout: 2,
      coverType: "built_in",
      coverValue: "3",
      workspaceId: "1"
    ),
    PageEntity(
      id: "qa8",
      title: "Customer Feedback",
      icon: "💬",
      iconType: 0,
      layout: 0,
      coverType: nil,
      coverValue: nil,
      workspaceId: "1"
    ),
    PageEntity(
      id: "qa9",
      title: "Release Notes",
      icon: "🚀",
      iconType: 0,
      layout: 0,
      coverType: nil,
      coverValue: nil,
      workspaceId: "1"
    ),
  ]
}

@available(iOS 16, *)
public struct BackgroundIntent: AppIntent {
  static public var title: LocalizedStringResource =
    "HomeWidget Background Intent"

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
