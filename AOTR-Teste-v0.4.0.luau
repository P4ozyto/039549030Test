-- Generated local bundle v0.4.0. Default mode: in-memory Demo.
local factories, cache, loading = {}, {}, {}
factories["Main"] = function(require)
local Config = require("core/Config")
local Logger = require("core/Logger")
local Engine = require("automation/Engine")
local Panel = require("ui/Panel")
local Main = {}
function Main.start(options)
    options = options or {}
    local config = table.clone(Config)
    for key, value in pairs(options.config or {}) do
        assert(config[key] ~= nil and typeof(config[key]) == typeof(value), "Invalid config: " .. key)
        config[key] = value
    end
    for _, key in ipairs({ "tick", "retryDelay", "maxFailures", "stallTimeout", "attackRange", "attackCooldown", "moveSpeed", "maxLogs", "aotrRemoteTimeout", "aotrRetryInterval", "aotrHoverHeight", "aotrUniverseId", "aotrAltitudeTolerance", "aotrHoverTolerance", "aotrAscentSpeed", "aotrSteeringGain", "aotrForcePerMass", "aotrAuraRadius", "aotrAuraMaxTargets", "aotrAvoidRadius" }) do
        local value = config[key]
        assert(value == value and value > 0 and value < math.huge, "Invalid positive number: " .. key)
    end
    assert(config.targetMode == "Nearest" or config.targetMode == "LowestHealth", "Invalid target mode")
    assert(config.aotrRetryMethod == "Navigation" or config.aotrRetryMethod == "Click", "Invalid retry UI method")
    assert(config.aotrCombatMode == "Tekkit" or config.aotrCombatMode == "Measured", "Invalid combat mode")
    assert(config.aotrHitSpeedMin >= 0 and config.aotrHitSpeedMax >= config.aotrHitSpeedMin and config.aotrHitSpeedMax < math.huge, "Invalid hit-speed range")
    assert(config.aotrHitExtraMin >= 0 and config.aotrHitExtraMax >= config.aotrHitExtraMin and config.aotrHitExtraMax < math.huge, "Invalid extra range")
    for _, key in ipairs({ "aotrHitSpeedMin", "aotrHitSpeedMax", "aotrHitExtraMin", "aotrHitExtraMax", "aotrAuraMaxTargets" }) do
        assert(config[key] == math.floor(config[key]), "Integer required: " .. key)
    end
    assert(config.aotrAltitudeP > 0 and config.aotrAltitudeP < math.huge and config.aotrAltitudeD > 0 and config.aotrAltitudeD < math.huge, "Invalid altitude gains")
    local adapter
    if config.mode == "Demo" then adapter = require("adapters/Demo").new()
    elseif config.mode == "AOTR" then adapter = require("adapters/AOTR").new(config)
    elseif config.mode == "OwnGame" then adapter = require("adapters/OwnGame").new(options.bindings)
    else error("Unknown mode") end
    local log = Logger.new(config.maxLogs)
    if config.mode == "AOTR" then adapter.log = log end
    local engine = Engine.new(adapter, config, log)
    local controller = { engine = engine, log = log, config = config, adapter = adapter }
    local connection, panel, destroyed
    local autoStartPending, autoStartDeadline = config.autoExecute, os.clock() + 120
    function controller:destroy()
        if destroyed then return end
        destroyed = true; engine:stop("Destroyed")
        if connection then connection:Disconnect() end
        if panel then panel:destroy() end
        if controller.resumeConnection then controller.resumeConnection:Disconnect() end
    end
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        local now = os.clock()
        if autoStartPending then
            if not config.autoExecute or now >= autoStartDeadline then
                autoStartPending = false
                if config.autoExecute then log:write("error", "autoexecute", "Mission readiness timeout (120s)") end
            else
                local ok, valid = pcall(function() return adapter:validate(config) end)
                if ok and valid then autoStartPending = false; engine:start() end
            end
        end
        engine:step(now)
    end)
    local ok, err = pcall(function()
        if options.ui ~= false then
            local ui = if config.mode == "AOTR" then require("ui/TestPanel") else Panel
            panel = ui.mount(engine, adapter, config, log, function() controller:destroy() end)
        end
    end)
    if not ok then controller:destroy(); error(err) end
    return controller
end
return Main

end
factories["adapters/AOTR"] = function(require)
-- Experimental contracts from Tekkit fetched 2026-11-01. Not runtime-verified.
local Flight = require("automation/Flight")
local Retry = require("ui/Retry")
local TekkitCombat = require("automation/TekkitCombat")
local AOTR = {}
AOTR.__index = AOTR
local function child(root, ...)
    for _, name in ipairs({ ... }) do
        if not root then return nil end
        root = root:FindFirstChild(name)
    end
    return root
end
function AOTR.new(config, log)
    local player = game:GetService("Players").LocalPlayer
    return setmetatable({ config = config, log = log, requiresOptIn = true, retryUI = Retry.new(player),
        player = game:GetService("Players").LocalPlayer, epoch = 0,
        pending = nil, sent = 0, completed = 0, lastRetry = -math.huge,
        savedMovers = {}, lastError = nil, lastResult = "Not tested", targetCount = 0,
        flightTarget = nil, flightConnection = nil, flightPhase = "Idle", auraCursor = 0,
        nearbyTargets = 0, hoverAltitude = nil,
        altitudeMover = nil, savedCollisions = {}, healthSeen = {}, observedDamage = 0,
    }, AOTR)
end
function AOTR:resolve()
    local character = self.player.Character
    local root = child(character, "HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local titans = workspace:FindFirstChild("Titans")
    local remotes = child(game:GetService("ReplicatedStorage"), "Assets", "Remotes")
    return character, root, humanoid, titans, child(remotes, "POST"), child(remotes, "GET")
end
function AOTR:diagnose()
    local character, root, humanoid, titans, post, get = self:resolve()
    local rows = {
        "PlaceId=" .. game.PlaceId .. " UniverseId=" .. game.GameId,
        "Character=" .. tostring(character ~= nil), "Root=" .. tostring(root ~= nil),
        "Humanoid=" .. tostring(humanoid ~= nil), "Titans=" .. tostring(titans ~= nil),
        "POST=" .. (post and post.ClassName or "missing"), "GET=" .. (get and get.ClassName or "missing"),
        "BV=" .. tostring(child(root, "BV") ~= nil), "BG=" .. tostring(child(root, "BG") ~= nil),
        "AltitudeController=" .. tostring(self.altitudeMover ~= nil),
        "Blade=" .. tostring(child(character, "Rig_" .. self.player.Name, "LeftHand", "Blade_1") ~= nil),
    }
    table.insert(rows, "ValidTargets=" .. #self:targets())
    local retryButton, _, retryRoot = self.retryUI:locate()
    table.insert(rows, "RetryRoot=" .. (retryRoot and retryRoot.ClassName or "missing"))
    table.insert(rows, "RetryButton=" .. (retryButton and retryButton.ClassName or "missing"))
    table.insert(rows, "RetryVisible=" .. tostring(self.retryUI:visible(retryButton)))
    for _, row in ipairs(rows) do self.log:write("info", "AOTR dependency", row); print("[AOTR] " .. row) end
    return table.concat(rows, "\n")
end
function AOTR:validate(config)
    self.config = config
    if game.GameId ~= config.aotrUniverseId then return false, "Unexpected universe; AOTR actions blocked" end
    local radius = if config.aotrAuraEnabled then config.aotrAuraRadius else config.attackRange
    if radius <= config.aotrHoverHeight then return false, "Attack/aura radius must exceed hover height" end
    local _, root, humanoid, titans, post, get = self:resolve()
    if not root or not humanoid or not titans then return false, "Enter a mission: character/root/humanoid/Titans missing" end
    if config.autoQuest or config.autoRaid or config.autoBoss then return false, "Quest/Raid/Boss entry contracts not verified; disable these options" end
    if config.aotrActionsEnabled and (not post or not post:IsA("RemoteEvent") or not get or not get:IsA("RemoteFunction")) then
        return false, "Tekkit POST/GET contract missing; actions blocked"
    end
    return true
end
function AOTR:ready()
    local _, root, humanoid = self:resolve()
    return root ~= nil and humanoid ~= nil and humanoid.Health > 0
end
function AOTR:position()
    local _, root = self:resolve(); assert(root, "Character root missing"); return root.Position
end
function AOTR:targets()
    local _, _, _, titans = self:resolve()
    local targets = {}
    if titans then
        for _, titan in ipairs(titans:GetChildren()) do
            if not titan:IsA("Model") then continue end
            local humanoid = titan:FindFirstChildOfClass("Humanoid")
            local hitbox = child(titan, "Hitboxes", "Hit", "Nape")
            if titan.Name == "Attack_Titan" then
                local marker = child(titan, "Marker")
                if marker then
                    local ok, adornee = pcall(function() return marker.Adornee end)
                    if ok and adornee and adornee:IsA("BasePart") and adornee:IsDescendantOf(titan) then hitbox = adornee end
                end
            end
            if humanoid then
                local previous = self.healthSeen[humanoid]
                if previous and humanoid.Health < previous then
                    local damage = previous - humanoid.Health
                    self.observedDamage += damage
                    self.log:write("info", "health decreased (source of damage unverified)", damage)
                end
                self.healthSeen[humanoid] = humanoid.Health
            end
            if humanoid and humanoid.Health > 0 and hitbox and hitbox:IsA("BasePart") then
                table.insert(targets, { id = hitbox, position = hitbox.Position, health = humanoid.Health })
            end
        end
    end
    for humanoid in pairs(self.healthSeen) do if not humanoid.Parent then self.healthSeen[humanoid] = nil end end
    self.targetCount = #targets; return targets
end
function AOTR:checkErrors()
    if self.lastError then local err = self.lastError; self.lastError = nil; error(err) end
end
function AOTR:validTarget(target)
    local _, _, _, titans = self:resolve()
    return typeof(target) == "Instance" and target:IsA("BasePart") and titans and target:IsDescendantOf(titans)
end
function AOTR:queue(name, callback)
    assert(self.config.aotrActionsEnabled, "Real actions disabled")
    if self.pending then return false end
    local job = { name = name, epoch = self.epoch }
    self.pending = job; self.sent += 1; self.log:write("info", "request", name)
    job.thread = task.defer(function()
        if self.pending ~= job or self.epoch ~= job.epoch then return end
        local ok, result = xpcall(callback, debug.traceback)
        if self.pending ~= job or self.epoch ~= job.epoch then return end
        self.pending = nil
        if job.timer then pcall(task.cancel, job.timer) end
        if not ok then
            self.lastError = name .. ": " .. tostring(result); self.lastResult = "Error: " .. name
            self.log:write("error", "request", self.lastError)
        else
            self.completed += 1
            self.lastResult = if result == false then "Server returned false: " .. name else "Returned: " .. name
            self.log:write("info", "returned (not proof of effect)", name)
        end
    end)
    job.timer = task.delay(self.config.aotrRemoteTimeout, function()
        if self.pending ~= job then return end
        self.pending = nil; pcall(task.cancel, job.thread)
        self.lastError = "RemoteTimeout: " .. name; self.lastResult = self.lastError
        self.log:write("error", "timeout", name)
    end)
    return true
end
function AOTR:attack(target)
    assert(self:validTarget(target), "Target removed")
    return self:queue("Attack", function()
        local _, root, _, _, post, get = self:resolve()
        assert(root and post and get and self:validTarget(target), "Attack dependencies changed")
        local radius = if self.config.aotrAuraEnabled then self.config.aotrAuraRadius else self.config.attackRange
        assert((root.Position - target.Position).Magnitude <= radius, "Target out of range")
        local bv = child(root, "BV")
        local speed = if bv and bv:IsA("BodyVelocity") then bv.Velocity.Magnitude else root.AssemblyLinearVelocity.Magnitude
        local hitSpeed, extra = TekkitCombat.arguments(self.config, speed, math.random)
        self.log:write("info", "attack arguments", self.config.aotrCombatMode .. " speed=" .. hitSpeed .. " extra=" .. extra)
        post:FireServer("Attacks", "Slash", true)
        return get:InvokeServer("Hitboxes", "Register", target, hitSpeed, extra)
    end)
end
function AOTR:flightDestination(target)
    local altitude = math.max(target.Position.Y + self.config.aotrHoverHeight, self.hoverAltitude or -math.huge)
    return Vector3.new(target.Position.X, altitude, target.Position.Z)
end
function AOTR:progressDistance(target)
    return (self:flightDestination(target.id) - self:position()).Magnitude
end
function AOTR:updateFlight()
    local target = self.flightTarget
    if not target or not self:validTarget(target) or not self:ready() then self:haltMotion(); return end
    local _, root = self:resolve()
    local bv, bg = child(root, "BV"), child(root, "BG")
    assert(bv and bv:IsA("BodyVelocity"), "Movement dependency BV missing")
    if not self.savedMovers[bv] then self.savedMovers[bv] = { maxForce = bv.MaxForce } end
    local destination = self:flightDestination(target)
    if not self.altitudeMover or self.altitudeMover.Parent ~= root then
        if self.altitudeMover then self.altitudeMover:Destroy() end
        local hold = Instance.new("BodyPosition")
        hold.Name = "MahmutAltitude"; hold.Position = root.Position; hold.Parent = root
        self.altitudeMover = hold
    end
    local velocity, phase = Flight.plan(root.Position, destination, self.config)
    local force = root.AssemblyMass * self.config.aotrForcePerMass
    self.altitudeMover.MaxForce = Vector3.new(0, force, 0)
    self.altitudeMover.P = root.AssemblyMass * self.config.aotrAltitudeP
    self.altitudeMover.D = root.AssemblyMass * self.config.aotrAltitudeD
    self.altitudeMover.Position = Vector3.new(root.Position.X, destination.Y, root.Position.Z)
    bv.MaxForce = Vector3.new(force, force, force)
    bv.Velocity = velocity
    self.savedMovers[bv].lastVelocity = velocity
    self.savedMovers[bv].lastForce = bv.MaxForce
    self.flightPhase = phase
    if bg and bg:IsA("BodyGyro") then
        local direction = destination - root.Position
        if direction.Magnitude > 0.01 then
            if not self.savedMovers[bg] then self.savedMovers[bg] = { cframe = bg.CFrame } end
            bg.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
            self.savedMovers[bg].lastCFrame = bg.CFrame
        end
    end
end
function AOTR:move(target, _dt, _speed)
    assert(self.config.aotrActionsEnabled, "Real actions disabled")
    assert(self:validTarget(target), "Target removed")
    self.flightTarget = target
    self:updateFlight()
    if not self.flightConnection then
        self.flightConnection = game:GetService("RunService").Heartbeat:Connect(function()
            local ok, err = pcall(function() self:updateFlight() end)
            if not ok then self.lastError = "Flight: " .. tostring(err); self:haltMotion() end
        end)
    end
end
function AOTR:stepTarget(target, targets, now, lastAttack)
    if self.config.aotrNoCollision then
        local character = self.player.Character
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if self.savedCollisions[part] == nil then self.savedCollisions[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end
    local position = self:position()
    local highest = target.position.Y
    for _, other in ipairs(targets) do
        local delta = other.position - position
        if Vector3.new(delta.X, 0, delta.Z).Magnitude <= self.config.aotrAvoidRadius then highest = math.max(highest, other.position.Y) end
    end
    self.hoverAltitude = highest + self.config.aotrHoverHeight
    self:move(target.id, self.config.tick, self.config.moveSpeed)
    if not self.config.autoAttack then return lastAttack, self.flightPhase .. ": attack OFF" end
    if self.pending or now - lastAttack < self.config.attackCooldown then return lastAttack, self.flightPhase end
    if self.config.autoReload and self:needsReload() then self:reload(); return now, "HoverReload" end
    local radius = if self.config.aotrAuraEnabled then self.config.aotrAuraRadius else self.config.attackRange
    local nearby = {}
    for _, other in ipairs(targets) do
        if (other.position - position).Magnitude <= radius and (self.config.aotrAuraEnabled or other.id == target.id) then
            table.insert(nearby, other)
        end
    end
    table.sort(nearby, function(a, b) return (a.position - position).Magnitude < (b.position - position).Magnitude end)
    local count = math.min(#nearby, self.config.aotrAuraMaxTargets)
    self.nearbyTargets = count
    if count == 0 then return lastAttack, self.flightPhase end
    self.auraCursor = self.auraCursor % count + 1
    if self:attack(nearby[self.auraCursor].id) then
        if self.flightPhase == "Ascending" then return now, "AscendingAttack" end
        return now, if self.config.aotrAuraEnabled then "HoverAura" else "HoverAttack"
    end
    return lastAttack, self.flightPhase
end
function AOTR:haltMotion()
    if self.flightConnection then self.flightConnection:Disconnect(); self.flightConnection = nil end
    self.flightTarget = nil; self.flightPhase = "Idle"; self.hoverAltitude = nil
    if self.altitudeMover then self.altitudeMover:Destroy(); self.altitudeMover = nil end
    for part, previous in pairs(self.savedCollisions) do
        if part.Parent and not part.CanCollide then part.CanCollide = previous end
    end
    table.clear(self.savedCollisions)
    for mover, saved in pairs(self.savedMovers) do
        if mover.Parent then
            if mover:IsA("BodyVelocity") then
                if mover.Velocity == saved.lastVelocity then mover.Velocity = Vector3.zero end
                if mover.MaxForce == saved.lastForce then mover.MaxForce = saved.maxForce end
            elseif mover:IsA("BodyGyro") and mover.CFrame == saved.lastCFrame then mover.CFrame = saved.cframe end
        end
    end
    table.clear(self.savedMovers)
end
function AOTR:needsReload()
    local blade = child(self.player.Character, "Rig_" .. self.player.Name, "LeftHand", "Blade_1")
    return blade ~= nil and blade:IsA("BasePart") and blade.Transparency == 1
end
function AOTR:reload()
    self:queue("Reload", function()
        local _, _, _, _, _, get = self:resolve(); assert(get, "GET missing")
        return get:InvokeServer("Blades", "Reload")
    end)
end
function AOTR:mission()
    local button = self.retryUI:locate()
    if self.retryUI:visible(button) then return "Complete" end
    -- No targets alone is not proof of mission completion.
    return "Active"
end
function AOTR:retry()
    if os.clock() - self.lastRetry < self.config.aotrRetryInterval then return "RetryWaiting" end
    if self:queue("RetryUI", function()
        if self.config.aotrRetryMethod == "Click" and self.minimizeUI then self.minimizeUI() end
        local result = self.retryUI:activate(self.config.aotrRetryMethod)
        self.log:write("info", "retry UI", result)
        return result
    end) then self.lastRetry = os.clock() end
    return "RetryUI"
end
function AOTR:startMission() error("Mission entry contract unavailable") end
function AOTR:metrics()
    return { targets = self.targetCount, requests = self.sent, returned = self.completed,
        pending = self.pending and self.pending.name or "none", result = self.lastResult,
        flight = self.flightPhase, auraTargets = self.nearbyTargets, height = self.config.aotrHoverHeight,
        resume = self.resumeStatus or "Not attached", retry = self.config.aotrRetryMethod,
        combat = self.config.aotrCombatMode, healthDecrease = self.observedDamage }
end
function AOTR:stop()
    self.retryUI:cancel()
    self.epoch += 1
    local job = self.pending; self.pending = nil
    if job then
        if job.thread then pcall(task.cancel, job.thread) end
        if job.timer then pcall(task.cancel, job.timer) end
    end
    self.lastError = nil; self:haltMotion()
end
return AOTR

end
factories["adapters/Demo"] = function(require)
-- Simulation in memory: never moves a Roblox character or awards real currency.
local Demo = {}
Demo.__index = Demo
function Demo.new()
    return setmetatable({ origin = Vector3.zero, ammo = 3, xp = 0, round = "Active", enemies = {
        { id = "demo-1", position = Vector3.new(30, 0, 0), health = 100 },
        { id = "demo-2", position = Vector3.new(50, 0, 0), health = 150 },
    } }, Demo)
end
function Demo:validate() return true end
function Demo:ready() return true end
function Demo:position() return self.origin end
function Demo:targets() return self.enemies end
function Demo:mission() return self.round end
function Demo:needsReload() return self.ammo == 0 end
function Demo:reload() self.ammo = 3 end
function Demo:stop() end
function Demo:find(id)
    for _, enemy in ipairs(self.enemies) do if enemy.id == id then return enemy end end
    error("Unknown demo target")
end
function Demo:move(id, dt, speed)
    local delta = self:find(id).position - self.origin
    if delta.Magnitude > 0 then self.origin += delta.Unit * math.min(delta.Magnitude, dt * speed) end
end
function Demo:attack(id)
    local enemy = self:find(id)
    if self.ammo <= 0 then error("EquipmentEmpty") end
    self.ammo -= 1
    local before = enemy.health
    enemy.health = math.max(0, before - 50)
    if before > 0 and enemy.health == 0 then self.xp += 10 end
    local alive = false
    for _, item in ipairs(self.enemies) do if item.health > 0 then alive = true end end
    if not alive then self.round = "Complete" end
end
function Demo:retry()
    for _, enemy in ipairs(self.enemies) do enemy.health = 100 end
    self.origin = Vector3.zero; self.ammo = 3; self.round = "Active"
end
function Demo:startMission(_kind) self:retry() end
function Demo:metrics() return { xp = self.xp, ammo = self.ammo, mission = self.round } end
return Demo

end
factories["adapters/OwnGame"] = function(require)
-- bindings are supplied by the owner; queries must use a local snapshot.
-- Actions must return promptly, implement server validation and support stop().
local OwnGame = {}
OwnGame.__index = OwnGame
local required = { "ready", "position", "targets", "mission", "needsReload", "reload",
    "attack", "move", "stop", "retry", "startMission", "metrics" }
function OwnGame.new(bindings)
    return setmetatable({ bindings = bindings or {} }, OwnGame)
end
function OwnGame:validate()
    for _, name in ipairs(required) do
        if type(self.bindings[name]) ~= "function" then return false, "Missing binding: " .. name end
    end
    return true
end
for _, name in ipairs(required) do
    OwnGame[name] = function(self, ...) return self.bindings[name](...) end
end
return OwnGame

end
factories["auth/Client"] = function(require)
local Client = {}
Client.__index = Client
function Client.new(remote)
    assert(remote and remote:IsA("RemoteFunction"), "Own-game gateway is required")
    return setmetatable({ remote = remote, busy = false }, Client)
end
function Client:request(action, payload)
    if self.busy then return { ok = false, code = "Busy" } end
    self.busy = true
    local ok, result = pcall(function() return self.remote:InvokeServer(action, payload) end)
    self.busy = false
    if not ok then return { ok = false, code = "TransportError" } end
    return result
end
function Client:authenticate(key) return self:request("Authenticate", { key = key }) end
return Client

end
factories["automation/Combat"] = function(require)
local Combat = {}
function Combat.step(adapter, target, config, now, lastAttack)
    if not config.autoAttack then return lastAttack, "AttackDisabled" end
    if now - lastAttack < config.attackCooldown then return lastAttack, "Cooldown" end
    if config.autoReload and adapter:needsReload() then
        adapter:reload(); return now, "Reload"
    end
    adapter:attack(target.id)
    return now, "Attack"
end
return Combat

end
factories["automation/Engine"] = function(require)
local Targeting = require("automation/Targeting")
local Combat = require("automation/Combat")
local Missions = require("automation/Missions")
local Engine = {}
Engine.__index = Engine
function Engine.new(adapter, config, log)
    return setmetatable({ adapter = adapter, config = config, log = log, running = false,
        state = "Stopped", failures = 0, lastAttack = -math.huge, nextAt = 0,
        targetId = nil, progressAt = 0, bestDistance = math.huge, lastHealth = nil }, Engine)
end
function Engine:setState(state)
    if self.state ~= state then self.state = state; self.log:write("info", "state", state) end
end
function Engine:start()
    if self.running then return end
    local valid, ok, reason = pcall(function() return self.adapter:validate(self.config) end)
    if not valid then self.log:write("error", "validation", ok); self:setState("Blocked"); return end
    if not ok then self.log:write("error", "dependency", reason); self:setState("Blocked"); return end
    self.failures = 0; self.nextAt = 0; self.targetId = nil
    self.running = true; self:setState("Starting")
end
function Engine:stop(reason)
    self.running = false
    local ok, err = pcall(function() self.adapter:stop() end)
    if not ok then self.log:write("error", "stop", err) end
    self:setState(reason or "Stopped")
end
function Engine:step(now)
    if not self.running or now < self.nextAt then return end
    self.nextAt = now + self.config.tick
    local ok, err = xpcall(function()
        if self.adapter.checkErrors then self.adapter:checkErrors() end
        if self.adapter.requiresOptIn and not self.config.aotrActionsEnabled then
            if not self.adapter:ready() then self.adapter:stop(); self:setState("WaitingCharacter"); return end
            local targets = self.adapter:targets()
            local target = Targeting.select(targets, self.adapter:position(), self.config.targetMode)
            self:setState(if target then "Preview: target found" else "Preview: no targets")
            return
        end
        local missionState = Missions.step(self.adapter, self.config)
        if missionState then
            if self.adapter.haltMotion then self.adapter:haltMotion() end
            self:setState(missionState); return
        end
        if not self.adapter:ready() then self.adapter:stop(); self:setState("WaitingCharacter"); return end
        local targets = self.adapter:targets()
        local target = Targeting.select(targets, self.adapter:position(), self.config.targetMode)
        if not target then
            if self.adapter.haltMotion then self.adapter:haltMotion() end
            self.targetId = nil; self:setState("NoTargets"); return
        end
        local distance = (target.position - self.adapter:position()).Magnitude
        if self.adapter.progressDistance then distance = self.adapter:progressDistance(target) end
        if self.targetId ~= target.id then
            self.targetId = target.id; self.bestDistance = distance; self.lastHealth = target.health; self.progressAt = now
        end
        if distance < self.bestDistance - 0.1 or target.health < self.lastHealth then
            self.progressAt = now; self.bestDistance = distance; self.lastHealth = target.health
        end
        if now - self.progressAt >= self.config.stallTimeout then error("NoProgress: " .. tostring(target.id)) end
        if self.adapter.stepTarget then
            local state
            self.lastAttack, state = self.adapter:stepTarget(target, targets, now, self.lastAttack)
            self:setState(state)
            if not self.config.autoAttack then self.progressAt = now end
            return
        end
        if distance > self.config.attackRange then
            self.adapter:move(target.id, self.config.tick, self.config.moveSpeed); self:setState("Moving")
        else
            if self.adapter.haltMotion then self.adapter:haltMotion() end
            local state
            self.lastAttack, state = Combat.step(self.adapter, target, self.config, now, self.lastAttack)
            self:setState(state)
            -- An intentional disabled attack is not a stalled combat action.
            if not self.config.autoAttack then self.progressAt = now end
        end
    end, debug.traceback)
    if ok then return end
    self.failures += 1; self.log:write("error", "automation", err)
    pcall(function() self.adapter:stop() end)
    if self.failures >= self.config.maxFailures then self:stop("CircuitOpen"); return end
    self.targetId = nil; self.nextAt = now + self.config.retryDelay
    self:setState("Recovering")
end
return Engine

end
factories["automation/Flight"] = function(require)
-- Pure steering planner: climb vertically, then travel horizontally while holding altitude.
local Flight = {}
function Flight.plan(origin, destination, config)
    local verticalError = destination.Y - origin.Y
    local climbing = verticalError > config.aotrAltitudeTolerance
    local horizontal = Vector3.new(destination.X - origin.X, 0, destination.Z - origin.Z)
    local horizontalSpeed = math.min(config.moveSpeed, horizontal.Magnitude * config.aotrSteeringGain)
    local horizontalVelocity = Vector3.zero
    if not climbing and horizontal.Magnitude > 0 then horizontalVelocity = horizontal.Unit * horizontalSpeed end
    local verticalSpeed = math.clamp(verticalError * config.aotrSteeringGain, -config.aotrAscentSpeed, config.aotrAscentSpeed)
    local velocity = horizontalVelocity + Vector3.new(0, verticalSpeed, 0)
    local phase = if climbing then "Ascending" elseif horizontal.Magnitude > config.aotrHoverTolerance then "CruisingAbove" else "HoveringAbove"
    return velocity, phase
end
return Flight

end
factories["automation/Missions"] = function(require)
local Missions = {}
function Missions.step(adapter, config)
    local state = adapter:mission()
    if state == "Complete" or state == "Failed" then
        if config.autoRetry then return adapter:retry() or "Retry" end
        return "MissionEnded"
    end
    if state == "Idle" then
        if config.autoRaid then adapter:startMission("Raid"); return "Raid" end
        if config.autoBoss then adapter:startMission("Boss"); return "Boss" end
        if config.autoQuest then adapter:startMission("Quest"); return "Quest" end
    end
    return nil
end
return Missions

end
factories["automation/Targeting"] = function(require)
local Targeting = {}
function Targeting.select(targets, origin, mode)
    local best, score
    for _, target in ipairs(targets) do
        if target.health > 0 then
            local value = if mode == "LowestHealth" then target.health else (target.position - origin).Magnitude
            if score == nil or value < score then best, score = target, value end
        end
    end
    return best
end
return Targeting

end
factories["automation/TekkitCombat"] = function(require)
-- Argument ranges are transcribed from v136 in the provided Tekkit WIP farm.
local Combat = {}
function Combat.arguments(config, measuredSpeed, randomInteger)
    if config.aotrCombatMode == "Measured" then return measuredSpeed, 0 end
    return randomInteger(config.aotrHitSpeedMin, config.aotrHitSpeedMax), randomInteger(config.aotrHitExtraMin, config.aotrHitExtraMax)
end
return Combat

end
factories["core/Config"] = function(require)
return {
    tick = 0.2, retryDelay = 2, maxFailures = 5, stallTimeout = 15,
    attackRange = 8, attackCooldown = 0.5, moveSpeed = 12,
    targetMode = "Nearest", autoAttack = true, autoQuest = false,
    autoRetry = false, autoRaid = false, autoBoss = false, autoReload = true,
    maxLogs = 200, mode = "Demo",
    aotrActionsEnabled = false, aotrRemoteTimeout = 8, aotrRetryInterval = 3,
    aotrHoverHeight = 60, aotrAltitudeTolerance = 5, aotrHoverTolerance = 6,
    aotrAscentSpeed = 180, aotrSteeringGain = 3, aotrForcePerMass = 3000,
    aotrAuraEnabled = true, aotrAuraRadius = 150, aotrAuraMaxTargets = 6,
    aotrAvoidRadius = 120,
    aotrRetryMethod = "Navigation", autoExecute = false,
    aotrCombatMode = "Tekkit", aotrHitSpeedMin = 215, aotrHitSpeedMax = 230,
    aotrHitExtraMin = 10, aotrHitExtraMax = 100,
    aotrAltitudeP = 100, aotrAltitudeD = 20, aotrNoCollision = true,
    aotrUniverseId = 4658598196,
}

end
factories["core/Logger"] = function(require)
local Logger = {}
Logger.__index = Logger
function Logger.new(limit)
    return setmetatable({ entries = {}, limit = limit or 200 }, Logger)
end
function Logger:write(level, event, detail)
    local entry = { time = os.clock(), level = level, event = event, detail = tostring(detail or "") }
    table.insert(self.entries, entry)
    if #self.entries > self.limit then table.remove(self.entries, 1) end
    if level == "error" then warn("[AdminHub] " .. event .. ": " .. entry.detail) end
end
function Logger:snapshot()
    local result = {}
    for i, entry in ipairs(self.entries) do result[i] = table.clone(entry) end
    return result
end
return Logger

end
factories["core/Preferences"] = function(require)
local Preferences = {}
local fileName = "MahmutAdminHub-settings-v0.4.json"
function Preferences.load(defaults)
    local config = table.clone(defaults)
    if type(readfile) ~= "function" then return config end
    local ok, saved = pcall(function()
        if type(isfile) == "function" and not isfile(fileName) then return {} end
        local content = readfile(fileName)
        assert(#content <= 8192, "Settings too large")
        return game:GetService("HttpService"):JSONDecode(content)
    end)
    if not ok or type(saved) ~= "table" then return config end
    for name, value in pairs(saved) do
        local original = defaults[name]
        if original ~= nil and typeof(original) == typeof(value) then
            if type(value) ~= "number" or (value > 0 and value < math.huge and value == value) then config[name] = value end
        end
    end
    config.mode = "AOTR"
    return config
end
function Preferences.save(config)
    if type(writefile) ~= "function" then return false, "Executor has no writefile; settings only last this session" end
    local ok, err = pcall(function()
        writefile(fileName, game:GetService("HttpService"):JSONEncode(config))
    end)
    return ok, err
end
return Preferences

end
factories["core/Resume"] = function(require)
local Resume = {}
function Resume.attach(controller, sourceUrl)
    local queue = queue_on_teleport
    if type(queue) ~= "function" and type(syn) == "table" then queue = syn.queue_on_teleport end
    local adapter, config, log = controller.adapter, controller.config, controller.log
    local supported = type(queue) == "function"
    adapter.resumeStatus = supported and "Teleport ready" or "Executor has no queue_on_teleport"
    log:write("info", "autoexecute", adapter.resumeStatus)
    local player = game:GetService("Players").LocalPlayer
    local queued = false
    return player.OnTeleport:Connect(function(state)
        if not config.autoExecute or queued or not supported then return end
        if state ~= Enum.TeleportState.Started and state ~= Enum.TeleportState.InProgress then return end
        local json = game:GetService("HttpService"):JSONEncode(config)
        assert(not string.find(json, "]===]", 1, true), "Unexpected settings delimiter")
        local payload = "local e=(getgenv and getgenv()) or _G; e.MahmutAOTRResumeConfig=game:GetService('HttpService'):JSONDecode([===[" .. json .. "]===]); loadstring(game:HttpGet(" .. string.format("%q", sourceUrl) .. "))()"
        local ok, err = pcall(queue, payload)
        if ok then queued = true; adapter.resumeStatus = "Queued for next teleport"
        else adapter.resumeStatus = "Queue failed"; log:write("error", "autoexecute", err) end
    end)
end
return Resume

end
factories["core/Scope"] = function(require)
local Scope = {}
Scope.__index = Scope
function Scope.new() return setmetatable({ items = {} }, Scope) end
function Scope:add(item) table.insert(self.items, item); return item end
function Scope:destroy()
    for i = #self.items, 1, -1 do
        local item = self.items[i]
        pcall(function()
            if typeof(item) == "RBXScriptConnection" then item:Disconnect()
            elseif typeof(item) == "Instance" then item:Destroy()
            elseif type(item) == "function" then item() end
        end)
    end
    table.clear(self.items)
end
return Scope

end
factories["diagnostics/Inspect"] = function(require)
local Inspect = {}
-- Only roots explicitly selected by the developer; no remote calls or hooks.
function Inspect.snapshot(root, maxNodes)
    assert(typeof(root) == "Instance", "Select an Instance root")
    local limit = math.clamp(maxNodes or 200, 1, 2000)
    local rows, queue, index = {}, { root }, 1
    while index <= #queue and #rows < limit do
        local node = queue[index]; index += 1
        table.insert(rows, { path = node:GetFullName(), class = node.ClassName })
        for _, child in ipairs(node:GetChildren()) do
            if #queue >= limit then break end
            table.insert(queue, child)
        end
    end
    return { nodes = rows, limitReached = #rows >= limit }
end
return Inspect

end
factories["ui/Panel"] = function(require)
local Scope = require("core/Scope")
local Panel = {}
function Panel.mount(engine, adapter, config, log, onDestroy)
    local scope = Scope.new()
    local player = game:GetService("Players").LocalPlayer
    local gui = scope:add(Instance.new("ScreenGui"))
    gui.Name = "MahmutAdminHub"; gui.ResetOnSpawn = false
    gui.Parent = player:FindFirstChildOfClass("PlayerGui") or error("PlayerGui unavailable")
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(390, 520); frame.Position = UDim2.fromOffset(30, 60)
    frame.BackgroundColor3 = Color3.fromRGB(22, 25, 34); frame.Parent = gui
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 5); layout.Parent = frame
    local function label(text)
        local item = Instance.new("TextLabel"); item.Size = UDim2.new(1, 0, 0, 28)
        item.BackgroundTransparency = 1; item.TextColor3 = Color3.new(1, 1, 1)
        item.Text = text; item.Parent = frame; return item
    end
    local function button(text, callback)
        local item = Instance.new("TextButton"); item.Size = UDim2.new(1, 0, 0, 28)
        item.Text = text; item.Parent = frame
        scope:add(item.Activated:Connect(function() callback(item) end)); return item
    end
    label("Mahmut Admin | " .. config.mode .. " | v0.1.0")
    local status = label("Stopped")
    local metrics = label("Métricas: aguardando")
    button("Auto Farm ON / OFF", function()
        if engine.running then engine:stop() else engine:start() end
    end)
    for _, name in ipairs({ "autoAttack", "autoQuest", "autoRetry", "autoRaid", "autoBoss", "autoReload" }) do
        button(name .. ": " .. tostring(config[name]), function(item)
            config[name] = not config[name]
            -- Only one mission entry mode at a time.
            if config[name] and (name == "autoQuest" or name == "autoRaid" or name == "autoBoss") then
                for _, other in ipairs({ "autoQuest", "autoRaid", "autoBoss" }) do
                    if other ~= name then config[other] = false end
                end
            end
            item.Text = name .. ": " .. tostring(config[name])
        end)
    end
    button("Alvo: " .. config.targetMode, function(item)
        config.targetMode = if config.targetMode == "Nearest" then "LowestHealth" else "Nearest"
        item.Text = "Alvo: " .. config.targetMode
    end)
    local range = label("Raio de ataque: " .. config.attackRange)
    local slider = Instance.new("TextButton"); slider.Text = "Clique para ajustar raio (1–50)"
    slider.Size = UDim2.new(1, 0, 0, 28); slider.Parent = frame
    scope:add(slider.MouseButton1Down:Connect(function(x)
        config.attackRange = math.floor(1 + math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1) * 49)
        range.Text = "Raio de ataque: " .. config.attackRange
    end))
    button("Diagnóstico (Output)", function()
        for _, entry in ipairs(log:snapshot()) do print(entry.time, entry.level, entry.event, entry.detail) end
    end)
    button("PARAR E FECHAR", function() onDestroy() end)
    local elapsed = 0
    scope:add(game:GetService("RunService").Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.5 then return end
        elapsed = 0
        status.Text = engine.state .. " | falhas: " .. engine.failures
        local ok, values = pcall(function() return adapter:metrics() end)
        if ok then
            local parts = {}
            for key, value in pairs(values) do table.insert(parts, tostring(key) .. "=" .. tostring(value)) end
            table.sort(parts); metrics.Text = table.concat(parts, " | ")
        else metrics.Text = "Métricas indisponíveis" end
        -- Update toggle labels after mission-mode exclusivity changes.
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("TextButton") then
                for _, name in ipairs({ "autoAttack", "autoQuest", "autoRetry", "autoRaid", "autoBoss", "autoReload" }) do
                    if string.sub(child.Text, 1, #name + 1) == name .. ":" then child.Text = name .. ": " .. tostring(config[name]) end
                end
            end
        end
    end))
    return scope
end
return Panel

end
factories["ui/Retry"] = function(require)
-- UI contract taken from Tekkit's Rewards/Main/Info/Main/Buttons/Retry path.
local Retry = {}
Retry.__index = Retry
local function child(root, ...)
    for _, name in ipairs({ ... }) do if not root then return nil end; root = root:FindFirstChild(name) end
    return root
end
function Retry.new(player) return setmetatable({ player = player, release = nil }, Retry) end
function Retry:locate()
    local gui = self.player:FindFirstChildOfClass("PlayerGui")
    local root = child(gui, "Interface", "Rewards", "Main", "Info", "Main", "Buttons", "Retry")
    local button = root
    if root and not root:IsA("GuiButton") then
        button = nil
        for index, node in ipairs(root:GetDescendants()) do
            if index > 64 then break end
            if node:IsA("GuiButton") then button = node; break end
        end
    end
    return button, child(root, "Title"), root
end
function Retry:visible(button)
    if not button or not button:IsA("GuiButton") or button.AbsoluteSize.X <= 0 or button.AbsoluteSize.Y <= 0 then return false end
    local node = button
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node = node.Parent
    end
    return true
end
function Retry:cancel()
    if self.release then local release = self.release; self.release = nil; pcall(release) end
end
function Retry:activate(method)
    local button, title = self:locate()
    if not self:visible(button) then return "RetryWaitingUI" end
    if title and (title:IsA("TextLabel") or title:IsA("TextButton")) and string.find(string.upper(title.Text), "STARTING", 1, true) then return "RetryStarting" end
    if not button.Active then return "RetryButtonDisabled" end
    local input = game:GetService("VirtualInputManager")
    local navigation = game:GetService("GuiService")
    if method == "Click" then
        local center = button.AbsolutePosition + button.AbsoluteSize / 2
        local camera = workspace.CurrentCamera
        if camera and (center.X < 0 or center.Y < 0 or center.X >= camera.ViewportSize.X or center.Y >= camera.ViewportSize.Y) then return "RetryOffscreen" end
        self.release = function() input:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0) end
        local ok, err = pcall(function()
            input:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
            task.wait(0.08)
        end)
        self:cancel(); if not ok then error(err) end
        return "RetryClickSent"
    end
    local previous, selectable = navigation.SelectedObject, button.Selectable
    self.release = function()
        pcall(function() input:SendKeyEvent(false, Enum.KeyCode.Return, false, game) end)
        if button.Parent then button.Selectable = selectable end
        if navigation.SelectedObject == button then navigation.SelectedObject = previous end
    end
    local ok, err = pcall(function()
        button.Selectable = true; navigation.SelectedObject = button
        assert(navigation.SelectedObject == button, "Could not focus Retry button")
        input:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.08)
    end)
    self:cancel(); if not ok then error("UI navigation unavailable: " .. tostring(err)) end
    return "RetryNavigationSent"
end
return Retry

end
factories["ui/Slider"] = function(require)
local Math = require("ui/SliderMath")
local Slider = {}
function Slider.mount(scope, parent, config, key, minimum, maximum, changed, began, ended, step)
    local inputService = game:GetService("UserInputService")
    local surface = Instance.new("TextButton")
    surface.Text = ""; surface.AutoButtonColor = false; surface.BackgroundTransparency = 1
    surface.Size = UDim2.new(1, -10, 0, 40); surface.Parent = parent
    local track = Instance.new("Frame"); track.Size = UDim2.new(1, -24, 0, 8)
    track.Position = UDim2.new(0, 12, 0.5, -4); track.BackgroundColor3 = Color3.fromRGB(60, 67, 85); track.Parent = surface
    local fill = Instance.new("Frame"); fill.BackgroundColor3 = Color3.fromRGB(91, 161, 255); fill.BorderSizePixel = 0; fill.Parent = track
    local knob = Instance.new("Frame"); knob.Size = UDim2.fromOffset(22, 22); knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(225, 238, 255); knob.Parent = track
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = knob
    local pointer, mouse, scrolling
    local function render()
        local fraction = Math.fraction(config[key], minimum, maximum)
        fill.Size = UDim2.new(fraction, 0, 1, 0); knob.Position = UDim2.new(fraction, 0, 0.5, 0)
        changed(config[key])
    end
    local function update(x)
        if track.AbsoluteSize.X <= 0 then return end
        config[key] = Math.valueAt(x, track.AbsolutePosition.X, track.AbsoluteSize.X, minimum, maximum, step)
        render()
    end
    local function finish(cancelled)
        if not pointer then return end
        pointer = nil; mouse = nil
        if parent.Parent and parent:IsA("ScrollingFrame") then parent.ScrollingEnabled = scrolling end
        ended(cancelled)
    end
    scope:add(surface.InputBegan:Connect(function(input)
        if pointer then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        pointer = input; mouse = input.UserInputType == Enum.UserInputType.MouseButton1
        if parent:IsA("ScrollingFrame") then scrolling = parent.ScrollingEnabled; parent.ScrollingEnabled = false end
        began(); update(input.Position.X)
    end))
    scope:add(inputService.InputChanged:Connect(function(input)
        if pointer and ((mouse and input.UserInputType == Enum.UserInputType.MouseMovement) or input == pointer) then update(input.Position.X) end
    end))
    scope:add(inputService.InputEnded:Connect(function(input)
        if pointer and ((mouse and input.UserInputType == Enum.UserInputType.MouseButton1) or input == pointer) then finish(false) end
    end))
    scope:add(inputService.WindowFocusReleased:Connect(function() finish(true) end))
    scope:add(function() finish(true) end)
    render()
    return surface
end
return Slider

end
factories["ui/SliderMath"] = function(require)
local Math = {}
function Math.valueAt(x, left, width, minimum, maximum, step)
    assert(width > 0 and maximum > minimum, "Invalid slider geometry")
    step = step or 1
    local value = minimum + math.clamp((x - left) / width, 0, 1) * (maximum - minimum)
    return math.clamp(math.floor(value / step + 0.5) * step, minimum, maximum)
end
function Math.fraction(value, minimum, maximum)
    return math.clamp((value - minimum) / (maximum - minimum), 0, 1)
end
return Math

end
factories["ui/TestPanel"] = function(require)
local Scope = require("core/Scope")
local Preferences = require("core/Preferences")
local Slider = require("ui/Slider")
local Panel = {}
function Panel.mount(engine, adapter, config, log, onDestroy)
    local scope = Scope.new()
    local gui = scope:add(Instance.new("ScreenGui"))
    gui.Name = "MahmutAOTRTest"; gui.ResetOnSpawn = false; gui.DisplayOrder = 1000
    gui.Parent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui") or error("PlayerGui missing")
    local frame = Instance.new("Frame"); frame.Size = UDim2.fromOffset(440, 560)
    frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(20, 23, 32); frame.Parent = gui
    local restore = Instance.new("TextButton"); restore.Text = "ABRIR HUB"
    restore.Size = UDim2.fromOffset(120, 40); restore.Position = UDim2.fromOffset(12, 12)
    restore.Visible = false; restore.Parent = gui
    local function minimize(value) frame.Visible = not value; restore.Visible = value end
    adapter.minimizeUI = function() minimize(true) end
    scope:add(restore.Activated:Connect(function() minimize(false) end))
    local function save()
        local ok, err = Preferences.save(config)
        if not ok then log:write("info", "preferences", err) end
    end
    local scale = Instance.new("UIScale"); scale.Parent = frame
    local function resize()
        local camera = workspace.CurrentCamera
        if camera then scale.Scale = math.min(1, (camera.ViewportSize.X - 24) / 440, (camera.ViewportSize.Y - 40) / 560) end
    end
    local function text(parent, value, height)
        local node = Instance.new("TextLabel"); node.Size = UDim2.new(1, 0, 0, height or 32)
        node.BackgroundTransparency = 1; node.TextColor3 = Color3.fromRGB(235, 240, 255)
        node.Font = Enum.Font.Code; node.TextSize = 16; node.TextWrapped = true
        node.Text = value; node.Parent = parent; return node
    end
    local function button(parent, value, callback)
        local node = Instance.new("TextButton"); node.Size = UDim2.new(1, 0, 0, 36)
        node.BackgroundColor3 = Color3.fromRGB(45, 53, 73); node.TextColor3 = Color3.new(1, 1, 1)
        node.Font = Enum.Font.SourceSansBold; node.TextSize = 19; node.Text = value; node.Parent = parent
        scope:add(node.Activated:Connect(function() callback(node) end)); return node
    end
    local title = text(frame, "AOTR • Tekkit experimental v0.4.0", 34)
    title.Size = UDim2.new(1, -42, 0, 34)
    title.Position = UDim2.fromOffset(0, 4)
    local minimizeButton = button(frame, "−", function() minimize(true) end)
    minimizeButton.Size = UDim2.fromOffset(34, 30); minimizeButton.Position = UDim2.new(1, -38, 0, 4)
    local status = text(frame, "Parado — ações reais OFF", 44); status.Position = UDim2.fromOffset(0, 40)
    local tabs = Instance.new("Frame"); tabs.BackgroundTransparency = 1
    tabs.Size = UDim2.new(1, -16, 0, 36); tabs.Position = UDim2.fromOffset(8, 88); tabs.Parent = frame
    local pages = {}
    for _, name in ipairs({ "Automação", "Diagnóstico", "Logs" }) do
        local page = Instance.new("ScrollingFrame"); page.Name = name; page.BackgroundTransparency = 1
        page.Position = UDim2.fromOffset(8, 132); page.Size = UDim2.new(1, -16, 0, 366)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y; page.CanvasSize = UDim2.new()
        page.ScrollBarThickness = 6; page.Visible = name == "Automação"; page.Parent = frame
        local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.Parent = page
        pages[name] = page
    end
    for i, name in ipairs({ "Automação", "Diagnóstico", "Logs" }) do
        local tab = button(tabs, name, function()
            for pageName, page in pairs(pages) do page.Visible = pageName == name end
        end)
        tab.Size = UDim2.new(1 / 3, -4, 1, 0); tab.Position = UDim2.new((i - 1) / 3, 0, 0, 0)
    end
    local auto = pages["Automação"]
    text(auto, "Inicie em leitura. Habilite ações reais para tentar movimento e combate.", 46)
    local run = button(auto, "INICIAR / PARAR", function()
        if engine.running then engine:stop() else engine:start() end
    end)
    local actions = button(auto, "Ações reais: OFF", function(node)
        engine:stop()
        config.aotrActionsEnabled = not config.aotrActionsEnabled
        save()
        node.Text = "Ações reais: " .. (config.aotrActionsEnabled and "ON" or "OFF")
    end)
    for _, name in ipairs({ "autoAttack", "autoReload", "autoRetry", "aotrAuraEnabled", "autoExecute" }) do
        button(auto, name .. ": " .. tostring(config[name]), function(node)
            engine:stop(); config[name] = not config[name]; node.Text = name .. ": " .. tostring(config[name]); save()
        end)
    end
    button(auto, "Retry UI: " .. config.aotrRetryMethod, function(node)
        engine:stop()
        config.aotrRetryMethod = if config.aotrRetryMethod == "Navigation" then "Click" else "Navigation"
        node.Text = "Retry UI: " .. config.aotrRetryMethod; save()
    end)
    button(auto, "Combate: " .. config.aotrCombatMode, function(node)
        engine:stop()
        config.aotrCombatMode = if config.aotrCombatMode == "Tekkit" then "Measured" else "Tekkit"
        node.Text = "Combate: " .. config.aotrCombatMode; save()
    end)
    button(auto, "Alvo: " .. config.targetMode, function(node)
        config.targetMode = if config.targetMode == "Nearest" then "LowestHealth" else "Nearest"
        node.Text = "Alvo: " .. config.targetMode
        save()
    end)
    local function parameter(name, titleText, minimum, maximum, step)
        local display = text(auto, titleText .. ": " .. config[name])
        local wasRunning = false
        Slider.mount(scope, auto, config, name, minimum, maximum,
            function(value) display.Text = titleText .. ": " .. value end,
            function() wasRunning = engine.running; engine:stop() end,
            function(cancelled)
                if not cancelled then save(); if wasRunning then engine:start() end end
                wasRunning = false
            end, step)
    end
    parameter("aotrHoverHeight", "Altura acima das nucas (studs)", 20, 120)
    parameter("moveSpeed", "Velocidade horizontal (studs/s)", 50, 300)
    parameter("attackCooldown", "Intervalo de ataques (s)", 0.2, 3, 0.05)
    parameter("aotrAuraRadius", "Raio da aura (studs)", 40, 200)
    parameter("attackRange", "Raio sem aura (studs)", 40, 200)
    local dependency = text(pages["Diagnóstico"], "Clique em Verificar dependências", 260)
    dependency.TextXAlignment = Enum.TextXAlignment.Left; dependency.TextYAlignment = Enum.TextYAlignment.Top
    button(pages["Diagnóstico"], "Verificar dependências", function()
        local ok, result = pcall(function() return adapter:diagnose() end)
        dependency.Text = tostring(result)
        if not ok then log:write("error", "diagnostic", result) end
    end)
    local metrics = text(pages["Diagnóstico"], "", 130)
    local logs = text(pages["Logs"], "", 560)
    logs.Size = UDim2.new(1, -8, 0, 0); logs.AutomaticSize = Enum.AutomaticSize.Y
    logs.TextXAlignment = Enum.TextXAlignment.Left; logs.TextYAlignment = Enum.TextYAlignment.Top
    button(pages["Logs"], "Enviar registros ao F9", function()
        for _, row in ipairs(log:snapshot()) do print("[AOTR]", row.time, row.event, row.detail) end
    end)
    local close = button(frame, "PARAR E FECHAR", onDestroy)
    close.Position = UDim2.fromOffset(8, 512); close.Size = UDim2.new(1, -16, 0, 36)
    close.BackgroundColor3 = Color3.fromRGB(135, 42, 49)
    local elapsed = 0
    scope:add(game:GetService("RunService").Heartbeat:Connect(function(dt)
        elapsed += dt; if elapsed < 0.5 then return end; elapsed = 0; resize()
        status.Text = engine.state .. " | falhas=" .. engine.failures .. "\n" .. adapter.lastResult
        run.Text = engine.running and "PARAR" or "INICIAR"
        actions.Text = "Ações reais: " .. (config.aotrActionsEnabled and "ON" or "OFF")
        local values = adapter:metrics(); local parts = {}
        for key, value in pairs(values) do table.insert(parts, key .. "=" .. tostring(value)) end
        table.sort(parts); metrics.Text = table.concat(parts, "\n")
        local rows = log:snapshot(); local lines = {}
        for i = math.max(1, #rows - 19), #rows do
            table.insert(lines, string.format("%.1f %s: %s", rows[i].time, rows[i].event, rows[i].detail))
        end
        logs.Text = table.concat(lines, "\n")
    end))
    resize()
    return scope
end
return Panel

end
local function import(id)
    if cache[id] ~= nil then return cache[id] end
    assert(factories[id], "Missing module: " .. id)
    assert(not loading[id], "Cyclic module: " .. id)
    loading[id] = true
    local ok, value = pcall(factories[id], import)
    loading[id] = nil
    if not ok then error(value) end
    cache[id] = value
    return value
end
local environment = (getgenv and getgenv()) or _G
for _ = 1, 120 do
    local player = game:GetService("Players").LocalPlayer
    if game:IsLoaded() and player and player:FindFirstChildOfClass("PlayerGui") then break end
    task.wait(0.25)
end
local previous = environment.MahmutAOTRController
if type(previous) == "table" and type(previous.destroy) == "function" then pcall(function() previous:destroy() end) end
local defaults = import("core/Config")
local initial = table.clone(defaults)
for key, value in pairs({
    mode = "AOTR", aotrActionsEnabled = false, autoAttack = true,
    autoReload = false, autoRetry = true, moveSpeed = 150, autoExecute = true,
    attackRange = 175, attackCooldown = 1, maxFailures = 3, tick = 0.1,
    aotrHoverHeight = 75, aotrAscentSpeed = 150,
    aotrAuraEnabled = true, aotrAuraRadius = 175, aotrSteeringGain = 1,
    aotrCombatMode = "Tekkit",
}) do initial[key] = value end
local config = import("core/Preferences").load(initial)
if type(environment.MahmutAOTRResumeConfig) == "table" then
    for key, value in pairs(environment.MahmutAOTRResumeConfig) do
        if initial[key] ~= nil and typeof(initial[key]) == typeof(value) then config[key] = value end
    end
    environment.MahmutAOTRResumeConfig = nil
end
local controller = import("Main").start({ config = config })
environment.MahmutAOTRController = controller
controller.resumeConnection = import("core/Resume").attach(controller,
    "https://raw.githubusercontent.com/ppao52038-hub/Project-Titan/refs/heads/main/AOTR-Teste-v0.4.0.luau")
print("[AOTR] v0.4.0: Tekkit WIP movement/combat contracts; actions OFF until enabled.")
return controller
