-- Func #118: Teleport Down | button
return {
    id = "TpDown", type = "button", name = "Teleport Down",
    tooltip = "Телепорт вниз на 50 studs", tab = "Movement",
    onClick = function(Settings, Utils)
        local hrp = Utils.getHRP()
        if hrp then Utils.teleportTo(hrp.CFrame + Vector3.new(0, -50, 0)) end
    end
}