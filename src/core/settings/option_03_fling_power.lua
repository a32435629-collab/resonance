return {
    id = "FlingPower", type = "slider", name = "Fling Power",
    section = "Дистанции", tab = "Combat",
    default = 300, range = {50, 1000}, increment = 10, suffix = " p",
    tooltip = "Сила флинга",
    onChanged = function(v, S) S.FlingPower = v end
}