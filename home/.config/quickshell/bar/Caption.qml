import QtQuick
import qs.services

// The small title over a part of a popup ("Output", "Next days", ...): as written, bold and dim.
Label {
    small: true
    color: Theme.dim
    font.pixelSize: Theme.fontCaption
    bold: true
}
