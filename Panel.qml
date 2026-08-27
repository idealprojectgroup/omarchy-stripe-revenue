import QtQuick
import qs.Commons
import qs.Ui

// The Stripe Revenue detail popup: today's net income as the hero, the same
// day last month in grey beneath it, today's payments as a feed, and daily
// totals for the recent days. BarWidget.qml owns the bar label and hands
// this panel the button to anchor against.
Panel {
  id: root
  moduleName: "io.github.awicklander.stripe-revenue"
  ipcTarget: "io.github.awicklander.stripe-revenue"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel, so everything the bar identifies a panel by must be the
  // host widget.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var days: hostWidget ? hostWidget.days : []
  readonly property var payments: hostWidget ? hostWidget.payments : []
  readonly property var lastMonth: hostWidget ? hostWidget.lastMonth : null
  readonly property int todayCents: hostWidget ? hostWidget.todayCents : -1
  readonly property date lastUpdated: hostWidget ? hostWidget.lastUpdated : new Date(0)

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dimForeground: Qt.darker(contentForeground, 1.6)
  readonly property color faintForeground: Qt.darker(contentForeground, 2.0)

  function moneyExact(cents) {
    var sign = cents < 0 ? "-" : ""
    return sign + "$" + (Math.abs(cents) / 100).toLocaleString(Qt.locale("en_US"), "f", 2)
  }

  function parseDay(dateString) {
    var parts = String(dateString || "").split("-")
    return new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
  }

  function dayLabel(index, dateString) {
    if (index === 1) return "Yesterday"
    return Qt.formatDate(parseDay(dateString), "ddd MMM d")
  }

  function paymentLabel(payment) {
    var description = String(payment.desc || "")
      .replace(/^Application fee from application .*? for /, "")
      .replace(/\s*\(acct_[^)]*\)\s*$/, "")
      .trim()
    if (description !== "") return description
    var names = {
      charge: "Payment", payment: "Payment", application_fee: "Application fee",
      refund: "Refund", payment_refund: "Refund", application_fee_refund: "Fee refund",
      adjustment: "Adjustment"
    }
    return names[payment.type] || payment.type
  }

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: content
          width: parent.width
          spacing: Style.space(10)

          // ---- Hero: today, and last month's same day in grey under it.
          Column {
            width: parent.width
            spacing: Style.space(2)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "TODAY"
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 2
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.todayCents < 0 ? "…" : root.moneyExact(root.todayCents)
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: 44
              font.weight: Font.DemiBold
            }

            Text {
              visible: root.lastMonth !== null
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.lastMonth
                ? root.moneyExact(root.lastMonth.cents) + " on "
                  + Qt.formatDate(root.parseDay(root.lastMonth.date), "MMM d")
                : ""
              color: root.faintForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          PanelSeparator {
            width: parent.width
          }

          // ---- Today's payments, newest first, like an inbox.
          Column {
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "PAYMENTS"
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            Text {
              visible: root.payments.length === 0
              text: "No payments yet today"
              color: root.faintForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              model: root.payments

              Item {
                id: paymentRow
                required property var modelData
                width: content.width
                height: Style.space(20)

                Text {
                  id: paymentTime
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(44)
                  text: Qt.formatTime(new Date(paymentRow.modelData.at * 1000), "h:mm ap")
                  color: root.faintForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  id: paymentAmount
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.moneyExact(paymentRow.modelData.net)
                  color: paymentRow.modelData.net < 0 ? root.dimForeground : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  anchors.left: paymentTime.right
                  anchors.right: paymentAmount.left
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.paymentLabel(paymentRow.modelData)
                  elide: Text.ElideRight
                  color: root.dimForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          PanelSeparator {
            width: parent.width
          }

          // ---- Daily totals for the recent days; today already stars above.
          Column {
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "PREVIOUS DAYS"
              color: root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            Repeater {
              model: root.days.length > 1 ? root.days.slice(1) : []

              Item {
                id: dayRow
                required property var modelData
                required property int index
                width: content.width
                height: Style.space(20)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.dayLabel(dayRow.index + 1, dayRow.modelData.date)
                  color: root.dimForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.moneyExact(dayRow.modelData.cents)
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          // ---- Footer: the dashboard, and when the numbers were last true.
          Item {
            width: parent.width
            height: Style.space(22)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Open Stripe dashboard"
              color: dashboardMouse.containsMouse
                ? Style.hoverStateColor(root.contentForeground, Color.accent)
                : root.dimForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall

              MouseArea {
                id: dashboardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  Qt.openUrlExternally("https://dashboard.stripe.com/payments")
                  root.close()
                }
              }
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "as of " + Qt.formatTime(root.lastUpdated, "h:mm ap")
              color: root.faintForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
