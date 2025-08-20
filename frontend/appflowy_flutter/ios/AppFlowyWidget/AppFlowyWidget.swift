import SwiftUI
import WidgetKit

@available(iOS 16.0, *)
struct FavoritesProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> FavoritesEntry {
    FavoritesEntry(
      date: Date(),
      configuration: FavoritesConfigurationAppIntent(),
      pages: [],
      workspace: nil,
      isUserLoggedIn: false
    )
  }

  func snapshot(for configuration: FavoritesConfigurationAppIntent, in context: Context) async
    -> FavoritesEntry
  {

    guard let configuredWorkspace = configuration.workspace else {

      return FavoritesEntry(
        date: Date(),
        configuration: configuration,
        pages: [],
        workspace: nil,
        isUserLoggedIn: false
      )
    }

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(for: configuredWorkspace.id)
    let pages = WidgetDataReader.getFavoritePages(for: configuredWorkspace.id)

    return FavoritesEntry(
      date: Date(),
      configuration: configuration,
      pages: pages,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )
  }

  func timeline(for configuration: FavoritesConfigurationAppIntent, in context: Context) async
    -> Timeline<FavoritesEntry>
  {
    if WidgetDataReader.shouldClearData() {
      WidgetDataReader.checkAndClearData()
      let entry = FavoritesEntry(
        date: Date(),
        configuration: configuration,
        pages: [],
        workspace: nil,
        isUserLoggedIn: false
      )
      let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    guard let configuredWorkspace = configuration.workspace else {

      let entry = FavoritesEntry(
        date: Date(),
        configuration: configuration,
        pages: [],
        workspace: nil,
        isUserLoggedIn: false
      )
      let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(for: configuredWorkspace.id)
    let pages = WidgetDataReader.getFavoritePages(for: configuredWorkspace.id)

    let entry = FavoritesEntry(
      date: Date(),
      configuration: configuration,
      pages: pages,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )

    let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    return Timeline(entries: [entry], policy: .after(nextUpdate))
  }
}

@available(iOS 16.0, *)
struct RecentProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> RecentEntry {
    RecentEntry(
      date: Date(),
      configuration: RecentConfigurationAppIntent(),
      pages: [],
      workspace: nil,
      isUserLoggedIn: false
    )
  }

  func snapshot(for configuration: RecentConfigurationAppIntent, in context: Context) async
    -> RecentEntry
  {

    guard let configuredWorkspace = configuration.workspace else {

      return RecentEntry(
        date: Date(),
        configuration: configuration,
        pages: [],
        workspace: nil,
        isUserLoggedIn: false
      )
    }

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(for: configuredWorkspace.id)
    let pages = WidgetDataReader.getRecentPages(for: configuredWorkspace.id)

    return RecentEntry(
      date: Date(),
      configuration: configuration,
      pages: pages,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )
  }

  func timeline(for configuration: RecentConfigurationAppIntent, in context: Context) async
    -> Timeline<RecentEntry>
  {
    if WidgetDataReader.shouldClearData() {
      WidgetDataReader.checkAndClearData()
      let entry = RecentEntry(
        date: Date(),
        configuration: configuration,
        pages: [],
        workspace: nil,
        isUserLoggedIn: false
      )
      let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    guard let configuredWorkspace = configuration.workspace else {

      let entry = RecentEntry(
        date: Date(),
        configuration: configuration,
        pages: [],
        workspace: nil,
        isUserLoggedIn: false
      )
      let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(for: configuredWorkspace.id)
    let pages = WidgetDataReader.getRecentPages(for: configuredWorkspace.id)

    let entry = RecentEntry(
      date: Date(),
      configuration: configuration,
      pages: pages,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )

    let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    return Timeline(entries: [entry], policy: .after(nextUpdate))
  }
}

@available(iOS 16.0, *)
struct FavoritesEntry: TimelineEntry {
  let date: Date
  let configuration: FavoritesConfigurationAppIntent
  let pages: [PageItem]
  let workspace: Workspace?
  let isUserLoggedIn: Bool
}

@available(iOS 16.0, *)
struct RecentEntry: TimelineEntry {
  let date: Date
  let configuration: RecentConfigurationAppIntent
  let pages: [PageItem]
  let workspace: Workspace?
  let isUserLoggedIn: Bool
}

struct WidgetIconView: View {
  var body: some View {
    Image("default_preview_icon")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .foregroundColor(.white)
  }
}

struct WidgetHeaderView: View {
  let widgetType: SimpleWidgetType
  let size: WidgetSize

  enum WidgetSize {
    case small, medium, large

    var iconSize: CGFloat {
      switch self {
      case .small: return 0
      case .medium: return 20
      case .large: return 24
      }
    }

    var fontSize: CGFloat {
      switch self {
      case .small: return 10
      case .medium: return 14
      case .large: return 16
      }
    }

    var plusIconSize: CGFloat {
      switch self {
      case .small: return 0
      case .medium: return 20
      case .large: return 24
      }
    }

    var horizontalPadding: CGFloat {
      switch self {
      case .small: return 12
      case .medium: return 16
      case .large: return 16
      }
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      Text(widgetType.displayName)
        .font(.system(size: size.fontSize, weight: .medium))
        .foregroundColor(.secondary)

      Spacer()

      if size != .small {
        Image("appflowy_logo")
      }
    }
    .padding(.horizontal, 0)
    .padding(.top, 10)
    .padding(.bottom, 12)
    .frame(maxWidth: .infinity, alignment: .center)
  }
}

struct PageRowView: View {
  let page: PageItem
  let workspaceId: String
  let iconSize: CGFloat
  let fontSize: CGFloat

  var body: some View {
    let urlString = "appflowy-flutter://open-page/\(workspaceId)/\(page.id)?homeWidget"

    return Link(destination: URL(string: urlString)!) {
      HStack(alignment: .center, spacing: 6) {
        iconView

        Text(page.title)
          .font(.system(size: fontSize, weight: .regular))
          .foregroundColor(.primary)
          .lineLimit(1)

        Spacer()
      }
    }
  }
  
  @ViewBuilder
  private var iconView: some View {
    if let imagePath = page.imageUrl,
       let uiImage = UIImage(contentsOfFile: imagePath) {
      Image(uiImage: uiImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 22, height: 22)
        .clipped()
    } else {
      Text(page.icon)
        .font(.system(size: iconSize))
        .frame(width: 22, height: 22)
    }
  }
}

struct PageRowPlaceholderView: View {
  let iconSize: CGFloat
  let fontSize: CGFloat

  var body: some View {
    HStack(spacing: 6) {
      Text(" ")
        .font(.system(size: iconSize))
        .frame(width: 22, height: 22)

      Text(" ")
        .font(.system(size: fontSize, weight: .regular))
        .lineLimit(1)

      Spacer()
    }
  }
}

struct CreateDocumentButtonView: View {
  let workspaceId: String
  let bottomPadding: CGFloat

  var body: some View {
    let urlString = "appflowy-flutter://create-document/\(workspaceId)?homeWidget"

    return Link(destination: URL(string: urlString)!) {
      ZStack {
        Circle()
          .fill(Color(red: 0.0, green: 0.71, blue: 1.0))
          .frame(width: 48, height: 48)

        Image(systemName: "plus")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.white)
      }
    }
    .padding(.bottom, bottomPadding)
  }
}

struct PlaceholderView: View {
  let widgetType: SimpleWidgetType
  let iconSize: CGFloat
  let titleSize: CGFloat
  let subtitleSize: CGFloat

  var body: some View {
    VStack(spacing: iconSize == 48 ? 12 : iconSize == 80 ? 24 : 8) {
      WidgetIconView()
        .frame(width: iconSize, height: iconSize)

      VStack(spacing: 8) {
        Text(widgetType.title)
          .font(.system(size: titleSize, weight: .bold))
          .foregroundColor(.primary)
          .multilineTextAlignment(.center)

        if subtitleSize > 0 {
          Text(widgetType.subtitle)
            .font(.system(size: subtitleSize, weight: .regular))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
      }

    }
  }
}

struct PageListView: View {
  let pages: [PageItem]
  let workspaceId: String
  let maxItems: Int
  let spacing: CGFloat
  let iconSize: CGFloat
  let fontSize: CGFloat
  let padding: EdgeInsets

  private var paddedPages: [PageItem] {
    var result = pages
    while result.count < maxItems {
      result.append(
        PageItem(
          id: "placeholder_\(result.count)",
          title: "",
          icon: "",
          layout: 0
        ))
    }
    return result
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(paddedPages.prefix(maxItems).indices, id: \.self) { index in
        let page = paddedPages[index]
        if index < pages.count {
          PageRowView(
            page: page,
            workspaceId: workspaceId,
            iconSize: iconSize,
            fontSize: fontSize
          )
          .padding(.trailing, 40)
          .padding(.bottom, spacing)
        } else {
          PageRowPlaceholderView(
            iconSize: iconSize,
            fontSize: fontSize
          )
          .padding(.trailing, 40)
          .padding(.bottom, spacing)
        }
      }
    }
  }
}

struct WidgetContentView: View {
  let widgetType: SimpleWidgetType
  let workspace: SimpleWorkspace?
  let widgetFamily: WidgetFamily
  let pages: [PageItem]
  let isUserLoggedIn: Bool

  private var config: WidgetConfig {
    WidgetConfig(for: widgetFamily)
  }

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Group {

        if workspace == nil || !isUserLoggedIn {
          placeholderContent
        } else {
          pageListContent
        }
      }
      .frame(
        maxWidth: .infinity, maxHeight: .infinity,
        alignment: (workspace == nil || !isUserLoggedIn) ? .center : .topLeading
      )
      .containerBackground(Color(UIColor.systemBackground), for: .widget)

      if workspace != nil && isUserLoggedIn && !pages.isEmpty {
        CreateDocumentButtonView(workspaceId: workspace!.id, bottomPadding: config.createButtonBottomPadding)
      }
    }
  }

  @ViewBuilder
  private var pageListContent: some View {

    VStack(alignment: .leading, spacing: 0) {
      WidgetHeaderView(
        widgetType: widgetType,
        size: config.headerSize
      )

      Divider()
        .frame(maxWidth: .infinity, minHeight: 1)
        .background(Color(red: 0.451, green: 0.478, blue: 0.580, opacity: 0.1))

      PageListView(
        pages: pages,
        workspaceId: workspace?.id ?? "",
        maxItems: config.maxPageItems,
        spacing: config.itemSpacing,
        iconSize: config.pageIconSize,
        fontSize: config.pageFontSize,
        padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
      )
      .padding(.top, 12)
    }

  }

  @ViewBuilder
  private var placeholderContent: some View {
    PlaceholderView(
      widgetType: widgetType,
      iconSize: config.placeholderIconSize,
      titleSize: config.placeholderTitleSize,
      subtitleSize: config.placeholderSubtitleSize
    )
    .padding(config.placeholderPadding)
  }
}

struct WidgetConfig {
  let headerSize: WidgetHeaderView.WidgetSize
  let maxPageItems: Int
  let contentSpacing: CGFloat
  let itemSpacing: CGFloat
  let pageIconSize: CGFloat
  let pageFontSize: CGFloat
  let padding: EdgeInsets
  let placeholderIconSize: CGFloat
  let placeholderTitleSize: CGFloat
  let placeholderSubtitleSize: CGFloat
  let placeholderPadding: CGFloat
  let createButtonBottomPadding: CGFloat

  init(for family: WidgetFamily) {
    switch family {
    case .systemSmall:
      headerSize = .small
      maxPageItems = 3
      contentSpacing = 4
      itemSpacing = 2
      pageIconSize = 12
      pageFontSize = 12
      padding = EdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12)
      placeholderIconSize = 48
      placeholderTitleSize = 14
      placeholderSubtitleSize = 0
      placeholderPadding = 16
      createButtonBottomPadding = 0

    case .systemMedium:
      headerSize = .medium
      maxPageItems = 3
      contentSpacing = 8
      itemSpacing = 10
      pageIconSize = 12
      pageFontSize = 16
      padding = EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4)
      placeholderIconSize = 0
      placeholderTitleSize = 20
      placeholderSubtitleSize = 14
      placeholderPadding = 20
      createButtonBottomPadding = 8

    case .systemLarge:
      headerSize = .large
      maxPageItems = 9
      contentSpacing = 12
      itemSpacing = 10
      pageIconSize = 12
      pageFontSize = 16
      padding = EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4)
      placeholderIconSize = 80
      placeholderTitleSize = 20
      placeholderSubtitleSize = 14
      placeholderPadding = 24
      createButtonBottomPadding = 12

    default:
      headerSize = .medium
      maxPageItems = 5
      contentSpacing = 8
      itemSpacing = 4
      pageIconSize = 16
      pageFontSize = 14
      padding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
      placeholderIconSize = 0
      placeholderTitleSize = 20
      placeholderSubtitleSize = 14
      placeholderPadding = 20
      createButtonBottomPadding = 0
    }
  }
}

@available(iOS 16.0, *)
struct FavoritesWidgetEntryView: View {
  var entry: FavoritesProvider.Entry
  @Environment(\.widgetFamily) var widgetFamily

  var body: some View {
    let simpleWorkspace = entry.workspace.map { workspace in
      SimpleWorkspace(
        id: workspace.id,
        name: workspace.name,
        email: workspace.email,
        icon: workspace.icon
      )
    }

    WidgetContentView(
      widgetType: .favorites,
      workspace: simpleWorkspace,
      widgetFamily: widgetFamily,
      pages: entry.pages,
      isUserLoggedIn: entry.isUserLoggedIn
    )
  }
}

@available(iOS 16.0, *)
struct RecentWidgetEntryView: View {
  var entry: RecentProvider.Entry
  @Environment(\.widgetFamily) var widgetFamily

  var body: some View {
    let simpleWorkspace = entry.workspace.map { workspace in
      SimpleWorkspace(
        id: workspace.id,
        name: workspace.name,
        email: workspace.email,
        icon: workspace.icon
      )
    }

    WidgetContentView(
      widgetType: .recent,
      workspace: simpleWorkspace,
      widgetFamily: widgetFamily,
      pages: entry.pages,
      isUserLoggedIn: entry.isUserLoggedIn
    )
  }
}

@available(iOS 16.0, *)
struct FavoritesWidget: Widget {
  let kind: String = "favorite_widget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind, intent: FavoritesConfigurationAppIntent.self, provider: FavoritesProvider()
    ) { entry in
      FavoritesWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Favorites")
    .description("Quick access to your favorite pages.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

@available(iOS 16.0, *)
struct RecentWidget: Widget {
  let kind: String = "recent_widget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind, intent: RecentConfigurationAppIntent.self, provider: RecentProvider()
    ) { entry in
      RecentWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Recent Pages")
    .description("Quick access to your recent pages.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

@available(iOS 16.0, *)
extension FavoritesConfigurationAppIntent {
  fileprivate static var defaultWorkspace: FavoritesConfigurationAppIntent {
    let intent = FavoritesConfigurationAppIntent()
    intent.workspace = Workspace(
      id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻")
    return intent
  }

  fileprivate static var noWorkspace: FavoritesConfigurationAppIntent {
    let intent = FavoritesConfigurationAppIntent()
    intent.workspace = nil
    return intent
  }
}

@available(iOS 16.0, *)
extension RecentConfigurationAppIntent {
  fileprivate static var defaultWorkspace: RecentConfigurationAppIntent {
    let intent = RecentConfigurationAppIntent()
    intent.workspace = Workspace(
      id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻")
    return intent
  }

  fileprivate static var noWorkspace: RecentConfigurationAppIntent {
    let intent = RecentConfigurationAppIntent()
    intent.workspace = nil
    return intent
  }
}

@available(iOS 17.0, *)
#Preview("Favorites Medium", as: .systemMedium) {
  FavoritesWidget()
} timeline: {
  FavoritesEntry(
    date: .now, configuration: .defaultWorkspace, pages: PageItem.mockFavoritePages1,
    workspace: Workspace(
      id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻"),
    isUserLoggedIn: true)
  FavoritesEntry(
    date: .now, configuration: .defaultWorkspace, pages: PageItem.mockFavoritePages2,
    workspace: Workspace(
      id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻"),
    isUserLoggedIn: true)
  FavoritesEntry(
    date: .now, configuration: .noWorkspace, pages: [], workspace: nil, isUserLoggedIn: false)
}

@available(iOS 17.0, *)
#Preview("Recent Medium", as: .systemMedium) {
  RecentWidget()
} timeline: {
  RecentEntry(
    date: .now, configuration: .defaultWorkspace, pages: PageItem.mockRecentPages,
    workspace: Workspace(
      id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻"),
    isUserLoggedIn: true)
  RecentEntry(
    date: .now, configuration: .noWorkspace, pages: [], workspace: nil, isUserLoggedIn: false)
}

@available(iOS 17.0, *)
#Preview("Favorites Large", as: .systemLarge) {
  FavoritesWidget()
} timeline: {
  FavoritesEntry(
    date: .now, configuration: .defaultWorkspace, pages: PageItem.mockFavoritePages1,
    workspace: Workspace(
      id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻"),
    isUserLoggedIn: true)
  FavoritesEntry(
    date: .now, configuration: .defaultWorkspace, pages: PageItem.mockFavoritePages2,
    workspace: Workspace(
      id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻"),
    isUserLoggedIn: true)
  FavoritesEntry(
    date: .now, configuration: .noWorkspace, pages: [], workspace: nil, isUserLoggedIn: false)
}

@available(iOS 17.0, *)
#Preview("Recent Large", as: .systemLarge) {
  RecentWidget()
} timeline: {
  RecentEntry(
    date: .now, configuration: .defaultWorkspace, pages: PageItem.mockRecentPages,
    workspace: Workspace(
      id: "1", name: "AppFlowy.IO", email: "lucas.xu@appflowy.io", icon: "🐻"),
    isUserLoggedIn: true)
  RecentEntry(
    date: .now, configuration: .noWorkspace, pages: [], workspace: nil, isUserLoggedIn: false)
}
