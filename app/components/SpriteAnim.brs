Sub init()
    m.timer = m.top.findNode("frameTimer")
    m.timer.observeField("fire", "NextFrame")
    m.posters = []
    m.frame = 0
End Sub

Sub Setup()
    'Os quadros foram gerados no tamanho exato de pixels da TV: converte para Full HD
    uiScale = m.global.uiScale
    if uiScale = invalid then uiScale = 1.0
    dw = m.top.frameWidth / uiScale
    dh = m.top.frameHeight / uiScale
    for i = 0 to m.top.frames - 1
        poster = m.top.createChild("Poster")
        poster.width = dw
        poster.height = dh
        poster.visible = i = 0
        m.posters.push(poster)
    end for
    OnMirrored()
    m.top.displayWidth = dw
    m.top.displayHeight = dh
    m.timer.duration = 1.0 / m.top.fps
End Sub

Sub OnPlaying()
    if m.posters.Count() = 0 then Setup()
    if m.top.playing
        'Sempre comeca do primeiro quadro (permite sincronizar com o movimento)
        m.posters[m.frame].visible = false
        m.frame = 0
        m.posters[0].visible = true
    end if
    if m.top.playing then m.timer.control = "start" else m.timer.control = "stop"
End Sub

Sub NextFrame()
    m.posters[m.frame].visible = false
    m.frame = (m.frame + 1) mod m.posters.Count()
    m.posters[m.frame].visible = true
End Sub

'Troca para os quadros espelhados (gerados no PC: nome_mNN.png)
Sub OnMirrored()
    if m.top.mirrored then variant = "m" else variant = ""
    for i = 0 to m.posters.Count() - 1
        index = i.ToStr()
        if index.Len() < 2 then index = "0" + index
        m.posters[i].uri = m.top.framePrefix + variant + index + ".png"
    end for
End Sub

'Quadro escolhido por fora (sincronizado com o movimento na mesma linha do tempo)
Sub OnFrameIndex()
    if m.posters.Count() = 0 then Setup()
    index = Int(m.top.frameIndex) mod m.posters.Count()
    if index = m.frame then return
    m.posters[m.frame].visible = false
    m.frame = index
    m.posters[m.frame].visible = true
End Sub
