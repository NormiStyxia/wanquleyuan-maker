local logger = require("shared.utils.logger")

local M = {}

---@param path string
---@param moduleName string
---@return table|nil
function M.read(path, moduleName)
    if not fileSystem:FileExists(path) then
        logger.info(moduleName, "load", "no save file, using defaults")
        return nil
    end

    local file = File(path, FILE_READ)
    if not file:IsOpen() then
        logger.warn(moduleName, "load", "cannot open save file")
        return nil
    end

    local jsonStr = file:ReadString()
    file:Close()
    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or type(data) ~= "table" then
        logger.warn(moduleName, "load", "save file corrupted, using defaults")
        return nil
    end
    return data
end

---@param path string
---@param data table
---@param moduleName string|nil Omit for the silent local cache write.
---@return boolean
function M.write(path, data, moduleName)
    fileSystem:CreateDir("saves")
    local file = File(path, FILE_WRITE)
    if not file:IsOpen() then
        if moduleName then logger.error(moduleName, "save", "cannot write save file") end
        return false
    end

    local ok, jsonStr = pcall(cjson.encode, data)
    if not ok then
        file:Close()
        if moduleName then logger.error(moduleName, "save", "encode failed: " .. tostring(jsonStr)) end
        return false
    end
    file:WriteString(jsonStr)
    file:Close()
    return true
end

return M
