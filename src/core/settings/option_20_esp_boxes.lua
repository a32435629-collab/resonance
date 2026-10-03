return {
    id = "ESPBoxes", type = "toggle", name = "ESP Boxes",
    section = "ESP", tab = "Visuals",
    default = false,
    tooltip = "Рамки вокруг игроков",
    onChanged = function(v, S) S.ESPBoxes = v end
}