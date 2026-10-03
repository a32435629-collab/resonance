return {
    id = "ESPInfo", type = "toggle", name = "Player Info",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Ник, HP и дистанция",
    onChanged = function(v, S) S.ESPInfo = v end
}