//
//  IconHelper.swift
//  Runner
//
//  Created by Lucas on 2025/8/27.
//

import SVGKit
import SwiftUI

struct IconData: Codable {
  let color: String
  let groupName: String
  let iconName: String
}

struct IconGroup: Codable {
  let name: String
  let icons: [Icon]
}

struct Icon: Codable {
  let name: String
  let keywords: [String]
  let content: String
}

class IconHelper {
  static let shared = IconHelper()
  private var iconGroups: [String: IconGroup] = [:]
  private var isLoaded = false

  private init() {
    loadIcons()
  }

  func loadIcons() {

    if let assetData = NSDataAsset(name: "icons") {
      if let json = try? JSONSerialization.jsonObject(with: assetData.data)
        as? [String: Any]
      {
        parseIconsData(json: json)
        isLoaded = true
        return
      }
    }

    let bundle = Bundle(for: type(of: self))
    if let url = bundle.url(forResource: "icons", withExtension: "json") {
      if let data = try? Data(contentsOf: url),
        let json = try? JSONSerialization.jsonObject(with: data)
          as? [String: Any]
      {
        parseIconsData(json: json)
        isLoaded = true
        return
      }
    }

    if let url = Bundle.main.url(forResource: "icons", withExtension: "json") {
      if let data = try? Data(contentsOf: url),
        let json = try? JSONSerialization.jsonObject(with: data)
          as? [String: Any]
      {
        parseIconsData(json: json)
        isLoaded = true
        return
      }
    }
  }

  private func parseIconsData(json: [String: Any]) {
    for (groupName, groupData) in json {
      if let iconsArray = groupData as? [[String: Any]] {
        let icons = iconsArray.compactMap { iconData -> Icon? in
          guard let name = iconData["name"] as? String,
            let keywords = iconData["keywords"] as? [String],
            let content = iconData["content"] as? String
          else {
            return nil
          }
          return Icon(name: name, keywords: keywords, content: content)
        }
        iconGroups[groupName] = IconGroup(name: groupName, icons: icons)
      }
    }
  }

  static func parseIconString(_ iconString: String) -> IconData? {
    guard let data = iconString.data(using: .utf8) else { return nil }
    do {
      let iconData = try JSONDecoder().decode(IconData.self, from: data)
      return iconData
    } catch {
      return nil
    }
  }

  static func getSVGContent(groupName: String, iconName: String) -> String? {
    if !shared.isLoaded {
      return nil
    }
    let content = shared.iconGroups[groupName]?.icons.first(where: {
      $0.name == iconName
    })?.content
    return content
  }

  static func createSVGImage(
    from svgContent: String,
    color: String,
    size: CGSize
  ) -> UIImage? {

    let coloredSVG = svgContent.replacingOccurrences(
      of: "fill=\"black\"",
      with: "fill=\"\(color)\""
    )

    guard let data = coloredSVG.data(using: .utf8) else { return nil }

    let svgImage = SVGKImage(data: data)
    svgImage?.size = size

    return svgImage?.uiImage
  }

  static func colorFromHex(_ hex: String) -> String {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
    hexSanitized = hexSanitized.replacingOccurrences(of: "0x", with: "")
    hexSanitized = hexSanitized.replacingOccurrences(of: "0X", with: "")

    if hexSanitized.hasPrefix("FF") && hexSanitized.count == 8 {
      hexSanitized = String(hexSanitized.dropFirst(2))
    }

    return "#\(hexSanitized)"
  }

  static func colorFromHexToSwiftUIColor(_ hex: String) -> Color {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
    hexSanitized = hexSanitized.replacingOccurrences(of: "0x", with: "")
    hexSanitized = hexSanitized.replacingOccurrences(of: "0X", with: "")

    if hexSanitized.hasPrefix("FF") && hexSanitized.count == 8 {
      hexSanitized = String(hexSanitized.dropFirst(2))
    }

    var rgb: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgb)

    let red = Double((rgb & 0xFF0000) >> 16) / 255.0
    let green = Double((rgb & 0x00FF00) >> 8) / 255.0
    let blue = Double(rgb & 0x0000FF) / 255.0

    return Color(red: red, green: green, blue: blue)
  }
}
