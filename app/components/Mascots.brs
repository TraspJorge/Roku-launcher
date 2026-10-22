Sub init()
    m.runner = m.top.findNode("runner")
    m.runAnim = m.top.findNode("runAnim")
    m.runTimer = m.top.findNode("runTimer")
    m.runTimer.observeField("fire", "OnRunTimer")
    m.runAnim.observeField("state", "OnRunAnimState")
    Schedule(m.runTimer, 40, 40) 'primeira aparicao logo depois de abrir o menu

    m.slime = m.top.findNode("slime")
    m.slimeAnim = m.top.findNode("slimeAnim")
    m.slimeTimer = m.top.findNode("slimeTimer")
    m.slimeTimer.observeField("fire", "OnSlimeTimer")
    m.slimeAnim.observeField("state", "OnSlimeAnimState")
    Schedule(m.slimeTimer, 90, 90)
End Sub

Sub Schedule(timer as Object, minSeconds as Integer, maxSeconds as Integer)
    timer.control = "stop"
    timer.duration = minSeconds + Rnd(maxSeconds - minSeconds + 1) - 1
    timer.control = "start"
End Sub

Sub OnRunTimer()
    if m.top.paused or m.runAnim.state = "running" or m.slimeAnim.state = "running"
        Schedule(m.runTimer, 5, 10)
        return
    end if
    StartRun()
    Schedule(m.runTimer, 120, 240)
End Sub

Sub StartRun()
    m.runner.playing = true 'carrega os quadros (e o tamanho) antes de posicionar
    w = m.runner.displayWidth
    h = m.runner.displayHeight
    y = 1076 - h 'patas rente a borda de baixo
    if Rnd(2) = 1
        startX = -w - 20
        endX = 1940
        m.runner.mirrored = false 'a animacao corre para a direita
    else
        startX = 1940
        endX = -w - 20
        m.runner.mirrored = true
    end if

    anim = m.runAnim
    anim.removeChildrenIndex(anim.getChildCount(), 0)
    interp = anim.createChild("Vector2DFieldInterpolator")
    interp.key = [0, 1]
    interp.keyValue = [[startX, y], [endX, y]]
    interp.fieldToInterp = "runner.translation"
    m.runner.translation = [startX, y]
    m.runner.visible = true
    anim.control = "start"
End Sub

Sub OnRunAnimState()
    if m.runAnim.state = "stopped"
        m.runner.visible = false
        m.runner.playing = false
    end if
End Sub

' ---------- Rimuru slime quicando ----------

Sub OnSlimeTimer()
    if m.top.paused or m.slimeAnim.state = "running" or m.runAnim.state = "running"
        Schedule(m.slimeTimer, 5, 10)
        return
    end if
    StartBounce()
    Schedule(m.slimeTimer, 150, 270)
End Sub

Sub StartBounce()
    m.slime.frameIndex = 0.5 'precisa mudar o valor para disparar a carga dos quadros (e o tamanho)
    w = m.slime.displayWidth
    h = m.slime.displayHeight
    y = 1076 - h * 90 / 96 'a linha do chao fica em 90/96 da altura do quadro
    if Rnd(2) = 1
        startX = -w - 20
        endX = 1940
    else
        startX = 1940
        endX = -w - 20
    end if

    'Cada pulo dura 0,8 s: parado enquanto agacha (quadros 0-3), avanca so no ar (4-10),
    'parado de novo enquanto amassa no pouso (11-15)
    hopSeconds = 0.8
    hops = Int(Abs(endX - startX) / 107) + 1
    m.slimeAnim.duration = hops * hopSeconds
    stepX = (endX - startX) / hops
    keys = []
    positions = []
    frameKeys = []
    frames = []
    for i = 0 to hops - 1
        t0 = i / hops
        d = 1 / hops
        x0 = startX + stepX * i
        keys.Append([t0, t0 + d * 4 / 16, t0 + d * 11 / 16])
        positions.Append([[x0, y], [x0, y], [x0 + stepX, y]])
        frameKeys.Append([t0, t0 + d * 0.999])
        frames.Append([0, 15.99])
    end for
    keys.push(1)
    positions.push([endX, y])

    anim = m.slimeAnim
    anim.removeChildrenIndex(anim.getChildCount(), 0)
    move = anim.createChild("Vector2DFieldInterpolator")
    move.key = keys
    move.keyValue = positions
    move.fieldToInterp = "slime.translation"
    pose = anim.createChild("FloatFieldInterpolator")
    pose.key = frameKeys
    pose.keyValue = frames
    pose.fieldToInterp = "slime.frameIndex"
    m.slime.translation = [startX, y]
    m.slime.visible = true
    anim.control = "start"
End Sub

Sub OnSlimeAnimState()
    if m.slimeAnim.state = "stopped" then m.slime.visible = false
End Sub
