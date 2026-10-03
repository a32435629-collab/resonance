-- Func #182: Reverse Controls | toggle
local State = { running = false }

return {
    id = "ReverseControls", type = "toggle", name = "Reverse Controls",
    tooltip = "Инвертировать управление у себя", tab = "Trolling", default = false,
    onEnable = function(Settings, Utils)
        State.running = true
        task.spawn(function()
            while State.running do
                task.wait(0.05)
                local hum = Utils.getHum()
                if hum then
                    -- визуальный эффект через camera
                end
            end
        end)
    end,
    onDisable = function() State.running = false end
}