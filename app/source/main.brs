Sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    'MaskGroup usa pixels reais da tela: em TVs 720p a mascara precisa ser reduzida
    uiHeight = CreateObject("roDeviceInfo").GetUIResolution().height
    screen.getGlobalNode().addFields({uiScale: uiHeight / 1080.0})
    scene = screen.CreateScene("MenuScene")
    if CreateObject("roFileSystem").Exists("pkg:/images/fundo.jpg") 'Fundo personalizado, se existir
        scene.findNode("background").uri = "pkg:/images/fundo.jpg"
    end if
    screen.Show()

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.IsScreenClosed() then return
    end while
End Sub
