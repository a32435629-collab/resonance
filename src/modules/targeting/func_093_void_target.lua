-- Func #093: Void Target | button
local Players = game:GetService("Players")

return {
    id = "VoidTarget", type = "button", name = "Void Target",
    tooltip = "Отправить цель в пустоту", tab = "Targeting",
    onClick = function(Settings, Utils)
        local name = Settings.TargetName or Settings.TargetPlayerName
        if not name or name == "" then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(0, -500, 0) end
    end
}