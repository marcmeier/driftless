import QtQuick
import qs.services

// The small title over a part of a popup ("OUTPUT", "NEXT DAYS", ...).
Label {
    small: true
    color: Theme.dim
    font.pixelSize: Theme.fontCaption
    font.letterSpacing: 1.2
    font.capitalization: Font.AllUppercase
    bold: true
}
