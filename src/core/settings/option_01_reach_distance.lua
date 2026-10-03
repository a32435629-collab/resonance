return {
    id = "ReachDistance", type = "slider", name = "Reach Distance",
    section = "Дистанции", tab = "Main",
    default = 20, range = {1, 1000}, increment = 1, suffix = " studs",
    tooltip = "Радиус захвата объекта или игрока",
    onChanged = function(v, S) S.ReachDistance = v end
}