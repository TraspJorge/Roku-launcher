Sub init()
    m.top.functionName = "run"
End Sub

Sub run()
    if m.top.command = "apps"
        'Lista e icones gerados no PC (a Roku bloqueia ECP vindo de dentro do app)
        apps = ParseJson(ReadAsciiFile("pkg:/source/apps.json"))
        if apps = invalid
            m.top.status = "erro"
            return
        end if
        content = CreateObject("roSGNode", "ContentNode")
        for each app in apps
            item = content.CreateChild("ContentNode")
            item.id = app.id
            item.title = app.title
            item.ShortDescriptionLine1 = app.title
            item.HDGridPosterUrl = app.icon
            item.HDPosterUrl = app.icon
        end for
        m.top.apps = content
        m.top.status = "ok"

    else if m.top.command = "launch"
        if Left(m.top.appId, 8) = "tvinput."
            m.top.status = LaunchInputViaPc(m.top.appId)
            return
        end if
        try
            CreateObject("roAppManager").LaunchApp(m.top.appId, "", {})
            m.top.status = "launched"
        catch e
            print "Falha ao abrir "; m.top.appId; ": "; e.message
            m.top.status = "erro"
        end try
    end if
End Sub

'A Roku ignora LaunchApp para entradas HDMI: pede ao servico do PC para trocar
Function LaunchInputViaPc(inputId as String) as String
    config = ParseJson(ReadAsciiFile("pkg:/source/pc.json"))
    if config = invalid then return "sem_pc"
    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.SetMessagePort(port)
    http.SetUrl(config.bridge + "/launch/" + inputId)
    if not http.AsyncGetToString() then return "sem_pc"
    msg = wait(4000, port)
    if type(msg) = "roUrlEvent" and msg.GetResponseCode() = 200 then return "launched"
    return "sem_pc"
End Function
