-- Func #167: Clear Workspace | button
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return {
    id = "ClearWorkspace", type = "button", name = "Clear Workspace",
    tooltip = "Удалить модели (кроме персонажей)", tab = "Utility",
    onClick = function(Settings, Utils)
        local count = 0
        for _, obj in pairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                pcall(function() obj:Destroy() end)
                count = count + 1
            end
        end
        Utils.notify("Resonance", "Удалено: " .. count, Settings)
    end
}