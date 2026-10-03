return {
    id = "ESPTracers", type = "toggle", name = "ESP Tracers",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Линии от низа экрана к игрокам",
    onChanged = function(v, S) S.ESPTracers = v end
}