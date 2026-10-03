-- Func #147: Copy Server Link | button
return {
    id = "CopyServerLink", type = "button", name = "Copy Server Link",
    tooltip = "Скопировать ссылку на сервер", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            local link = "roblox://placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId
            setclipboard(link)
            Utils.notify("Resonance", "Ссылка скопирована", Settings)
        end
    end
}