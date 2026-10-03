return {
    id = "SpinRPM", type = "slider", name = "Spin RPM",
    section = "Торнадо", tab = "Auras",
    default = 60, range = {10, 500}, increment = 10, suffix = " RPM",
    tooltip = "Скорость вращения",
    onChanged = function(v, S) S.SpinRPM = v end
}