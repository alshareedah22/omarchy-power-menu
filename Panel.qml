import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "blackcode.power-menu"
  ipcTarget: "blackcode.power-menu"
  manageIpc: true

  // Settings (shell.json → bar layout entry):
  //   "confirm": false   skip the confirmation for logout / reboot / shutdown
  //   "pinned": false    stop keeping the button at the far right of the bar
  readonly property bool confirmDestructive: setting("confirm", true) !== false
  readonly property bool pinned: setting("pinned", true) !== false

  // Same commands and availability checks as the built-in Omarchy menu.
  readonly property var allActions: [
    { key: "lock",      icon: "󰌾",  label: "Lock",      command: "omarchy-system-lock",     confirm: false },
    { key: "logout",    icon: "󰍃", label: "Logout",    command: "omarchy-system-logout",   confirm: true },
    { key: "suspend",   icon: "󰒲", label: "Suspend",   command: "systemctl suspend",       confirm: false },
    { key: "hibernate", icon: "󰤁", label: "Hibernate", command: "systemctl hibernate",     confirm: false },
    { key: "reboot",    icon: "󰜉", label: "Reboot",    command: "omarchy-system-reboot",   confirm: true },
    { key: "shutdown",  icon: "󰐥", label: "Shutdown",  command: "omarchy-system-shutdown", confirm: true }
  ]

  property bool suspendAvailable: true
  property bool hibernateAvailable: false
  property string uptimeText: ""

  readonly property var actions: allActions.filter(function(a) {
    if (a.key === "suspend") return suspendAvailable
    if (a.key === "hibernate") return hibernateAvailable
    return true
  })

  property int selectedIndex: 0
  property bool cursorActive: false
  property var pendingAction: null

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : ""

  function refresh() {
    if (!probe.running) probe.running = true
  }

  function trigger(action) {
    if (!action) return
    if (action.confirm && root.confirmDestructive) {
      root.pendingAction = action
      return
    }
    run(action)
  }

  function run(action) {
    root.pendingAction = null
    root.close()
    if (root.bar) root.bar.run(action.command)
  }

  function moveCursor(dy) {
    if (root.actions.length === 0) return
    root.selectedIndex = (root.selectedIndex + dy + root.actions.length) % root.actions.length
  }

  onActionsChanged: if (selectedIndex >= actions.length) selectedIndex = Math.max(0, actions.length - 1)

  onOpenedChanged: {
    if (opened) {
      refresh()
      selectedIndex = 0
      cursorActive = false
    } else {
      pendingAction = null
    }
  }

  onPendingActionChanged: {
    if (pendingAction) {
      confirm.selectedIndex = 1
      confirmKeys.forceActiveFocus()
    } else {
      keyCatcher.forceActiveFocus()
    }
  }

  Process {
    id: probe
    command: ["bash", "-c",
      "s=1; command -v omarchy-toggle-enabled >/dev/null && omarchy-toggle-enabled suspend-off && s=0; " +
      "h=0; command -v omarchy-hibernation-available >/dev/null && omarchy-hibernation-available && h=1; " +
      "echo \"$s $h\"; uptime -p 2>/dev/null | sed 's/^up //'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const lines = text.trim().split("\n")
        const flags = (lines[0] || "1 0").split(" ")
        root.suspendAvailable = flags[0] === "1"
        root.hibernateAvailable = flags[1] === "1"
        root.uptimeText = lines[1] || ""
      }
    }
  }

  Component.onCompleted: refresh()

  // ---- Keep the button at the far right edge of the bar ----
  // Omarchy appends newly enabled widgets to the end of a section and has no
  // manifest field for a fixed slot, so watch the layout and move back to the
  // last slot of the right section whenever something lands after us. Only
  // acts while the button is on the bar, so removing it is respected.
  function entryId(entry) {
    return typeof entry === "string" ? entry : (entry && entry.id ? String(entry.id) : "")
  }

  function ensurePlacement(text) {
    if (!root.pinned || !root.bar) return
    let config
    try { config = JSON.parse(text) } catch (e) { return }
    const layout = config && config.bar && config.bar.layout
    if (!layout) return
    const inBar = ["left", "center", "right"].some(function(section) {
      return Array.isArray(layout[section]) && layout[section].some(function(e) { return entryId(e) === root.moduleName })
    })
    if (!inBar) return

    const right = (Array.isArray(layout.right) ? layout.right : []).map(entryId)
    if (right.length > 0 && right[right.length - 1] === root.moduleName) return
    const others = right.filter(function(id) { return id !== root.moduleName }).length
    root.bar.run("omarchy bar move " + root.moduleName + " --section right --index " + others)
  }

  FileView {
    id: layoutFile
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: pinTimer.restart()
  }

  // Let a burst of layout writes settle before checking.
  Timer {
    id: pinTimer
    interval: 1500
    onTriggered: root.ensurePlacement(layoutFile.text())
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰐥"
    slotSize: Style.bar.statusSlot
    tooltipText: "Power"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(280))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.pendingAction !== null
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.trigger(root.actions[root.selectedIndex])
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        const n = parseInt(t)
        if (n >= 1 && n <= root.actions.length) {
          root.selectedIndex = n - 1
          root.cursorActive = true
          root.trigger(root.actions[n - 1])
        }
      }

      Column {
        id: panelColumn
        anchors.fill: parent
        spacing: Style.space(10)

        // ---- Header ----
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰐥"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "Power"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              width: parent.width
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              visible: text !== ""
              text: root.uptimeText !== "" ? "UP " + root.uptimeText.toUpperCase() : ""
              color: Qt.darker(root.fg, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              width: parent.width
              elide: Text.ElideRight
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        // ---- Actions ----
        Column {
          width: parent.width
          spacing: Style.space(2)

          Repeater {
            model: root.actions

            CursorSurface {
              id: row
              required property var modelData
              required property int index

              readonly property bool destructive: modelData.confirm

              width: parent.width
              height: Math.max(rowIcon.implicitHeight, rowLabel.implicitHeight) + Style.space(14)
              hasCursor: root.cursorActive && root.selectedIndex === index
              foreground: root.fg
              accent: destructive ? Color.urgent : Color.accent

              Text {
                id: rowIcon
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(22)
                text: row.modelData.icon
                color: row.hasCursor && row.destructive ? Color.urgent : root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.iconLarge
              }

              Text {
                id: rowLabel
                textFormat: Text.PlainText
                anchors.left: rowIcon.right
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                color: row.hasCursor && row.destructive ? Color.urgent : root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                textFormat: Text.PlainText
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: String(row.index + 1)
                color: Qt.darker(root.fg, 1.8)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) {
                  root.cursorActive = true
                  root.selectedIndex = row.index
                }
                onClicked: root.trigger(row.modelData)
              }
            }
          }
        }
      }

      // ---- Confirmation for logout / reboot / shutdown ----
      Item {
        id: confirmKeys
        anchors.fill: parent
        visible: confirm.opened
        Keys.onPressed: function(event) { event.accepted = confirm.handleKey(event) }

        ConfirmDialog {
          id: confirm
          anchors.fill: parent
          opened: root.pendingAction !== null
          message: root.pendingAction ? root.pendingAction.label + " now?" : ""
          confirmText: root.pendingAction ? root.pendingAction.label : "Confirm"
          foreground: root.fg
          fontFamily: root.fontFamily
          onCanceled: root.pendingAction = null
          onConfirmed: root.run(root.pendingAction)
        }
      }
    }
  }
}
