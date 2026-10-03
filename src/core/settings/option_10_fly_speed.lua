return {
    id = "FlySpeed", type = "slider", name = "Fly Speed",
    section = "Движение", tab = "Movement",
    default = 50, range = {10, 500}, increment = 5, suffix = " studs",
    tooltip = "Скорость полёта",
    onChanged = function(v, S) S.FlySpeed = v end
}