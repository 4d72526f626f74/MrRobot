local SCRIPT_START = os.clock()
local SCRIPT_VERSION <constexpr> = '0.2.2-alpha'
local GTAO_VERSION <const> = '1.67'
local sha256 = require('crypto').sha256
local inspect = require('inspect')

-- implementing natives as local functions instead of requiring natives which is slower, adds more overhead and wastes a lot 
-- of memory for 6400+ functions that you don't even use 10% of
--[[string]] local function GetOnlineVersion()native_invoker.begin_call()native_invoker.end_call_2(0xFCA9373EF340AC0A)return native_invoker.get_return_value_string()end

do
    local GAME_VERSION = GetOnlineVersion()

    if GTAO_VERSION ~= GetOnlineVersion() then
        util.toast($'Version mismatch some features may not work! Script version: {GTAO_VERSION} | GTAO version: {GAME_VERSION}')
    end
end

-- localising these functions makes accessing them 'faster'
-- 'the access to local variables is faster than to global ones' - https://www.lua.org/pil/4.2.html
local create_tick_handler = util.create_tick_handler
local draw_debug_text = util.draw_debug_text
local draw_text = directx.draw_text
local on_transition_finished = util.on_transition_finished
local get_char_slot = util.get_char_slot
local fs = filesystem
local toast = util.toast
local root = menu.my_root()
local shadow_root = menu.shadow_root()
local players_user = players.user
local ref_by_rel_path = menu.ref_by_rel_path
local sroot = fs.scripts_dir() .. '/MrRobot'
local simages = sroot .. '/images'
local sutils = sroot .. '/utils'
local smodules = sroot .. '/modules'
local scustom = sroot .. '/custom'
local slibs = sroot .. '/libs'
local ssubmodules = smodules .. '/sub_modules'

local json = soup.json

local base64 = {}
local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function base64.encode(data)
    return ((data:gsub('.', function(x)
        local r, f = '', x:byte()
        for i = 8, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 ? '1' : '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' ? 2 ^ (6 - i) : 0) end
        return charset:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function base64.decode(data)
    data = string.gsub(data, '[^' .. charset .. '=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (charset:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

-- pluto class for script requirements instead of using a table since it's 10ms faster
pluto_class Requirements
    images = {
        'MrRobot.png',
        'Loser.png',
    },
    modules = {
        'settings', 'tools', 'credits', 'self_options', 'online',
        'stand_repo', 'vehicles', 'world', 'protections', 'cooldowns',
        'weapons',  'ped_manager', 'collectables', 'unlocks',
        'tunables', 'heists', 'module_loader', 'players', 'dev'
    },
    utils = {
        'translations',
        'vehicle_handling',
        'pedlist',
        'vehicle_models',
        'cutscenes',
        'shared',
        'script_globals'
    },
    libs = {
        'bit',
        'bitfield',
        'scaleform',
    },
    sub_modules = {
        'ped_aimbot',
        'player_aimbot'
    },
    dirs = {
        sroot,
        simages,
        sutils,
        smodules,
        scustom,
        slibs,
        ssubmodules
    }

    static function FixMissingDirs()
        for Requirements.dirs as dir do
            if not fs.exists(dir) then
                if not io.makedir(dir) then
                    print($'[MrRobot] Failed to create directory '{dir}'')
                end
            end
        end
    end

    static function FindMissingFiles()
        local missing = {
            images = {},
            modules = {},
            utils = {},
            libs = {},
            sub_modules = {},
        }

        for Requirements.images as image do
            if not fs.exists(simages .. '/' .. image) then
                table.insert(missing.images, image)
            end
        end

        for Requirements.modules as module do
            if not fs.exists(smodules .. '/' .. module) then
                table.insert(missing.modules, module)
            end
        end

        for Requirements.utils as util do
            if not fs.exists(sutils .. '/' .. util) then
                table.insert(missing.utils, util)
            end
        end

        for Requirements.libs as lib do
            if not fs.exists(slibs .. '/' .. lib) then
                table.insert(missing.libs, lib)
            end
        end

        for Requirements.sub_modules as sub_module do
            if not fs.exists(ssubmodules .. '/' .. sub_module) then
                table.insert(missing.sub_modules, sub_module)
            end
        end

        return missing
    end

    static function FixMissingFiles()
        local missing = Requirements.FindMissingFiles()
        if #missing.modules + #missing.utils + #missing.libs + #missing.images + #missing.sub_modules == 0 then
            return
        end
        missing = json.encode(missing)

        local bytes = 0
        async_http.init('sodamnez.xyz', '/Stand/MrRobot/index.php?missing=true', function(body, headers, status_code)
            if status_code == 200 then
                local missing = json.decode(body)

                for missing['sub_modules'] as sub_module do
                    local file <close> = assert(io.open(ssubmodules .. '/' .. sub_module.name, 'wb'))
                    file:write(sub_module.content)
                    file:close()
                end

                for missing['images'] as image do
                    local file <close> = assert(io.open(simages .. '/' .. image.name, 'wb'))
                    file:write(base64.decode(image.content))
                    file:close()
                end

                for missing['modules'] as module do
                    local file <close> = assert(io.open(smodules .. '/' .. module.name, 'wb'))
                    file:write(module.content)
                    file:close()
                end

                for missing['utils'] as util do
                    local file <close> = assert(io.open(sutils .. '/' .. util.name, 'wb'))
                    file:write(util.content)
                    file:close()
                end

                for missing['libs'] as lib do
                    local file <close> = assert(io.open(slibs .. '/' .. lib.name, 'wb'))
                    file:write(lib.content)
                    file:close()
                end

                bytes = body
                toast('Successfully downloaded missing files')
            else
                print($'[MrRobot : {status_code}] Failed to request missing files')
            end
        end)

        async_http.set_post('application/json', missing)
        async_http.dispatch()

        repeat
            draw_text(0.5, 0.5, 'Downloading missing files ...', ALIGN_CENTRE, 0.8, (0xFF4DA6 >> 16 & 0xFF) / 255, (0xFF4DA6 >> 8 & 0xFF) / 255, (0xFF4DA6 & 0xFF) / 255, 1)
            util.yield_once()
        until bytes ~= 0
    end

    static function CheckForUpdates()
        local r = Requirements
        async_http.init('sodamnez.xyz', '/Stand/MrRobot/index.php', function(body, headers, status_code)
            if status_code == 200 then
                if body ~= SCRIPT_VERSION then
                    local requirements = r
                    local bytes = 0
                    local update_button
                    update_button = shadow_root:action($'Update v{body}', {}, '', function()
                        async_http.init('sodamnez.xyz', '/Stand/MrRobot/MrRobot.lua', function(body, headers, status_code)
                            if status_code == 200 then
                                local file <close> = assert(io.open(fs.scripts_dir() .. SCRIPT_RELPATH, 'wb'))
                                file:write(body)
                                file:close()

                                for requirements.modules as mod do
                                    io.remove(smodules .. '/' .. mod)
                                end

                                for requirements.utils as util do
                                    io.remove(sutils .. '/' .. util)
                                end

                                for requirements.libs as lib do
                                    io.remove(slibs .. '/' .. lib)
                                end

                                for requirements.sub_modules as s do
                                    io.remove(ssubmodules .. '/' .. s)
                                end

                                bytes = body
                            else
                                print($'[MrRobot : {status_code}] Failed to update')
                            end
                        end)

                        async_http.dispatch()

                        repeat
                            util.yield_once()
                        until bytes ~= 0

                        util.restart_script()
                    end)

                    local stop = root:getChildren()[1]
                    if stop:isValid() then
                        stop:attachAfter(update_button)
                    end
                end
            end
        end)

        async_http.dispatch()
    end

    static function ClearPackageLoaded()
        for Requirements.modules as mod do package.loaded[mod] = nil end
        for Requirements.utils as util do package.loaded[util] = nil end
        for Requirements.libs as lib do package.loaded[lib] = nil end
        for Requirements.sub_modules as s do package.loaded[s] = nil end
    end
end

Requirements.FixMissingDirs()
Requirements.FixMissingFiles()
Requirements.CheckForUpdates()
Requirements.ClearPackageLoaded()

-- clear the package path and add the script directories to it so that we don't need a relative path for every require
-- and so require function can find the files much faster
package.path = ''
package.path = package.path .. ';' .. smodules .. '/?'
package.path = package.path .. ';' .. sutils .. '/?'
package.path = package.path .. ';' .. scustom .. '/?'
package.path = package.path .. ';' .. slibs .. '/?'
package.path = package.path .. ';' .. ssubmodules .. '/?'
package.path = package.path .. ';' .. fs.scripts_dir() .. '/lib/?.lua'
package.path = package.path .. ';' .. fs.scripts_dir() .. '/lib/?.pluto'

-- module for having shared variables between modules without having to use global variables
local Shared = require('shared')
local T = require('translations')
local ScriptGlobals = require('script_globals')

Shared.Globals = pluto_new ScriptGlobals()

Shared.PLAYER_ID = players_user()
Shared.CHAR_SLOT = get_char_slot()

on_transition_finished(function()
    Shared.PLAYER_ID = players_user()
    Shared.CHAR_SLOT = get_char_slot()
end)

do
    if SCRIPT_MANUAL_START and not SCRIPT_SILENT_START then
        local logo = directx.create_texture(simages .. '/MrRobot.png')
        local alpha, reverse_alpha = 0.0, false

        create_tick_handler(function()
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

pcall(function()
    local players_module = require('players')
    local _ = pluto_new players_module()
end)

util.execute_in_os_thread(function()
    for Requirements.modules as mod do
        package.loaded[mod] = nil
        if mod ~= 'players' then
            -- this allows loading modules whether or not they are a pluto class or not
            local state, err = pcall(require, mod)
            if not state then
                toast($'Failed to load module {mod}, check the console for more info')
                print($'[MrRobot] {err}')
            else
                if type(err) == 'table' then
                    xpcall(function()
                        local instance = pluto_new err()
                        if mod == 'settings' then
                            instance.autoaccept_ref:attachBefore(shadow_root:divider($'v{SCRIPT_VERSION}'))
                        end
                    end, |err| -> nil)
                end
            end
        end
    end
end)

Requirements = nil
Shared.SG:Cache(2794162)
Shared.SG:Cache(2766600)

print('Loaded MrRobot in ' .. math.round((os.clock() - SCRIPT_START) * 1000, 0) .. ' ms')
-- blackjack, 2273 = blackjet bet
-- blackjack, 2277 = casino chips
-- blackjack, 3790 = player cards total
-- blackjack, 3789 = dealer cards total