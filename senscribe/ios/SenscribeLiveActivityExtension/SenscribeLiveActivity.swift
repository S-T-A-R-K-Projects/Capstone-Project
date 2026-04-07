import ActivityKit
import SwiftUI
import WidgetKit

struct SenscribeLiveActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    let status: String
    let startedAtMs: Int
    let lastDetectedIdentifier: String
    let lastDetectedLabel: String
    let lastDetectedConfidencePercent: Int
    let lastDetectedAtMs: Int
  }

  let id: String
}

@available(iOSApplicationExtension 16.1, *)
struct SenscribeLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SenscribeLiveActivityAttributes.self) { context in
      let payload = SenscribeLiveActivityPayload(state: context.state)

      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .center, spacing: 12) {
          Text("Listening")
            .font(.headline.weight(.semibold))
            .lineLimit(1)

          Spacer(minLength: 0)
        }

        HStack(alignment: .top, spacing: 12) {
          SoundSymbolView(payload: payload, font: .title2)

          VStack(alignment: .leading, spacing: 6) {
            Text(payload.headlineText)
              .font(.title3.weight(.semibold))
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            if payload.hasDetection {
              HStack(alignment: .firstTextBaseline, spacing: 12) {
                DetectionRecencyView(lastDetectedAt: payload.lastDetectedAt)

                Spacer(minLength: 8)

                if let confidenceMatchText = payload.confidenceMatchText {
                  Text(confidenceMatchText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
            } else {
              Text("No sound detected yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
          }
        }

        if payload.isCritical {
          Text("Critical sound")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.red)
            .lineLimit(1)
        }
      }
      .padding(14)
      .activityBackgroundTint(Color(.systemBackground))
      .activitySystemActionForegroundColor(Color.accentColor)
    } dynamicIsland: { context in
      let payload = SenscribeLiveActivityPayload(state: context.state)

      return DynamicIsland {
        DynamicIslandExpandedRegion(.center, priority: 1) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 10) {
              SoundSymbolView(payload: payload, font: .title3)
                .frame(width: 22, height: 22, alignment: .center)

              Text(payload.headlineText)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)

              Spacer(minLength: 8)

              if let confidenceMatchText = payload.confidenceMatchText {
                Text(confidenceMatchText)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }

            if payload.hasDetection {
              HStack(spacing: 8) {
                DetectionRecencyView(lastDetectedAt: payload.lastDetectedAt)

                if payload.isCritical {
                  Text("•")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                  Text("Critical sound")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                }
              }
            } else {
              Text("No sound detected yet")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .dynamicIsland(verticalPlacement: .belowIfTooWide)
        }
        .contentMargins([.leading, .trailing], 24)
      } compactLeading: {
        SoundSymbolView(payload: payload, font: .caption)
      } compactTrailing: {
        Text(payload.compactTrailingText)
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      } minimal: {
        SoundSymbolView(payload: payload, font: .caption)
      }
      .contentMargins(.all, 24, for: .expanded)
      .keylineTint(payload.isCritical ? .red : .accentColor)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct SenscribeLiveActivityPayload {
  init(state: SenscribeLiveActivityAttributes.ContentState) {
    let normalizedIdentifier = Self.normalizeIdentifier(state.lastDetectedIdentifier)
    lastDetectedIdentifier = normalizedIdentifier.isEmpty ? nil : normalizedIdentifier

    let normalizedLabel = state.lastDetectedLabel.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    if normalizedLabel.isEmpty {
      lastDetectedLabel = Self.displayLabel(from: normalizedIdentifier)
    } else {
      lastDetectedLabel = Self.displayLabel(from: normalizedLabel)
    }

    lastDetectedConfidencePercent =
      state.lastDetectedConfidencePercent >= 0
      ? state.lastDetectedConfidencePercent
      : nil
    lastDetectedAt =
      state.lastDetectedAtMs >= 0
      ? Date(timeIntervalSince1970: Double(state.lastDetectedAtMs) / 1000.0)
      : nil
  }

  let lastDetectedIdentifier: String?
  let lastDetectedLabel: String?
  let lastDetectedConfidencePercent: Int?
  let lastDetectedAt: Date?

  var hasDetection: Bool {
    lastDetectedLabel != nil
  }

  var headlineText: String {
    lastDetectedLabel ?? "Listening for sounds"
  }

  var confidenceMatchText: String? {
    guard hasDetection, let lastDetectedConfidencePercent else { return nil }
    return "\(lastDetectedConfidencePercent)% match"
  }

  var compactTrailingText: String {
    hasDetection ? compactLabel : "Live"
  }

  var compactLabel: String {
    guard hasDetection else { return "Live" }

    guard let identifier = lastDetectedIdentifier else {
      return Self.shortLabel(from: headlineText)
    }

    switch identifier {
    case "alarm_clock", "fire_alarm", "smoke_alarm":
      return "Alarm"
    case "door_bell", "bell", "church_bell", "chime", "bicycle_bell":
      return "Bell"
    case "ambulance_siren", "civil_defense_siren", "emergency_vehicle", "fire_engine_siren":
      return "Siren"
    case "glass_breaking":
      return "Glass"
    case "speech", "babble", "chatter", "crowd", "children_shouting", "choir_singing":
      return "Speech"
    case "dog", "dog_bark", "dog_growl", "dog_howl":
      return "Dog"
    case "cat", "cat_meow":
      return "Cat"
    case "baby_crying":
      return "Baby"
    case "car_horn", "car_passing_by", "engine", "engine_accelerating_revving", "engine_idling", "engine_starting":
      return "Engine"
    case "aircraft", "airplane":
      return "Plane"
    case "fire", "fire_crackle":
      return "Fire"
    default:
      return Self.shortLabel(from: headlineText)
    }
  }

  var symbolName: String {
    guard let identifier = lastDetectedIdentifier else { return "waveform" }

    switch identifier {
    case "alarm_clock", "fire_alarm", "smoke_alarm", "door_bell", "bell", "church_bell", "chime", "bicycle_bell":
      return "bell.fill"
    case "ambulance_siren", "civil_defense_siren", "emergency_vehicle", "fire_engine_siren", "gunshot", "glass_breaking":
      return "exclamationmark.triangle.fill"
    case "speech", "babble", "chatter", "crowd", "children_shouting", "choir_singing":
      return "quote.bubble.fill"
    case "dog", "dog_bark", "dog_growl", "dog_howl", "cat", "cat_meow", "baby_crying":
      return "pawprint.fill"
    case "car_horn", "car_passing_by", "engine", "engine_accelerating_revving", "engine_idling", "engine_starting":
      return "car.fill"
    case "aircraft", "airplane":
      return "airplane"
    case "fire", "fire_crackle":
      return "flame.fill"
    default:
      return "waveform"
    }
  }

  var isCritical: Bool {
    guard let identifier = lastDetectedIdentifier else { return false }
    return Self.criticalIdentifiers.contains(identifier)
  }

  var iconColor: Color {
    isCritical ? .red : .accentColor
  }

  var bottomStatusText: String {
    isCritical ? "Critical sound" : "On-device recognition"
  }

  private static let criticalIdentifiers: Set<String> = [
    "siren",
    "fire_alarm",
    "smoke_alarm",
    "scream",
    "baby_crying",
    "glass_breaking",
    "gunshot",
    "ambulance_siren",
    "civil_defense_siren",
    "emergency_vehicle",
    "fire_engine_siren",
  ]

  private static func normalizeIdentifier(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: " ", with: "_")
  }

  private static func displayLabel(from rawValue: String) -> String? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    return trimmed
      .replacingOccurrences(of: "_", with: " ")
      .localizedCapitalized
  }

  private static func shortLabel(from label: String) -> String {
    let firstWord = label
      .split(whereSeparator: \.isWhitespace)
      .first
      .map(String.init)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let firstWord, !firstWord.isEmpty else { return "Live" }
    return String(firstWord.prefix(8))
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct SoundSymbolView: View {
  let payload: SenscribeLiveActivityPayload
  let font: Font

  var body: some View {
    Image(systemName: payload.symbolName)
      .font(font.weight(.semibold))
      .foregroundStyle(payload.iconColor)
      .lineLimit(1)
      .accessibilityHidden(true)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct DetectionRecencyView: View {
  let lastDetectedAt: Date?

  var body: some View {
    if let lastDetectedAt {
      TimelineView(.periodic(from: lastDetectedAt, by: 5)) { context in
        Text("Last heard \(Self.relativeAgeText(since: lastDetectedAt, now: context.date))")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    } else {
      Text("No sound detected yet")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private static func relativeAgeText(since date: Date, now: Date) -> String {
    let elapsed = max(0, Int(now.timeIntervalSince(date)))

    if elapsed < 60 {
      return "\(elapsed) sec"
    }
    if elapsed < 3600 {
      return "\(elapsed / 60) min"
    }
    return "\(elapsed / 3600) hr"
  }
}
