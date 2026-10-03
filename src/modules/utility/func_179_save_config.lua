-- Func #179: Save Config | button
return {
    id = "SaveConfig", type = "button", name = "Save Config",
    tooltip = "Сохранить конфиг", tab = "Utility",
    onClick = function(Settings, Utils)
        local Config = _G.ResonanceConfig
        if Config then
            local ok, err = Config.save(Settings)
            if ok then
                Utils.notify("Resonance", "Конфиг сохранён", Settings)
            else
                Utils.notify("Resonance", "Ошибка: " .. tostring(err), Settings)
            end
        end
    end
}