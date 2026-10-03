-- Func #222: Stop All Anims
-- Категория: Animations | Тип: button

return {
    id = "StopAllAnims", type = "button", name = "Остановить все анимации",
    tooltip = "Останавливает все проигрываемые треки персонажа",
    tab = "Animations",
    onClick = function(Settings, Utils)
        local char = Utils.getChar()
        if not char then return end
        local animator = char:FindFirstChildOfClass("Animator")
        if not animator then return end
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0.1) end)
        end
        _G.ResonanceCurrentAnim = nil
    end
}