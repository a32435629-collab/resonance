return {
    id = "TargetLockMethod", type = "dropdown", name = "Target Lock Method",
    section = "Наведение", tab = "Combat",
    default = "Ближайший игрок",
    options = {"По курсору","Ближайший игрок","По нику из списка"},
    multiple = false,
    tooltip = "Алгоритм автонаведения",
    onChanged = function(opt, S) S.TargetLockMethod = opt[1] end
}