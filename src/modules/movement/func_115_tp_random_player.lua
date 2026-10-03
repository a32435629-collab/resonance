-- Func #115: Teleport to Random Player | button
return {
    id = "TpRandomPlayer", type = "button", name = "Teleport to Random Player",
    tooltip = "Телепорт к случайному игроку", tab = "Movement",
    onClick = function(Settings, Utils)
        local list = Utils.getAllPlayers(false)
        if #list == 0 then return end
        local target = list[math.random(1, #list)]
        local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 3, 0)) end
    end
}