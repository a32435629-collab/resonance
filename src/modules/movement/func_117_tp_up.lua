-- Func #117: Teleport Up | button
return {
    id = "TpUp", type = "button", name = "Teleport Up",
    tooltip = "Телепорт вверх на 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, 50, 0)) end
    end
}