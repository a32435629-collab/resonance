-- ============================================================
-- Resonance v4.0 — core/config.lua
-- Сохранение/загрузка конфига через executor API
-- ============================================================

local HttpService = game:GetService("HttpService")

local Config = {}
Config.folder = "Resonance"
Config.file = "config.json"

local function getPath()
    if writefile and isfolder then
        if not isfolder(Config.folder) then makefolder(Config.folder) end
        return Config.folder .. "/" .. Config.file
    end
    return nil
end

local function sanitize(tbl)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        local tv = type(v)
        if tv ~= "function" and tv ~= "userdata" and tv ~= "thread" then
            out[k] = (tv == "table") and sanitize(v) or v
        end
    end
    return out
end

function Config.save(Settings)
    local path = getPath()
    if not path then return false, "executor без файловой системы" end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(sanitize(Settings))
    end)
    if not ok then return false, "ошибка сериализации" end
    local ok2, err = pcall(function() writefile(path, encoded) end)
    return ok2, err
end

function Config.load(Settings)
    local path = getPath()
    if not path then return false, "executor без файловой системы" end
    if not (isfile and isfile(path)) then return false, "конфиг не найден" end
    local ok, data = pcall(function() return readfile(path) end)
    if not ok then return false, "ошибка чтения" end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    if not ok2 then return false, "битый JSON" end
    for k, v in pairs(decoded) do Settings[k] = v end
    return true
end

function Config.delete()
    local path = getPath()
    if path and delfile and isfile and isfile(path) then
        delfile(path)
        return true
    end
    return false
end

function Config.exists()
    local path = getPath()
    return path and isfile and isfile(path) or false
end

return Config