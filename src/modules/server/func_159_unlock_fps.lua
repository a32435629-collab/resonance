-- Func #159: Unlock FPS | toggle
return {
    id = "UnlockFps", type = "toggle", name = "Unlock FPS",
    tooltip = "Снять лимит FPS (до 240)", tab = "Server", default = false,
    onEnable = function(Settings, Utils)
        if setfpscap then
            setfpscap(240)
            Utils.notify("Resonance", "FPS cap: 240", Settings)
        end
    end,
    onDisable = function(Settings, Utils)
        if setfpscap then
            setfpscap(60)
            Utils.notify("Resonance", "FPS cap: 60", Settings)
        end
    end
}