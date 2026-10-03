-- ============================================================
-- Resonance v4.0 — ui/notifications.lua
-- Обёртка над Library:Notify для единообразных уведомлений
-- ============================================================

local Notifications = {}

local function getLibrary()
    return _G.ResonanceLibrary
end

-- Базовое уведомление
function Notifications.send(title, content, duration)
    local Library = getLibrary()
    if not Library then
        warn("[Resonance] Library не загружена для уведомления")
        return
    end
    pcall(function()
        Library:Notify({
            Title = title or "Resonance",
            Content = content or "",
            Duration = duration or 3
        })
    end)
end

-- Успех
function Notifications.success(content, duration)
    Notifications.send("✓ Успех", content, duration)
end

-- Ошибка
function Notifications.error(content, duration)
    Notifications.send("✗ Ошибка", content, duration)
end

-- Предупреждение
function Notifications.warn(content, duration)
    Notifications.send("⚠ Внимание", content, duration)
end

-- Информация
function Notifications.info(content, duration)
    Notifications.send("ℹ Инфо", content, duration)
end

-- Только для debug-режима
function Notifications.debug(content)
    if _G.ResonanceSettings and _G.ResonanceSettings.Debug then
        Notifications.send("[DEBUG]", content, 2)
    end
end

-- Биндим в Utils для использования из модулей
if _G.ResonanceUtils then
    _G.ResonanceUtils.notifyLib = Notifications.send
end

return Notifications