import SwiftUI
import WidgetKit

@main
struct SenscribeLiveActivityExtensionBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOSApplicationExtension 16.1, *) {
      SenscribeLiveActivity()
    }
  }
}
