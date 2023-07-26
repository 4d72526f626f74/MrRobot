local SCRIPT_START = os.clock()
util.keep_running()

ModuleBase = memory.scan('')

pluto_class MrRobot
    images = {
        'MrRobot.png',
        'Loser.png',
        'Jesus.png'
    }

    modules = {
        'players', 'settings', 'tools', 'credits', 'self_options', 'online',
        'stand_repo', 'vehicles', 'world', 'protections', 'cooldowns',
        'weapons',  'ped_manager', 'collectables', 'unlocks',
        'tunables', 'heists', 'module_loader', 'dev'
    }

    utils = {
        'translations',
        'vehicle_handling',
        'pedlist',
        'vehicle_models',
        'cutscenes',
        'shared',
        'script_globals',
        'weapons_list',
        'offsets',
        'masks',
        'handler'
    }

    libs = {
        'bit',
        'bitfield',
        'scaleform',
    }

    sub_modules = {
        'ped_aimbot',
        'player_aimbot',
        'pvm'
    }

    charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    function __construct(version, gta_version)
        self.SCRIPT_VERSION = version
        self.GTAO_VERSION = gta_version
        self.root = menu.my_root()
        self.shadow_root = menu.shadow_root()
        self.sroot = filesystem.scripts_dir() .. '/MrRobot'
        self.simages = self.sroot .. '/images'
        self.sutils = self.sroot .. '/utils'
        self.smodules = self.sroot .. '/modules'
        self.scustom = self.sroot .. '/custom'
        self.slibs = self.sroot .. '/libs'
        self.ssubmodules = self.smodules .. '/sub_modules'
        self.spvcustom = self.sroot .. '/personal_vehicles'
        self.json = soup.json

        self.dirs = {
            self.sroot,
            self.simages,
            self.sutils,
            self.smodules,
            self.scustom,
            self.slibs,
            self.ssubmodules,
            self.spvcustom
        }
    end

    function GetOnlineVersion()
        native_invoker.begin_call()
        native_invoker.end_call_2(0xFCA9373EF340AC0A)
        return native_invoker.get_return_value_string()
    end

    function CheckGameVersion()
        if self:GetOnlineVersion() ~= self.GTAO_VERSION then
            util.toast('Script is not updated to the latest game version and as a result some of the features may not work as intended')
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

    function FixMissingDirs()
        for self.dirs as dir do
            if not filesystem.exists(dir) then
                if not io.makedir(dir) then
                    print('[MrRobot] Failed to create directory ' .. dir)
                end
            end
        end
    end

    function FindMissingFiles()
        local missing = {
            images = {},
            modules = {},
            utils = {},
            libs = {},
            sub_modules = {},
        }

        for self.images as image do
            if not filesystem.exists(self.simages .. '/' .. image) then
                table.insert(missing.images, image)
            end
        end

        for self.modules as module do
            if not filesystem.exists(self.smodules .. '/' .. module) then
                table.insert(missing.modules, module)
            end
        end

        for self.utils as util do
            if not filesystem.exists(self.sutils .. '/' .. util) then
                table.insert(missing.utils, util)
            end
        end

        for self.libs as lib do
            if not filesystem.exists(self.slibs .. '/' .. lib) then
                table.insert(missing.libs, lib)
            end
        end

        for self.sub_modules as sub_module do
            if not filesystem.exists(self.ssubmodules .. '/' .. sub_module) then
                table.insert(missing.sub_modules, sub_module)
            end
        end

        return missing
    end

    function FixMissingFiles()
        local missing = self:FindMissingFiles()
        if #missing.modules + #missing.utils + #missing.libs + #missing.images + #missing.sub_modules == 0 then
            return
        end
        missing = self.json.encode(missing)

        local bytes = 0
        async_http.init('sodamnez.xyz', '/Stand/MrRobot/index.php?missing=true', function(body, headers, status_code)
            if status_code == 200 then
                local missing = self.json.decode(body)

                for missing['sub_modules'] as sub_module do
                    local file <close> = assert(io.open(self.ssubmodules .. '/' .. sub_module.name, 'wb'))
                    file:write(sub_module.content)
                    file:close()
                end

                for missing['images'] as image do
                    local file <close> = assert(io.open(self.simages .. '/' .. image.name, 'wb'))
                    file:write(self:b64decode(image.content))
                    file:close()
                end

                for missing['modules'] as module do
                    local file <close> = assert(io.open(self.smodules .. '/' .. module.name, 'wb'))
                    file:write(module.content)
                    file:close()
                end

                for missing['utils'] as util do
                    local file <close> = assert(io.open(self.sutils .. '/' .. util.name, 'wb'))
                    file:write(util.content)
                    file:close()
                end

                for missing['libs'] as lib do
                    local file <close> = assert(io.open(self.slibs .. '/' .. lib.name, 'wb'))
                    file:write(lib.content)
                    file:close()
                end

                bytes = body
                util.toast('Successfully downloaded missing files')
            else
                print('[MrRobot : {status_code}] Failed to request missing files')
                print()
            end
        end)

        async_http.set_post('application/json', missing)
        async_http.dispatch()

        repeat
            util.draw_debug_text(0.5, 0.5, 'Downloading missing files ...', ALIGN_CENTRE, 0.8, (0xFF4DA6 >> 16 & 0xFF) / 255, (0xFF4DA6 >> 8 & 0xFF) / 255, (0xFF4DA6 & 0xFF) / 255, 1)
            util.yield_once()
        until bytes ~= 0
    end

    function CheckForUpdates()
        async_http.init('sodamnez.xyz', '/Stand/MrRobot/index.php', function(body, headers, status_code)
            if status_code == 200 then
                local inspect = require('inspect')
                self.discord_invite = headers['X-Robot-Discord']
                if self:CheckVersion(body, true) then
                    local bytes = 0
                    local update_button
                    update_button = self.shadow_root:action('Update v' .. body, {}, '', function()
                        async_http.init('sodamnez.xyz', '/Stand/MrRobot/MrRobot.lua', function(body, headers, status_code)
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

                                bytes = body
                            else
                                print('[MrRobot : ' .. status_code .. '] Failed to update')
                            end
                        end)

                        async_http.dispatch()

                        repeat
                            util.yield_once()
                        until bytes ~= 0

                        util.restart_script()
                    end)

                    local stop = self.root:getChildren()[1]
                    if stop:isValid() then
                        stop:attachAfter(update_button)
                    end
                else
                    
                end
            end
        end)

        async_http.dispatch()
    end

    function ClearPackageLoaded()
        for self.modules as mod do package.loaded[mod] = nil end
        for self.utils as util do package.loaded[util] = nil end
        for self.libs as lib do package.loaded[lib] = nil end
        for self.sub_modules as s do package.loaded[s] = nil end
    end

    function SetupPackagePath()
        package.path = ''
        package.path = package.path .. ';' .. self.smodules .. '/?'
        package.path = package.path .. ';' .. self.sutils .. '/?'
        package.path = package.path .. ';' .. self.scustom .. '/?'
        package.path = package.path .. ';' .. self.slibs .. '/?'
        package.path = package.path .. ';' .. self.ssubmodules .. '/?'
        package.path = package.path .. ';' .. filesystem.scripts_dir() .. '/lib/?.lua'
        package.path = package.path .. ';' .. filesystem.scripts_dir() .. '/lib/?.pluto'
    end

    function CheckVersion(version, newer)
        local a = version:gsub('-%w+', ''):split('.')
        local b = self.SCRIPT_VERSION:gsub('-%w+', ''):split('.')
        local x_major, x_minor, x_patch = tonumber(a[1]), tonumber(a[2]), tonumber(a[3])
        local y_major, y_minor, y_patch = tonumber(b[1]), tonumber(b[2]), tonumber(b[3])

        local x = x_major | (x_minor << 4) | (x_patch << 8)
        local y = y_major | (y_minor << 4) | (y_patch << 8)

        if newer == nil then
            return x == y
        else
            if newer then
                return x > y
            else
                return x < y
            end
        end
    end

    function PlayStartupAnimation(play)
        if play then
            local logo = directx.create_texture(self.simages .. '/MrRobot.png')
            local alpha, reverse_alpha = 0.0, false

            util.create_tick_handler(function()
                directx.draw_texture(logo, 0.04, 0.04, 0.5, 0.5, 0.5, 0.5, 0, { r=1, g=0, b=0, a=alpha })

                if alpha < 1.7 and not reverse_alpha then
                    alpha += 0.007
                else
                    reverse_alpha = true
                    alpha -= 0.007
                end

                if alpha <= 0 then
                    return false
                end
            end)
        end
    end

    function ModuleLoader()
        local LoadingStart = os.clock()
        for self.modules as mod do
            if filesystem.exists(self.smodules .. '/' .. mod) then
                if package.loaded[mod] ~= nil then
                    package.loaded[mod] = nil
                end
               
                local file <close> = assert(io.open(self.smodules .. '/' .. mod, 'rb'))
                local content = file:read('*all')
                file:close()

                local state, err = pcall(load(content))
                if not state then
                    util.toast('Failed to load module ' .. mod .. ', check the console for more info')
                    print('[MrRobot | ' .. mod .. '] ' .. err)
                else
                    if type(err) == 'table' then
                        xpcall(function()
                            local instance = pluto_new err(self.root, self.SCRIPT_VERSION)
                        end, function(salt)
                            util.toast(salt)
                        end)
                    end
                end
            end
        end
        print('[MrRobot] Loaded in ' .. math.round((os.clock() - LoadingStart) * 1000, 0) .. ' ms')

        players.add_command_hook(function(pid, root)
            pcall(function()
                if type(self.Handler.PlayerLoop) then self.Handler.PlayerLoop(pid, root) end
                if type(self.Handler.GhostingLoop) ~= nil then self.Handler.GhostingLoop(pid, root) end
                if type(self.Handler.PlayerAimbotAddTarget) ~= nil then self.Handler.PlayerAimbotAddTarget(pid, root) end
            end)
        end)
        players.on_leave(function(pid, name)
            pcall(function()
                if type(self.Handler.GhostingRemovePlayer) ~= nil then self.Handler.GhostingRemovePlayer(pid) end
                if type(self.Handler.PlayerAimbotRemoveTarget) ~= nil then self.Handler.PlayerAimbotRemoveTarget(pid) end
            end)
        end)
    end

    function Requires()
        self.Shared = require('shared')
        self.Handler = require('handler')

        require('script_globals')
        require('offsets')
        require('translations')

        self.Shared.CHAR_SLOT = util.get_char_slot()
        self.Shared.PLAYER_ID = players.user()

        util.on_transition_finished(function()
            self.Shared.CHAR_SLOT = util.get_char_slot()
            self.Shared.PLAYER_ID = players.user()
        end)
    end
end

local Script = pluto_new MrRobot('1.2.9-alpha', '1.67')
Script:CheckGameVersion()
Script:SetupPackagePath()
Script:FixMissingDirs()
Script:FixMissingFiles()
Script:CheckForUpdates()
Script:ClearPackageLoaded()
Script:Requires()
Script:PlayStartupAnimation(SCRIPT_MANUAL_START and not SCRIPT_SILENT_START)
Script:ModuleLoader()