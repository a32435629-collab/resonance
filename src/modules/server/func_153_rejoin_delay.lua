-- Func #153: Rejoin Delay | button
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

return {
    id = "RejoinDelay", type = "button", name = "Rejoin in 3s",
    tooltip = "Переподключиться через 3 секунды", tab = "Server",
    onClick = function(Settings, Utils)
        Utils.notify("Resonance", "Ре-джойн через 3 сек...", Settings)
        task.wait(3)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
}