import QtQuick
import QtQuick.Effects
import qs.services

// The soft shadow a card casts (popups, tooltips, notifications, the on-screen display): set it as the
// card's `layer.effect` with `layer.enabled: true`. The window needs room around the card for it.
MultiEffect {
    shadowEnabled: true
    shadowColor: Theme.shadow
    shadowOpacity: Theme.shadowOpacity
    shadowBlur: 1.0
    blurMax: 40
    shadowVerticalOffset: 6
    autoPaddingEnabled: true
}
