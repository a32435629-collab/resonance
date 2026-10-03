return {
    id = "SpinRadius", type = "slider", name = "Spin Radius",
    section = "Торнадо", tab = "Auras",
    default = 5, range = {1, 50}, increment = 1, suffix = " studs",
    tooltip = "Радиус орбиты вокруг вас",
    onChanged = function(v, S) S.SpinRadius = v end
}