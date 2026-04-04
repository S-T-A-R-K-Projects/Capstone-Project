import ActivityKit
import SwiftUI
import WidgetKit

struct SenscribeLiveActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    let status: String
    let startedAtMs: Int
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
        HStack(alignment: .center) {
          Label("SenScribe", systemImage: "waveform.and.mic")
            .font(.headline.weight(.semibold))
            .lineLimit(1)

          Spacer()

          SessionTimerView(startDate: payload.startedAt)
        }

        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 6) {
            Text(payload.primaryStatusText)
              .font(.title3.weight(.semibold))
              .lineLimit(1)

            Text(payload.secondaryStatusText)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }

          Spacer(minLength: 8)

          ConfidenceBadgeView(
            confidenceText: payload.confidenceText,
            isHighlighted: payload.isFreshDetection
          )
        }
      }
      .padding(16)
      .activityBackgroundTint(Color(.systemBackground))
      .activitySystemActionForegroundColor(Color.accentColor)
    } dynamicIsland: { context in
      let payload = SenscribeLiveActivityPayload(state: context.state)

      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 4) {
            Label("SenScribe", systemImage: "waveform.and.mic")
              .font(.footnote.weight(.semibold))
            Text(payload.primaryStatusText)
              .font(.headline.weight(.semibold))
              .lineLimit(2)
          }
        }

        DynamicIslandExpandedRegion(.trailing) {
          ConfidenceBadgeView(
            confidenceText: payload.confidenceText,
            isHighlighted: payload.isFreshDetection
          )
        }

        DynamicIslandExpandedRegion(.center) {
          Text(payload.secondaryStatusText)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }

        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Image(systemName: "clock")
            SessionTimerView(startDate: payload.startedAt)
            Spacer()
            Text(payload.compactTrailingText)
              .font(.subheadline.weight(.semibold))
          }
          .font(.footnote)
        }
      } compactLeading: {
        Image(systemName: "waveform")
      } compactTrailing: {
        Text(payload.compactTrailingText)
          .font(.caption2.weight(.semibold))
      } minimal: {
        Image(systemName: "waveform")
      }
      .keylineTint(Color.accentColor)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct SenscribeLiveActivityPayload {
  init(state: SenscribeLiveActivityAttributes.ContentState) {
    status = state.status

    let safeStartedAtMs = state.startedAtMs > 0
      ? state.startedAtMs
      : Int(Date().timeIntervalSince1970 * 1000)
    startedAt = Date(timeIntervalSince1970: Double(safeStartedAtMs) / 1000.0)

    let normalizedLabel = state.lastDetectedLabel.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    lastDetectedLabel = normalizedLabel.isEmpty ? nil : normalizedLabel
    lastDetectedConfidencePercent =
      state.lastDetectedConfidencePercent >= 0
      ? state.lastDetectedConfidencePercent
      : nil
    lastDetectedAt =
      state.lastDetectedAtMs >= 0
      ? Date(timeIntervalSince1970: Double(state.lastDetectedAtMs) / 1000.0)
      : nil
  }

  let status: String
  let startedAt: Date
  let lastDetectedLabel: String?
  let lastDetectedConfidencePercent: Int?
  let lastDetectedAt: Date?

  var isFreshDetection: Bool {
    guard status == "detected", let lastDetectedAt else { return false }
    return Date().timeIntervalSince(lastDetectedAt) <= 8
  }

  var primaryStatusText: String {
    isFreshDetection ? "Sound detected" : "Listening for sounds"
  }

  var secondaryStatusText: String {
    if let lastDetectedLabel, !lastDetectedLabel.isEmpty {
      return isFreshDetection
        ? lastDetectedLabel
        : "Last detected: \(lastDetectedLabel)"
    }
    return "Waiting for on-device sound recognition"
  }

  var confidenceText: String? {
    guard let lastDetectedConfidencePercent else { return nil }
    return "\(lastDetectedConfidencePercent)%"
  }

  var compactTrailingText: String {
    confidenceText ?? "ON"
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct SessionTimerView: View {
  let startDate: Date

  var body: some View {
    Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
      .font(.subheadline.monospacedDigit())
      .foregroundStyle(.secondary)
      .lineLimit(1)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct ConfidenceBadgeView: View {
  let confidenceText: String?
  let isHighlighted: Bool

  var body: some View {
    Text(confidenceText ?? "ON")
      .font(.caption.weight(.semibold))
      .foregroundStyle(isHighlighted ? Color.white : Color.primary)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        Capsule()
          .fill(isHighlighted ? Color.accentColor : Color(.secondarySystemFill))
      )
      .lineLimit(1)
  }
}
