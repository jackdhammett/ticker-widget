import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem{
    id: root

    property var stockData: []
    property bool isLoading: false
    property var historyData: []
    property string historySymbol: ""

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    function refreshStock(silent) {
        if (silent !== true) {
            root.isLoading = true
        }
        // Resolve the path to the script relative to this QML file
        var scriptPath = Qt.resolvedUrl("finance.py").toString().replace("file://", "")
        var symbol = Plasmoid.configuration.stockSymbol
        executable.connectedSources = ["python3 " + scriptPath + " '" + symbol + "'"]
    }

    function showHistory(symbol) {
        root.historySymbol = symbol
        var scriptPath = Qt.resolvedUrl("finance.py").toString().replace("file://", "")
        historyExecutable.connectedSources = ["python3 " + scriptPath + " --history " + symbol]
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var stdout = data["stdout"]
            if (stdout) {
                try {
                    var json = JSON.parse(stdout)
                    root.stockData = json
                } catch(e) {
                    console.error("Failed to parse stock data: " + e)
                }
            }
            root.isLoading = false
            // Disconnect to allow re-running the command later
            executable.disconnectSource(sourceName)
        }
    }

    Plasma5Support.DataSource {
        id: historyExecutable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var stdout = data["stdout"]
            if (stdout) {
                try {
                    root.historyData = JSON.parse(stdout)
                } catch(e) {
                    console.error("Failed to parse history data: " + e)
                }
            }
            historyExecutable.disconnectSource(sourceName)
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onStockSymbolChanged() {
            root.refreshStock()
        }
    }

    Component.onCompleted: {
        root.refreshStock()
    }

    Timer {
        interval: 60000 // 60 seconds
        running: true
        repeat: true
        onTriggered: root.refreshStock(true)
    }

    Rectangle {
        anchors.fill: parent
        color: Plasmoid.configuration.backgroundColor
        radius: 10
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.historyData.length === 0
        spacing: 10
        Repeater {
            model: root.stockData
            RowLayout {
                spacing: 20
                opacity: 0
                NumberAnimation on opacity {
                    from: 0
                    to: 1
                    duration: 800
                    easing.type: Easing.OutQuad
                }
                Item {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.showHistory(modelData.symbol)
                    }
                    Image {
                        id: logoImg
                        anchors.centerIn: parent
                        source: modelData.logo !== undefined ? modelData.logo : ""
                        width: 30; height: 30
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: modelData.symbol
                        font.bold: true
                        visible: !logoImg.visible
                    }
                }
                PlasmaComponents.Label {
                    text: "$" + modelData.price
                    Layout.preferredWidth: 80
                    horizontalAlignment: Text.AlignRight
                    color: modelData.change > 0 ? "green" : (modelData.change < 0 ? "red" : palette.text)
                    font.pointSize: 14
                }
                PlasmaComponents.Label {
                    text: modelData.change + "%"
                    Layout.preferredWidth: 70
                    horizontalAlignment: Text.AlignRight
                    color: modelData.change > 0 ? "green" : (modelData.change < 0 ? "red" : palette.text)
                    font.pointSize: 14
                }
            }
        }
        PlasmaComponents.Button {
            flat: true
            background: null
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.refreshStock()
            ToolTip.visible: hovered
            
            ToolTip.text: "Refresh"
            contentItem: Kirigami.Icon {
                source: "view-refresh"
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 1000
                    loops: Animation.Infinite
                    running: root.isLoading
                }
            }
        }
    }

    Rectangle {
        id: graphOverlay
        width: 600
        height: 400
        anchors.centerIn: parent
        color: Plasmoid.configuration.backgroundColor
        radius: 10
        visible: root.historyData.length > 0
        z: 100
        property int hoverIndex: -1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            
            PlasmaComponents.Label {
                text: root.historySymbol + " - Last 5 Days"
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Canvas {
                id: graphCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    
                    var data = root.historyData
                    if (data.length < 2) return

                    var prices = data.map(d => d.price)
                    var min = Math.min(...prices)
                    var max = Math.max(...prices)
                    var range = max - min
                    if (range === 0) range = 1

                    var w = width
                    var h = height
                    var padding = 5

                    ctx.strokeStyle = palette.text
                    ctx.lineWidth = 2
                    ctx.beginPath()

                    for (var i = 0; i < prices.length; i++) {
                        var x = (i / (prices.length - 1)) * (w - 2 * padding) + padding
                        var y = h - ((prices[i] - min) / range) * (h - 2 * padding) - padding
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()

                    if (graphOverlay.hoverIndex !== -1 && graphOverlay.hoverIndex < prices.length) {
                        var i = graphOverlay.hoverIndex
                        var x = (i / (prices.length - 1)) * (w - 2 * padding) + padding
                        var y = h - ((prices[i] - min) / range) * (h - 2 * padding) - padding
                        ctx.fillStyle = palette.text
                        ctx.beginPath()
                        ctx.arc(x, y, 4, 0, 2 * Math.PI)
                        ctx.fill()
                    }
                }
                onVisibleChanged: if (visible) requestPaint()

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: (mouse) => {
                        var data = root.historyData
                        if (data.length < 2) return
                        var padding = 5
                        var w = width
                        var index = Math.round(((mouse.x - padding) / (w - 2 * padding)) * (data.length - 1))
                        if (index < 0) index = 0
                        if (index >= data.length) index = data.length - 1
                        
                        if (graphOverlay.hoverIndex !== index) {
                            graphOverlay.hoverIndex = index
                            graphCanvas.requestPaint()
                        }
                    }
                    onExited: {
                        graphOverlay.hoverIndex = -1
                        graphCanvas.requestPaint()
                    }
                    ToolTip.visible: graphOverlay.hoverIndex !== -1
                    ToolTip.text: graphOverlay.hoverIndex !== -1 ? (root.historyData[graphOverlay.hoverIndex].date + ": $" + root.historyData[graphOverlay.hoverIndex].price) : ""
                }
            }

            PlasmaComponents.Button {
                text: "Close"
                Layout.alignment: Qt.AlignHCenter
                onClicked: root.historyData = []
            }
        }
    }
}