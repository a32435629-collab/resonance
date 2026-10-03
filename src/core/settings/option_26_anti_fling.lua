return {
    id = "AntiFling", type = "toggle", name = "Anti-Fling",
    section = "Защита", tab = "Protection",
    default = true,
    tooltip = "Иммунитет к флингу",
    onChanged = function(v, S) S.AntiFling = v end
}