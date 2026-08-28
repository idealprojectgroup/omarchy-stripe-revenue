import QtQuick
import Quickshell.Io
import qs.Ui

// Today's net Stripe income as a single number in the bar. Left click opens
// the detail panel — today's payments, recent days, same day last month —
// or the setup terminal when no working key is saved. Right click refreshes
// now; middle click opens the Stripe dashboard.
//
// The numbers come from the bundled stripe-revenue-fetch script, which reads
// a restricted API key from ~/.config/stripe-revenue/api_key — the key never
// enters the shell process or shell.json.
BarWidget {
  id: root
  moduleName: "io.github.idealprojectgroup.stripe-revenue"

  // Newest first; days[0] is today. Shapes match the fetch script's JSON.
  property var days: []
  property var payments: []
  property var lastMonth: null
  property var payout: null
  property string error: ""
  property date lastUpdated: new Date(0)

  readonly property int todayCents: days.length > 0 ? days[0].cents : -1

  readonly property int pollSeconds: {
    var v = parseInt(setting("pollSeconds", 60), 10)
    return isFinite(v) && v >= 15 ? v : 60
  }
  readonly property bool showCents: setting("showCents", false) === true
  readonly property int historyDays: {
    var v = parseInt(setting("days", 7), 10)
    return isFinite(v) && v >= 2 && v <= 31 ? v : 7
  }

  readonly property string fetchScript: Qt.resolvedUrl("stripe-revenue-fetch").toString().replace(/^file:\/\//, "")
  readonly property string setupScript: Qt.resolvedUrl("stripe-revenue-setup").toString().replace(/^file:\/\//, "")
  readonly property bool needsSetup: error === "no_key" || error === "auth" || error === "key_perms"

  readonly property string displayText: {
    if (root.needsSetup) return "Stripe: set key"
    // A transient failure keeps the last good numbers on the bar; the next
    // poll heals it. Only a failure with nothing to show reads as an error.
    if (todayCents >= 0) return money(todayCents)
    if (error !== "") return "Stripe: error"
    return "Stripe …"
  }

  readonly property string tooltip: {
    if (error === "no_key") return "Click to set up your Stripe API key"
    if (error === "auth") return "Stripe rejected the saved API key — click to set it up again"
    if (error === "key_perms") return "Key file is readable by others — click to re-save it locked down"
    if (error !== "")
      return "Could not reach Stripe — will retry"
        + (todayCents >= 0 ? " (showing " + Qt.formatTime(lastUpdated, "h:mm ap") + " numbers)" : "")
    if (todayCents < 0) return "Loading Stripe revenue…"
    return "Net income today — click for details"
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function money(cents) {
    if (cents < 0) return "…"
    if (root.showCents) return moneyExact(cents)
    return "$" + Math.round(cents / 100).toLocaleString(Qt.locale("en_US"), "f", 0)
  }

  function moneyExact(cents) {
    var sign = cents < 0 ? "-" : ""
    return sign + "$" + (Math.abs(cents) / 100).toLocaleString(Qt.locale("en_US"), "f", 2)
  }

  function refresh() {
    if (!fetchProcess.running) fetchProcess.running = true
  }

  function runSetup() {
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation \"" + root.setupScript + "\"")
  }

  function applyResult(text) {
    var parsed
    try {
      parsed = JSON.parse(text)
    } catch (problem) {
      error = "parse_failed"
      return
    }
    if (parsed.error) {
      error = String(parsed.error)
      return
    }
    error = ""
    days = parsed.days || []
    payments = parsed.payments || []
    lastMonth = parsed.last_month || null
    payout = parsed.payout || null
    lastUpdated = new Date()
  }

  // ---- Detail panel. Shape contract for the bar's popout routing:
  //      open/close/opened on the bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.idealprojectgroup.stripe-revenue"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  Timer {
    interval: root.pollSeconds * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: fetchProcess
    running: false
    command: [root.fetchScript, String(root.historyDays)]
    stdout: StdioCollector {
      id: fetchStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.applyResult(String(fetchStdout.text || ""))
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // The visible text is the overlay below — WidgetButton cannot weight
    // its own label — so the slot is sized from metrics taken at the same
    // weight, not from the hidden default-weight label.
    text: root.displayText
    labelVisible: false
    hasVisualContent: root.displayText !== ""
    fixedWidth: Math.max(12, labelMetrics.advanceWidth + button.scaledHorizontalMargin * 2)
    tooltipText: root.tooltip
    horizontalMargin: 8.75
    verticalPadding: 8.75

    TextMetrics {
      id: labelMetrics
      text: root.displayText
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      font.weight: Font.Medium
    }

    Text {
      anchors.centerIn: parent
      text: root.displayText
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      font.weight: Font.Medium
      renderType: Text.NativeRendering
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else if (buttonCode === Qt.MiddleButton) Qt.openUrlExternally("https://dashboard.stripe.com/payments")
      else if (root.needsSetup) root.runSetup()
      else root.togglePanel()
    }
  }
}
