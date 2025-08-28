//
//  ColorMapper.swift
//  Runner
//
//  Created by Lucas on 2025/8/27.
//

import SwiftUI

struct ColorMapper {
  @Environment(\.colorScheme) var colorScheme

  static func stringToColor(_ colorString: String, colorScheme: ColorScheme)
    -> Color
  {
    if colorScheme == .dark {
      return darkColor(for: colorString)
    } else {
      return lightColor(for: colorString)
    }
  }

  static func stringToGradient(_ gradientString: String) -> LinearGradient {
    switch gradientString {
    case "appflowy_them_color_gradient1":
      return LinearGradient(
        colors: [
          Color(red: 0.4275, green: 0.8353, blue: 1.0000),
          Color(red: 0.8157, green: 0.6353, blue: 1.0000),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient2":
      return LinearGradient(
        colors: [
          Color(red: 0.8157, green: 0.6353, blue: 1.0000),
          Color(red: 1.0000, green: 0.5176, blue: 0.7490),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient3":
      return LinearGradient(
        colors: [
          Color(red: 1.0000, green: 0.5176, blue: 0.7490),
          Color(red: 1.0000, green: 0.8667, blue: 0.4824),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient4":
      return LinearGradient(
        colors: [
          Color(red: 1.0000, green: 0.8667, blue: 0.4824),
          Color(red: 0.5294, green: 1.0000, blue: 0.6706),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient5":
      return LinearGradient(
        colors: [
          Color(red: 0.5373, green: 0.8431, blue: 0.9961),
          Color(red: 0.4784, green: 0.5059, blue: 1.0000),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient6":
      return LinearGradient(
        colors: [
          Color(red: 0.0000, green: 0.7098, blue: 1.0000),
          Color(red: 0.5725, green: 0.1451, blue: 1.0000),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient7":
      return LinearGradient(
        colors: [
          Color(red: 0.5765, green: 0.1529, blue: 1.0000),
          Color(red: 0.9059, green: 0.2039, blue: 0.5412),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient8":
      return LinearGradient(
        colors: [
          Color(red: 0.8902, green: 0.0000, blue: 0.4275),
          Color(red: 1.0000, green: 0.7412, blue: 0.0000),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient9":
      return LinearGradient(
        colors: [
          Color(red: 1.0000, green: 0.7412, blue: 0.0000),
          Color(red: 0.0000, green: 0.7373, blue: 0.2196),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case "appflowy_them_color_gradient10":
      return LinearGradient(
        colors: [
          Color(red: 0.1098, green: 0.9725, blue: 0.8902),
          Color(red: 0.2941, green: 0.1961, blue: 0.9961),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    default:
      return LinearGradient(
        colors: [Color.gray],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }

  private static func darkColor(for colorString: String) -> Color {
    switch colorString {
    case "appflowy_them_color_tint1":
      return Color(red: 0.2706, green: 0.2706, blue: 0.6510)
    case "appflowy_them_color_tint2":
      return Color(red: 0.4667, green: 0.1843, blue: 0.5882)
    case "appflowy_them_color_tint3":
      return Color(red: 0.4314, green: 0.1373, blue: 0.2627)
    case "appflowy_them_color_tint4":
      return Color(red: 0.6471, green: 0.2941, blue: 0.1412)
    case "appflowy_them_color_tint5":
      return Color(red: 0.5647, green: 0.3765, blue: 0.0000)
    case "appflowy_them_color_tint6":
      return Color(red: 0.3843, green: 0.4510, blue: 0.0000)
    case "appflowy_them_color_tint7":
      return Color(red: 0.2706, green: 0.3961, blue: 0.0784)
    case "appflowy_them_color_tint8":
      return Color(red: 0.0706, green: 0.4824, blue: 0.2784)
    case "appflowy_them_color_tint9":
      return Color(red: 0.0471, green: 0.3569, blue: 0.6196)
    case "appflowy_them_color_tint10":
      return Color(red: 0.2980, green: 0.3490, blue: 0.4000)
    case "appflowy_them_color_tint11":
      return Color(red: 0.3922, green: 0.2078, blue: 0.6588)
    case "appflowy_them_color_tint12":
      return Color(red: 0.5412, green: 0.2039, blue: 0.5216)
    case "appflowy_them_color_tint13":
      return Color(red: 0.6196, green: 0.2314, blue: 0.2314)
    case "appflowy_them_color_tint14":
      return Color(red: 0.5255, green: 0.4078, blue: 0.0000)
    default:
      return Color.gray
    }
  }

  private static func lightColor(for colorString: String) -> Color {
    switch colorString {
    case "appflowy_them_color_tint1":
      return Color(red: 0.8627, green: 0.8627, blue: 0.9686)
    case "appflowy_them_color_tint2":
      return Color(red: 0.9294, green: 0.8431, blue: 0.9686)
    case "appflowy_them_color_tint3":
      return Color(red: 0.9686, green: 0.8431, blue: 0.8980)
    case "appflowy_them_color_tint4":
      return Color(red: 0.9804, green: 0.8745, blue: 0.8235)
    case "appflowy_them_color_tint5":
      return Color(red: 0.9804, green: 0.9137, blue: 0.7647)
    case "appflowy_them_color_tint6":
      return Color(red: 0.9412, green: 0.9490, blue: 0.7020)
    case "appflowy_them_color_tint7":
      return Color(red: 0.8706, green: 0.9412, blue: 0.7725)
    case "appflowy_them_color_tint8":
      return Color(red: 0.8078, green: 0.9412, blue: 0.8824)
    case "appflowy_them_color_tint9":
      return Color(red: 0.8275, green: 0.9020, blue: 0.9608)
    case "appflowy_them_color_tint10":
      return Color(red: 0.8549, green: 0.8706, blue: 0.8980)
    case "appflowy_them_color_tint11":
      return Color(red: 0.8941, green: 0.8549, blue: 0.9686)
    case "appflowy_them_color_tint12":
      return Color(red: 0.9608, green: 0.8431, blue: 0.9569)
    case "appflowy_them_color_tint13":
      return Color(red: 0.9804, green: 0.8510, blue: 0.8510)
    case "appflowy_them_color_tint14":
      return Color(red: 0.9804, green: 0.9373, blue: 0.7255)
    default:
      return Color.gray
    }
  }
}
