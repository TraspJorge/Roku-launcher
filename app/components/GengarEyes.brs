Sub init()
    m.eyes = m.top.findNode("eyes")
    m.anim = m.top.findNode("eyesAnim")
    m.timer = m.top.findNode("eyesTimer")

    'Imagem gerada no tamanho exato de pixels da TV: converte para Full HD
    uiScale = m.global.uiScale
    if uiScale = invalid then uiScale = 1.0
    m.eyes.width = 213 / uiScale
    m.eyes.height = 113 / uiScale
    m.eyes.scaleRotateCenter = [m.eyes.width / 2, m.eyes.height / 2]

    m.timer.observeField("fire", "OnTimer")
    Schedule(15, 15)
End Sub

Sub Schedule(minSeconds as Integer, maxSeconds as Integer)
    m.timer.control = "stop"
    m.timer.duration = minSeconds + Rnd(maxSeconds - minSeconds + 1) - 1
    m.timer.control = "start"
End Sub

Sub OnTimer()
    if m.top.paused or m.anim.state = "running"
        Schedule(5, 10)
        return
    end if
    Pass()
    Schedule(60, 120)
End Sub

Sub AddInterp(kind as String, field as String, keys as Object, values as Object)
    interp = m.anim.createChild(kind)
    interp.key = keys
    interp.keyValue = values
    interp.fieldToInterp = field
End Sub

Sub Pass()
    'Faixa livre acima ou abaixo do nome do app (nunca sobre o nome nem sobre a previa)
    x = 90 + Rnd(500)
    if Rnd(2) = 1 then y = 130 + Rnd(15) else y = 392 + Rnd(15)

    m.anim.removeChildrenIndex(m.anim.getChildCount(), 0)
    AddInterp("FloatFieldInterpolator", "eyes.opacity", [0, 0.2, 0.8, 1], [0, 0.9, 0.9, 0])
    'Duas piscadas rapidas
    AddInterp("Vector2DFieldInterpolator", "eyes.scale", [0, 0.38, 0.40, 0.42, 0.62, 0.64, 0.66, 1], [[1, 1], [1, 1], [1, 0.08], [1, 1], [1, 1], [1, 0.08], [1, 1], [1, 1]])

    m.eyes.translation = [x, y]
    m.anim.control = "start"
End Sub
