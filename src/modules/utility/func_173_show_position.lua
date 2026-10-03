-- Func #173: Show Position | button
return {
    id = "ShowPosition", type = "button", name = "Show Position",
    tooltip = "Показать текущую позицию", tab = "Utility",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then
            Utils.notify("Position", tostring(hrp.Position), Settings)
        end
    end
}