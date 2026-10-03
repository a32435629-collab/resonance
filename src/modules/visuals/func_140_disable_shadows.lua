-- Func #140: Disable Shadows | toggle
local Lighting = game:GetService("Lighting")
local State = { orig = nil }

return {
    id = "DisableShadows", type = "toggle", name = "Disable Shadows",
    tooltip = "Отключить тени", tab = "Visuals", default = false,
    onEnable = function(Settings, Utils)
        State.orig = Lighting.GlobalShadows
        Lighting.GlobalShadows = false
    end,
    onDisable = function()
        Lighting.GlobalShadows = State.orig ~= false
    end
}