return {
    id = "AntiGrab", type = "toggle", name = "Anti-Grab",
    section = "Защита", tab = "Protection",
    default = true,
    tooltip = "Иммунитет к чужим захватам",
    onChanged = function(v, S) S.AntiGrab = v end
}