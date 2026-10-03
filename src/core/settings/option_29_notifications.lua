return {
    id = "Notifications", type = "toggle", name = "Notifications",
    section = "Интерфейс", tab = "Settings",
    default = true,
    tooltip = "Показывать всплывающие уведомления",
    onChanged = function(v, S) S.Notifications = v end
}