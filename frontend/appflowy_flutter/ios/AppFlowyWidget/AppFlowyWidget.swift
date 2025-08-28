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

  func snapshot(
    for configuration: FavoritesConfigurationAppIntent,
    in context: Context
  ) async
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

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(
      for: configuredWorkspace.id
    )
    let pages = WidgetDataReader.getFavoritePages(for: configuredWorkspace.id)

    return FavoritesEntry(
      date: Date(),
      configuration: configuration,
      pages: pages,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )
  }

  func timeline(
    for configuration: FavoritesConfigurationAppIntent,
    in context: Context
  ) async
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
      let nextUpdate = Calendar.current.date(
        byAdding: .minute,
        value: 1,
        to: Date()
      )!
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
      let nextUpdate = Calendar.current.date(
        byAdding: .hour,
        value: 1,
        to: Date()
      )!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(
      for: configuredWorkspace.id
    )
    let pages = WidgetDataReader.getFavoritePages(for: configuredWorkspace.id)

    let entry = FavoritesEntry(
      date: Date(),
      configuration: configuration,
      pages: pages,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )

    let nextUpdate = Calendar.current.date(
      byAdding: .hour,
      value: 1,
      to: Date()
    )!
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

  func snapshot(
    for configuration: RecentConfigurationAppIntent,
    in context: Context
  ) async
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

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(
      for: configuredWorkspace.id
    )
    let pages = WidgetDataReader.getRecentPages(for: configuredWorkspace.id)

    return RecentEntry(
      date: Date(),
      configuration: configuration,
      pages: pages,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )
  }

  func timeline(
    for configuration: RecentConfigurationAppIntent,
    in context: Context
  ) async
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
      let nextUpdate = Calendar.current.date(
        byAdding: .minute,
        value: 1,
        to: Date()
      )!
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
      let nextUpdate = Calendar.current.date(
        byAdding: .hour,
        value: 1,
        to: Date()
      )!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(
      for: configuredWorkspace.id
    )
    let pages = WidgetDataReader.getRecentPages(for: configuredWorkspace.id)

    let entry = RecentEntry(
      date: Date(),
      configuration: configuration,
      pages: pages,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )

    let nextUpdate = Calendar.current.date(
      byAdding: .hour,
      value: 1,
      to: Date()
    )!
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

@available(iOS 16.0, *)
struct QuickAccessProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> QuickAccessEntry {
    QuickAccessEntry(
      date: Date(),
      configuration: QuickAccessConfigurationAppIntent(),
      page: nil,
      workspace: nil,
      isUserLoggedIn: false
    )
  }

  func snapshot(
    for configuration: QuickAccessConfigurationAppIntent,
    in context: Context
  ) async
    -> QuickAccessEntry
  {
    guard let configuredWorkspace = configuration.workspace else {
      return QuickAccessEntry(
        date: Date(),
        configuration: configuration,
        page: nil,
        workspace: nil,
        isUserLoggedIn: false
      )
    }

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(
      for: configuredWorkspace.id
    )
    let page = WidgetDataReader.getQuickAccessPage(for: configuredWorkspace.id)

    return QuickAccessEntry(
      date: Date(),
      configuration: configuration,
      page: page,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )
  }

  private func downloadAndCacheCoverImage(coverType: String, coverValue: String)
    async
  {
    let cacheKey = getCacheKey(for: coverType, value: coverValue)

    guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
      return
    }

    var imageURL: URL?

    switch coverType {
    case "built_in":
      return
    case "unsplash":
      imageURL = URL(string: "\(coverValue)&width=200")
    case "custom":
      imageURL = URL(string: "\(coverValue)")
    default:
      return
    }

    guard let url = imageURL else { return }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)

      if let uiImage = UIImage(data: data),
        let compressedData = uiImage.jpegData(compressionQuality: 0.7)
      {
        userDefaults.set(compressedData, forKey: cacheKey)
      } else {
        userDefaults.set(data, forKey: cacheKey)
      }
    } catch {

    }
  }

  private func downloadAndCacheIconImage(_ iconUrl: String) async {
    guard let userDefaults = UserDefaults(suiteName: appGroupID),
      let url = URL(string: iconUrl)
    else {
      return
    }

    let cacheKey = "appflowy_home_screen_widget_icon_\(iconUrl)"

    do {
      let (data, _) = try await URLSession.shared.data(from: url)

      if let uiImage = UIImage(data: data),
        let compressedData = uiImage.jpegData(compressionQuality: 0.7)
      {
        userDefaults.set(compressedData, forKey: cacheKey)
      } else {
        userDefaults.set(data, forKey: cacheKey)
      }
    } catch {

    }
  }

  private func getCacheKey(for coverType: String, value: String) -> String {
    return "appflowy_home_screen_widget_data_\(coverType)_\(value)"
  }

  func timeline(
    for configuration: QuickAccessConfigurationAppIntent,
    in context: Context
  ) async
    -> Timeline<QuickAccessEntry>
  {
    if WidgetDataReader.shouldClearData() {
      WidgetDataReader.checkAndClearData()
      let entry = QuickAccessEntry(
        date: Date(),
        configuration: configuration,
        page: nil,
        workspace: nil,
        isUserLoggedIn: false
      )
      let nextUpdate = Calendar.current.date(
        byAdding: .minute,
        value: 1,
        to: Date()
      )!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    guard let configuredWorkspace = configuration.workspace else {
      let entry = QuickAccessEntry(
        date: Date(),
        configuration: configuration,
        page: nil,
        workspace: nil,
        isUserLoggedIn: false
      )
      let nextUpdate = Calendar.current.date(
        byAdding: .hour,
        value: 1,
        to: Date()
      )!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    guard let configuredPage = configuration.selectedPage else {
      let entry = QuickAccessEntry(
        date: Date(),
        configuration: configuration,
        page: nil,
        workspace: nil,
        isUserLoggedIn: false
      )
      let nextUpdate = Calendar.current.date(
        byAdding: .hour,
        value: 1,
        to: Date()
      )!
      return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    let isLoggedIn = WidgetDataReader.isUserLoggedIn(
      for: configuredWorkspace.id
    )
    let page = QuickAccessPageItem(
      id: configuredPage.id,
      title: configuredPage.title,
      icon: configuredPage.icon,
      layout: configuredPage.layout,
      iconType: configuredPage.iconType,
      imageUrl: nil,
      coverType: configuredPage.coverType,
      coverValue: configuredPage.coverValue
    )

    if let coverType = page.coverType, let coverValue = page.coverValue {
      await downloadAndCacheCoverImage(
        coverType: coverType,
        coverValue: coverValue
      )
    }

    if page.iconType == 1 {
      await downloadAndCacheIconImage(page.icon)
    }

    IconHelper.shared.loadIcons()

    let entry = QuickAccessEntry(
      date: Date(),
      configuration: configuration,
      page: page,
      workspace: configuredWorkspace,
      isUserLoggedIn: isLoggedIn
    )

    let nextUpdate = Calendar.current.date(
      byAdding: .hour,
      value: 1,
      to: Date()
    )!
    return Timeline(entries: [entry], policy: .after(nextUpdate))
  }
}

@available(iOS 16.0, *)
struct QuickAccessEntry: TimelineEntry {
  let date: Date
  let configuration: QuickAccessConfigurationAppIntent
  let page: QuickAccessPageItem?
  let workspace: Workspace?
  let isUserLoggedIn: Bool
}

struct WidgetIconView: View {
  let widgetType: SimpleWidgetType

  var body: some View {
    let name =
      switch widgetType {
      case .recent:
        "recent"
      case .favorites:
        "favorite"
      case .quickAccess:
        "quick_access"
      }
    Image(name)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .foregroundColor(.white)
  }
}

struct WidgetHeaderView: View {
  let widgetType: SimpleWidgetType
  let size: WidgetSize
  let topPadding: CGFloat

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
      case .large: return 14
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
    .padding(.top, topPadding)
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
    let urlString =
      "appflowy-flutter://open-page/\(workspaceId)/\(page.id)?homeWidget"

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
      let uiImage = UIImage(contentsOfFile: imagePath)
    {
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

struct EmptyFavoritesView: View {
  let titleSize: CGFloat
  let subtitleSize: CGFloat

  var body: some View {
    VStack(spacing: 8) {
      Text("No Favorite Pages")
        .font(.system(size: titleSize, weight: .bold))
        .foregroundColor(.primary)
        .multilineTextAlignment(.center)

      Text("Pages you’ve favorited will show here")
        .font(.system(size: subtitleSize, weight: .regular))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.top, 18)
  }
}

struct CreateDocumentButtonView: View {
  let workspaceId: String
  let bottomPadding: CGFloat

  var body: some View {
    let urlString =
      "appflowy-flutter://create-document/\(workspaceId)?homeWidget"

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

  private var verticalSpacing: CGFloat {
    switch iconSize {
    case 48:
      return 12
    case 72:
      return 4
    default:
      return 0
    }
  }

  var body: some View {
    VStack(spacing: verticalSpacing) {
      WidgetIconView(widgetType: widgetType)
        .frame(width: iconSize, height: iconSize)

      VStack(spacing: 4) {
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
  let widgetType: SimpleWidgetType
  let widgetFamily: WidgetFamily

  private var paddedPages: [PageItem] {
    var result = pages
    while result.count < maxItems {
      result.append(
        PageItem(
          id: "placeholder_\(result.count)",
          title: "",
          icon: "",
          layout: 0
        )
      )
    }
    return result
  }

  private var shouldShowMoreFavorites: Bool {
    return widgetType == .favorites && pages.count > maxItems
      && widgetFamily == .systemLarge
  }

  private var displayItemCount: Int {
    if shouldShowMoreFavorites {
      return maxItems - 1
    }
    return maxItems
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(paddedPages.prefix(displayItemCount).indices, id: \.self) {
        index in
        let page = paddedPages[index]
        if index < pages.count && index < displayItemCount {
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

      if shouldShowMoreFavorites {
        let urlString =
          "appflowy-flutter://open-favorites/\(workspaceId)?homeWidget"

        Link(destination: URL(string: urlString)!) {
          HStack(alignment: .center, spacing: 6) {
            Text("More favorites...")
              .font(.system(size: fontSize, weight: .regular))
              .foregroundColor(.secondary)
              .lineLimit(1)
              .frame(height: 22)

            Spacer()
          }
        }
        .padding(.bottom, spacing)
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
        maxWidth: .infinity,
        maxHeight: .infinity,
        alignment: (workspace == nil || !isUserLoggedIn) ? .center : .topLeading
      )
      .containerBackground(Color(UIColor.systemBackground), for: .widget)

      if workspace != nil && isUserLoggedIn && !pages.isEmpty {
        CreateDocumentButtonView(
          workspaceId: workspace!.id,
          bottomPadding: config.createButtonBottomPadding
        )
      }
    }
  }

  private var topPadding: CGFloat {
    var topPadding = 10.0

    if widgetType == .favorites && pages.isEmpty {
      if widgetFamily == .systemLarge {
        topPadding = 0.0
      } else if widgetFamily == .systemMedium {
        topPadding = -3.0
      }
    }
    return topPadding
  }

  @ViewBuilder
  private var pageListContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      WidgetHeaderView(
        widgetType: widgetType,
        size: config.headerSize,
        topPadding: topPadding
      )

      Divider()
        .frame(maxWidth: .infinity, minHeight: 1)
        .background(Color(red: 0.451, green: 0.478, blue: 0.580, opacity: 0.1))

      if widgetType == .favorites && pages.isEmpty {
        EmptyFavoritesView(
          titleSize: config.placeholderTitleSize,
          subtitleSize: config.placeholderSubtitleSize
        )
      } else {
        PageListView(
          pages: pages,
          workspaceId: workspace?.id ?? "",
          maxItems: config.maxPageItems,
          spacing: config.itemSpacing,
          iconSize: config.pageIconSize,
          fontSize: config.pageFontSize,
          padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
          widgetType: widgetType,
          widgetFamily: widgetFamily
        )
        .padding(.top, 12)
      }
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
      placeholderIconSize = 72
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
      placeholderIconSize = 72
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
      kind: kind,
      intent: FavoritesConfigurationAppIntent.self,
      provider: FavoritesProvider()
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
      kind: kind,
      intent: RecentConfigurationAppIntent.self,
      provider: RecentProvider()
    ) { entry in
      RecentWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Recent Pages")
    .description("Quick access to your recent pages.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

@available(iOS 16.0, *)
struct QuickAccessView: View {
  let page: QuickAccessPageItem?
  let workspace: SimpleWorkspace?
  let widgetFamily: WidgetFamily
  let isUserLoggedIn: Bool
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    if let page = page, workspace != nil && isUserLoggedIn {
      configuredPageView(page: page)
    } else {
      emptyStateView
        .containerBackground(Color(UIColor.systemBackground), for: .widget)
    }
  }

  @ViewBuilder
  private func configuredPageView(page: QuickAccessPageItem) -> some View {
    let urlString =
      "appflowy-flutter://open-page/\(workspace?.id ?? "")/\(page.id)?homeWidget"

    Link(destination: URL(string: urlString)!) {
      ZStack(
        alignment: .topLeading,
        content: {
          coverImageView(
            page: page,
            height: 48,
            edgeToEdge: true
          )

          HStack {
            pageIcon(page: page)
            Spacer()
          }
          .padding(.top, 8)

          Text(page.title.uppercased())
            .font(.system(size: titleFontSize, weight: .semibold))
            .foregroundColor(.primary)
            .lineLimit(2)
            .lineSpacing(4)
            .padding(.top, 68)
        }
      )

    }
    .containerBackground(for: .widget) {
      Color.clear
    }
  }

  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 4) {
      Image("default_preview_icon")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: emptyIconSize, height: emptyIconSize)
        .foregroundColor(.secondary)

      if emptySubtitleSize > 0 {
        Text("Tap and hold to\n begin")
          .font(.system(size: emptySubtitleSize, weight: .regular))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(2)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func pageIcon(page: QuickAccessPageItem) -> some View {

    if page.iconType == 1,
      let userDefaults = UserDefaults(suiteName: appGroupID),
      let imageData = userDefaults.data(
        forKey: "appflowy_home_screen_widget_icon_\(page.icon)"
      ),
      let uiImage = UIImage(data: imageData)
    {
      Image(uiImage: uiImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: iconSize, height: iconSize)
    } else if let imagePath = page.imageUrl,
      let uiImage = UIImage(contentsOfFile: imagePath)
    {
      Image(uiImage: uiImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: iconSize, height: iconSize)
    } else if page.iconType == 2,
      let iconData = IconHelper.parseIconString(page.icon)
    {

      if let svgContent = IconHelper.getSVGContent(
        groupName: iconData.groupName,
        iconName: iconData.iconName
      ),
        let svgImage = IconHelper.createSVGImage(
          from: svgContent,
          color: IconHelper.colorFromHex(iconData.color),
          size: CGSize(width: iconSize * 0.8, height: iconSize * 0.8)
        )
      {
        Image(uiImage: svgImage)
          .frame(width: iconSize, height: iconSize)
          .padding(.top, 4)
      } else {

        RoundedRectangle(cornerRadius: 4)
          .fill(IconHelper.colorFromHexToSwiftUIColor(iconData.color))
          .frame(width: iconSize * 0.7, height: iconSize * 0.7)
          .frame(width: iconSize, height: iconSize)
      }
    } else if page.icon.isEmpty {
      let layout = page.layout;
      let name = switch layout {
      case 0:
        "document"
      case 1:
        "grid"
      case 2:
        "board"
      case 3:
        "calendar"
      case 4:
        "chat"
      default:
        "document"
      }
      
      Image(name)
        .frame(width: iconSize, height: iconSize)
        .padding(.top, -6)
    } else {
      Text(page.icon)
        .font(.system(size: iconSize))
    }
  }

  @ViewBuilder
  private func coverImageView(
    page: QuickAccessPageItem,
    height: CGFloat? = nil,
    edgeToEdge: Bool = false
  ) -> some View {
    coverContentView(page: page, height: height, edgeToEdge: edgeToEdge)
      .clipShape(
        .rect(
          topLeadingRadius: 16,
          bottomLeadingRadius: 8,
          bottomTrailingRadius: 8,
          topTrailingRadius: 16
        )
      )
      .padding(EdgeInsets(top: -18, leading: -10, bottom: 80, trailing: -10))
  }

  @ViewBuilder
  private func coverContentView(
    page: QuickAccessPageItem,
    height: CGFloat?,
    edgeToEdge: Bool
  ) -> some View {
    if let coverType = page.coverType,
      let coverValue = page.coverValue
    {
      switch coverType {
      case "color":
        Rectangle()
          .fill(ColorMapper.stringToColor(coverValue, colorScheme: colorScheme))
          .frame(height: 48)
      case "gradient":
        Rectangle()
          .fill(ColorMapper.stringToGradient(coverValue))
          .frame(height: 48)
      case "built_in":
        Image("cover_\(coverValue)")
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(height: height)
          .frame(maxWidth: edgeToEdge ? .infinity : nil)
      default:
        if let uiImage = getCachedCoverImage(
          coverType: coverType,
          coverValue: coverValue
        ) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: height)
            .frame(maxWidth: edgeToEdge ? .infinity : nil)
        } else {
          defaultBackground
            .frame(height: 48)
        }
      }
    } else {
      defaultBackground
        .frame(height: 48)
    }
  }

  private func getCachedCoverImage(coverType: String, coverValue: String)
    -> UIImage?
  {
    let cacheKey = "appflowy_home_screen_widget_data_\(coverType)_\(coverValue)"
    guard let userDefaults = UserDefaults(suiteName: appGroupID),
      let data = userDefaults.data(forKey: cacheKey)
    else {
      return nil
    }
    return UIImage(data: data)
  }

  @ViewBuilder
  private var defaultBackground: some View {
    LinearGradient(
      gradient: Gradient(colors: []),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var iconSize: CGFloat {
    switch widgetFamily {
    case .systemSmall: return 36
    case .systemMedium: return 36
    case .systemLarge: return 36
    default: return 36
    }
  }

  private var titleFontSize: CGFloat {
    switch widgetFamily {
    case .systemSmall: return 16
    case .systemMedium: return 16
    case .systemLarge: return 18
    default: return 16
    }
  }

  private var previewFontSize: CGFloat {
    switch widgetFamily {
    case .systemSmall: return 0
    case .systemMedium: return 14
    case .systemLarge: return 16
    default: return 0
    }
  }

  private var titleLineLimit: Int {
    switch widgetFamily {
    case .systemSmall: return 2
    case .systemMedium: return 2
    case .systemLarge: return 2
    default: return 2
    }
  }

  private var previewLineLimit: Int {
    switch widgetFamily {
    case .systemSmall: return 0
    case .systemMedium: return 2
    case .systemLarge: return 3
    default: return 2
    }
  }

  private var showTextPreview: Bool {
    widgetFamily != .systemSmall
  }

  private var contentPadding: EdgeInsets {
    switch widgetFamily {
    case .systemSmall:
      return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    case .systemMedium:
      return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    case .systemLarge:
      return EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    default: return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    }
  }

  private var emptyIconSize: CGFloat {
    switch widgetFamily {
    case .systemSmall: return 72
    case .systemMedium: return 0
    case .systemLarge: return 80
    default: return 0
    }
  }

  private var emptyTitleSize: CGFloat {
    switch widgetFamily {
    case .systemSmall: return 18
    case .systemMedium: return 20
    case .systemLarge: return 20
    default: return 20
    }
  }

  private var emptySubtitleSize: CGFloat {
    switch widgetFamily {
    case .systemSmall: return 12
    case .systemMedium: return 14
    case .systemLarge: return 14
    default: return 14
    }
  }
}

@available(iOS 16.0, *)
struct QuickAccessWidgetEntryView: View {
  var entry: QuickAccessProvider.Entry
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

    QuickAccessView(
      page: entry.page,
      workspace: simpleWorkspace,
      widgetFamily: widgetFamily,
      isUserLoggedIn: entry.isUserLoggedIn
    )
  }
}

@available(iOS 16.0, *)
struct QuickAccessWidget: Widget {
  let kind: String = "quick_access_widget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: QuickAccessConfigurationAppIntent.self,
      provider: QuickAccessProvider()
    ) { entry in
      QuickAccessWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Quick Access")
    .description("Quick access to your most important page.")
    .supportedFamilies([.systemSmall])
  }
}

@available(iOS 16.0, *)
extension FavoritesConfigurationAppIntent {
  fileprivate static var defaultWorkspace: FavoritesConfigurationAppIntent {
    let intent = FavoritesConfigurationAppIntent()
    intent.workspace = Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    )
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
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    )
    return intent
  }

  fileprivate static var noWorkspace: RecentConfigurationAppIntent {
    let intent = RecentConfigurationAppIntent()
    intent.workspace = nil
    return intent
  }
}

@available(iOS 16.0, *)
extension QuickAccessConfigurationAppIntent {
  fileprivate static var defaultPage1: QuickAccessConfigurationAppIntent {
    let intent = QuickAccessConfigurationAppIntent()
    intent.workspace = Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    )
    intent.selectedPage = PageEntity(
      id: "qa1",
      title: "Product Requirements",
      icon: "📋",
      iconType: 0,
      layout: 0,
      coverType: "1",
      coverValue: nil,
      workspaceId: "/Users/lucas.xu/Desktop/cover.png"
    )
    return intent
  }

  fileprivate static var defaultPage2: QuickAccessConfigurationAppIntent {
    let intent = QuickAccessConfigurationAppIntent()
    intent.workspace = Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    )
    intent.selectedPage = PageEntity(
      id: "qa1",
      title: "Product",
      icon: "🎞️",
      iconType: 0,
      layout: 0,
      coverType: "1",
      coverValue: "/Users/lucas.xu/Desktop/cover.png",
      workspaceId: ""
    )
    return intent
  }

  fileprivate static var noPage: QuickAccessConfigurationAppIntent {
    let intent = QuickAccessConfigurationAppIntent()
    intent.workspace = nil
    intent.selectedPage = nil
    return intent
  }
}

@available(iOS 17.0, *)
#Preview("Quick Access Small", as: .systemSmall) {
  QuickAccessWidget()
} timeline: {
  QuickAccessEntry(
    date: .now,
    configuration: .defaultPage2,
    page: QuickAccessPageItem.mockPage,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  QuickAccessEntry(
    date: .now,
    configuration: .defaultPage2,
    page: QuickAccessPageItem.mockPage2,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  QuickAccessEntry(
    date: .now,
    configuration: .defaultPage1,
    page: QuickAccessPageItem.mockPage3,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  QuickAccessEntry(
    date: .now,
    configuration: .defaultPage1,
    page: QuickAccessPageItem.mockPage4,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  QuickAccessEntry(
    date: .now,
    configuration: .noPage,
    page: nil,
    workspace: nil,
    isUserLoggedIn: false
  )
}

//@available(iOS 17.0, *)
//#Preview("Quick Access Medium", as: .systemMedium) {
//  QuickAccessWidget()
//} timeline: {
//  QuickAccessEntry(
//    date: .now,
//    configuration: .defaultPage1,
//    page: QuickAccessPageItem.mockPage,
//    workspace: Workspace(
//      id: "1",
//      name: "AppFlowy.IO",
//      email: "lucas.xu@appflowy.io",
//      icon: "🐻"
//    ),
//    isUserLoggedIn: true
//  )
//  QuickAccessEntry(
//    date: .now,
//    configuration: .noPage,
//    page: nil,
//    workspace: nil,
//    isUserLoggedIn: false
//  )
//}
//
//@available(iOS 17.0, *)
//#Preview("Quick Access Large", as: .systemLarge) {
//  QuickAccessWidget()
//} timeline: {
//  QuickAccessEntry(
//    date: .now,
//    configuration: .defaultPage1,
//    page: QuickAccessPageItem.mockPage,
//    workspace: Workspace(
//      id: "1",
//      name: "AppFlowy.IO",
//      email: "lucas.xu@appflowy.io",
//      icon: "🐻"
//    ),
//    isUserLoggedIn: true
//  )
//  QuickAccessEntry(
//    date: .now,
//    configuration: .noPage,
//    page: nil,
//    workspace: nil,
//    isUserLoggedIn: false
//  )
//}

@available(iOS 17.0, *)
#Preview("Favorites Medium", as: .systemMedium) {
  FavoritesWidget()
} timeline: {
  FavoritesEntry(
    date: .now,
    configuration: .defaultWorkspace,
    pages: PageItem.mockFavoritePages1,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  FavoritesEntry(
    date: .now,
    configuration: .defaultWorkspace,
    pages: PageItem.mockFavoritePages2,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  FavoritesEntry(
    date: .now,
    configuration: .defaultWorkspace,
    pages: [],
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  FavoritesEntry(
    date: .now,
    configuration: .noWorkspace,
    pages: [],
    workspace: nil,
    isUserLoggedIn: false
  )
}

@available(iOS 17.0, *)
#Preview("Recent Medium", as: .systemMedium) {
  RecentWidget()
} timeline: {
  RecentEntry(
    date: .now,
    configuration: .defaultWorkspace,
    pages: PageItem.mockRecentPages,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  RecentEntry(
    date: .now,
    configuration: .noWorkspace,
    pages: [],
    workspace: nil,
    isUserLoggedIn: false
  )
}

@available(iOS 17.0, *)
#Preview("Favorites Large", as: .systemLarge) {
  FavoritesWidget()
} timeline: {
  FavoritesEntry(
    date: .now,
    configuration: .defaultWorkspace,
    pages: PageItem.mockFavoritePages1,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  FavoritesEntry(
    date: .now,
    configuration: .defaultWorkspace,
    pages: PageItem.mockFavoritePages2,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  FavoritesEntry(
    date: .now,
    configuration: .defaultWorkspace,
    pages: [],
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  FavoritesEntry(
    date: .now,
    configuration: .noWorkspace,
    pages: [],
    workspace: nil,
    isUserLoggedIn: false
  )
}

@available(iOS 17.0, *)
#Preview("Recent Large", as: .systemLarge) {
  RecentWidget()
} timeline: {
  RecentEntry(
    date: .now,
    configuration: .defaultWorkspace,
    pages: PageItem.mockRecentPages,
    workspace: Workspace(
      id: "1",
      name: "AppFlowy.IO",
      email: "lucas.xu@appflowy.io",
      icon: "🐻"
    ),
    isUserLoggedIn: true
  )
  RecentEntry(
    date: .now,
    configuration: .noWorkspace,
    pages: [],
    workspace: nil,
    isUserLoggedIn: false
  )
}
