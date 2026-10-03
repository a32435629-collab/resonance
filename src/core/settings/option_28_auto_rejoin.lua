return {
    id = "AutoRejoin", type = "toggle", name = "Auto Rejoin",
    section = "Сервер", tab = "Server",
    default = false,
    tooltip = "Авто-переподключение после кика",
    onChanged = function(v, S) S.AutoRejoin = v end
}