import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols 2.0 as KQuickControls

Kirigami.FormLayout {
    id: page
    property alias cfg_stockSymbol: symbolField.text
    property alias cfg_backgroundColor: colorButton.color

    TextField {
        id: symbolField
        Kirigami.FormData.label: "Stock Symbols (comma separated):"
    }

    KQuickControls.ColorButton {
        id: colorButton
        Kirigami.FormData.label: "Background Color:"
        showAlphaChannel: true
    }
}