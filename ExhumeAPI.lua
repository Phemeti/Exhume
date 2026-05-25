local Module = {}

local function ExhumeDissector(script)
    local cloneref = cloneref or function(...) return ... end
    local players = cloneref(game:GetService('Players'))
    local lplr = players.LocalPlayer

    local ismodule = script:IsA('ModuleScript')
    local output = {}

    if ismodule then
        output[1] = 'local module = {}\n'
    else
        output[1] = '-- Exhume: '..script.ClassName..' (game.'..script:GetFullName()..')\n'
    end

    local scriptenv = getsenv(script)
    local moduleresult = nil

    if ismodule then
        pcall(function()
            moduleresult = require(script)
        end)
    end

    local gcclosures = {}
    pcall(function()
        for _, v in getgc(true) do
            if type(v) == 'function' and islclosure(v) then
                local info = debug.getinfo(v, 'flnSu')
                if info and info.source and info.source:find(script.Name, 1, true) then
                    local key = (info.name or '?')..'_'..tostring(info.linedefined or 0)
                    if not gcclosures[key] then
                        gcclosures[key] = v
                    end
                end
            end
        end
    end)

    local connectionFunctions = {}
    pcall(function()
        local char = lplr.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass('Humanoid')
        if not humanoid then return end
        local signals = {
            humanoid.Running, humanoid.Jumping, humanoid.Climbing,
            humanoid.GettingUp, humanoid.FreeFalling, humanoid.FallingDown,
            humanoid.StateChanged, humanoid.Died, humanoid.Seated,
            humanoid.PlatformStanding, humanoid.Swimming,
        }
        for _, sig in signals do
            pcall(function()
                for _, conn in getconnections(sig) do
                    local fn = conn.Function
                    if fn and islclosure(fn) then
                        local info = debug.getinfo(fn, 'flnSu')
                        if info and info.source and info.source:find(script.Name, 1, true) then
                            connectionFunctions[(info.name or '?')..'_'..tostring(info.linedefined or 0)] = fn
                        end
                    end
                end
            end)
        end
    end)

    local function serialize(v)
        local t = typeof(v)
        if t == 'string' then
            return "'"..v:gsub("'", "\\'").."'"
        elseif t == 'Instance' then
            return 'Instance.new(\''..v.ClassName..'\')'
        elseif t == 'Vector3' then
            return ('Vector3.new(%s, %s, %s)'):format(v.X, v.Y, v.Z)
        elseif t == 'CFrame' then
            return 'CFrame.new('..tostring(v)..')'
        elseif t == 'EnumItem' then
            return tostring(v)
        elseif t == 'boolean' or t == 'number' then
            return tostring(v)
        elseif t == 'nil' then
            return 'nil'
        end
        return '\''..tostring(v)..'\''
    end

    local function topath(path)
        local result = ''
        for part in path:gmatch('[^.]+') do
            if part:find(' ') then
                result ..= '[\''..part..'\']'
            else
                result = result == '' and part or result..'.'..part
            end
        end
        return result
    end

    local function sanitizename(name)
        return name:gsub('[^%w_]', '_')
    end

    local blacklistedProperties = {}
    for _, p in {
        'className', 'archivable', 'maxHealth', 'InternalDisplayName',
        'WalkToPoint', 'SourceAssetId', 'Capabilities', 'RobloxLocked',
        'Sandboxed', 'EvaluateStateMachine',
    } do
        blacklistedProperties[p] = true
    end

    local function serializetable(tbl, varname, pad, seen, depth)
        seen = seen or {}
        depth = depth or 0
        if seen[tbl] then
            return pad..'-- '..varname..' is a circular table reference\n'
        end
        seen[tbl] = true

        local function tabletostring(t, innerpad, s)
            local result = '{\n'
            for k, v in t do
                local keystr = type(k) == 'string' and '[\''..k..'\'] = ' or ''
                if type(v) == 'table' then
                    result ..= innerpad..'\t'..keystr..tabletostring(v, innerpad..'\t', s)..',\n'
                elseif type(v) == 'function' then
                    result ..= innerpad..'\t'..keystr..'function(...) end,\n'
                elseif typeof(v) == 'Instance' then
                    result ..= innerpad..'\t'..keystr..'Instance.new(\''..v.ClassName..'\'),\n'
                else
                    result ..= innerpad..'\t'..keystr..serialize(v)..',\n'
                end
            end
            return result..innerpad..'}'
        end

        local result = pad..'local '..varname..' = '..tabletostring(tbl, pad, seen)..'\n'
        seen[tbl] = nil
        return result
    end

    local function serializemodulevalue(v, pad, seen, depth)
        seen = seen or {}
        depth = depth or 0
        local t = type(v)
        if t == 'table' then
            if seen[v] then return '{}' end
            seen[v] = true
            local result = '{\n'
            for k, val in v do
                local keystr = type(k) == 'string' and '[\''..k..'\'] = ' or ''
                result ..= pad..'\t'..keystr..serializemodulevalue(val, pad..'\t', seen, depth + 1)..',\n'
            end
            seen[v] = nil
            return result..pad..'}'
        elseif t == 'function' then
            if islclosure(v) then
                local info = debug.getinfo(v, 'flnSu')
                local args = {}
                if info and info.nparams then
                    for i = 1, info.nparams do
                        args[i] = 'arg'..i
                    end
                end
                if info and info.is_vararg and info.is_vararg ~= 0 then
                    args[#args+1] = '...'
                end
                return 'function('..table.concat(args, ', ')..')\n'..pad..'end'
            else
                return 'function(...) end'
            end
        else
            return serialize(v)
        end
    end

    local function getupvals(fn, fnName, seen, depth)
        seen = seen or {}
        depth = depth or 1

        if seen[fn] then return '' end
        if type(fn) ~= 'function' then return '' end
        if not islclosure(fn) then return '' end
        seen[fn] = true

        local upvals = ''
        local nested = ''
        local pad = string.rep('\t', depth)

        local info = debug.getinfo(fn, 'flnSu')
        if info then
            local parts = {}
            if info.name and info.name ~= '' then parts[#parts+1] = 'name: '..info.name end
            if info.linedefined and info.linedefined > 0 then parts[#parts+1] = 'line: '..info.linedefined end
            if info.nups then parts[#parts+1] = 'upvalues: '..info.nups end
            if info.nparams then parts[#parts+1] = 'params: '..info.nparams end
            if info.is_vararg ~= nil then parts[#parts+1] = 'vararg: '..tostring(info.is_vararg) end
            if #parts > 0 then
                upvals ..= pad..'--[[ '..table.concat(parts, ' | ')..' ]]\n'
            end
        end

        local suc0, consts = pcall(debug.getconstants, fn)
        if suc0 and consts then
            local constlines = {}
            for i, v in consts do
                if type(v) == 'string' or type(v) == 'number' or type(v) == 'boolean' then
                    constlines[#constlines+1] = '['..i..']: '..serialize(v)
                end
            end
            if #constlines > 0 then
                upvals ..= pad..'--[[ constants: '..table.concat(constlines, ', ')..' ]]\n'
            end
        end

        if info and info.name then
            local gckey = info.name..'_'..tostring(info.linedefined or 0)
            local livefn = connectionFunctions[gckey] or gcclosures[gckey]
            if livefn and livefn ~= fn then
                local suc3, stack = pcall(debug.getstack, livefn)
                if suc3 and stack and #stack > 0 then
                    local stackparts = {}
                    for i, v in stack do
                        stackparts[#stackparts+1] = '['..i..']: '..serialize(v)
                    end
                    upvals ..= pad..'--[[ live stack: '..table.concat(stackparts, ', ')..' ]]\n'
                end
            end
        end

        pcall(function()
            local decomp = decompile(fn)
            if decomp and decomp ~= '' and not decomp:find('Failed') and not decomp:find('failed') then
                upvals ..= pad..'--[[ decompile output:\n'
                for line in decomp:gmatch('[^\n]+') do
                    upvals ..= pad..'\t'..line..'\n'
                end
                upvals ..= pad..']]\n'
            end
        end)
        local suc1, upvalues = pcall(debug.getupvalues, fn)
        if suc1 and upvalues then
            for upname, upval in upvalues do
                local val = upval
                local newname = fnName..'_upvalue_v'..upname
                pcall(function()
                    if upval.DisplayName == lplr.DisplayName then
                        newname = 'LocalPlayer_'..(upval.ClassName or '')..'_'..sanitizename(upval.Name)..'_upvalue_v'..upname
                    end
                end)
                if type(val) == 'function' then
                    if islclosure(val) then
                        nested ..= '\n'..pad..'local function '..newname..'(...)\n'..getupvals(val, newname, seen, depth + 1)..pad..'end\n'
                    else
                        nested ..= '\n'..pad..'-- '..newname..' is a C closure\n'
                    end
                    upvals ..= pad..'-- '..newname..' is a function, see below\n'
                elseif type(val) == 'table' then
                    upvals ..= '\n'..serializetable(val, newname, pad, {}, depth)
                elseif typeof(val) == 'Instance' then
                    local instname = sanitizename(upval.Name)
                    pcall(function()
                        if upval.DisplayName == lplr.DisplayName then
                            newname = 'LocalPlayer_'..upval.ClassName..'_'..instname..'_upvalue_v'..upname
                        else
                            newname = fnName..'_'..instname..'_upvalue_v'..upname
                        end
                    end)
                    if not newname:find('LocalPlayer') then
                        newname = fnName..'_'..instname..'_upvalue_v'..upname
                    end
                    local parentcomment = pad..'-- Parent: '..tostring(upval.Parent)..' (game.'..topath(upval:GetFullName())..')\n'
                    val = 'Instance.new(\''..upval.ClassName..'\')'
                    for _, prop in getproperties(upval) do
                        pcall(function()
                            local propval = upval[prop]
                            if propval ~= nil and not blacklistedProperties[prop] then
                                if typeof(propval) ~= 'Instance' then
                                    local oldpropval = propval
                                    local testinst = Instance.new(upval.ClassName)
                                    local suc = pcall(function()
                                        testinst[prop] = typeof(propval) == 'string' and 'test' or typeof(propval) == 'number' and 50 or typeof(propval) == 'boolean' and false
                                    end)
                                    if suc and not gethiddenproperties(upval)[prop] then
                                        upval[prop] = oldpropval
                                        val ..= '\n'..pad..newname..'[\''..prop..'\'] = '..serialize(propval)
                                        val = val:gsub('\''..lplr.DisplayName..'\'', 'game.Players.LocalPlayer.DisplayName')
                                        val = val:gsub('\''..lplr.Name..'\'', 'game.Players.LocalPlayer.Name')
                                    end
                                end
                            end
                        end)
                    end
                    upvals ..= '\n'..parentcomment..pad..'local '..newname..' = '..val..'\n'
                else
                    upvals ..= pad..'local '..newname..' = '..serialize(val)..'\n'
                end
            end
        end
        local suc2, protos = pcall(debug.getprotos, fn)
        if suc2 and protos then
            for i, proto in protos do
                if type(proto) == 'function' and islclosure(proto) and not seen[proto] then
                    local protoname = fnName..'_proto_'..i
                    nested ..= '\n'..pad..'local function '..protoname..'(...)\n'..getupvals(proto, protoname, seen, depth + 1)..pad..'end\n'
                end
            end
        end
        return upvals..nested
    end
    if ismodule and moduleresult ~= nil then
        local t = type(moduleresult)
        if t == 'table' then
            for k, v in moduleresult do
                local keystr = type(k) == 'string' and k or '['..tostring(k)..']'
                if type(v) == 'function' then
                    if islclosure(v) then
                        local info = debug.getinfo(v, 'flnSu')
                        local args = {}
                        if info and info.nparams then
                            for i = 1, info.nparams do
                                args[i] = 'arg'..i
                            end
                        end
                        if info and info.is_vararg and info.is_vararg ~= 0 then
                            args[#args+1] = '...'
                        end
                        output[#output+1] = 'function module.'..keystr..'('..table.concat(args, ', ')..')\n'..getupvals(v, keystr, {}, 1)..'end\n'
                    else
                        output[#output+1] = 'module.'..keystr..' = function(...) end\n'
                    end
                elseif type(v) == 'table' then
                    output[#output+1] = 'module.'..keystr..' = '..serializemodulevalue(v, '', {}, 0)..'\n'
                else
                    output[#output+1] = 'module.'..keystr..' = '..serialize(v)..'\n'
                end
            end
            if type(moduleresult) == 'table' then
                for k, v in scriptenv do
                    if k ~= 'shared' and k ~= '_G' and moduleresult[k] == nil then
                        if type(v) == 'function' and islclosure(v) then
                            output[#output+1] = 'local function '..k..'(...)\n'..getupvals(v, k, {}, 1)..'end\n'
                        elseif type(v) == 'table' then
                            output[#output+1] = serializetable(v, k, '', {}, 0)
                        end
                    end
                end
            end
        elseif t == 'function' then
            if islclosure(moduleresult) then
                output[#output+1] = 'local module = function(...)\n'..getupvals(moduleresult, 'module', {}, 1)..'end\n'
            else
                output[#output+1] = 'local module = function(...) end\n'
            end
        else
            output[#output+1] = 'local module = '..serialize(moduleresult)..'\n'
        end
        output[#output+1] = '\nreturn module\n'
    else
        for i, v in scriptenv do
            if i ~= 'shared' and i ~= '_G' then
                if type(v) == 'function' and islclosure(v) then
                    output[#output+1] = 'local function '..i..'(...)\n'..getupvals(v, i, {}, 1)..'end\n'
                elseif type(v) == 'table' then
                    output[#output+1] = serializetable(v, i, '', {}, 0)
                end
            end
        end
    end
    local result = ''
    for _, v in output do
        result ..= v..'\n'
    end
    return result
end

Module.RunDissector = function(self, script)
    local lastTime = tick()

    local suc, contents = pcall(function()
        return ExhumeDissector(script)
    end)
    if not suc then
        contents = '-- failed to dissect: '..contents
    else
        contents = '-- Dissected in '..math.abs(lastTime - tick())..' seconds.\n'..contents
    end

    local Module = {}
    
    Module.GetContents = function(self)
        return contents
    end

    return Module
end

return Module
