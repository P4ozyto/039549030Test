-- Project Titan v0.6.2. Default library mode: in-memory Demo.
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
    assert(config.aotrCombatMode == "Source" or config.aotrCombatMode == "Measured", "Invalid combat mode")
    assert(config.aotrAttackMethod == "Input" or config.aotrAttackMethod == "InputRegister" or config.aotrAttackMethod == "Remote", "Invalid attack method")
    assert(config.aotrInputMethod == "Signal", "Only button-handler input is supported; screen clicking removed")
    assert(config.aotrInputHold > 0 and config.aotrInputHold <= 1 and config.aotrInputRegisterDelay >= 0 and config.aotrInputRegisterDelay <= 1, "Invalid input timing")
    assert(config.aotrHitSpeedMin >= 0 and config.aotrHitSpeedMax >= config.aotrHitSpeedMin and config.aotrHitSpeedMax < math.huge, "Invalid hit-speed range")
    assert(config.aotrHitExtraMin >= 0 and config.aotrHitExtraMax >= config.aotrHitExtraMin and config.aotrHitExtraMax < math.huge, "Invalid extra range")
    for _, key in ipairs({ "aotrHitSpeedMin", "aotrHitSpeedMax", "aotrHitExtraMin", "aotrHitExtraMax", "aotrAuraMaxTargets" }) do
        assert(config[key] == math.floor(config[key]), "Integer required: " .. key)
    end
    assert(config.aotrAltitudeP > 0 and config.aotrAltitudeP < math.huge and config.aotrAltitudeD > 0 and config.aotrAltitudeD < math.huge, "Invalid altitude gains")
    for _, key in ipairs({"aotrMaxTitans","aotrMaxLimbs","aotrEscapeMaxAttempts"}) do
        assert(config[key]==math.floor(config[key]) and config[key]>=1 and config[key]<=6,"Count must be 1–6: "..key)
    end
    for _, key in ipairs({"aotrBatchHitInterval","aotrReloadInterval","aotrEscapeDelay","aotrEscapeCooldown","aotrRetryHold","aotrRetryFocusDelay"}) do
        assert(config[key]>0 and config[key]<math.huge,"Invalid interval: "..key)
    end
    for _, key in ipairs({"aotrEquipmentDebounce","aotrRefillSpeed","aotrRefillArrival","aotrRefillTravelTimeout","aotrRefillConfirmTimeout","aotrRefillRetryDelay"}) do
        assert(config[key]>0 and config[key]<math.huge,"Invalid equipment interval/value: "..key)
    end
    assert(config.aotrGasLowRatio>=0 and config.aotrGasLowRatio<1,"Invalid gas threshold")
    assert(config.aotrBladeLowRatio>=0 and config.aotrBladeLowRatio<1,"Invalid blade threshold")
    assert(config.aotrRefillSetsThreshold>=0 and config.aotrRefillSetsThreshold==math.floor(config.aotrRefillSetsThreshold),"Invalid reserve threshold")
    assert(config.aotrRefillMaxAttempts>=1 and config.aotrRefillMaxAttempts<=6 and config.aotrRefillMaxAttempts==math.floor(config.aotrRefillMaxAttempts),"Invalid refill attempt count")
    assert(config.aotrNoDamageAttempts>=1 and config.aotrNoDamageAttempts<1000 and config.aotrNoDamageAttempts==math.floor(config.aotrNoDamageAttempts),"Invalid no-damage attempt count")
    assert(config.aotrNoDamageSeconds>0 and config.aotrNoDamageSeconds<math.huge and config.aotrNoDamageRefillCooldown>0 and config.aotrNoDamageRefillCooldown<math.huge,"Invalid damage observation interval")
    local adapter
    if config.mode == "Demo" then adapter = require("adapters/Demo").new()
    elseif config.mode == "AOTR" then adapter = require("adapters/AOTR").new(config)
    elseif config.mode == "OwnGame" then adapter = require("adapters/OwnGame").new(options.bindings)
    else error("Unknown mode") end
    local log = Logger.new(config.maxLogs)
    if config.mode == "AOTR" then adapter.log = log;adapter.grabEscape.log=log end
    local engine = Engine.new(adapter, config, log)
    local controller = { engine = engine, log = log, config = config, adapter = adapter }
    local connection, panel, destroyed
    local autoStartPending = config.autoExecute and (not config.persistentFarm or config.farmActive)
    local autoStartDeadline = os.clock() + 120
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
            if engine.manualStopRequested then autoStartPending=false
            elseif config.persistentFarm then autoStartPending=false;engine:start()
            elseif not config.autoExecute or now >= autoStartDeadline then
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
local InputAttack = require("automation/InputAttack")
local MultiTarget = require("automation/MultiTarget")
local GrabEscape = require("automation/GrabEscape")
local Equipment = require("automation/Equipment")
local DamageWatch = require("automation/DamageWatch")
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
    return setmetatable({ config = config, log = log, requiresOptIn = true, retryUI = Retry.new(player,config), inputAttack = InputAttack.new(player, config), grabEscape = GrabEscape.new(player,config,log),
        player = game:GetService("Players").LocalPlayer, epoch = 0,
        pending = nil, sent = 0, completed = 0, lastRetry = -math.huge,
        savedMovers = {}, lastError = nil, lastResult = "Not tested", targetCount = 0,
        flightTarget = nil, flightConnection = nil, flightPhase = "Idle", auraCursor = 0,
        nearbyTargets = 0, hoverAltitude = nil,
        altitudeMover = nil, savedCollisions = {}, healthSeen = {}, observedDamage = 0,
        lastReload = -math.huge, batchRound = 0, titanCount = 0,
        equipment=Equipment.new(config),refill=nil,equipmentSample=nil,
        damageWatch=DamageWatch.new(config),
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
    table.insert(rows, "M1Button=" .. tostring(self.inputAttack:button() ~= nil))
    table.insert(rows, "AttackMethod=" .. self.config.aotrAttackMethod)
    local equipment=self:readEquipment()
    table.insert(rows,"BladeSets="..tostring(equipment.sets).."/"..tostring(equipment.maxSets))
    table.insert(rows,"BladeVisible="..tostring(equipment.visible))
    table.insert(rows,"GasRatio="..tostring(equipment.gas))
    table.insert(rows,"BladeDurability="..tostring(equipment.durability))
    table.insert(rows,"RefillPoint="..tostring(self:refillStation()~=nil))
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
    local titanCount = 0
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
                titanCount += 1
                local points, seen = {}, {}
                local function add(point,priority)
                    if point and point:IsA("BasePart") and not seen[point] then
                        seen[point]=true
                        table.insert(points,{id=point,position=point.Position,health=humanoid.Health,titan=titan,part=point.Name,priority=priority})
                    end
                end
                add(hitbox,0)
                if self.config.aotrMultiLimbs then
                    -- Names observed in the supplied source; missing limbs are skipped.
                    for _, name in ipairs({"Nape","LeftLeg","RightLeg","LeftArm","RightArm","Eyes"}) do
                        add(child(titan,"Hitboxes","Hit",name),1)
                    end
                end
                for _, point in ipairs(points) do table.insert(targets,point) end
            end
        end
    end
    for humanoid in pairs(self.healthSeen) do if not humanoid.Parent then self.healthSeen[humanoid] = nil end end
    self.targetCount = #targets; self.titanCount=titanCount; return targets
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
            self.lastResult = if result==false then "Server returned false: "..name elseif type(result)=="string" then result else "Returned: "..name
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
    return self:attackBatch({{id=target}})
end
function AOTR:attackBatch(points)
    return self:queue("Attack", function()
        local _, root, _, _, post, get = self:resolve()
        assert(root,"Attack character changed")
        local radius = if self.config.aotrAuraEnabled then self.config.aotrAuraRadius else self.config.attackRange
        local valid = {}
        for _, point in ipairs(points) do
            local target=point.id
            local alive=point.titan and point.titan:FindFirstChildOfClass("Humanoid")
            if self:validTarget(target) and (root.Position-target.Position).Magnitude<=radius and (not alive or alive.Health>0) then table.insert(valid,point) end
        end
        if #valid==0 then return "BatchTargetsMoved" end
        if self.config.aotrAttackMethod ~= "Remote" then
            local result,dispatched = self.inputAttack:press()
            self.log:write("info", "manual-equivalent input", result)
            if not dispatched then return result end
            self.damageWatch:sent(os.clock())
            if self.config.aotrAttackMethod == "Input" then return result end
            task.wait(self.config.aotrInputRegisterDelay)
        end
        local bv = child(root, "BV")
        local speed = if bv and bv:IsA("BodyVelocity") then bv.Velocity.Magnitude else root.AssemblyLinearVelocity.Magnitude
        assert(get, "GET missing for hit registration")
        local sent=0
        if self.config.aotrAttackMethod=="Remote" then self.damageWatch:sent(os.clock()) end
        for index, point in ipairs(valid) do
            if index>1 then task.wait(self.config.aotrBatchHitInterval) end
            local target=point.id
            local _, currentRoot=self:resolve()
            if not currentRoot then break end
            local alive=point.titan and point.titan:FindFirstChildOfClass("Humanoid")
            if self:validTarget(target) and (currentRoot.Position-target.Position).Magnitude<=radius and (not alive or alive.Health>0) then
                local hitSpeed,extra=TekkitCombat.arguments(self.config,speed,math.random)
                if self.config.aotrAttackMethod=="Remote" then assert(post,"POST missing");post:FireServer("Attacks", "Slash", true) end
                local result=get:InvokeServer("Hitboxes","Register",target,hitSpeed,extra)
                sent+=1
                self.log:write("info","hit registration",target.Name .. " returned=" .. tostring(result))
            end
        end
        return "Registered attempts=" .. sent
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
    local radius = if self.config.aotrAuraEnabled then self.config.aotrAuraRadius else self.config.attackRange
    local candidates=if self.config.aotrAuraEnabled then targets else {target}
    local batch=MultiTarget.pick(candidates,position,radius,self.config.aotrMaxTitans,
        if self.config.aotrMultiLimbs then self.config.aotrMaxLimbs else 1,self.batchRound)
    self.nearbyTargets=#batch
    if #batch==0 then return lastAttack,self.flightPhase end
    self.batchRound+=1
    if self:attackBatch(batch) then
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
    local sample=self:readEquipment()
    local now=os.clock();self.equipment:observe(sample,now)
    return self.equipment:reloadNeeded(sample,now)
end
function AOTR:reload()
    return self:queue("Reload", function()
        local _, _, _, _, _, get = self:resolve(); assert(get, "GET missing")
        return get:InvokeServer("Blades", "Reload")
    end)
end
function AOTR:readEquipment()
    local character=self.player.Character
    local blade=child(character,"Rig_"..self.player.Name,"LeftHand","Blade_1")
    local top=child(self.player:FindFirstChildOfClass("PlayerGui"),"Interface","HUD","Main","Top")
    local setsNode=child(top,"Blade","Sets")
    local sets,maximum
    if setsNode and (setsNode:IsA("TextLabel") or setsNode:IsA("TextButton")) then sets,maximum=Equipment.pair(setsNode.Text) end
    local gauge=top
    if self.config.aotrGasHudPath=="" then gauge=nil
    else for name in self.config.aotrGasHudPath:gmatch("[^/]+") do gauge=child(gauge,name) end end
    local gas
    if gauge and (gauge:IsA("TextLabel") or gauge:IsA("TextButton")) then gas=Equipment.gauge(gauge.Text) end
    local condition=top
    if self.config.aotrBladeHudPath=="" then condition=nil
    else for name in self.config.aotrBladeHudPath:gmatch("[^/]+") do condition=child(condition,name) end end
    local durability
    if condition and (condition:IsA("TextLabel") or condition:IsA("TextButton")) then durability=Equipment.gauge(condition.Text) end
    local visible
    if blade and blade:IsA("BasePart") then visible=blade.Transparency<1 end
    return {character=character,sets=sets,maxSets=maximum,visible=visible,gas=gas,durability=durability,top=top}
end
function AOTR:gasCandidates()
    local top=self:readEquipment().top
    local result={}
    if not top then return result end
    for _, node in ipairs(top:GetDescendants()) do
        if #result>=100 then break end
        if (node:IsA("TextLabel") or node:IsA("TextButton")) and Equipment.gauge(node.Text)~=nil then
            local path, cursor={},node
            while cursor and cursor~=top do table.insert(path,1,cursor.Name);cursor=cursor.Parent end
            local value=table.concat(path,"/")
            if value~="Blade/Sets" then table.insert(result,{path=value,text=node.Text}) end
        end
    end
    table.sort(result,function(a,b)return a.path<b.path end)
    return result
end
function AOTR:refillStation()
    local reloads=child(workspace,"Unclimbable","Reloads")
    if not reloads then return nil end
    local point,distance
    local _,root=self:resolve()
    for _, node in ipairs(reloads:GetDescendants()) do
        if node.Name=="Refill" and node:IsA("BasePart") then
            local d=root and (node.Position-root.Position).Magnitude or 0
            if not distance or d<distance then point,distance=node,d end
        end
    end
    if not point then return nil end
    local prompt
    for _, node in ipairs(point.Parent:GetDescendants()) do
        if node:IsA("ProximityPrompt") and node.Enabled then prompt=node;break end
    end
    return point,prompt
end
function AOTR:cancelRefill()
    if self.refill and self.refill.tween then self.refill.tween:Cancel() end
    self.refill=nil
end
function AOTR:serviceEquipment(now)
    local sample=self:readEquipment();self.equipmentSample=sample
    local equipment=self.equipment;equipment:observe(sample,now)
    self.damageWatch:observe(self.observedDamage,now)
    if self.damageWatch:refillDue(now) then
        equipment.manual=true;self.damageWatch:markTrip(now)
        self.log:write("info","no damage recovery","One station trip; no blade discard. Lack of damage is not proof of depletion.")
    end
    local route=self.refill
    if route then
        local _,root=self:resolve()
        if not root or not route.station.Parent then self:cancelRefill();return "RefillDependencyChanged" end
        local setsConfirmed=not route.triggerSets or (sample.sets~=nil and sample.sets>self.config.aotrRefillSetsThreshold)
        local gasConfirmed=not route.triggerGas or (sample.gas~=nil and sample.gas>self.config.aotrGasLowRatio)
        local bladeConfirmed=not route.triggerBlade or (sample.durability~=nil and sample.durability>self.config.aotrBladeLowRatio)
        local increased=(sample.sets and route.baselineSets and sample.sets>route.baselineSets)
            or (sample.gas and route.baselineGas and sample.gas>route.baselineGas)
            or (sample.durability and route.baselineBlade and sample.durability>route.baselineBlade)
        if route.sent and setsConfirmed and gasConfirmed and bladeConfirmed and (not route.manual or increased) then
            self:cancelRefill();equipment.status="RefillConfirmed";return "RefillConfirmed"
        end
        if not route.sent and now>route.deadline then self:cancelRefill();equipment.status="RefillTravelTimeout";return "RefillTravelTimeout" end
        if (root.Position-route.destination).Magnitude>self.config.aotrRefillArrival then return "MovingToRefill" end
        if route.tween then route.tween:Cancel();route.tween=nil end
        if not route.sent and not self.pending then
            route.sent=true;route.sentAt=now
            self:queue("Refill",function()
                if route.prompt and route.prompt.Parent and route.prompt.Enabled then
                    if type(fireproximityprompt)=="function" then fireproximityprompt(route.prompt)
                    else
                        local input=game:GetService("VirtualInputManager")
                        local key=route.prompt.KeyboardKeyCode
                        self.refillRelease=function()input:SendKeyEvent(false,key,false,game)end
                        input:SendKeyEvent(true,key,false,game)
                        task.wait(math.max(route.prompt.HoldDuration+0.15,0.25))
                        self.refillRelease();self.refillRelease=nil
                    end
                    return "Station prompt requested"
                end
                local _,_,_,_,_,get=self:resolve();assert(get,"Refill GET missing")
                get:InvokeServer("Blades","Full_Reload","Left",route.station)
                return get:InvokeServer("Blades","Full_Reload","Right",route.station)
            end)
            return "RefillRequested"
        end
        if route.sentAt and now-route.sentAt>=self.config.aotrRefillConfirmTimeout then
            self:cancelRefill();equipment.status="RefillAwaitStatus";return "RefillAwaitStatus"
        end
        return "RefillAwaitStatus"
    end
    if equipment:canRefill(sample,now) then
        local station,prompt=self:refillStation()
        if not station then equipment.status="RefillPointMissing";return nil end
        self:cancelPending();self:haltMotion()
        local _,root=self:resolve();assert(root,"Refill character missing")
        local destination=station.Position+Vector3.new(0,2,0)
        if prompt and prompt.Parent:IsA("BasePart") then destination=prompt.Parent.Position+Vector3.new(0,2,0) end
        local duration=math.max(0.1,(root.Position-destination).Magnitude/self.config.aotrRefillSpeed)
        local tween=game:GetService("TweenService"):Create(root,TweenInfo.new(duration,Enum.EasingStyle.Linear,Enum.EasingDirection.In),{CFrame=CFrame.new(destination)})
        local manual=equipment.manual
        equipment:markRefill(now)
        self.refill={station=station,prompt=prompt,destination=destination,tween=tween,deadline=now+self.config.aotrRefillTravelTimeout,manual=manual,
            baselineSets=sample.sets,baselineGas=sample.gas,triggerSets=sample.sets~=nil and sample.sets<=self.config.aotrRefillSetsThreshold,
            triggerGas=sample.gas~=nil and sample.gas<=self.config.aotrGasLowRatio,
            baselineBlade=sample.durability,triggerBlade=sample.durability~=nil and sample.durability<=self.config.aotrBladeLowRatio}
        tween:Play();return "MovingToRefill"
    end
    if equipment:reloadNeeded(sample,now) and not self.pending then
        if self:reload() then equipment:markReload();return "ReloadRequestedAwaitStatus" end
    end
    if equipment:low(sample) then equipment.status="RefillCooldownOrLimit"
    elseif sample.sets==nil then equipment.status="EquipmentStatusUnknown"
    elseif equipment.reloadedHidden and sample.durability~=nil and sample.durability<=self.config.aotrBladeLowRatio then equipment.status="ReloadAwaitingEquipmentUpdate"
    elseif sample.durability==nil then equipment.status="BladeDurabilityUnknown"
    else equipment.status="EquipmentReady" end
    return nil
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
        m1=self.inputAttack.last,damageWatchAttempts=self.damageWatch.attempts,noDamageTripUsed=self.damageWatch.issued,
        combat = self.config.aotrCombatMode, healthDecrease = self.observedDamage,
        titans=self.titanCount,maxTitans=self.config.aotrMaxTitans,maxLimbs=self.config.aotrMaxLimbs,escapeAttempts=self.grabEscape.sent }
end
function AOTR:serviceEscape(now)
    if not self.config.autoEscapeGrab then self.grabEscape:stop();return false end
    local _,_,_,_,post=self:resolve()
    if self.grabEscape:step(now,post) then
        self:cancelPending();self:cancelRefill();self:haltMotion();return true
    end
    return false
end
function AOTR:cancelPending()
    if self.refillRelease then pcall(self.refillRelease);self.refillRelease=nil end
    self.inputAttack:cancel()
    self.retryUI:cancel()
    self.epoch += 1
    local job = self.pending; self.pending = nil
    if job then
        if job.thread then pcall(task.cancel, job.thread) end
        if job.timer then pcall(task.cancel, job.timer) end
    end
    self.lastError = nil
end
function AOTR:stop()
    self.grabEscape:stop();self:cancelPending();self:cancelRefill();self:haltMotion();self.damageWatch:pause()
    self.inputAttack:destroy()
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
factories["automation/DamageWatch"] = function(require)
local Watch={}
Watch.__index=Watch
function Watch.new(config)return setmetatable({config=config,total=0,attempts=0,since=nil,issued=false,lastTrip=-math.huge},Watch)end
function Watch:sent(now)self.since=self.since or now;self.attempts+=1 end
function Watch:observe(total,now)
    if total>self.total then self.since=now;self.attempts=0;self.issued=false end
    self.total=total
end
function Watch:refillDue(now)
    return self.config.aotrRefillOnNoDamage and self.since and not self.issued
        and self.attempts>=self.config.aotrNoDamageAttempts and now-self.since>=self.config.aotrNoDamageSeconds
        and now-self.lastTrip>=self.config.aotrNoDamageRefillCooldown
end
function Watch:markTrip(now)self.issued=true;self.lastTrip=now end
function Watch:pause()self.since=nil;self.attempts=0 end
return Watch

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
    self.manualStopRequested=false
    local valid, ok, reason = pcall(function() return self.adapter:validate(self.config) end)
    if not valid or not ok then
        self.log:write("error", "dependency", if valid then reason else ok)
        if self.config.persistentFarm then self.running=true;self.nextAt=0;self:setState("WaitingDependencies")
        else self:setState("Blocked") end
        return
    end
    self.failures = 0; self.nextAt = 0; self.targetId = nil
    self.running = true; self:setState("Starting")
end
function Engine:stop(reason)
    self.manualStopRequested=true
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
        if self.config.persistentFarm then
            local valid, reason = self.adapter:validate(self.config)
            if not valid then
                if self.lastDependency ~= reason then self.log:write("info","waiting dependency",reason);self.lastDependency=reason end
                self.nextAt=now+self.config.retryDelay;self:setState("WaitingDependencies");return
            end
            self.lastDependency=nil
        end
        if not self.adapter:ready() then self.adapter:stop(); self:setState("WaitingCharacter"); return end
        if self.adapter.serviceEscape and self.adapter:serviceEscape(now) then
            self:setState("EscapeGrab");return
        end
        if self.adapter.serviceEquipment then
            local equipmentState=self.adapter:serviceEquipment(now)
            if equipmentState then self:setState(equipmentState);return end
        end
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
    if not self.config.persistentFarm and self.failures >= self.config.maxFailures then self:stop("CircuitOpen"); return end
    self.targetId = nil; self.nextAt = now + self.config.retryDelay
    self:setState("Recovering")
end
return Engine

end
factories["automation/Equipment"] = function(require)
-- Status-driven decisions. Never treats an invisible blade alone as proof of depletion.
local Equipment = {}
Equipment.__index = Equipment
function Equipment.pair(text)
    if type(text)~="string" then return nil end
    local a,b=text:match("(%d+)%s*/%s*(%d+)")
    a,b=tonumber(a),tonumber(b)
    if a and b and b>0 and a>=0 and a<=b then return a,b end
end
function Equipment.gauge(text)
    local a,b=Equipment.pair(text)
    if a then return a/b end
    if type(text)=="string" then
        local percent=tonumber(text:match("(%d+%.?%d*)%s*%%"))
        if percent and percent>=0 and percent<=100 then return percent/100 end
    end
end
function Equipment.new(config)
    return setmetatable({config=config,character=nil,key=nil,stableAt=0,sawVisible=false,
        reloadedHidden=false,refillKey=nil,refillAttempts=0,lastRefill=-math.huge,
        manual=false,status="WaitingEquipment"},Equipment)
end
function Equipment:observe(sample,now)
    if sample.character~=self.character then
        self.character=sample.character;self.key=nil;self.sawVisible=false;self.reloadedHidden=false
        self.refillKey=nil;self.refillAttempts=0
    end
    local key=tostring(sample.sets)..":"..tostring(sample.visible)..":"..tostring(sample.durability)
    if key~=self.key then self.key=key;self.stableAt=now end
    if sample.visible==true then self.sawVisible=true end
    if sample.durability~=nil and sample.durability>self.config.aotrBladeLowRatio then self.reloadedHidden=false end
    local refillKey=tostring(sample.sets)..":"..tostring(sample.gas)
    if refillKey~=self.refillKey then self.refillKey=refillKey;self.refillAttempts=0 end
end
function Equipment:low(sample)
    return (sample.sets~=nil and sample.sets<=self.config.aotrRefillSetsThreshold)
        or (sample.gas~=nil and sample.gas<=self.config.aotrGasLowRatio)
        or (sample.durability~=nil and sample.durability<=self.config.aotrBladeLowRatio)
end
function Equipment:reloadNeeded(sample,now)
    return self.config.aotrAllowAutomaticBladeSwap and self.config.autoReload and sample.sets~=nil and sample.sets>0
        and sample.durability~=nil and sample.durability<=self.config.aotrBladeLowRatio
        and not self.reloadedHidden and now-self.stableAt>=self.config.aotrEquipmentDebounce
end
function Equipment:markReload()self.reloadedHidden=true;self.status="ReloadRequestedAwaitStatus"end
function Equipment:canRefill(sample,now)
    return (self.manual or (self.config.autoRefill and self:low(sample)))
        and now-self.lastRefill>=self.config.aotrRefillRetryDelay
        and (self.manual or self.refillAttempts<self.config.aotrRefillMaxAttempts)
end
function Equipment:markRefill(now)
    self.manual=false;self.lastRefill=now;self.refillAttempts+=1;self.status="MovingToRefill"
end
return Equipment

end
factories["automation/FarmPreset"] = function(require)
local Preset = {}
function Preset.enable(config)
    config.farmActive = true; config.persistentFarm = true
    config.aotrActionsEnabled = true; config.autoAttack = true
    config.autoReload = false;config.aotrAllowAutomaticBladeSwap=false
    config.autoRetry = true; config.autoExecute = true
    config.autoRefill = true
    config.autoEscapeGrab = true; config.aotrAuraEnabled = true; config.aotrMultiLimbs = true
    config.aotrNoCollision = true
    config.aotrAttackMethod = "InputRegister"
    config.aotrRefillOnNoDamage=true
    -- Counts, flight settings and UI input choices are deliberately preserved.
end
function Preset.disable(config) config.farmActive = false end
return Preset

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
factories["automation/GrabEscape"] = function(require)
-- Source indicator: PlayerGui.Interface.Buttons.ChildAdded.
-- This is an indicator used by the supplied source, not a verified server grab state.
local Escape = {}
Escape.__index = Escape
function Escape.new(player, config, log)
    return setmetatable({ player=player,config=config,log=log,folder=nil,connection=nil,
        indicator=nil,at=0,last=-math.huge,attempts=0,sent=0 },Escape)
end
local function child(root,name) return root and root:FindFirstChild(name) end
function Escape:bind(now)
    local gui=self.player:FindFirstChildOfClass("PlayerGui")
    local folder=child(child(gui,"Interface"),"Buttons")
    if folder==self.folder then return end
    if self.connection then self.connection:Disconnect();self.connection=nil end
    self.folder=folder;self.indicator=nil
    if not folder then return end
    local function observe(node)
        if node:IsA("GuiObject") and node.Visible then
            self.indicator=node;self.at=os.clock();self.attempts=0
            self.log:write("info","grab UI indicator",node.Name)
        end
    end
    self.connection=folder.ChildAdded:Connect(observe)
    for _, node in ipairs(folder:GetChildren()) do observe(node) end
end
function Escape:step(now,post)
    self:bind(now)
    local node=self.indicator
    if not node or not node.Parent or (node:IsA("GuiObject") and not node.Visible) then self.indicator=nil;return false end
    if self.attempts>=self.config.aotrEscapeMaxAttempts or now-self.at<self.config.aotrEscapeDelay
        or now-self.last<self.config.aotrEscapeCooldown then return false end
    assert(post and post:IsA("RemoteEvent"),"Escape POST unavailable")
    post:FireServer("Attacks","Slash_Escape")
    self.last=now;self.attempts+=1;self.sent+=1
    self.log:write("info","escape requested",self.attempts)
    return true
end
function Escape:stop()
    if self.connection then self.connection:Disconnect();self.connection=nil end
    self.folder=nil;self.indicator=nil
end
return Escape

end
factories["automation/InputAttack"] = function(require)
-- Dispatches observed M1 button handlers; never injects a screen click.
local Input = {}
Input.__index = Input
function Input.new(player, config)
    return setmetatable({ player = player, config = config, release = nil, cached = nil, last = "Not sent" }, Input)
end
local function visible(node)
    if not node or not node.Parent or not node:IsA("GuiObject") or node.AbsoluteSize.X <= 0 or node.AbsoluteSize.Y <= 0 then return false end
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node = node.Parent
    end
    return true
end
function Input:button()
    if visible(self.cached) then return self.cached end
    self.cached = nil
    local gui = self.player:FindFirstChildOfClass("PlayerGui")
    if not gui then return nil end
    for index, node in ipairs(gui:GetDescendants()) do
        if index > 3000 then break end
        local text = node.Name
        if node:IsA("TextLabel") or node:IsA("TextButton") then text = tostring(node.Text or node.Name) end
        if string.upper((string.gsub(text, "<[^>]*>", "")):gsub("%s+", "")) == "M1" and visible(node) then
            local candidate, cursor = node, node
            while cursor and cursor ~= gui do
                if cursor:IsA("GuiButton") then candidate = cursor; break end
                cursor = cursor.Parent
            end
            self.cached = candidate; return candidate
        end
    end
    return nil
end
function Input:cancel()
    if self.release then local release = self.release; self.release = nil; pcall(release) end
end
function Input:press()
    local function waiting(reason)self.last=reason;return reason,false end
    local button=self:button()
    if not button or not button:IsA("GuiButton") then return waiting("M1 button handler unavailable") end
    if not button.Active then return waiting("M1 button disabled") end
    if type(firesignal)~="function" or type(getconnections)~="function" then return waiting("Executor lacks M1 signal capabilities") end
    local function count(event)
        local ok,rows=pcall(getconnections,event)
        if not ok then return 0 end
        local total=0
        for _, row in ipairs(rows) do if row.Enabled~=false then total+=1 end end
        return total
    end
    if not self.watch or self.watched~=button then
        if self.watch then self.watch:Disconnect() end
        self.watched=button
        self.watch=button.Activated:Connect(function(input)
            if typeof(input)=="InputObject" then self.lastInput=input end
        end)
    end
    local center=button.AbsolutePosition+button.AbsoluteSize/2
    if count(button.MouseButton1Click)>0 then
        firesignal(button.MouseButton1Click);self.last="M1 click handler dispatched";return self.last,true
    end
    if count(button.MouseButton1Down)>0 then
        self.release=function()firesignal(button.MouseButton1Up,center.X,center.Y)end
        local ok,err=pcall(function()
            firesignal(button.MouseButton1Down,center.X,center.Y)
            task.wait(self.config.aotrInputHold or 0.08)
        end)
        self:cancel();if not ok then error(err) end
        self.last="M1 down/up handlers dispatched";return self.last,true
    end
    -- Activated requires an actual InputObject. Do not fabricate one.
    if self.lastInput and count(button.Activated)>1 then
        firesignal(button.Activated,self.lastInput,0);self.last="M1 Activated handler dispatched";return self.last,true
    end
    return waiting("M1 awaits one manual activation to capture real InputObject")
end
function Input:destroy()
    self:cancel()
    if self.watch then self.watch:Disconnect();self.watch=nil end
end
return Input

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
factories["automation/MultiTarget"] = function(require)
local Multi = {}
function Multi.pick(targets, origin, radius, maxTitans, maxPoints, cursor)
    local groups, order = {}, {}
    for _, target in ipairs(targets) do
        local distance = (target.position - origin).Magnitude
        if target.health > 0 and distance <= radius then
            local key = target.titan or target.id
            if not groups[key] then groups[key] = { points = {}, distance = distance }; table.insert(order, groups[key]) end
            local group = groups[key]
            group.distance = math.min(group.distance, distance)
            table.insert(group.points, target)
        end
    end
    table.sort(order, function(a, b) return a.distance < b.distance end)
    local picked = {}
    for i = 1, math.min(maxTitans, #order) do
        local points = order[i].points
        table.sort(points, function(a, b)
            local ap, bp = a.priority or 1, b.priority or 1
            if ap ~= bp then return ap < bp end
            return (a.part or "") < (b.part or "")
        end)
        local count = math.min(maxPoints, #points)
        table.insert(picked, points[1]) -- keep current weak point in each round
        for j = 1, count - 1 do
            local index = 2 + ((cursor + j - 1) % (#points - 1))
            table.insert(picked, points[index])
        end
    end
    return picked
end
return Multi

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
    aotrCombatMode = "Source", aotrHitSpeedMin = 215, aotrHitSpeedMax = 230,
    aotrHitExtraMin = 10, aotrHitExtraMax = 100,
    aotrAltitudeP = 100, aotrAltitudeD = 20, aotrNoCollision = true,
    aotrAttackMethod = "InputRegister", aotrInputMethod = "Signal", aotrInputHold = 0.08,
    aotrInputRegisterDelay = 0.1,
    persistentFarm = false, farmActive = false, autoEscapeGrab = false,
    aotrMultiLimbs = false, aotrMaxTitans = 2, aotrMaxLimbs = 2,
    aotrBatchHitInterval = 0.12, aotrReloadInterval = 3,
    aotrEscapeDelay = 0.15, aotrEscapeCooldown = 1.5, aotrEscapeMaxAttempts = 3,
    aotrRetryHold = 0.25, aotrRetryFocusDelay = 0.2,
    autoRefill = true, aotrEquipmentDebounce = 0.75, aotrRefillSetsThreshold = 0,
    aotrGasHudPath = "", aotrGasLowRatio = 0.15,
    aotrBladeHudPath = "", aotrBladeLowRatio = 0,
    aotrRefillSpeed = 225, aotrRefillArrival = 4, aotrRefillTravelTimeout = 30,
    aotrRefillConfirmTimeout = 6, aotrRefillRetryDelay = 10, aotrRefillMaxAttempts = 3,
    aotrAllowAutomaticBladeSwap = false, aotrRefillOnNoDamage = false,
    aotrNoDamageAttempts = 6, aotrNoDamageSeconds = 10, aotrNoDamageRefillCooldown = 45,
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
local fileName = "ProjectTitan-settings-v0.6.2.json"
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
function Resume.attach(controller, sourceUrl, localFile)
    local queue = queue_on_teleport
    if type(queue) ~= "function" and type(syn) == "table" then queue = syn.queue_on_teleport end
    local adapter, config, log = controller.adapter, controller.config, controller.log
    local supported = type(queue) == "function"
    if not sourceUrl then
        local canRead = type(readfile) == "function" and type(isfile) == "function" and localFile and isfile(localFile)
        if not canRead then supported = false end
    end
    adapter.resumeStatus = supported and "Teleport ready" or "Resume unavailable: queue or local script missing"
    log:write("info", "autoexecute", adapter.resumeStatus)
    local player = game:GetService("Players").LocalPlayer
    local queued = false
    return player.OnTeleport:Connect(function(state)
        if not config.autoExecute or queued or not supported then return end
        if state ~= Enum.TeleportState.Started and state ~= Enum.TeleportState.InProgress then return end
        local json = game:GetService("HttpService"):JSONEncode(config)
        assert(not string.find(json, "]===]", 1, true), "Unexpected settings delimiter")
        local source = if sourceUrl then "game:HttpGet(" .. string.format("%q", sourceUrl) .. ")" else "readfile(" .. string.format("%q", localFile) .. ")"
        local payload = "local e=(getgenv and getgenv()) or _G; e.MahmutAOTRResumeConfig=game:GetService('HttpService'):JSONDecode([===[" .. json .. "]===]); loadstring(" .. source .. ")()"
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
function Retry.new(player,config) return setmetatable({ player = player, config=config or {}, release = nil }, Retry) end
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
        local pressed=false
        self.release = function()if pressed then input:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)end end
        local ok, err = pcall(function()
            task.wait(self.config.aotrRetryFocusDelay or 0.2)
            assert(self:visible(button),"Retry button disappeared before click")
            center=button.AbsolutePosition+button.AbsoluteSize/2
            local gui=self.player:FindFirstChildOfClass("PlayerGui")
            if gui then
                for _, hit in ipairs(gui:GetGuiObjectsAtPosition(center.X,center.Y)) do
                    if hit==button or hit:IsDescendantOf(button) then break end
                    assert(not hit:IsA("GuiButton"),"Retry is covered by another button; minimize manually or use Navigation")
                end
            end
            pressed=true;input:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
            task.wait(self.config.aotrRetryHold or 0.25)
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
        task.wait(self.config.aotrRetryFocusDelay or 0.2)
        input:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(self.config.aotrRetryHold or 0.25)
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
local FarmPreset = require("automation/FarmPreset")
local Panel = {}
function Panel.mount(engine, adapter, config, log, onDestroy)
    local scope = Scope.new()
    local gui = scope:add(Instance.new("ScreenGui"))
    gui.Name = "ProjectTitanHub"; gui.ResetOnSpawn = false; gui.DisplayOrder = 1000
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
    local title = text(frame, "Project Titan • v0.6.2", 34)
    title.Size = UDim2.new(1, -42, 0, 34)
    title.Position = UDim2.fromOffset(0, 4)
    local minimizeButton = button(frame, "−", function() minimize(true) end)
    minimizeButton.Size = UDim2.fromOffset(34, 30); minimizeButton.Position = UDim2.new(1, -38, 0, 4)
    local status = text(frame, "Parado — ações reais OFF", 44); status.Position = UDim2.fromOffset(0, 40)
    local tabs = Instance.new("Frame"); tabs.BackgroundTransparency = 1
    tabs.Size = UDim2.new(1, -16, 0, 36); tabs.Position = UDim2.fromOffset(8, 88); tabs.Parent = frame
    local pages = {}
    for _, name in ipairs({ "Automação", "Equipamento", "Diagnóstico", "Logs" }) do
        local page = Instance.new("ScrollingFrame"); page.Name = name; page.BackgroundTransparency = 1
        page.Position = UDim2.fromOffset(8, 132); page.Size = UDim2.new(1, -16, 0, 366)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y; page.CanvasSize = UDim2.new()
        page.ScrollBarThickness = 6; page.Visible = name == "Automação"; page.Parent = frame
        local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.Parent = page
        pages[name] = page
    end
    for i, name in ipairs({ "Automação", "Equipamento", "Diagnóstico", "Logs" }) do
        local tab = button(tabs, name, function()
            for pageName, page in pairs(pages) do page.Visible = pageName == name end
        end)
        tab.Size = UDim2.new(1 / 4, -4, 1, 0); tab.Position = UDim2.new((i - 1) / 4, 0, 0, 0)
        tab.TextSize=16
    end
    local auto = pages["Automação"]
    text(auto, "Auto Farm ativa voo, M1, membros, recarga, Retry e Escape. Só desliga ao parar manualmente.", 46)
    local run = button(auto, "AUTO FARM: OFF", function()
        if config.farmActive then FarmPreset.disable(config);engine:stop()
        else engine:stop();FarmPreset.enable(config);engine:start() end
        save()
    end)
    button(auto,"PARAR TUDO",function()FarmPreset.disable(config);engine:stop();save()end)
    local function change(callback)
        local wasRunning=engine.running
        engine:stop();callback();save()
        if wasRunning then engine:start() end
    end
    local actions = button(auto, "Ações reais: OFF", function(node)
        engine:stop()
        config.aotrActionsEnabled = not config.aotrActionsEnabled
        if not config.aotrActionsEnabled then FarmPreset.disable(config) end
        save()
        node.Text = "Ações reais: " .. (config.aotrActionsEnabled and "ON" or "OFF")
    end)
    for _, name in ipairs({ "autoAttack", "autoRefill", "autoRetry", "autoEscapeGrab", "aotrMultiLimbs", "aotrAuraEnabled", "autoExecute" }) do
        button(auto, name .. ": " .. tostring(config[name]), function(node)
            change(function()config[name]=not config[name];node.Text=name..": "..tostring(config[name])end)
        end)
    end
    button(auto, "Retry UI: " .. config.aotrRetryMethod, function(node)
        change(function()
            config.aotrRetryMethod=if config.aotrRetryMethod=="Navigation" then "Click" else "Navigation"
            node.Text="Retry UI: "..config.aotrRetryMethod
        end)
    end)
    button(auto, "Combate: " .. config.aotrCombatMode, function(node)
        change(function()
            config.aotrCombatMode=if config.aotrCombatMode=="Source" then "Measured" else "Source"
            node.Text="Combate: "..config.aotrCombatMode
        end)
    end)
    button(auto, "Método de ataque: " .. config.aotrAttackMethod, function(node)
        change(function()
            local nextMode={Input="InputRegister",InputRegister="Remote",Remote="Input"}
            config.aotrAttackMethod=nextMode[config.aotrAttackMethod]
            node.Text="Método de ataque: "..config.aotrAttackMethod
        end)
    end)
    text(auto,"M1 usa callbacks do botão; sem clique na tela. Troca automática de lâminas desativada.",52)
    button(auto, "Alvo: " .. config.targetMode, function(node)
        config.targetMode = if config.targetMode == "Nearest" then "LowestHealth" else "Nearest"
        node.Text = "Alvo: " .. config.targetMode
        save()
    end)
    local disposed=false
    local function parameter(name, titleText, minimum, maximum, step)
        local display = text(auto, titleText .. ": " .. config[name])
        local wasRunning = false
        Slider.mount(scope, auto, config, name, minimum, maximum,
            function(value) display.Text = titleText .. ": " .. value end,
            function() wasRunning = engine.running; engine:stop() end,
            function(cancelled)
                if not disposed then save();if wasRunning then engine:start() end end
                wasRunning = false
            end, step)
    end
    parameter("aotrHoverHeight", "Altura acima das nucas (studs)", 20, 120)
    parameter("moveSpeed", "Velocidade horizontal (studs/s)", 50, 300)
    parameter("attackCooldown", "Intervalo de ataques (s)", 0.2, 3, 0.05)
    parameter("aotrAuraRadius", "Raio da aura (studs)", 40, 200)
    parameter("attackRange", "Raio sem aura (studs)", 40, 200)
    parameter("aotrMaxTitans","Titãs por rodada (padrão 2)",1,6)
    parameter("aotrMaxLimbs","Pontos/membros por titã (padrão 2)",1,6)
    local equipmentStatus=text(pages["Equipamento"],"Aguardando leitura do equipamento",160)
    local conditionIndex=0
    local conditionButton=button(pages["Equipamento"],"Lâminas: selecionar durabilidade do HUD",function(node)
        local candidates=adapter:gasCandidates()
        if #candidates==0 then node.Text="Sem indicador numérico de durabilidade no HUD";return end
        conditionIndex=conditionIndex%(#candidates+1)+1
        local selected=candidates[conditionIndex]
        config.aotrBladeHudPath=selected and selected.path or ""
        node.Text=selected and ("Lâminas: "..selected.path.." = "..selected.text) or "Lâminas: durabilidade desconhecida"
        save()
    end)
    conditionButton.Size=UDim2.new(1,0,0,64);conditionButton.TextWrapped=true;conditionButton.TextSize=16
    local gasIndex=0
    local gasButton=button(pages["Equipamento"],"Gás: selecionar indicador do HUD",function(node)
        local candidates=adapter:gasCandidates()
        if #candidates==0 then node.Text="Sem indicador numérico no HUD; gás desconhecido";return end
        gasIndex=gasIndex%(#candidates+1)+1
        local selected=candidates[gasIndex]
        config.aotrGasHudPath=selected and selected.path or ""
        node.Text=selected and ("Gás: "..selected.path.." = "..selected.text) or "Gás: não configurado"
        save()
    end)
    gasButton.Size=UDim2.new(1,0,0,64);gasButton.TextWrapped=true;gasButton.TextSize=16
    text(pages["Equipamento"],"Selecione o indicador real de gás. Sem seleção, refill automático usa as reservas de lâminas.",64)
    button(pages["Equipamento"],"Reabastecer agora (Auto Farm ON)",function()adapter.equipment.manual=true end)
    local dependency = text(pages["Diagnóstico"], "Clique em Verificar dependências", 260)
    dependency.TextXAlignment = Enum.TextXAlignment.Left; dependency.TextYAlignment = Enum.TextYAlignment.Top
    button(pages["Diagnóstico"], "Verificar dependências", function()
        local ok, result = pcall(function() return adapter:diagnose() end)
        dependency.Text = tostring(result)
        if not ok then log:write("error", "diagnostic", result) end
    end)
    local metrics = text(pages["Diagnóstico"], "", 130)
    metrics.Size=UDim2.new(1,-8,0,0);metrics.AutomaticSize=Enum.AutomaticSize.Y
    local logs = text(pages["Logs"], "", 560)
    logs.Size = UDim2.new(1, -8, 0, 0); logs.AutomaticSize = Enum.AutomaticSize.Y
    logs.TextXAlignment = Enum.TextXAlignment.Left; logs.TextYAlignment = Enum.TextYAlignment.Top
    button(pages["Logs"], "Enviar registros ao F9", function()
        for _, row in ipairs(log:snapshot()) do print("[AOTR]", row.time, row.event, row.detail) end
    end)
    local close = button(frame, "PARAR E FECHAR", function()FarmPreset.disable(config);save();onDestroy()end)
    close.Position = UDim2.fromOffset(8, 512); close.Size = UDim2.new(1, -16, 0, 36)
    close.BackgroundColor3 = Color3.fromRGB(135, 42, 49)
    local elapsed = 0
    scope:add(game:GetService("RunService").Heartbeat:Connect(function(dt)
        elapsed += dt; if elapsed < 0.5 then return end; elapsed = 0; resize()
        status.Text = engine.state .. " | falhas=" .. engine.failures .. "\n" .. adapter.lastResult
        run.Text=if config.farmActive and engine.running then "AUTO FARM: ON — clique para parar" else "AUTO FARM: OFF"
        for _, node in ipairs(auto:GetChildren()) do
            if node:IsA("TextButton") then
                local attackPrefix="Método de ataque:"
                if node.Text:sub(1,#attackPrefix)==attackPrefix then node.Text=attackPrefix.." "..config.aotrAttackMethod end
                if node.Text:sub(1,11)=="Entrada M1:" then node.Text="Entrada M1: "..config.aotrInputMethod end
                for _, key in ipairs({"autoAttack","autoReload","autoRetry","autoEscapeGrab","aotrMultiLimbs","aotrAuraEnabled","autoExecute"}) do
                    if node.Text:sub(1,#key+1)==key..":" then node.Text=key..": "..tostring(config[key]) end
                end
            end
        end
        actions.Text = "Ações reais: " .. (config.aotrActionsEnabled and "ON" or "OFF")
        local values = adapter:metrics(); local parts = {}
        local sample=adapter:readEquipment()
        equipmentStatus.Text="Estado: "..adapter.equipment.status.."\nReservas: "..tostring(sample.sets).."/"..tostring(sample.maxSets)
            .."\nDurabilidade: "..(sample.durability and string.format("%.0f%%",sample.durability*100) or "desconhecida")
            .."\nLâmina visível: "..tostring(sample.visible).."\nGás: "..(sample.gas and string.format("%.0f%%",sample.gas*100) or "desconhecido")
            .."\nTentativas no ponto: "..adapter.equipment.refillAttempts
        for key, value in pairs(values) do table.insert(parts, key .. "=" .. tostring(value)) end
        table.sort(parts); metrics.Text = table.concat(parts, "\n")
        local rows = log:snapshot(); local lines = {}
        for i = math.max(1, #rows - 19), #rows do
            table.insert(lines, string.format("%.1f %s: %s", rows[i].time, rows[i].event, rows[i].detail))
        end
        logs.Text = table.concat(lines, "\n")
    end))
    resize()
    scope:add(function()disposed=true end)
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
    attackRange = 175, attackCooldown = 0.6, maxFailures = 3, tick = 0.1,
    aotrHoverHeight = 75, aotrAscentSpeed = 150,
    aotrAuraEnabled = true, aotrAuraRadius = 175, aotrSteeringGain = 1,
    aotrCombatMode = "Source", aotrAttackMethod = "InputRegister", aotrInputMethod = "Signal",
    aotrRetryMethod = "Click",
}) do initial[key] = value end
if type(environment.MahmutAOTRResumeConfig) == "table" then
    for key, value in pairs(environment.MahmutAOTRResumeConfig) do
        if initial[key] ~= nil and typeof(initial[key]) == typeof(value) then initial[key] = value end
    end
    environment.MahmutAOTRResumeConfig = nil
end
local config = import("core/Preferences").load(initial)
local controller = import("Main").start({ config = config })
environment.MahmutAOTRController = controller
controller.resumeConnection = import("core/Resume").attach(controller, nil, "ProjectTitan-v0.6.2.luau")
print("[Project Titan] v0.6.2: button handlers, no automatic blade discard, manual-only minimization.")
return controller
