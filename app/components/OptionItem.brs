Sub init()
    m.bg = m.top.findNode("bg")
    m.text = m.top.findNode("text")
    m.icon = m.top.findNode("icon")
    m.iconMask = m.top.findNode("iconMask")
    m.destructive = false
    uiScale = m.global.uiScale
    if uiScale = invalid then uiScale = 1.0
    m.iconMask.maskSize = [72 * uiScale, 54 * uiScale]
End Sub

Sub OnContent()
    item = m.top.itemContent
    if item = invalid then return
    m.text.text = item.title
    m.destructive = item.description = "destructive"
    hasIcon = item.HDPosterUrl <> ""
    m.iconMask.visible = hasIcon
    if hasIcon
        m.icon.uri = item.HDPosterUrl
        m.text.translation = [106, 0]
    else
        m.text.translation = [28, 0]
    end if
    OnFocus()
End Sub

Sub OnFocus()
    p = m.top.focusPercent
    m.bg.opacity = p
    if m.destructive
        if p > 0.5 then m.text.color = "0xD70015FF" else m.text.color = "0xFF6961FF"
    else
        if p > 0.5 then m.text.color = "0x111118FF" else m.text.color = "0xFFFFFFE6"
    end if
End Sub
