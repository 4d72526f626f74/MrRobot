pluto_use global, try, catch, new, class

global GTA_BASE = memory.scan('')
global SCRIPT_LANGUAGE = 'English'
global SCRIPT_VERSION = '0'
global SCRIPT_ROOT = filesystem.scripts_dir() .. 'MrRobot'

local json = require('json')
local HTTP_HOST <constexpr> = 'mrrobot.sodamnez.xyz'

class MrRobot
    data = { 
        'property_ids',     'cutscenes', 'pedlist', 
        'vehicle_handling', 'vehicles',  'weapons',
        'special_ammo_type', 'ls_customs', 'weapon_damage_types',
        'zone_info', 'unlocks', 'casino_cards', 'bounty_ids',
        'script_ids', 'animal_ids', 'custom_loadout'
    }

    images = { 'MrRobot.ytd', 'Error.ytd' }

    modules = { 
        'credits', 'settings', 'players', 'self',
        'online', 'vehicles', 'weapons', 'world',
        'entities', 'protections', 'detections',
        'cooldowns', 'collectables', 'gunvan',
        'tunables', 'cellphone', 'nightclub',
        'arcade', 'agency', 'unlocks', 'heists',
        'module_loader'
    }

    sub_modules = {
        vehicles = {
            'personal_vehicle_manager', 'homing_missiles',
            'homing_missiles_functions'
        },
        weapons = {
            'ped_aimbot', 'player_aimbot'
        }
    }

    user_modules = {}

    languages = { 
        'trans', 'german', 'spanish', 'french', 'russian', 'vietnamese', 'dutch',
        'ukrainian', 'portuguese', 'italian', 'polish', 'turkish'
    }

    libs = { 
        'inspect', 'bitwise', 'ext', 
        'natives-2944a', 'colour', 'cbitfield', 'esp' 
    }

    offsets = { 
        'ls_customs', 'money', 'personal_vehicle_request', 
        'player_states', 'request_services', 'stats_spoofing',
        'ceo_vehicle', 'business_production_stats', 'street_dealer'
    }

    abstract_base_classes = { 'module', 'aimbot' }

    utils = { 
        'script_globals', 'labels', 'utils', 
        'handler', 'emitter', 'entity', 
        'vehicle', 'weapon_manager', 'pvm',
        'se', 'hooks', 'door_manager', 'native_classes',
        'cmd_ref_handler'
    }

    flags = { 
        'script_settings', 'casino_state', 'kosatka_stats', 
        'lester_locate', 'vehicle_bitfield', 'vehicle_state_bitfield',
        'damage_flags', 'organisation'
    }

    function __construct(script_version, game_version, dev_updater=false, FILE_DEBUG=false)
        SCRIPT_VERSION = script_version
        self.dev_updater = dev_updater
        self.modules_loaded = 0
        self.root = menu.my_root()
        self.script_data = $'{SCRIPT_ROOT}\\data\\'
        self.script_images = $'{SCRIPT_ROOT}\\images\\'
        self.script_modules = $'{SCRIPT_ROOT}\\modules\\'
        self.script_sub_modules = $'{SCRIPT_ROOT}\\sub_modules\\'
        self.script_user_modules = $'{SCRIPT_ROOT}\\user_modules\\'
        self.script_config = $'{SCRIPT_ROOT}\\config\\'
        self.script_languages = $'{SCRIPT_ROOT}\\languages\\'
        self.script_libs = $'{SCRIPT_ROOT}\\libs\\'
        self.script_offsets = $'{SCRIPT_ROOT}\\offsets\\'
        self.script_abc = $'{SCRIPT_ROOT}\\abstract_base_classes\\'
        self.script_utils = $'{SCRIPT_ROOT}\\utils\\'
        self.script_flags = $'{SCRIPT_ROOT}\\flags\\'

        for ({
            SCRIPT_ROOT, self.script_data, self.script_images,
            self.script_modules, self.script_sub_modules, self.script_user_modules,
            self.script_config, self.script_languages, self.script_libs,
            self.script_offsets, self.script_abc, self.script_utils,
            self.script_flags
        }) as dir do
            if not filesystem.exists(dir) then
                try
                    io.makedir(dir)
                catch e then
                    print($'Error creating directory: {dir}')
                end
            end
        end

        for k, v in pairs(self.sub_modules) do
            if not filesystem.exists($'{self.script_sub_modules}\\{k}') then
                try
                    io.makedir($'{self.script_sub_modules}\\{k}')
                catch e then
                    print($'Error creating directory: {self.script_sub_modules}\\{k}')
                end
            end
        end

        do
            local dir = $'{self.script_languages}\\language.txt'
            if filesystem.exists(dir) then
                local file <close> = assert(io.open(dir, 'r'))
                SCRIPT_LANGUAGE = file:read('*all')
                file:close()
            else
                local file <close> = assert(io.open(dir, 'w'))
                file:write(SCRIPT_LANGUAGE)
                file:close()
            end
        end

        self.incompatible = game_version ~= menu.get_version().game:sub(1, 4)

        self:unload_all_modules()

        if not FILE_DEBUG then
            if async_http.have_access() then
                self:missing_and_update_handler()
                self.internet_access = true
            else
                self.internet_access = false
            end
        else
            local missing_data = {
                data = {},
                images = {},
                modules = {},
                sub_modules = {
                    vehicles = {},
                    weapons = {}
                },
                user_modules = {},
                languages = {},
                libs = {},
                offsets = {},
                abstract_base_classes = {},
                utils = {},
                flags = {}
            }

            for self.data as data do
                local dir = $'{self.script_data}\\{data}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['data'], $'{data}.luar')
                end
            end

            for self.images as image do
                local dir = $'{self.script_images}\\{image}'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['images'], image)
                end
            end

            for self.modules as module do
                local dir = $'{self.script_modules}\\{module}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['modules'], $'{module}.luar')
                end
            end

            for k, v in pairs(self.sub_modules) do
                for k1, v1 in pairs(v) do
                    local dir = $'{self.script_sub_modules}\\{k}\\{v1}.luar'
                    if not filesystem.exists(dir) then
                        table.insert(missing_data['sub_modules'][k], $'{v1}.luar')
                    end
                end
            end

            for self.user_modules as module do
                local dir = $'{self.script_user_modules}\\{module}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['user_modules'], $'{module}.luar')
                end
            end

            for self.languages as lang do
                local dir = $'{self.script_languages}\\{lang}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['languages'], $'{lang}.luar')
                end
            end

            for self.libs as lib do
                local dir = $'{self.script_libs}\\{lib}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['libs'], $'{lib}.luar')
                end
            end

            for self.offsets as offset do
                local dir = $'{self.script_offsets}\\{offset}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['offsets'], $'{offset}.luar')
                end
            end

            for self.abstract_base_classes as abc do
                local dir = $'{self.script_abc}\\{abc}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['abstract_base_classes'], $'{abc}.luar')
                end
            end

            for self.utils as util do
                local dir = $'{self.script_utils}\\{util}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['utils'], $'{util}.luar')
                end
            end

            for self.flags as flag do
                local dir = $'{self.script_flags}\\{flag}.luar'
                if not filesystem.exists(dir) then
                    table.insert(missing_data['flags'], $'{flag}.luar')
                end
            end

            local missing_files = false
            for k, v in pairs(missing_data) do
                if #v > 0 then
                    missing_files = true
                    break
                end
            end

            if missing_files then
                util.toast('Missing files detected!')
                util.stop_script()
            end
        end
    end

    function missing_and_update_handler()
        local missing_data = {
            data = {},
            images = {},
            modules = {},
            sub_modules = {
                vehicles = {},
                weapons = {}
            },
            user_modules = {},
            languages = {},
            libs = {},
            offsets = {},
            abstract_base_classes = {},
            utils = {},
            flags = {}
        }

        local missing_files = false

        for k, _ in pairs(missing_data) do
            for k1, item in pairs(self[k]) do
                if type(item) ~= 'table' then
                    local dir = $'{SCRIPT_ROOT}\\{k}\\{item}'
                    if item:match('%.') then
                        if not filesystem.exists(dir) then
                            if k ~= 'images' then
                                table.insert(missing_data[k], $'{item}.luar')
                            else
                                table.insert(missing_data[k], item)
                            end
                            missing_files = true
                        end
                    else
                        if not filesystem.exists($'{dir}.luar') then
                            if k ~= 'images' then
                                table.insert(missing_data[k], $'{item}.luar')
                            else
                                table.insert(missing_data[k], item)
                            end
                            missing_files = true
                        end
                    end
                else
                    for k2, sub_item in pairs(item) do
                        local dir = $'{SCRIPT_ROOT}\\{k}\\{k1}\\{sub_item}'
                        if sub_item:match('%.') then
                            if not filesystem.exists(dir) then
                                if k ~= 'images' then
                                    table.insert(missing_data[k][k1], $'{sub_item}.luar')
                                else
                                    table.insert(missing_data[k][k1], sub_item)
                                end
                                missing_files = true
                            end
                        else
                            if not filesystem.exists($'{dir}.luar') then
                                if k ~= 'images' then
                                    table.insert(missing_data[k][k1], $'{sub_item}.luar')
                                else
                                    table.insert(missing_data[k][k1], sub_item)
                                end
                                missing_files = true
                            end
                        end
                    end
                end
            end
        end

        if missing_files then
            local bytes = 0

            json_str = json.encode(missing_data)

            async_http.init(HTTP_HOST, '/index.php?get_missing', function(body, headers, status_code)
                if status_code == 200 then
                    local payload = body
                    body = json.decode(body)
                    util.execute_in_os_thread(function()
                        for k, v in pairs(body) do
                            if k == 'main' then
                                local name = v['name']
                                local buffer = v['buffer']
                                local dir = $'{filesystem.scripts_dir()}\\{name}'

                                print(dir)
                                continue
                            elseif k == 'libs' or k == 'images' or k == 'languages' then
                                for k1, v1 in pairs(v) do
                                    local name = v1['name']
                                    local buffer = self:base64(v1['buffer'], 'decode')
                                    local dir = $'{SCRIPT_ROOT}\\{k}\\{name}'
    
                                    local file <close> = assert(io.open($'{dir}', 'wb'))
                                    file:write(buffer)
                                    file:close()
                                end
                                continue
                            elseif k == 'sub_modules' then
                                for k1, v1 in pairs(v) do
                                    for k2, v2 in pairs(v1) do
                                        local name = v2['name']
                                        local buffer = v2['buffer']
                                        local dir = $'{SCRIPT_ROOT}\\{k}\\{k1}\\{name}'
    
                                        local file <close> = assert(io.open($'{dir}', 'wb'))
                                        file:write(buffer)
                                        file:close()
                                    end
                                end
                                continue
                            end
    
                            for k1, v1 in pairs(v) do
                                local name = v1['name']
                                local buffer = v1['buffer']
                                local dir = $'{SCRIPT_ROOT}\\{k}\\{name}'
    
                                local file <close> = assert(io.open($'{dir}', 'wb'))
                                file:write(buffer)
                                file:close()
                            end
                        end

                        bytes = #payload
                    end)
                end
            end)
            if self.dev_update then async_http.add_header('Dev', true) end
            async_http.set_post('application/json', json_str)
            async_http.dispatch()

            repeat
                util.yield_once()
            until bytes ~= 0

            util.yield(100)
            self.T = require('languages.trans')
        end

        async_http.init(HTTP_HOST, '/index.php', function(body, headers, status_code)
            if status_code == 200 then
                local compare = soup.version_compare((self.dev_updater) ? headers['Dev-Latest'] : body, SCRIPT_VERSION)
                if compare == 1 then
                    local update_button = menu.shadow_root():action($'[MrRobot] v{body}', {}, '', function()
                        for self.libs as lib do
                            local dir = $'{self.script_libs}\\{lib}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.utils as util do
                            local dir = $'{self.script_utils}\\{util}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.data as data do
                            local dir = $'{self.script_data}\\{data}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.flags as flag do
                            local dir = $'{self.script_flags}\\{flag}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.offsets as offset do
                            local dir = $'{self.script_offsets}\\{offset}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.abstract_base_classes as abc do
                            local dir = $'{self.script_abc}\\{abc}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.modules as module do
                            local dir = $'{self.script_modules}\\{module}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.images as image do
                            local dir = $'{self.script_images}\\{image}'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.languages as lang do
                            local dir = $'{self.script_languages}\\{lang}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for self.user_modules as module do
                            local dir = $'{self.script_user_modules}\\{module}.luar'
                            if filesystem.exists(dir) then
                                io.remove(dir)
                            end
                        end

                        for k, v in pairs(self.sub_modules) do
                            for k1, v1 in pairs(v) do
                                local dir = $'{self.script_sub_modules}{k}\\{v1}.luar'
                                if filesystem.exists(dir) then
                                    io.remove(dir)
                                end
                            end
                        end

                        util.restart_script()
                    end)

                    update_button = menu.my_root():getChildren()[1]:attachAfter(update_button)
                    update_button:focus()
                end
            end
        end)
        async_http.dispatch()
    end

    inline function title(str)
        for word in str:gmatch('%w+') do
            str = str:gsub(word, word:gsub('^%l', string.upper))
        end
        return str
    end

    inline function base64(data, operation)
        $define charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
        if operation == 'encode' then
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
        elseif operation == 'decode' then
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
    end

    inline function unload_all_modules()
        for k, v in pairs(package.loaded) do
            if (k:match('data') or k:match('images') or k:match('modules') or 
                k:match('sub_modules') or k:match('user_modules') or k:match('config') or 
                k:match('languages') or k:match('libs') or k:match('offsets') or k:match('abc') or 
                k:match('utils') or k:match('flags')
            ) then
                package.loaded[k] = nil
            end
        end
    end

    inline function setup_package_path()
        package.path = ''
        package.path = $'{package.path};{SCRIPT_ROOT}\\?.luar'
    end

    function load_modules()
        local T = self.T or require('languages.trans')

        if self.incompatible then
            for k, v in pairs(memory) do
                if k:find('read') then
                    memory[k] = function(addr)
                        return 0
                    end
                elseif k:find('write') then
                    memory[k] = function(addr, value)
                        return
                    end
                end
            end
        end

        self.errors = {}

        util.register_file($'{SCRIPT_ROOT}\\images\\MrRobot.ytd')
        util.register_file($'{SCRIPT_ROOT}\\images\\Error.ytd')
        self:request_streamed_texture_dict('MrRobot', 1)
        self:request_streamed_texture_dict('Error', 1)
        require('libs.natives-2944a')

        local meta = {
            __index = function(self, key)
                if not key:match('^[A-Z_]+_[A-Z_]+_[A-Z_]+$') then   
                    if key:match('^[a-z_]+') then
                        key = key:upper()
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
        
        for ns as key do _G[key:lower()] = setmetatable(_G[key], meta) end
        repeat
            util.yield_once()
        until self:has_streamed_texture_dict_loaded('MrRobot') and self:has_streamed_texture_dict_loaded('Error')

        for self.libs as lib do require($'libs.{lib}');self.modules_loaded += 1 end
        for self.utils as util do require($'utils.{util}');self.modules_loaded += 1 end
        for self.data as data do require($'data.{data}');self.modules_loaded += 1 end
        for self.flags as flag do require($'flags.{flag}');self.modules_loaded += 1 end
        for self.offsets as offset do require($'offsets.{offset}');self.modules_loaded += 1 end
        for self.abstract_base_classes as abc do require($'abstract_base_classes.{abc}');self.modules_loaded += 1 end

        for self.modules as name do
            try
                local r = require($'modules.{name}')
                local rtype = type(r)
                name = self:title(name)

                if r ~= nil then
                    local ref = self.root:list(T(name), {$'r{name}'}, '')
                if rtype == 'table' then
                    do 
                        local _ = new r(ref)
                    end
                elseif rtype == 'function' then
                    r(ref)
                end
                self.modules_loaded += 1
            end
            catch e then
                local line = e:match(':(%d+):')
                local filename = e:match('(%w+%.luar)')

                util.log_error(filename, line, e)
                table.insert(self.errors, { line=line, filename=filename, stacktrace=e })
            end
        end

        local handler = require('utils.handler')

        for self.errors as e do
            util.toast(
                T:T(
                    'Error in %s on line %d\n\n %s', 
                    e.filename, 
                    e.line, 
                    e.stacktrace
                )
            )
        end
    
        local utils = require('utils.utils')
        players.add_command_hook(function(pid, root)
            if pid == players.user() then utils.char_slot = util.get_char_slot() end

            try
                handler.player_loop(pid, root)
                handler.ghosting_loop(pid, root)
                handler.blame_kill_add(pid, root)
                handler.aimbot_add(pid, root)
            catch e then
                util.display_error(e)
            end
        end)

        players.on_leave(function(pid, name)
            try
                handler.player_remove(pid, name)
                handler.ghosting_remove_player(pid, name)
                handler.blame_kill_remove(pid, name)
                handler.aimbot_remove(pid, name)
            catch e then
                util.display_error(e)
            end
        end)

        util.on_pre_stop(function()
            local utils = require('utils.utils')
            utils.to_delete = nil
            self:set_streamed_texture_dict_as_no_longer_needed('MrRobot')
            self:set_streamed_texture_dict_as_no_longer_needed('Error')
        end)

        local load_percent = (self.modules_loaded / self:get_module_count()) * 100
        local module_count = self:get_module_count()
        if load_percent < 100 then
            util.log(string.format($'Successfully loaded {self.modules_loaded}/{module_count} modules (%.2f%s)', load_percent, '%'))
        else
            util.log($'Successfully loaded {self.modules_loaded}/{module_count} modules')
        end

        if self.incompatible then
            util.toast(T'Game version mismatch detected!')
        end

        if not self.internet_access then
            util.toast(T'You do not have internet access, new updates will not be available!')
            local no_access = menu.shadow_root():divider(T'Offline Mode')
            no_access = menu.my_root():getChildren()[1]:attachAfter(no_access)
        end
    end

    inline function get_module_count()
        return (
            #self.modules + #self.data + #self.utils + #self.flags + 
            #self.offsets + #self.abstract_base_classes + #self.libs
        )
    end

    inline function request_streamed_texture_dict(textureDict, p1)
        native_invoker.begin_call()
        native_invoker.push_arg_string(textureDict)
        native_invoker.push_arg_bool(p1)
        native_invoker.end_call_2(0xDFA2EF8E04127DD5)
    end

    inline function has_streamed_texture_dict_loaded(textureDict)
        native_invoker.begin_call()
        native_invoker.push_arg_string(textureDict)
        native_invoker.end_call_2(0x0145F696AAAAD2E4)
        return native_invoker.get_return_value_bool()
    end

    inline function set_streamed_texture_dict_as_no_longer_needed(textureDict)
        native_invoker.begin_call()
        native_invoker.push_arg_string(textureDict)
        native_invoker.end_call_2(0xBE2CACCF5A8AA805)
    end
end

local MrRobot = new MrRobot('4.1.1', '1.69')
MrRobot:setup_package_path()
MrRobot:load_modules()