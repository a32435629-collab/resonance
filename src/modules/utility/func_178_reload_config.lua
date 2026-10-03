-- Func #178: Reload Config | button
return {
    id = "ReloadConfig", type = "button", name = "Reload Config",
    tooltip = "Загрузить конфиг", tab = "Utility",
    onClick = function(Settings, Utils)
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.load(Settings)
            if ok then
                Utils.notify("Resonance", "Конфиг загружен", Settings)
            else
                Utils.notify("Resonance", "Ошибка: " .. tostring(err), Settings)
            end
        end
    end
}