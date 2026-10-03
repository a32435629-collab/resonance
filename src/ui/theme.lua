-- ============================================================
-- Resonance v4.0 — ui/theme.lua
-- Кастомные настройки темы Obsidian
-- ============================================================

local Theme = {
    -- Основные цвета (hex)
    Accent      = Color3.fromRGB(120, 90, 255),
    AccentDark  = Color3.fromRGB(80, 60, 180),
    Background  = Color3.fromRGB(18, 18, 24),
    Panel       = Color3.fromRGB(26, 26, 36),
    Text        = Color3.fromRGB(240, 240, 255),
    TextDim     = Color3.fromRGB(150, 150, 170),
    Success     = Color3.fromRGB(80, 200, 120),
    Danger      = Color3.fromRGB(220, 80, 80),
    Warning     = Color3.fromRGB(240, 180, 60),

    -- Настройки окна
    Window = {
        Title = "Resonance",
        Icon = "rocket",
        Footer = "Resonance v4.0 | FTAP",
        CornerRadius = 20,
        Width = 600,
        Height = 500,
        MinWidth = 400,
        MinHeight = 300,
        NotifySide = "Right"
    },

    -- Настройки анимаций
    Animations = {
        OpenTime  = 0.25,
        CloseTime = 0.2,
        HoverTime = 0.15,
        EasingStyle = Enum.EasingStyle.Quart,
        EasingDirection = Enum.EasingDirection.Out
    }
}

-- Применить тему к Library (если поддерживается)
function Theme.apply(Library)
    if not Library then return end
    local ok, err = pcall(function()
        if Library.SetAccentColor then
            Library:SetAccentColor(Theme.Accent)
        end
        if Library.SetCornerRadius then
            Library:SetCornerRadius(Theme.Window.CornerRadius)
        end
    end)
    if not ok then
        warn("[Resonance Theme] " .. tostring(err))
    end
end

return Theme