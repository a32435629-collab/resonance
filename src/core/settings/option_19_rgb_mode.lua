return {
    id = "RGBMode", type = "toggle", name = "RGB / Rainbow Mode",
    section = "Визуал", tab = "Visuals",
    default = false,
    tooltip = "Переливание элементов всеми цветами",
    onChanged = function(v, S) S.RGBMode = v end
}