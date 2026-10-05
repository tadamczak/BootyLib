local MOS = BootyLib
local Search = {}
MOS.Core.SettingsSearch = Search
local noChildren = {}

function Search.Normalize(query)
    return string.lower(string.gsub(string.gsub(tostring(query or ""), "%s+", " "), "^%s*(.-)%s*$", "%1"))
end

local function IndexNode(node, path)
    node.searchPath = path .. " " .. string.lower(node.text or "") .. " " .. string.lower(node.key or "")
    for _, child in ipairs(node.children or noChildren) do IndexNode(child, node.searchPath) end
end

function Search.Index(roots)
    for _, node in ipairs(roots) do IndexNode(node, "") end
end

local function HasPhrase(node, query)
    if string.find(node.searchPath, query, 1, true) then return true end
    for _, child in ipairs(node.children or noChildren) do if HasPhrase(child, query) then return true end end
    return false
end

local function MatchNode(node, tokens, phrase)
    local matches = not phrase or string.find(node.searchPath, phrase, 1, true) ~= nil
    if not phrase then
        for _, token in ipairs(tokens) do
            if not string.find(node.searchPath, token, 1, true) then matches = false; break end
        end
    end
    node.matches = matches
    local visible = matches
    for _, child in ipairs(node.children or noChildren) do
        if MatchNode(child, tokens, phrase) then visible = true end
    end
    node.visible = visible
    return visible
end

-- Captions/keys are indexed once. Typing filters only the existing tree and
-- never reads guild/raid APIs, scans settings values or changes expansion.
function Search.Apply(roots, query)
    local tokens, count, phrase = {}, 0, nil
    query = Search.Normalize(query)
    for token in string.gfind(query, "%S+") do table.insert(tokens, token) end
    -- Prefer the contiguous caption when it exists: "group view" must not
    -- also retain List View merely because it contains a Show group field.
    for _, node in ipairs(roots) do if HasPhrase(node, query) then phrase=query;break end end
    for _, node in ipairs(roots) do if MatchNode(node, tokens, phrase) then count = count + 1 end end
    return count
end
