return {
    id = "WalkSpeed", type = "slider", name = "WalkSpeed",
    section = "Движение", tab = "Movement",
    default = 16, range = {16, 500}, increment = 1, suffix = " studs",
    tooltip = "Скорость передвижения",
    onChanged = function(v, S)
        S.WalkSpeed = v
        local p = game:GetService("Players").LocalPlayer
        local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = v end
    end
}