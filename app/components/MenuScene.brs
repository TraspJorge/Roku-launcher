Sub init()
    m.cols = 6
    m.tileW = 250
    m.tileH = 188
    m.stepX = 300
    m.stepY = 244
    m.visibleRows = 2
    m.focusScale = 1.13
    m.tiles = []
    m.chips = []
    m.focus = -1
    m.zone = "grid" '"grid" (apps) ou "inputs" (botoes HDMI)
    m.inputFocus = 0
    m.ambientFront = "ambientA"
    m.ready = false
    m.launching = false
    m.moving = false
    m.uptime = CreateObject("roTimespan")
    m.optionsClosedAt = -1000
    m.idleSecs = 0
    m.idleLimit = 10 * 60 'Segundos sem tecla ate a protecao de tela
    m.uiScale = m.global.uiScale
    if m.uiScale = invalid then m.uiScale = 1.0

    'Entradas da TV mostradas no canto superior. Vazio = sem botoes HDMI
    '(o Switch troca de entrada sozinho via HDMI-CEC). Exemplo para reativar:
    '{id: "tvinput.hdmi1", title: "Switch"}  - precisa do servico do PC ligado
    m.inputs = []

    m.rows = m.top.findNode("rows")
    m.message = m.top.findNode("message")
    m.clock = m.top.findNode("clock")
    m.date = m.top.findNode("date")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroIcon = m.top.findNode("heroIcon")
    m.focusAnim = m.top.findNode("focusAnim")
    m.heroAnim = m.top.findNode("heroAnim")
    m.launchAnim = m.top.findNode("launchAnim")
    m.fader = m.top.findNode("fader")
    m.top.findNode("heroMask").maskSize = [520 * m.uiScale, 390 * m.uiScale]

    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "UpdateClock")
    m.clockTimer.control = "start"
    UpdateClock()

    CreateInputChips()
    m.launchAnim.observeField("state", "OnLaunchAnimState")
    PlayIntro()
    m.top.findNode("introAnim").control = "start"
    m.top.setFocus(true)
    LoadApps()
End Sub

' ---------- Abertura animada ----------

Sub PlayIntro()
    'Mesma geometria da tela de abertura (tools/gerar_icone.py): quadrados de 132, espaco 36
    logo = m.top.findNode("introLogo")
    anim = m.top.findNode("logoAnim")
    m.introDone = false
    for i = 0 to 5
        startX = (726 + (i mod 3) * 168 + 66 - 72) * 1.0 'decimais: a Roku nao aceita inteiro misturado
        startY = (390 + (i \ 3) * 168 + 66 - 72) * 1.0
        'Destino: o lugar do icone i na primeira linha da grade
        endX = (85 + i * m.stepX + m.tileW / 2 - 72) * 1.0
        endY = (610 + m.tileH / 2 - 72) * 1.0

        square = logo.createChild("Poster")
        square.id = "introSquare" + i.ToStr()
        square.uri = "pkg:/images/ui/intro_tile_outline.png"
        square.width = 144
        square.height = 144
        square.scaleRotateCenter = [72, 72]
        square.translation = [startX, startY]

        delay = 0.06 + i * 0.03 'saem um logo apos o outro
        arrive = delay + 0.62
        AddInterp(anim, "Vector2DFieldInterpolator", square.id + ".translation", invalid, invalid, [0, delay, arrive, 1], [[startX, startY], [startX, startY], [endX, endY], [endX, endY]])
        AddInterp(anim, "Vector2DFieldInterpolator", square.id + ".scale", invalid, invalid, [0, delay, arrive, 1], [[1.0, 1.0], [1.0, 1.0], [m.tileW / 132.0, m.tileH / 132.0], [m.tileW / 132.0, m.tileH / 132.0]])
        AddInterp(anim, "FloatFieldInterpolator", square.id + ".opacity", invalid, invalid, [0, arrive - 0.05, 1], [1.0, 1.0, 0.0])
    end for
    'O preto vai sumindo enquanto os quadradinhos voam, revelando o fundo do menu
    AddInterp(anim, "FloatFieldInterpolator", "introBg.opacity", invalid, invalid, [0, 0.15, 0.75], [1.0, 1.0, 0.0])
    anim.observeField("state", "OnIntroState")
    anim.control = "start"
End Sub

Sub OnIntroState()
    if m.top.findNode("logoAnim").state = "stopped" then FinishIntro()
End Sub

Sub FinishIntro()
    if m.introDone then return
    m.introDone = true
    m.top.findNode("logoAnim").control = "stop"
    m.top.findNode("intro").visible = false
    intro = m.top.findNode("introAnim")
    if intro.state <> "running" and m.top.findNode("content").opacity < 1
        intro.delay = 0
        intro.control = "start"
    end if
End Sub

Sub UpdateClock()
    m.idleSecs = m.idleSecs + 1
    if m.idleSecs = m.idleLimit
        m.top.findNode("saver").visible = true
    end if
    if m.idleSecs >= m.idleLimit and m.idleSecs mod 60 = 0
        'Muda o relogio de lugar para nao marcar a tela
        m.top.findNode("saverClock").translation = [100 + Rnd(1000), 100 + Rnd(800)]
    end if
    days = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"]
    months = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    minutes = now.GetMinutes().ToStr()
    if minutes.Len() < 2 then minutes = "0" + minutes
    hours = now.GetHours().ToStr()
    if hours.Len() < 2 then hours = "0" + hours
    m.clock.text = hours + ":" + minutes
    m.top.findNode("saverClock").text = m.clock.text
    m.date.text = days[now.GetDayOfWeek()] + ", " + now.GetDayOfMonth().ToStr() + " de " + months[now.GetMonth() - 1]
End Sub

Sub LoadApps()
    m.message.text = ""
    m.appsTask = CreateObject("roSGNode", "EcpTask")
    m.appsTask.command = "apps"
    m.appsTask.observeField("status", "OnAppsLoaded")
    m.appsTask.control = "RUN"
End Sub

Sub OnAppsLoaded()
    if m.appsTask.status <> "ok"
        m.message.text = "Não foi possível carregar os apps. Aperte OK para tentar de novo."
        return
    end if

    m.allApps = m.appsTask.apps
    m.appById = {}
    for i = 0 to m.allApps.getChildCount() - 1
        app = m.allApps.getChild(i)
        m.appById[app.id] = app
    end for
    m.hidden = LoadHidden()
    m.orderIds = BuildOrder()
    RebuildGrid(0)
End Sub

'Apps removidos pelo usuario ficam salvos no registro da TV
Function LoadList(key as String) as Object
    raw = CreateObject("roRegistrySection", "meumenu").Read(key)
    if raw = "" then return []
    saved = ParseJson(raw)
    if saved = invalid then return []
    return saved
End Function

Sub SaveList(key as String, values as Object)
    section = CreateObject("roRegistrySection", "meumenu")
    section.Write(key, FormatJson(values))
    section.Flush()
End Sub

Function LoadHidden() as Object
    return LoadList("hidden")
End Function

Sub SaveHidden()
    SaveList("hidden", m.hidden)
End Sub

'Ordem salva pelo usuario; apps novos (ainda sem posicao) vao para o final
Function BuildOrder() as Object
    order = []
    seen = {}
    for each id in LoadList("order")
        if m.appById.DoesExist(id) and not seen.DoesExist(id)
            order.push(id)
            seen[id] = true
        end if
    end for
    for i = 0 to m.allApps.getChildCount() - 1
        id = m.allApps.getChild(i).id
        if not seen.DoesExist(id) then order.push(id)
    end for
    return order
End Function

'Grava a ordem visivel, mantendo os apps ocultos nas posicoes deles
Sub SaveOrder()
    newOrder = []
    visibleIndex = 0
    for each id in m.orderIds
        if IsHidden(id)
            newOrder.push(id)
        else
            newOrder.push(m.apps.getChild(visibleIndex).id)
            visibleIndex = visibleIndex + 1
        end if
    end for
    m.orderIds = newOrder
    SaveList("order", m.orderIds)
End Sub

Function IsHidden(appId as String) as Boolean
    for each id in m.hidden
        if id = appId then return true
    end for
    return false
End Function

Sub RebuildGrid(focusIndex as Integer)
    m.rows.removeChildrenIndex(m.rows.getChildCount(), 0)
    m.tiles = []
    m.focus = -1
    m.apps = CreateObject("roSGNode", "ContentNode")
    for each id in m.orderIds
        app = m.appById[id]
        if not IsHidden(app.id)
            item = m.apps.createChild("ContentNode")
            item.id = app.id
            item.title = app.title
            item.HDPosterUrl = app.HDPosterUrl
        end if
    end for
    for i = 0 to m.apps.getChildCount() - 1
        m.tiles.push(CreateTile(i, m.apps.getChild(i)))
    end for

    m.ready = true
    if m.tiles.Count() = 0
        m.zone = "grid"
        m.message.text = "Nenhum app no menu. Aperte * para adicionar."
        UpdateHero("", "")
        return
    end if
    m.message.text = ""
    if focusIndex > m.tiles.Count() - 1 then focusIndex = m.tiles.Count() - 1
    if focusIndex < 0 then focusIndex = 0
    m.rows.translation = [85, 610]
    SetFocus(focusIndex)
End Sub

' ---------- Painel de opcoes (tecla *) ----------

Sub OpenOptions(mode as String)
    m.optionsMode = mode
    m.optionsActions = []
    content = CreateObject("roSGNode", "ContentNode")
    title = m.top.findNode("optionsTitle")
    subtitle = m.top.findNode("optionsSubtitle")
    thumbIcon = ""

    if mode = "main"
        if m.tiles.Count() > 0
            app = m.apps.getChild(m.focus)
            title.text = app.title
            subtitle.text = "Opções do app"
            thumbIcon = app.HDPosterUrl
            AddOption(content, "Mover", "move", "", "")
            AddOption(content, "Remover do menu", "remove", "destructive", "")
        else
            title.text = "Meu Menu"
            subtitle.text = "Opções"
        end if
        if m.hidden.Count() > 0
            AddOption(content, "Apps removidos (" + m.hidden.Count().ToStr() + ")", "add", "", "")
        end if
        AddOption(content, "Cancelar", "close", "", "")
    else
        title.text = "Apps removidos"
        subtitle.text = "Escolha para voltar ao menu"
        if m.hidden.Count() > 1 then AddOption(content, "Restaurar todos", "restoreAll", "", "")
        for i = 0 to m.allApps.getChildCount() - 1
            app = m.allApps.getChild(i)
            if IsHidden(app.id) then AddOption(content, app.title, "show:" + app.id, "", app.HDPosterUrl)
        end for
        AddOption(content, "Voltar", "back", "", "")
    end if

    'Cabecalho com miniatura do app (ou so texto)
    m.top.findNode("thumbMask").visible = thumbIcon <> ""
    m.top.findNode("thumbMask").maskSize = [128 * m.uiScale, 96 * m.uiScale]
    if thumbIcon <> ""
        m.top.findNode("thumb").uri = thumbIcon
        title.translation = [186, 40]
        subtitle.translation = [186, 88]
    else
        title.translation = [36, 40]
        subtitle.translation = [36, 88]
    end if

    'Painel com altura ajustada ao numero de opcoes, centralizado na tela
    rows = content.getChildCount()
    if rows > 6 then rows = 6
    panelW = 680
    panelH = 172 + rows * 82 - 6 + 32
    panel = m.top.findNode("panel")
    panel.translation = [(1920 - panelW) / 2, (1080 - panelH) / 2]
    panel.scaleRotateCenter = [panelW / 2, panelH / 2]
    for each id in ["panelBg", "panelEdge"]
        node = m.top.findNode(id)
        node.width = panelW
        node.height = panelH
    end for
    shadow = m.top.findNode("panelShadow")
    shadow.width = panelW + 120
    shadow.height = panelH + 120

    list = m.top.findNode("optionsList")
    list.numRows = rows
    list.content = content
    list.jumpToItem = 0
    overlay = m.top.findNode("optionsOverlay")
    if not overlay.visible
        overlay.visible = true
        m.top.findNode("mascots").paused = true
        m.top.findNode("gengarEyes").paused = true
        list.observeField("itemSelected", "OnOptionSelected")
        list.observeField("itemFocused", "OnOptionFocused")
        PlaySound("sfxSelect")
    end if
    m.top.findNode("overlayAnim").control = "start"
    list.setFocus(true)
End Sub

Sub AddOption(content as Object, label as String, action as String, style as String, icon as String)
    item = content.createChild("ContentNode")
    item.title = label
    item.description = style
    item.HDPosterUrl = icon
    m.optionsActions.push(action)
End Sub

Sub CloseOptions()
    list = m.top.findNode("optionsList")
    list.unobserveField("itemSelected")
    list.unobserveField("itemFocused")
    overlay = m.top.findNode("optionsOverlay")
    overlay.visible = false
    overlay.opacity = 0
    m.optionsClosedAt = m.uptime.TotalMilliseconds()
    m.top.findNode("mascots").paused = false
    m.top.findNode("gengarEyes").paused = false
    'Tira o foco da lista explicitamente; senao ela continua "engolindo" cima/baixo
    list.setFocus(false)
    m.top.setFocus(true)
End Sub

Sub OnOptionFocused()
    if m.top.findNode("optionsOverlay").visible then PlaySound("sfxMove")
End Sub

Sub OnOptionSelected()
    PlaySound("sfxSelect")
    action = m.optionsActions[m.top.findNode("optionsList").itemSelected]
    if action = "remove"
        m.hidden.push(m.apps.getChild(m.focus).id)
        SaveHidden()
        CloseOptions()
        RebuildGrid(m.focus)
    else if action = "add"
        OpenOptions("add")
    else if action = "back"
        OpenOptions("main")
    else if Left(action, 5) = "show:"
        appId = Mid(action, 6)
        visible = []
        for each id in m.hidden
            if id <> appId then visible.push(id)
        end for
        m.hidden = visible
        SaveHidden()
        CloseOptions()
        RebuildGrid(0)
        for i = 0 to m.apps.getChildCount() - 1
            if m.apps.getChild(i).id = appId then SetFocus(i)
        end for
    else if action = "move"
        CloseOptions()
        StartMove()
    else if action = "restoreAll"
        m.hidden = []
        SaveHidden()
        CloseOptions()
        RebuildGrid(m.focus)
    else if action = "close"
        CloseOptions()
    end if
End Sub

Function CreateTile(i as Integer, app as Object) as Object
    tile = m.rows.createChild("Group")
    tile.id = "tile" + i.ToStr()
    tile.translation = [(i mod m.cols) * m.stepX, (i \ m.cols) * m.stepY]
    tile.scaleRotateCenter = [m.tileW / 2, m.tileH / 2]

    shadow = tile.createChild("Poster")
    shadow.id = "shadow" + i.ToStr()
    shadow.uri = "pkg:/images/ui/tile_shadow.png"
    shadow.translation = [-34, -22]
    shadow.width = m.tileW + 68
    shadow.height = m.tileH + 68
    shadow.opacity = 0

    clip = tile.createChild("MaskGroup")
    clip.maskUri = "pkg:/images/ui/tile_mask.png"
    clip.maskSize = [m.tileW * m.uiScale, m.tileH * m.uiScale]

    icon = clip.createChild("Poster")
    icon.uri = app.HDPosterUrl
    icon.width = m.tileW
    icon.height = m.tileH
    icon.loadDisplayMode = "scaleToFill"

    sheen = clip.createChild("Poster")
    sheen.id = "sheen" + i.ToStr()
    sheen.uri = "pkg:/images/ui/tile_sheen.png"
    sheen.width = m.tileW
    sheen.height = m.tileH
    sheen.opacity = 0

    edge = tile.createChild("Poster")
    edge.uri = "pkg:/images/ui/tile_border.png"
    edge.width = m.tileW
    edge.height = m.tileH

    return {group: tile, shadow: shadow, sheen: sheen}
End Function

Sub CreateInputChips()
    container = m.top.findNode("inputs")
    for i = 0 to m.inputs.Count() - 1
        chip = container.createChild("Group")
        chip.id = "chip" + i.ToStr()
        chip.translation = [i * 210, 0]
        chip.scaleRotateCenter = [95, 32]

        bg = chip.createChild("Poster")
        bg.id = "chipBg" + i.ToStr()
        bg.uri = "pkg:/images/ui/pill.png"
        bg.width = 190
        bg.height = 64
        bg.opacity = 0.16

        text = chip.createChild("Label")
        text.text = m.inputs[i].title
        text.width = 190
        text.height = 64
        text.horizAlign = "center"
        text.vertAlign = "center"
        text.color = "0xFFFFFFE0"
        font = CreateObject("roSGNode", "Font")
        font.uri = "font:BoldSystemFontFile"
        font.size = 26
        text.font = font

        m.chips.push({group: chip, bg: bg, text: text})
    end for
End Sub

Sub PlaySound(id as String)
    sfx = m.top.findNode(id)
    if sfx = invalid then return 'sons desativados
    sfx.control = "stop"
    sfx.control = "play"
End Sub

Sub AddInterp(anim as Object, kind as String, field as String, fromValue as Object, toValue as Object, keys = invalid as Object, values = invalid as Object)
    interp = anim.createChild(kind)
    if keys = invalid
        interp.key = [0, 1]
        interp.keyValue = ToFloats([fromValue, toValue])
    else
        interp.key = keys
        interp.keyValue = ToFloats(values)
    end if
    interp.fieldToInterp = field
End Sub

'Interpoladores da Roku rejeitam inteiros (ou inteiros misturados com decimais)
Function ToFloats(value as Dynamic) as Dynamic
    if type(value) = "roArray"
        result = []
        for each item in value
            result.push(ToFloats(item))
        end for
        return result
    end if
    if type(value) = "roInt" or type(value) = "Integer" then return value * 1.0
    return value
End Function

Function RestartAnim(anim as Object) as Object
    anim.control = "stop"
    anim.removeChildrenIndex(anim.getChildCount(), 0)
    return anim
End Function

Sub AnimateTile(anim as Object, i as Integer, focused as Boolean)
    t = m.tiles[i]
    if focused then s = m.focusScale else s = 1.0
    if focused then level = 1.0 else level = 0.0
    AddInterp(anim, "Vector2DFieldInterpolator", t.group.id + ".scale", t.group.scale, [s, s])
    AddInterp(anim, "FloatFieldInterpolator", t.shadow.id + ".opacity", t.shadow.opacity, level)
    AddInterp(anim, "FloatFieldInterpolator", t.sheen.id + ".opacity", t.sheen.opacity, level)
End Sub

Sub AnimateChip(anim as Object, i as Integer, focused as Boolean)
    c = m.chips[i]
    if focused
        AddInterp(anim, "Vector2DFieldInterpolator", c.group.id + ".scale", c.group.scale, [1.1, 1.1])
        AddInterp(anim, "FloatFieldInterpolator", c.bg.id + ".opacity", c.bg.opacity, 1.0)
        c.text.color = "0x111118FF"
    else
        AddInterp(anim, "Vector2DFieldInterpolator", c.group.id + ".scale", c.group.scale, [1.0, 1.0])
        AddInterp(anim, "FloatFieldInterpolator", c.bg.id + ".opacity", c.bg.opacity, 0.16)
        c.text.color = "0xFFFFFFE0"
    end if
End Sub

Sub SetFocus(index as Integer)
    old = m.focus
    fromInputs = m.zone = "inputs"
    if old >= 0 and (old <> index or fromInputs) then PlaySound("sfxMove")
    m.focus = index
    m.zone = "grid"
    anim = RestartAnim(m.focusAnim)

    if fromInputs then AnimateChip(anim, m.inputFocus, false)
    if old >= 0 and old <> index then AnimateTile(anim, old, false)
    AnimateTile(anim, index, true)

    'Rola as linhas quando ha mais apps do que cabem na tela
    targetY = RowsOffset(index)
    if m.rows.translation[1] <> targetY
        AddInterp(anim, "Vector2DFieldInterpolator", "rows.translation", m.rows.translation, [85, targetY])
    end if
    anim.control = "start"

    if old <> index or fromInputs
        app = m.apps.getChild(index)
        UpdateHero(app.title, app.HDPosterUrl)
    end if
End Sub

Sub FocusInput(index as Integer)
    PlaySound("sfxMove")
    anim = RestartAnim(m.focusAnim)
    if m.zone = "grid"
        AnimateTile(anim, m.focus, false)
    else if index <> m.inputFocus
        AnimateChip(anim, m.inputFocus, false)
    end if
    m.zone = "inputs"
    m.inputFocus = index
    AnimateChip(anim, index, true)
    anim.control = "start"
    UpdateHero(m.inputs[index].title, "")
End Sub

Sub UpdateHero(title as String, icon as String)
    m.heroTitle.text = title
    if icon <> "" then m.heroIcon.uri = icon

    'Alterna entre dois fundos para fazer crossfade da cor ambiente
    if m.ambientFront = "ambientA" then nextAmbient = "ambientB" else nextAmbient = "ambientA"
    front = m.top.findNode(m.ambientFront)
    back = m.top.findNode(nextAmbient)
    if icon <> "" then back.uri = icon
    m.ambientFront = nextAmbient

    if icon <> "" then artOpacity = 1.0 else artOpacity = 0.0
    if icon <> "" then ambientOpacity = 0.75 else ambientOpacity = 0.0

    anim = RestartAnim(m.heroAnim)
    AddInterp(anim, "FloatFieldInterpolator", "heroText.opacity", 0.0, 1.0)
    AddInterp(anim, "Vector2DFieldInterpolator", "heroText.translation", [130, 140], [100, 140])
    AddInterp(anim, "FloatFieldInterpolator", "heroArt.opacity", 0.0, artOpacity)
    AddInterp(anim, "Vector2DFieldInterpolator", "heroArt.scale", [0.94, 0.94], [1.0, 1.0])
    AddInterp(anim, "FloatFieldInterpolator", back.id + ".opacity", back.opacity, ambientOpacity)
    AddInterp(anim, "FloatFieldInterpolator", front.id + ".opacity", front.opacity, 0.0)
    anim.control = "start"
End Sub

' ---------- Modo mover (reordenar apps) ----------

Sub StartMove()
    m.moving = true
    anim = RestartAnim(m.focusAnim)
    for i = 0 to m.tiles.Count() - 1
        t = m.tiles[i]
        if i = m.focus
            AddInterp(anim, "Vector2DFieldInterpolator", t.group.id + ".scale", t.group.scale, [1.22, 1.22])
        else
            AddInterp(anim, "FloatFieldInterpolator", t.group.id + ".opacity", t.group.opacity, 0.4)
        end if
    end for
    anim.control = "start"
    m.top.findNode("heroHint").text = "Use as setas para mover  ·  OK para concluir"
End Sub

Sub EndMove()
    m.moving = false
    anim = RestartAnim(m.focusAnim)
    for i = 0 to m.tiles.Count() - 1
        t = m.tiles[i]
        if i = m.focus
            AddInterp(anim, "Vector2DFieldInterpolator", t.group.id + ".scale", t.group.scale, [m.focusScale, m.focusScale])
        else
            AddInterp(anim, "FloatFieldInterpolator", t.group.id + ".opacity", t.group.opacity, 1.0)
        end if
    end for
    anim.control = "start"
    m.top.findNode("heroHint").text = ""
End Sub

Function SlotPosition(i as Integer) as Object
    return [(i mod m.cols) * m.stepX, (i \ m.cols) * m.stepY]
End Function

Sub MoveApp(fromIndex as Integer, toIndex as Integer)
    'Reordena os blocos e o conteudo
    moved = m.tiles[fromIndex]
    others = []
    for i = 0 to m.tiles.Count() - 1
        if i <> fromIndex then others.push(m.tiles[i])
    end for
    tiles = []
    for i = 0 to others.Count()
        if i = toIndex then tiles.push(moved)
        if i < others.Count() then tiles.push(others[i])
    end for
    m.tiles = tiles
    node = m.apps.getChild(fromIndex)
    m.apps.removeChildIndex(fromIndex)
    m.apps.insertChild(node, toIndex)
    m.focus = toIndex
    PlaySound("sfxMove")
    SaveOrder()

    'Anima cada bloco ate a nova posicao
    anim = RestartAnim(m.focusAnim)
    for i = 0 to m.tiles.Count() - 1
        t = m.tiles[i]
        target = SlotPosition(i)
        if t.group.translation[0] <> target[0] or t.group.translation[1] <> target[1]
            AddInterp(anim, "Vector2DFieldInterpolator", t.group.id + ".translation", t.group.translation, target)
        end if
    end for
    targetY = RowsOffset(toIndex)
    if m.rows.translation[1] <> targetY
        AddInterp(anim, "Vector2DFieldInterpolator", "rows.translation", m.rows.translation, [85, targetY])
    end if
    anim.control = "start"
End Sub

Function RowsOffset(index as Integer) as Integer
    firstRow = index \ m.cols - m.visibleRows + 1
    if firstRow < 0 then firstRow = 0
    return 610 - firstRow * m.stepY
End Function

'Indice de destino para uma seta na grade (-1 = sem destino, -2 = subir para HDMI)
Function GridTarget(key as String) as Integer
    count = m.tiles.Count()
    if key = "right" and (m.focus + 1) mod m.cols <> 0 and m.focus + 1 < count then return m.focus + 1
    if key = "left" and m.focus mod m.cols <> 0 then return m.focus - 1
    if key = "down" and (m.focus \ m.cols) < ((count - 1) \ m.cols)
        target = m.focus + m.cols
        if target >= count then target = count - 1
        return target
    end if
    if key = "up" and m.focus >= m.cols then return m.focus - m.cols
    if key = "up" and m.inputs.Count() > 0 then return -2
    return -1
End Function

Sub LaunchFocused()
    PlaySound("sfxSelect")
    m.launching = true
    if m.zone = "inputs"
        m.launchId = m.inputs[m.inputFocus].id
        target = m.chips[m.inputFocus].group
        restScale = 1.1
    else
        m.launchId = m.apps.getChild(m.focus).id
        target = m.tiles[m.focus].group
        restScale = m.focusScale
    end if
    m.launchTarget = target
    m.launchRestScale = restScale

    anim = RestartAnim(m.launchAnim)
    pulse = anim.createChild("Vector2DFieldInterpolator")
    pulse.key = [0, 0.35, 1]
    pulse.keyValue = [[restScale, restScale], [restScale * 0.9, restScale * 0.9], [restScale * 1.1, restScale * 1.1]]
    pulse.fieldToInterp = target.id + ".scale"
    AddInterp(anim, "FloatFieldInterpolator", "fader.opacity", 0.0, 1.0)
    anim.control = "start"
End Sub

Sub OnLaunchAnimState()
    if m.launchAnim.state <> "stopped" or not m.launching then return
    m.launchTask = CreateObject("roSGNode", "EcpTask")
    m.launchTask.command = "launch"
    m.launchTask.appId = m.launchId
    m.launchTask.observeField("status", "OnLaunched")
    m.launchTask.control = "RUN"
End Sub

Sub OnLaunched()
    'Se o app nao abrir (ou ao voltar), restaura a tela
    m.launching = false
    m.fader.opacity = 0
    m.launchTarget.scale = [m.launchRestScale, m.launchRestScale]
    if m.launchTask.status = "sem_pc"
        m.message.text = "Para trocar de entrada, o PC precisa estar ligado."
    end if
End Sub

Function onKeyEvent(key as String, press as Boolean) as Boolean
    m.idleSecs = 0
    saver = m.top.findNode("saver")
    if saver.visible
        'A tecla que acorda a tela nao age no menu
        if not press then saver.visible = false
        return true
    end if
    'Qualquer tecla pula a abertura
    if not m.introDone
        if press then FinishIntro()
        return true
    end if
    if not press or m.launching then return press and m.launching
    if m.top.findNode("optionsOverlay").visible
        if key = "back" or key = "options"
            if m.optionsMode = "add" and key = "back" then OpenOptions("main") else CloseOptions()
        end if
        return true
    end if
    'O OK que escolheu uma opcao tambem chega aqui depois do painel fechar: ignora
    if key = "OK" and m.uptime.TotalMilliseconds() - m.optionsClosedAt < 400 then return true
    if m.moving
        if key = "OK" or key = "back" or key = "options"
            EndMove()
        else
            target = GridTarget(key)
            if target >= 0 then MoveApp(m.focus, target)
        end if
        return true
    end if

    if key = "options" and m.ready and m.zone = "grid"
        OpenOptions("main")
        return true
    end if
    if not m.ready
        if key = "OK" then LoadApps()
        return key = "OK"
    end if
    m.message.text = ""
    if key = "back" then return false
    if key = "OK"
        if m.zone = "grid" and m.tiles.Count() = 0 then return true
        LaunchFocused()
        return true
    end if

    if m.zone = "inputs"
        if key = "left" and m.inputFocus > 0
            FocusInput(m.inputFocus - 1)
        else if key = "right" and m.inputFocus < m.inputs.Count() - 1
            FocusInput(m.inputFocus + 1)
        else if key = "down"
            SetFocus(m.focus)
        end if
        return true
    end if

    if m.tiles.Count() = 0 then return true
    target = GridTarget(key)
    if target = -2
        'Da primeira linha sobe para o botao HDMI mais proximo
        column = m.focus mod m.cols
        if column > m.inputs.Count() - 1 then column = m.inputs.Count() - 1
        FocusInput(column)
    else if target >= 0 and target <> m.focus
        SetFocus(target)
    end if
    return true
End Function
