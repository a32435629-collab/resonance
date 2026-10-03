return {
    id = "AnimBlend", type = "slider", name = "Blend Weight",
    section = "Анимации", tab = "Animations",
    default = 1, range = {0, 1}, increment = 0.05, suffix = " w",
    tooltip = "Вес смешивания анимации",
    onChanged = function(v, S) S.AnimBlend = v end
}