return {
    id = "LineMaterial", type = "dropdown", name = "Line Material",
    section = "Захват", tab = "Combat",
    default = "Neon",
    options = {"Neon","Forcefield","Glass","Invisible"},
    multiple = false,
    tooltip = "Материал луча захвата",
    onChanged = function(opt, S) S.LineMaterial = opt[1] end
}