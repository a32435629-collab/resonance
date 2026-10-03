-- Func #170: Full Screen | toggle
local UserInputService = game:GetService("UserInputService")

return {
    id = "FullScreen", type = "toggle", name = "Full Screen",
    tooltip = "Освободить курсор из центра", tab = "Utility", default = false,
    onEnable = function(Settings, Utils)
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end,
    onDisable = function(Settings, Utils)
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end
}