local Booty = BootyLib

Booty.Core = Booty.Core or {}
Booty.Core.Compatibility = Booty.Core.Compatibility or {}
local Compatibility = Booty.Core.Compatibility

-- Keep the client implementation when an extension provides it. Never install a
-- global shim: other addons retain their own standard-library contract.
if type(string.match) == "function" then
    Compatibility.Match = string.match
    Compatibility.matchBackend = "native"
else
    local Find = string.find
    local Sub = string.sub

    -- Lua 5.0 returns non-nil strings or positions for every completed capture.
    -- Its pattern engine permits at most 32 captures. The rare large-capture
    -- path avoids a temporary result table and preserves the exact return count.
    local function MatchMany(subject, pattern, init)
        local first, last, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31, c32 = Find(subject, pattern, init)
        if not first then return nil end
        if c32 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31, c32
        elseif c31 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31
        elseif c30 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30
        elseif c29 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29
        elseif c28 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28
        elseif c27 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27
        elseif c26 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26
        elseif c25 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25
        elseif c24 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24
        elseif c23 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23
        elseif c22 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22
        elseif c21 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21
        elseif c20 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20
        elseif c19 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19
        elseif c18 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18
        elseif c17 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17
        elseif c16 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16
        elseif c15 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15
        elseif c14 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14
        elseif c13 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13
        elseif c12 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12
        elseif c11 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11
        elseif c10 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9, c10
        elseif c9 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9
        elseif c8 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8
        elseif c7 ~= nil then return c1, c2, c3, c4, c5, c6, c7
        elseif c6 ~= nil then return c1, c2, c3, c4, c5, c6
        elseif c5 ~= nil then return c1, c2, c3, c4, c5
        elseif c4 ~= nil then return c1, c2, c3, c4
        elseif c3 ~= nil then return c1, c2, c3
        elseif c2 ~= nil then return c1, c2
        elseif c1 ~= nil then return c1
        end
        return Sub(subject, first, last)
    end

    local function Match(subject, pattern, init)
        local first, last, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10 = Find(subject, pattern, init)
        if not first then return nil end
        if c10 ~= nil then return MatchMany(subject, pattern, init)
        elseif c9 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8, c9
        elseif c8 ~= nil then return c1, c2, c3, c4, c5, c6, c7, c8
        elseif c7 ~= nil then return c1, c2, c3, c4, c5, c6, c7
        elseif c6 ~= nil then return c1, c2, c3, c4, c5, c6
        elseif c5 ~= nil then return c1, c2, c3, c4, c5
        elseif c4 ~= nil then return c1, c2, c3, c4
        elseif c3 ~= nil then return c1, c2, c3
        elseif c2 ~= nil then return c1, c2
        elseif c1 ~= nil then return c1
        end
        return Sub(subject, first, last)
    end

    Compatibility.Match = Match
    Compatibility.matchBackend = "string.find"
end
