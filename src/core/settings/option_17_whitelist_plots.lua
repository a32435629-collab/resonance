return {
    id = "WhitelistPlots", type = "toggle", name = "Whitelist Plots",
    section = "Исключения", tab = "Filters",
    default = false,
    tooltip = "Не трогать игроков на их участках",
    onChanged = function(v, S) S.WhitelistPlots = v end
}