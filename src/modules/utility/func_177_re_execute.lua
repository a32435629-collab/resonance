-- Func #177: Re-execute Script | button
return {
    id = "ReExecute", type = "button", name = "Re-execute Script",
    tooltip = "Перезапустить скрипт", tab = "Utility",
    onClick = function(Settings, Utils)
        local url = "https://raw.githubusercontent.com/a32435629-collab/resonance/main/dist/resonance.lua"
        local ok, err = pcall(function()
            loadstring(game:HttpGet(url))()
        end)
        if not ok then
            Utils.notify("Resonance", "Ошибка: " .. tostring(err), Settings)
        end
    end
}