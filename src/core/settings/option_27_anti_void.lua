return {
    id = "AntiVoid", type = "toggle", name = "Anti-Void",
    section = "Защита", tab = "Protection",
    default = true,
    tooltip = "Авто-возврат при падении под текстуры",
    onChanged = function(v, S) S.AntiVoid = v end
}