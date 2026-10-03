-- Func #146: Copy PlaceID | button
return {
    id = "CopyPlaceId", type = "button", name = "Copy PlaceID",
    tooltip = "Скопировать PlaceID игры", tab = "Server",
    onClick = function(Settings, Utils)
        if setclipboard then
            setclipboard(tostring(game.PlaceId))
            Utils.notify("Resonance", "PlaceID скопирован", Settings)
        end
    end
}