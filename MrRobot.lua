GTA_BASE = memory.scan('')
SCRIPT_LANGUAGE = 'English'
VERSION_MISMATCH = false

pluto_class MrRobot
    images = {
        'MrRobot.png', 'Loser.png', 'Jesus.png'
    }
    modules = {
        'players', 'credits', 'settings', 'self', 'online', 'vehicles', 'weapons', 'world',
        'entities', 'gunvan', 'protections', 'cooldowns', 'collectables', 'tunables', 'cellphone',
        'moduleloader', 'nightclub', 'arcade', 'agency', 'unlocks', 'heists'
    }
    sub_modules = {
        'pvm', 'ped_aimbot', 'player_aimbot', 'experimental_aimbot'
    }
    utils = {
        'translations', 'handler', 'entity', 'vehicle_handling', 'pedlist',
        'vehicle_models', 'cutscenes', 'weapons_list', 'offsets', 'masks',
        'script_globals', 'shared', 'network', 'vehicle', 'zone_info', 'notifications',
        'door_manager', 'gta_classes', 'labels', 'blacklist', 'timer', 'sound', 'toolkit',
        'hooks', 'german'
    }
    libs = {
        'inspect', 'bitfield', 'bit', 'math'
    }

    charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    function __construct(version, gtao_version)
        self:BaseSetup()

        self.script_version = version
        self.gtao_version = gtao_version
        self.root = menu.my_root()
        self.shadow_root = menu.shadow_root()
        self.sroot = filesystem.script_root()
        self.simages = self.sroot .. '/images'
        self.sutils = self.sroot .. '/utils'
        self.smodules = self.sroot .. '/modules'
        self.scustom = self.sroot .. '/custom'
        self.slibs = self.sroot .. '/libs'
        self.ssubmodules = self.smodules .. '/sub_modules'
        self.spvcustom = self.sroot .. '/personal_vehicles'
        self.sconfigs = self.sroot .. '/config'
        self.slanguages = self.sroot .. '/languages'
        self.module_instances = {}
        self.settings = {
            modules = {},
            loading_order = 1,
        }

        for self.modules as mod do
            if mod == 'settings' or mod == 'credits' then
                continue
            end

            self.settings.modules[mod] = true
        end

        self.dirs = {
            self.sroot, self.simages, self.sutils,
            self.smodules, self.scustom, self.slibs,
            self.ssubmodules, self.spvcustom, self.sconfigs,
        }

        for self.dirs as dir do
            if not filesystem.exists(dir) then
                io.makedir(dir)
            end
        end

        if not filesystem.exists(self.sconfigs .. '/settings.json') then
            local file <close> = assert(io.open(self.sconfigs .. '/settings.json', 'w'))
            file:write(soup.json.encode(self.settings, true))
            file:close()
        else
            local file <close> = assert(io.open(self.sconfigs .. '/settings.json', 'r'))
            self.settings = soup.json.decode(file:read('*a'))
            file:close()
        end

        if filesystem.exists(filesystem.script_root() .. '/config/language.txt') then
            local file <close> = assert(io.open(filesystem.script_root() .. '/config/language.txt', 'r'))
            SCRIPT_LANGUAGE = file:read('*a')
            file:close()
        else
            local file <close> = assert(io.open(filesystem.script_root() .. '/config/language.txt', 'w'))
            file:write(SCRIPT_LANGUAGE)
            file:close()
        end
    end

    function BaseSetup()
        util.require_natives('natives-2944a')

        _G.string.sha256 = function(data) return (require('crypto').sha256)(data) end
        _G.filesystem.script_root = function() return filesystem.scripts_dir() .. '/MrRobot' end
        _G.async_http.host = 'stand.sodamnez.xyz'
        _G.async_http.update_path = '/MrRobot'

        function _G.async_http.get(url, path, callback)
            url = url or async_http.host
            async_http.init(url, path, callback)
            async_http.dispatch()
        end

        function _G.async_http.post(url, path, data, content_type, callback)
            url = url or async_http.host
            async_http.init(url, path, callback)
            async_http.set_post(content_type, data)
            async_http.dispatch()
        end
    end

    function b64encode(data)
        return ((data:gsub('.', function(x)
            local r, f = '', x:byte()
            for i = 8, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 ? '1' : '0') end
            return r
        end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
            if (#x < 6) then return '' end
            local c = 0
            for i = 1, 6 do c = c + (x:sub(i, i) == '1' ? 2 ^ (6 - i) : 0) end
            return self.charset:sub(c + 1, c + 1)
        end) .. ({ '', '==', '=' })[#data % 3 + 1])
    end
    
    function b64decode(data)
        data = string.gsub(data, '[^' .. self.charset .. '=]', '')
        return (data:gsub('.', function(x)
            if (x == '=') then return '' end
            local r, f = '', (self.charset:find(x) - 1)
            for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
            return r
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
            if (#x ~= 8) then return '' end
            local c = 0
            for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
            return string.char(c)
        end))
    end

    function GetOnlineVersion()
        local addr = memory.scan('4C 8D 05 ? ? ? ? 48 8D 15 ? ? ? ? 48 8B C8 E8 ? ? ? ? 48 8D 15 ? ? ? ? 48 8D 4C 24 20 E8')
        if addr ~= 0 then
            return memory.read_string(memory.rip(addr + 3))
        else
            return self.gtao_version
        end
    end

    function CheckGameVersion()
        return self.gtao_version == menu.get_version().game:sub(1, 4)
    end

    function FindMissingFiles()
        local missing = {
            images = {},
            modules = {},
            sub_modules = {},
            utils = {},
            libs = {}
        }

        for k, _ in pairs(missing) do
            for (self[k]) as item do
                local dir =  self['s' .. k:gsub('_', '')]
                if not filesystem.exists($'{dir}/{item}') then
                    table.insert(missing[k], item)
                end
            end
        end

        return soup.json.encode(missing), #missing.images + #missing.modules + #missing.sub_modules + #missing.utils + #missing.libs > 0, 0
    end

    function FixMissingFiles()
        local missing, is_missing, bytes = self:FindMissingFiles()
        if not is_missing then return end

        async_http.post(nil, $'{async_http.update_path}/index.php?missing=true', missing, 'application/json', function(body, headers, status_code)
            if status_code == 200 then
                local hash = headers['X-Robot-Hash']
                if body:sha256() ~= hash then
                    util.yield(2000)
                    util.stop_script()
                end

                local missing = soup.json.decode(body)
                for k, v in pairs(missing) do
                    for (self[k]) as item do
                        local path = self['s' .. k:gsub('_', '')] .. '/' .. item
                        local data = v[item]
                        if data then
                            local file <close> = assert(io.open(path, 'wb'))
                            if not 'images' in path then
                                file:write(data.content)
                                file:close()
                            else
                                file:write(self:b64decode(data.content))
                                file:close()
                            end
                        end
                    end
                end
                bytes = body
            end
        end)

        repeat
            util.yield_once()
        until bytes ~= 0
    end

    function ClearPackagePath()
        for self.modules as mod do package.loaded[mod] = nil end
        for self.utils as util do package.loaded[util] = nil end
        for self.libs as lib do package.loaded[lib] = nil end
        for self.sub_modules as s do package.loaded[s] = nil end
    end

    function SetupPackagePath()
        package.path = ''
        package.path = package.path .. ';' .. self.smodules .. '/?'
        package.path = package.path .. ';' .. self.ssubmodules .. '/?'
        package.path = package.path .. ';' .. self.sutils .. '/?'
        package.path = package.path .. ';' .. self.slibs .. '/?'
        package.path = package.path .. ';' .. self.scustom .. '/?'
    end

    function CheckForUpdates()
        if self:CheckGameVersion() ~= true then
            local Notifications = require('notifications')
            Notifications.Show($'This script was coded for {self.gtao_version} but your game version is {self:GetOnlineVersion()}, some features may not work as intended', 'Script is outdated', '', Notifications.HUD_COLOUR_REDDARK)
            VERSION_MISMATCH = true
        end

        if async_http.have_access() then
            local T = self.T
            async_http.get(nil, $'{async_http.update_path}/index.php', function(body, headers, status_code)
                if status_code == 200 then
                    self.discord_invite = headers['X-Robot-Discord']
                    local version_compare = soup.version_compare(body, self.script_version)
                    if version_compare == 1 then
                        util.toast(T($'v{body} is now available'))
                        self:CreateUpdateButton($'v{body}')
                    elseif version_compare == -1 then
                        util.toast(T($'You are using v{self.script_version}-dev which is newer than v{body}'))
                    end
                end
            end)
        else
            util.toast($'Goto Stand > Lua Scripts > MrRobot > Disable Internet Access and uncheck it to check for updates')
        end
    end

    function CreateUpdateButton(text)
        local bytes = 0
        local update_button = self.shadow_root:action(text, {}, '', function()
            async_http.get(nil, $'{async_http.update_path}/MrRobot.lua', function(body, headers, status_code)
                if status_code == 200 then
                    local file <close> = assert(io.open(filesystem.scripts_dir() .. SCRIPT_RELPATH, 'wb'))
                    file:write(body)
                    file:close()

                    for self.modules as mod do
                        io.remove(self.smodules .. '/' .. mod)
                    end

                    for self.utils as util do
                        io.remove(self.sutils .. '/' .. util)
                    end

                    for self.libs as lib do
                        io.remove(self.slibs .. '/' .. lib)
                    end

                    for self.sub_modules as s do
                        io.remove(self.ssubmodules .. '/' .. s)
                    end
                end

                bytes = body
            end)

            repeat
                util.yield_once()
            until bytes ~= 0 
            util.restart_script()
        end)

        local stop = self.root:getChildren()[1]
        if stop:isValid() then stop:attachAfter(update_button) end
    end

    function Requires()
        self:ClearPackagePath()
        self:SetupPackagePath()

        self.T = require('translations')
        self.S = require('shared')
        self.N = require('notifications')
        
        _G.table.inspect = require('inspect')
        require('toolkit')
    end

    function PlayStartupAnimation(play)
        if play and self.S ~= nil then
            self.S:PlayAnimation(self.simages .. '/MrRobot.png')
        end
    end

    function ModifyNatives()
        local meta = {
            __index = function(self, key)
                if not key:match('^[A-Z_]+_[A-Z_]+_[A-Z_]+$') then
                    if not key:match('^[A-Z_]+_[A-Z_]+_[A-Z_]+$') then
                        local snake_case_pattern = '^[a-z_]+'
        
                        if key:match(snake_case_pattern) then
                            key = key:upper()
                        end
                    end
                end
        
                return rawget(self, key)
            end
        }

        local ns <const> = {
            'CUTSCENE', 'DECORATOR', 'ENTITY', 'FIRE', 'GRAPHICS', 'HUD', 'INTERIOR', 'NETSHOPPING', 
            'NETWORK', 'OBJECT', 'PAD', 'PED', 'PLAYER', 'STATS', 'VEHICLE', 'WEAPON','CAM', 'TASK',
            'AUDIO', 'MISC', 'STREAMING', 'CUTSCENE', 'SCRIPT', 'ZONE', 'SHAPETEST', 'SYSTEM', 'FILES'
        }
        
        for ns as key do
            _G[key:lower()] = setmetatable(_G[key], meta)
        end
    end

    function LoadModule(name)
        if self.settings[name] == false then return end
        if package.loaded[name] then return end
        local state, err = pcall(require, name)
        if not state then
            local line = err:match(':(%d+):')
            self.N.Error($'{name:gsub("^%w", string.upper)}', $'Error is on line {line}', $'Failed to load module {name}, check the console for more info')
            util.log($'Failed to load module {name}: {err}')
        else
            local err_type = type(err)
            if err_type == 'table' then
                table.insert(self.module_instances, pluto_new err(self.root, self.script_version, self.settings))
            elseif err_type == 'function' then
                err()
            end
        end
    end

    function ModuleLoader()
        local Handler = require('handler')

        self:LoadModule('credits')
        self:LoadModule('settings')

        if self.settings.loading_order == 1 then
            -- Default so do nothing
        elseif self.settings.loading_order == 2 then
            table.sort(self.modules, function(a, b) return a < b end)
        elseif self.settings.loading_order == 3 then
            table.sort(self.modules, function(a, b) return a > b end)
        elseif self.settings.loading_order == 4 then
            table.sort(self.modules, function(a, b) return #a < #b end)
        elseif self.settings.loading_order == 5 then
            table.sort(self.modules, function(a, b) return #a > #b end)
        end

        for self.modules as name do self:LoadModule(name) end

        players.add_command_hook(function(pid, root)
            repeat
                util.yield_once()
            until not util.is_session_transition_active() and util.is_session_started()
            
            local status, result = pcall(function()
                Handler.PlayerLoop(pid, root)
                Handler.GhostingLoop(pid, root)
                Handler.PlayerAimbotAdd(pid, root)
                Handler.CheckBlacklist(pid, root)
                Handler.BlameKillAdd(pid, root)
            end)

            if not status then
                util.toast($'Error occured: {result}')
            end
        end)

        players.on_leave(function(pid, name)
            local status, result = pcall(function()
                Handler.GhostingRemovePlayer(pid, name)
                Handler.PlayerAimbotRemove(pid, name)
                Handler.BlameKillRemove(pid, name)
            end)

            if not status then
                util.toast($'Error occured: {result}')
            end
        end)
    end
end

local MrRobot = pluto_new MrRobot('3.6.2', '1.68')

MrRobot:FixMissingFiles()
MrRobot:Requires()
MrRobot:CheckForUpdates()
MrRobot:PlayStartupAnimation(SCRIPT_MANUAL_START and not SCRIPT_SILENT_START)
MrRobot:ModifyNatives()
MrRobot:ModuleLoader()