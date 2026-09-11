import SwiftUI

struct KeyboardLayoutSettingsView: View {
  @State private var selected = KeyboardLayoutPreference.selected
  @State private var voice = KeyboardLayoutPreference.voiceShortcutEnabled
  var body: some View {
    Form {
      Section("键盘布局") {
        ForEach(KeyboardLayoutPreset.allCases, id: \.self) { layout in
          Button {
            selected = layout
            KeyboardLayoutPreference.selected = layout
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(layout.title).font(.body.weight(.semibold))
                Text(layout.detail).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              if selected == layout { Image(systemName: "checkmark").foregroundStyle(MetasequoiaTheme.accent) }
            }
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("appLayout-\(layout.rawValue)")
        }
      }
      Section("快捷入口") {
        Toggle("顶部语音入口", isOn: $voice).accessibilityIdentifier("appVoiceShortcutSwitch")
      } footer: {
        Text("布局只改变键位外观和间距，不影响输入方案。")
      }
    }
    .tint(MetasequoiaTheme.accent)
    .navigationTitle("键盘设置").navigationBarTitleDisplayMode(.inline)
    .onChange(of: voice) { KeyboardLayoutPreference.voiceShortcutEnabled = $0 }
    .onAppear {
      selected = KeyboardLayoutPreference.selected
      voice = KeyboardLayoutPreference.voiceShortcutEnabled
    }
  }
}
