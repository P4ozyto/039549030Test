-- Project Titan v0.9.2: self-contained local runtime and teleport bootstrap.
local runtime=[========[
-- Project Titan v0.9.2. Default library mode: in-memory Demo.
local factories, cache, loading = {}, {}, {}
factories["Main"] = function(require)
local Config = require("core/Config")
local Logger = require("core/Logger")
local Engine = require("automation/Engine")
local Panel = require("ui/Panel")
local Main = {}
Main.Preferences=require("core/Preferences")
Main.Resume=require("core/Resume")
Main.defaultConfig=Config
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
    assert(config.aotrRetryMethod == "Auto" or config.aotrRetryMethod == "Signal" or config.aotrRetryMethod == "Navigation" or config.aotrRetryMethod == "Click", "Invalid retry UI method")
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
    for _,key in ipairs({"skillInterval","skillGap","skillHold","skillEscapeInterval"})do
        assert(config[key]>0 and config[key]<math.huge,"Invalid skill interval: "..key)
    end
    assert(config.skillEscapeAttempts>=1 and config.skillEscapeAttempts<=6 and config.skillEscapeAttempts==math.floor(config.skillEscapeAttempts),"Invalid skill escape attempt count")
    assert(config.aotrFocusMode=="Nape"or config.aotrFocusMode=="Indicated"or config.aotrFocusMode=="Nearest","Invalid focus mode")
    assert(config.aotrNapeHeight>0 and config.aotrNapeHeight<math.huge and config.aotrNapeAttackDistance>0 and config.aotrNapeAttackDistance<math.huge,"Invalid nape approach settings")
    for _,key in ipairs({"rapidEntrySpeed","rapidRetreatSpeed","rapidHeight","rapidStrikeDistance","rapidMaxExposure","rapidStrikeHold","rapidCooldown","rapidDamagePause","rapidRetreatHeight","rapidReadyTolerance","rapidGain"})do
        assert(config[key]>0 and config[key]<math.huge,"Invalid rapid parameter: "..key)
    end
    assert(config.rapidMinimumHealth>0 and config.rapidMinimumHealth<=1,"Invalid rapid health threshold")
    assert(config.m1Interval>0 and config.m1Interval<math.huge and config.farLimbDistance>0 and config.farLimbDistance<math.huge and config.farLimbInterval>0 and config.farLimbInterval<math.huge,"Invalid M1/far timing")
    assert(config.farLimbMaxPoints>=1 and config.farLimbMaxPoints<=4 and config.farLimbMaxPoints==math.floor(config.farLimbMaxPoints),"Invalid far limb cap")
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
            local ui = if config.mode == "AOTR" then require("ui/Dashboard") else Panel
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
local ContinuousM1=require("automation/ContinuousM1")
local FarTargets=require("automation/FarTargets")
local Rapid=require("automation/RapidApproach")
local Flight = require("automation/Flight")
local Retry = require("ui/Retry")
local TekkitCombat = require("automation/TekkitCombat")
local InputAttack = require("automation/InputAttack")
local MultiTarget = require("automation/MultiTarget")
local Skills=require("automation/Skills")
local GrabEscape = require("automation/GrabEscape")
local Equipment = require("automation/Equipment")
local DamageWatch = require("automation/DamageWatch")
local RaidPolicy=require("automation/RaidPolicy")
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
    local input=InputAttack.new(player,config)
    return setmetatable({ config = config, log = log, requiresOptIn = true, retryUI = Retry.new(player,config), inputAttack = input, m1Pulse=ContinuousM1.new(input,config), grabEscape = GrabEscape.new(player,config,log), skills=Skills.new(config),rapid=Rapid.new(config),
        player = game:GetService("Players").LocalPlayer, epoch = 0,
        pending = nil, sent = 0, completed = 0, lastRetry = -math.huge,
        savedMovers = {}, lastError = nil, lastResult = "Not tested", targetCount = 0,
        flightTarget = nil, flightConnection = nil, flightPhase = "Idle", auraCursor = 0,
        nearbyTargets = 0, hoverAltitude = nil,
        altitudeMover = nil, savedCollisions = {}, healthSeen = {}, observedDamage = 0,
        lastReload = -math.huge, batchRound = 0, titanCount = 0,
        equipment=Equipment.new(config),refill=nil,equipmentSample=nil,
        damageWatch=DamageWatch.new(config),
        retryRound=0,
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
    table.insert(rows,"EscapeButtons="..tostring(child(self.player:FindFirstChildOfClass("PlayerGui"),"Interface","Buttons")~=nil))
    table.insert(rows,"Resume="..tostring(self.resumeStatus))
    for _, row in ipairs(rows) do self.log:write("info", "AOTR dependency", row); print("[AOTR] " .. row) end
    return table.concat(rows, "\n")
end
function AOTR:validate(config)
    self.config = config
    if game.GameId ~= config.aotrUniverseId then return false, "Unexpected universe; AOTR actions blocked" end
    if self:rapidEnabled()and config.rapidStrikeDistance<=config.rapidHeight then return false,"Config: distância rápida deve superar a altura da passagem"end
    if self:rapidEnabled()and config.aotrFocusMode~="Nape"then return false,"Config: aproximação rápida exige foco Nape"end
    local radius = if config.aotrAuraEnabled then config.aotrAuraRadius else config.attackRange
    if self:closeApproach()and config.aotrNapeAttackDistance<=config.aotrNapeHeight then return false,"Config: distância para atacar ("..config.aotrNapeAttackDistance..") deve superar a altura de aproximação ("..config.aotrNapeHeight.."). Aumente a distância ou desligue a aproximação baixa"end
    if not config.aotrAttackFromHeight and radius <= (self:closeApproach()and config.aotrNapeHeight or config.aotrHoverHeight)then return false, "Config: raio de ataque/aura deve superar a altura ativa. Aumente o raio sem reduzir sua altura de voo" end
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
                if self.config.aotrFocusMode=="Nape"then add(child(titan,"Hitboxes","Hit","Nape"),0)end
                if self.config.aotrMultiLimbs or self.config.aotrAttackExtras or self.config.aotrFarLimbAttack then
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
function AOTR:attackBatch(points,context)
    return self:queue("Attack", function()
        local _, root, _, _, post, get = self:resolve()
        assert(root,"Attack character changed")
        local radius = context=="FarLimbs"and self:baseCombatRadius()or self:combatRadius()
        if context=="FarLimbs"and not self.config.aotrFarLimbAttack then return "Far limbs disabled"end
        local valid = {}
        for _, point in ipairs(points) do
            local target=point.id
            local alive=point.titan and point.titan:FindFirstChildOfClass("Humanoid")
            if self:validTarget(target) and (root.Position-target.Position).Magnitude<=radius and (not alive or alive.Health>0) then table.insert(valid,point) end
        end
        if #valid==0 then return "BatchTargetsMoved" end
        if self.config.aotrAttackMethod ~= "Remote" then
            local fresh=self.config.continuousM1 and self.inputAttack.lastDispatch and os.clock()-self.inputAttack.lastDispatch<=math.max(self.config.m1Interval,0.1)*2
            local result,dispatched
            if fresh then result,dispatched="M1 contínuo recente reutilizado",true else result,dispatched=self.inputAttack:press()end
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
                if self:rapidEnabled()and context~="FarLimbs"then self.rapid.registrations+=1;self.rapid.registeredThisPass=true;self.rapid.reason="Registro retornou; dano ainda não confirmado"end
                self.log:write("info","hit registration",target.Name .. " returned=" .. tostring(result))
            end
        end
        return "Registered attempts=" .. sent
    end)
end
function AOTR:baseCombatRadius()
    return self.config.aotrAuraEnabled and self.config.aotrAuraRadius or self.config.attackRange
end
function AOTR:serviceM1(now)
    if self:rapidEnabled()and self.rapid.state=="Strike"and not self.rapid.sent then return end
    local allowed=self.config.autoAttack and self.config.aotrActionsEnabled and not self.refill and not self.refillRequested and self:validTarget(self.flightTarget)
    if allowed then
        local owner=self.flightTarget.Parent and self.flightTarget.Parent.Parent and self.flightTarget.Parent.Parent.Parent
        local health=owner and owner:FindFirstChildOfClass("Humanoid")
        allowed=health~=nil and health.Health>0
    end
    if self.grabEscape:isActive()or(self:rapidEnabled()and self.rapid.state=="Retreat")then allowed=false end
    self.m1Pulse:step(now,allowed)
end
function AOTR:serviceFar(targets,now)
    if not self.config.autoAttack or self.refillRequested or not self.config.aotrFarLimbAttack or self.pending or now-(self.lastFarAttack or -math.huge)<self.config.farLimbInterval then return false end
    if self:rapidEnabled()and self.rapid:active()then return false end
    if self.grabEscape:isActive()then return false end
    local batch=FarTargets.pick(targets,self:position(),self:baseCombatRadius(),self.config.farLimbDistance,
        math.min(self.config.aotrMaxTitans,self.config.raidMode and self.config.raidTitans or 6),math.min(self.config.farLimbMaxPoints,self.config.raidMode and self.config.raidPoints or 4),self.batchRound)
    if #batch==0 then return false end
    if self:attackBatch(batch,"FarLimbs")then self.lastFarAttack=now;self.batchRound+=1;return true end
    return false
end
function AOTR:managesProgress()return self:rapidEnabled()end
function AOTR:idle()
    return self:rapidEnabled()and self.flightConnection~=nil and self.rapidDestination~=nil
end
function AOTR:rapidEnabled()return self.config.rapidApproach and not self.config.raidMode end
function AOTR:tickRapid(now)
    local _,root,humanoid=self:resolve()
    if not root or not humanoid then return nil,false end
    local target=self.flightTarget
    local valid=self:validTarget(target)
    if valid then
        local owner=target.Parent and target.Parent.Parent and target.Parent.Parent.Parent
        local health=owner and owner:FindFirstChildOfClass("Humanoid")
        valid=health~=nil and health.Health>0 and target.Name=="Nape"
    end
    local maxHealth=humanoid.MaxHealth
    local ratio=type(maxHealth)=="number"and maxHealth>0 and humanoid.Health/maxHealth or nil
    local safeY=math.max(self.rapidSafeY or root.Position.Y,self.rapid.safeY or -math.huge)
    local sample={position=root.Position,health=humanoid.Health,healthRatio=ratio,
        target=target,targetPosition=valid and target.Position or root.Position,valid=valid,
        grabbed=self.grabEscape:isActive(),pending=self.pending~=nil,
        safeY=safeY,highDestination=Vector3.new(valid and target.Position.X or root.Position.X,safeY,valid and target.Position.Z or root.Position.Z),
        canEnter=self.config.autoAttack and not self.refillRequested and self.config.aotrFocusMode=="Nape"}
    local previous=self.rapid.state
    local destination,allow=self.rapid:step(now,sample)
    if self.rapid.state=="Retreat"and previous~="Retreat"then
        self:cancelPending();self.skills:stop()
        self.log:write("info","rapid retreat",self.rapid.reason)
    end
    self.rapidDestination=destination;self.rapidAllowAttack=allow
    return destination,allow
end
function AOTR:serviceRapid(now)
    if not self:rapidEnabled()or not self.rapid:active()then return nil end
    self:tickRapid(now)
    if self.rapidAllowAttack and not self.pending and not self.inputAttack.busy and not self.m1Pulse.thread and self:validTarget(self.flightTarget)then
        if self:attackBatch({{id=self.flightTarget,titan=self.flightTarget.Parent.Parent.Parent,part="Nape"}})then self.rapid:markAttack(now)end
    end
    return "Rapid: "..self.rapid.state.." / "..self.rapid.reason
end
function AOTR:closeApproach()
    return not self.config.aotrAttackFromHeight and self.config.aotrNapeApproach and not self.config.raidMode
end
function AOTR:combatRadius()
    local radius=if self.config.aotrAuraEnabled then self.config.aotrAuraRadius else self.config.attackRange
    if self:rapidEnabled()then return math.min(radius,self.config.rapidStrikeDistance)end
    return self:closeApproach()and math.min(radius,self.config.aotrNapeAttackDistance)or radius
end
function AOTR:flightDestination(target)
    if self:rapidEnabled()and self.rapidDestination then return self.rapidDestination end
    if self.recoveryUntil and os.clock()<self.recoveryUntil and self.recoveryPosition then return self.recoveryPosition end
    local height=self:closeApproach()and self.config.aotrNapeHeight or self.config.aotrHoverHeight
    local altitude = math.max(target.Position.Y + height, self.hoverAltitude or -math.huge)
    return Vector3.new(target.Position.X, altitude, target.Position.Z)
end
function AOTR:progressDistance(target)
    return (self:flightDestination(target.id) - self:position()).Magnitude
end
function AOTR:updateFlight()
    local target = self.flightTarget
    if not self:ready()then self:haltMotion();return end
    if self:rapidEnabled()then self:tickRapid(os.clock())end
    if (not target or not self:validTarget(target))and not(self:rapidEnabled()and self.rapidDestination)then self:haltMotion();return end
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
    if self:rapidEnabled()and self.rapid:active()then
        local delta=destination-root.Position
        if self.rapid.state=="Retreat"then
            -- Ascend vertically first; avoid lateral travel at exposed height.
            velocity=Vector3.new(0,math.clamp(delta.Y*self.config.rapidGain,0,self.config.rapidRetreatSpeed),0)
        else
            velocity=delta.Magnitude>0 and delta.Unit*math.min(self.config.rapidEntrySpeed,delta.Magnitude*self.config.rapidGain)or Vector3.zero
        end
        phase="Rapid"..self.rapid.state
    end
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
        local direction = (target and self:validTarget(target)and target.Position or destination) - root.Position
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
    local height,interval,maxTitans,maxPoints=RaidPolicy.values(self.config)
    if self:rapidEnabled()then
        self.rapidSafeY=highest+math.max(height,self.config.rapidRetreatHeight)
        self.hoverAltitude=self.rapidSafeY
        self:move(target.id,self.config.tick,self.config.moveSpeed)
        self:serviceRapid(now)
        self:serviceFar(targets,now)
        return lastAttack,"Rapid: "..self.rapid.state.." / "..self.rapid.reason
    end
    self.hoverAltitude = self:closeApproach()and (target.position.Y+self.config.aotrNapeHeight)or (highest+height)
    self:move(target.id, self.config.tick, self.config.moveSpeed)
    if not self.config.autoAttack then return lastAttack, self.flightPhase .. ": attack OFF" end
    if self:serviceFar(targets,now)then return now,"FarLimbs: opção de membros distantes"end
    if self.pending or now - lastAttack < interval then return lastAttack, self.flightPhase end
    local radius = self:combatRadius()
    local candidates=if self.config.aotrAuraEnabled then targets else {target}
    local batch=MultiTarget.pick(candidates,position,radius,maxTitans,
        if self.config.aotrAttackExtras then maxPoints else 1,self.batchRound,self.config.aotrFocusMode)
    if #batch>0 then self.skills:request(now,false)end
    self.nearbyTargets=#batch
    if #batch==0 then return lastAttack,"WaitingAttackRange: alvo fora do raio configurado" end
    self.batchRound+=1
    if self:attackBatch(batch) then
        if self.flightPhase == "Ascending" then return now, "AscendingAttack" end
        return now, if self.config.aotrAuraEnabled then "HoverAura" else "HoverAttack"
    end
    return lastAttack, self.flightPhase
end
function AOTR:haltMotion()
    if self.flightConnection then self.flightConnection:Disconnect(); self.flightConnection = nil end
    self.flightTarget = nil; self.flightPhase = "Idle"; self.hoverAltitude = nil;self.recoveryPosition=nil;self.recoveryUntil=nil;self.rapidDestination=nil;self.rapidSafeY=nil
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
    local needRefill=equipment.manual or (self.config.autoRefill and equipment:low(sample))
    self.refillRequested=needRefill
    local route=self.refill
    if not route and needRefill and self:rapidEnabled()and self.rapid:active()and self.flightConnection then
        local _,root=self:resolve()
        if root then
            self.rapid:abort(now,{position=root.Position,safeY=self.rapidSafeY},"Retirada para reabastecer")
            self:cancelPending();self.skills:stop();self:tickRapid(now)
            equipment.status="RapidRetreatForRefill"
            return "RapidRetreatForRefill"
        end
    end
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
        if not station then equipment.status="RefillPointMissing";return "RefillPointMissing"end
        self:cancelPending();self.skills:stop();self:haltMotion()
        local previous=self.rapid
        self.rapid=Rapid.new(self.config)
        self.rapid.attempts=previous.attempts;self.rapid.registrations=previous.registrations;self.rapid.canceled=previous.canceled
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
    if needRefill then equipment.status="RefillCooldownOrLimit";return "RefillCooldownOrLimit"
    elseif sample.sets==nil then equipment.status="EquipmentStatusUnknown"
    elseif equipment.reloadedHidden and sample.durability~=nil and sample.durability<=self.config.aotrBladeLowRatio then equipment.status="ReloadAwaitingEquipmentUpdate"
    elseif sample.durability==nil then equipment.status="BladeDurabilityUnknown"
    else equipment.status="EquipmentReady" end
    return nil
end
function AOTR:mission()
    local button,title,root=self.retryUI:locate()
    if self.retryUI:visible(root or title or button) then return "Complete" end
    -- No targets alone is not proof of mission completion.
    return "Active"
end
function AOTR:retry()
    local button,title,root=self.retryUI:locate()
    if not self.retryUI:visible(root or title or button) then return "RetryWaitingUI" end
    if title and (title:IsA("TextLabel") or title:IsA("TextButton")) and title.Text:upper():find("STARTING",1,true) then return "RetryStarting" end
    if title and (title:IsA("TextLabel") or title:IsA("TextButton")) then
        local current,total=title.Text:match("%((%d+)%s*/%s*(%d+)%)")
        if tonumber(total) and tonumber(total)>0 and tonumber(current)>=tonumber(total) then return "RetryWaitingTeleport" end
    end
    if os.clock() - self.lastRetry < self.config.aotrRetryInterval then return "RetryWaiting" end
    if self.resumeManager then self.resumeManager:arm() end
    if self:queue("RetryUI", function()
        self.retryRound+=1
        if self.config.aotrRetryMethod=="Auto" then
            if self.retryRound%2==1 then
                local result,sent=self.retryUI:activate("Signal")
                if sent then self.log:write("info","retry",result);return result end
            end
            local _,_,_,_,_,get=self:resolve();assert(get,"Retry GET unavailable")
            local result=get:InvokeServer("Functions","Retry","Add")
            self.log:write("info","retry source request",tostring(result))
            return "Retry vote requested"
        end
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
        attackFromHeight=self.config.aotrAttackFromHeight, continuousM1=self.m1Pulse.status, continuousM1Count=self.m1Pulse.count, farLimbAttack=self.config.aotrFarLimbAttack, rapidQueued=self.rapid.attempts, rapidRegistered=self.rapid.registrations, rapidCanceled=self.rapid.canceled, rapidState=self.rapid.state, rapidReason=self.rapid.reason, approachActive=self:closeApproach(), combatDistance=self:combatRadius(), focusMode=self.config.aotrFocusMode, extraPointsEnabled=self.config.aotrAttackExtras, skills=self.skills.status, skillEscapeAttempts=self.skills.escapeAttempts, flight = self.flightPhase, auraTargets = self.nearbyTargets, height = self.config.aotrHoverHeight,
        resume = self.resumeStatus or "Not attached", retry = self.config.aotrRetryMethod,
        m1=self.inputAttack.last,damageWatchAttempts=self.damageWatch.attempts,noDamageTripUsed=self.damageWatch.issued,grab=self.grabEscape.status,
        combat = self.config.aotrCombatMode, healthDecrease = self.observedDamage,
        titans=self.titanCount,maxTitans=self.config.aotrMaxTitans,maxLimbs=self.config.aotrMaxLimbs,escapeAttempts=self.grabEscape.sent }
end
function AOTR:serviceEscape(now)
    if not self.config.autoEscapeGrab then
        self.grabEscape:stop();self.skills.escapeAttempts=0
        if self.skills.mode=="Grab"then self.skills:stop()end
        return false
    end
    local _,_,_,_,post=self:resolve()
    local escapeOK,escapeResult=pcall(function()return self.grabEscape:step(now,post)end)
    local attempted=escapeOK and escapeResult
    if not escapeOK and now-(self.lastEscapeErrorAt or -math.huge)>3 then
        self.lastEscapeErrorAt=now
        self.log:write("error","escape source attempt",escapeResult)
    end
    local active=self.grabEscape:isActive()
    if active then
        local skillAttempt=now-self.grabEscape.at>=self.config.aotrEscapeDelay and self.skills:request(now,true)
        if attempted or skillAttempt then
            self:cancelPending();self:cancelRefill()
            if self:rapidEnabled()and self.flightConnection then
                local _,root=self:resolve()
                self.rapid:abort(now,{position=root.Position,safeY=self.rapidSafeY},"Indicador de grab")
                self:tickRapid(now)
            else self:haltMotion()end
            return true
        end
        if self.skills.busy and self.skills.mode=="Grab"then return true end
    else
        self.skills.escapeAttempts=0
        if self.skills.mode=="Grab"and self.skills.busy then self.skills:stop()end
    end
    return attempted
end
function AOTR:cancelPending()
    self.m1Pulse:stop()
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
function AOTR:recover()
    if self:rapidEnabled()and self.flightConnection then
        local _,root=self:resolve()
        if root and self:ready()then
            self:cancelPending();self.skills:stop()
            self.rapid:abort(os.clock(),{position=root.Position,safeY=self.rapidSafeY},"Erro de combate")
            self:tickRapid(os.clock());return true
        end
    end
    if not self.flightConnection or not self.flightTarget or not self:ready()or not self:validTarget(self.flightTarget)then return false end
    self:cancelPending();self.skills:stop()
    self.recoveryPosition=self:position();self.recoveryUntil=os.clock()+self.config.retryDelay
    self.log:write("info","recovery","Holding flight during combat backoff")
    return true
end
function AOTR:stop()
    self.refillRequested=false
    self.rapid=Rapid.new(self.config)
    self.skills:stop();self.skills.escapeAttempts=0
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
factories["automation/ContinuousM1"] = function(require)
local Pulse={};Pulse.__index=Pulse
function Pulse.new(input,config)return setmetatable({input=input,config=config,nextAt=0,count=0,epoch=0,status="M1 contínuo OFF"},Pulse)end
function Pulse:stop()
    self.epoch+=1
    if self.thread then pcall(task.cancel,self.thread);self.thread=nil;self.input:cancel()end
end
function Pulse:step(now,allowed)
    if not self.config.continuousM1 or not allowed then self:stop();self.status="M1 contínuo pausado";return false end
    if self.thread or self.input.busy or now<self.nextAt then return false end
    self.nextAt=now+self.config.m1Interval
    local epoch=self.epoch
    self.thread=task.defer(function()
        local ok,result,sent=pcall(function()return self.input:press()end)
        if self.epoch~=epoch then return end
        self.thread=nil
        if ok and sent then self.count+=1;self.status="M1 solicitado #"..self.count
        else self.status=ok and tostring(result)or "Falha no callback M1"end
    end)
    return true
end
return Pulse

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
local function waitingState(reason)
    return type(reason)=="string"and string.sub(reason,1,7)=="Config:"and "WaitingConfiguration"or "WaitingDependencies"
end
function Engine:start()
    if self.running then return end
    self.manualStopRequested=false
    local valid, ok, reason = pcall(function() return self.adapter:validate(self.config) end)
    if not valid or not ok then
        self.lastDependency=tostring(if valid then reason else ok)
        self.log:write("error", "dependency", self.lastDependency)
        if self.config.persistentFarm then self.running=true;self.nextAt=0;self:setState(waitingState(self.lastDependency))
        else self:setState("Blocked") end
        return
    end
    self.lastDependency=nil
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
    self.nextAt = now + math.min(self.config.tick,self.config.attackCooldown)
    local ok, err = xpcall(function()
        if self.adapter.checkErrors then self.adapter:checkErrors() end
        if self.adapter.requiresOptIn and not self.config.aotrActionsEnabled then
            if not self.adapter:ready() then self.adapter:stop(); self:setState("WaitingCharacter"); return end
            local targets = self.adapter:targets()
            local target = Targeting.select(targets, self.adapter:position(), self.config.targetMode,if self.config.mode=="AOTR"then self.config.aotrFocusMode else nil)
            self:setState(if target then "Preview: target found" else "Preview: no targets")
            return
        end
        local missionState = Missions.step(self.adapter, self.config)
        if missionState then
            if not(self.adapter.idle and self.adapter:idle())and self.adapter.haltMotion then self.adapter:haltMotion() end
            self:setState(missionState); return
        end
        if self.config.persistentFarm then
            local valid, reason = self.adapter:validate(self.config)
            if not valid then
                if self.lastDependency ~= reason then self.log:write("info","waiting dependency",reason);self.lastDependency=reason end
                self.nextAt=now+self.config.retryDelay;self:setState(waitingState(self.lastDependency));return
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
        if self.adapter.serviceM1 then self.adapter:serviceM1(now)end
        if self.adapter.serviceRapid then
            local rapidState=self.adapter:serviceRapid(now)
            if rapidState then self.progressAt=now;self:setState(rapidState);return end
        end
        local targets = self.adapter:targets()
        local target = Targeting.select(targets, self.adapter:position(), self.config.targetMode,if self.config.mode=="AOTR"then self.config.aotrFocusMode else nil)
        if not target then
            if not(self.adapter.idle and self.adapter:idle())and self.adapter.haltMotion then self.adapter:haltMotion() end
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
        if self.adapter.managesProgress and self.adapter:managesProgress()then self.progressAt=now end
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
    local held=false
    if self.config.persistentFarm and self.adapter.recover then
        local recovered,result=pcall(function()return self.adapter:recover()end)
        held=recovered and result==true
    end
    if not held then pcall(function() self.adapter:stop() end)end
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
factories["automation/FarTargets"] = function(require)
local Multi=require("automation/MultiTarget")
local Far={}
function Far.pick(targets,origin,radius,threshold,maxTitans,maxPoints,cursor)
    local distances={}
    for _,target in ipairs(targets)do
        if target.part=="Nape"and target.health>0 then distances[target.titan or target.id]=(target.position-origin).Magnitude end
    end
    local limbs={}
    local names={LeftArm=true,RightArm=true,LeftLeg=true,RightLeg=true}
    for _,target in ipairs(targets)do
        local distance=distances[target.titan or target.id]
        if distance and distance>threshold and names[target.part]then table.insert(limbs,target)end
    end
    return Multi.pick(limbs,origin,radius,maxTitans,maxPoints,cursor,"Nearest")
end
return Far

end
factories["automation/FarmModes"] = function(require)
local Preset=require("automation/FarmPreset")
local Modes={}
function Modes.start(engine,config,rapid)
    engine:stop()
    config.rapidApproach=rapid
    if rapid then config.raidMode=false else config.aotrAttackFromHeight=true;config.aotrNapeApproach=false end
    Preset.enable(config);engine:start()
end
return Modes

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
        indicator=nil,at=0,last=-math.huge,attempts=0,sent=0,states={},status="WaitingIndicator" },Escape)
end
local function child(root,name) return root and root:FindFirstChild(name) end
function Escape:bind(now)
    local gui=self.player:FindFirstChildOfClass("PlayerGui")
    local folder=child(child(gui,"Interface"),"Buttons")
    if folder==self.folder then return end
    if self.connection then self.connection:Disconnect();self.connection=nil end
    self.folder=folder;self.indicator=nil;self.states={}
    if not folder then return end
    self.connection=folder.DescendantAdded:Connect(function(node)self:observe(node,os.clock())end)
    for _, node in ipairs(folder:GetDescendants()) do self:observe(node,now) end
end
local function visible(node)
    if not node or not node.Parent or not node:IsA("GuiObject") then return false end
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node=node.Parent
    end
    return true
end
function Escape:observe(node,now)
    local current=visible(node)
    if current and self.states[node]~=true then
        self.indicator=node;self.at=now;self.attempts=0;self.status="Indicator: "..node.Name
        self.log:write("info","grab visible transition",node.Name)
    end
    self.states[node]=current
end
function Escape:step(now,post)
    self:bind(now)
    if not self.folder then self.status="Buttons root missing";return false end
    if self.folder then
        for index,node in ipairs(self.folder:GetDescendants()) do if index>256 then break end;self:observe(node,now) end
    end
    for node in pairs(self.states) do if not node.Parent then self.states[node]=nil end end
    local node=self.indicator
    if not visible(node) or not self.folder or not node:IsDescendantOf(self.folder) then self.indicator=nil;self.status="WaitingIndicator";return false end
    if self.attempts>=self.config.aotrEscapeMaxAttempts or now-self.at<self.config.aotrEscapeDelay
        or now-self.last<self.config.aotrEscapeCooldown then return false end
    local handled=false
    if self.attempts%2==0 and type(firesignal)=="function" and type(getconnections)=="function" then
        local control=node
        while control and control~=self.folder do
            if control:IsA("GuiButton") then
                local ok,rows=pcall(getconnections,control.MouseButton1Click)
                if ok and #rows>0 then firesignal(control.MouseButton1Click);handled=true;self.status="Escape UI callback" end
                if not handled and self.lastInput then
                    local activated,callbacks=pcall(getconnections,control.Activated)
                    if activated and #callbacks>0 then firesignal(control.Activated,self.lastInput,0);handled=true;self.status="Escape Activated callback" end
                end
                break
            end
            control=control.Parent
        end
    end
    if not handled then
        assert(post and post:IsA("RemoteEvent"),"Escape POST unavailable")
        post:FireServer("Attacks","Slash_Escape");self.status="Slash_Escape requested"
    end
    self.last=now;self.attempts+=1;self.sent+=1
    self.log:write("info","escape requested",self.attempts)
    return true
end
function Escape:isActive()
    return self.folder~=nil and visible(self.indicator) and self.indicator:IsDescendantOf(self.folder)
end
function Escape:stop()
    if self.connection then self.connection:Disconnect();self.connection=nil end
    self.folder=nil;self.indicator=nil;self.states={};self.status="Stopped"
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
    self.busy=false
    if self.release then local release = self.release; self.release = nil; pcall(release) end
end
function Input:dispatch()
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
function Input:press()
    if self.busy then return "M1 já em andamento",false end
    self.busy=true
    local ok,result,sent=pcall(function()return self:dispatch()end)
    self.busy=false
    if not ok then error(result)end
    if sent then self.lastDispatch=os.clock()end
    return result,sent
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
local Targeting=require("automation/Targeting")
local Multi = {}
function Multi.pick(targets, origin, radius, maxTitans, maxPoints, cursor, focus)
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
    if focus and focus~="Nearest"then
        local focused={}
        for _,group in ipairs(order)do
            local distance=math.huge
            for _,point in ipairs(group.points)do
                if Targeting.isPrimary(point,focus)then distance=math.min(distance,(point.position-origin).Magnitude)end
            end
            if distance<math.huge then group.distance=distance;table.insert(focused,group)end
        end
        order=focused
    end
    table.sort(order, function(a, b) return a.distance < b.distance end)
    local picked,extras = {},{}
    for i = 1, math.min(maxTitans, #order) do
        local points = order[i].points
        table.sort(points, function(a, b)
            if focus and focus~="Nearest"then
                local af,bf=Targeting.isPrimary(a,focus),Targeting.isPrimary(b,focus)
                if af~=bf then return af end
            elseif focus=="Nearest"then
                local ad,bd=(a.position-origin).Magnitude,(b.position-origin).Magnitude
                if ad~=bd then return ad<bd end
            end
            local ap, bp = a.priority or 1, b.priority or 1
            if ap ~= bp then return ap < bp end
            return (a.part or "") < (b.part or "")
        end)
        local count = math.min(maxPoints, #points)
        table.insert(picked, points[1]) -- keep current weak point in each round
        for j = 1, count - 1 do
            local index = 2 + ((cursor + j - 1) % (#points - 1))
            table.insert(focus and extras or picked, points[index])
        end
    end
    for _,point in ipairs(extras)do table.insert(picked,point)end
    return picked
end
return Multi

end
factories["automation/RaidPolicy"] = function(require)
local Policy={}
function Policy.values(config)
    if not config.raidMode then return config.aotrHoverHeight,config.attackCooldown,config.aotrMaxTitans,config.aotrMaxLimbs end
    return math.max(config.aotrHoverHeight,config.raidHeight),math.max(config.attackCooldown,config.raidInterval),
        math.min(config.aotrMaxTitans,config.raidTitans),math.min(config.aotrMaxLimbs,config.raidPoints)
end
return Policy

end
factories["automation/RapidApproach"] = function(require)
-- Pure bounded approach/retreat policy; no input, remotes or game mutation.
local Rapid={};Rapid.__index=Rapid
function Rapid.new(config)
    return setmetatable({config=config,state="High",reason="Preparando voo alto",nextEntry=0,sent=false,attempts=0,registrations=0,canceled=0,registeredThisPass=false},Rapid)
end
function Rapid:active()return self.state=="Approach"or self.state=="Strike"or self.state=="Retreat"end
function Rapid:abort(now,sample,reason)
    if self.state=="Retreat"then return end
    if self.state=="Strike"and self.sent and not self.registeredThisPass then self.canceled+=1 end
    self.state="Retreat";self.reason=reason;self.sent=true
    self.escape=Vector3.new(sample.position.X,math.max(sample.safeY or self.safeY or sample.position.Y,sample.position.Y),sample.position.Z)
    self.nextEntry=math.max(self.nextEntry,now+self.config.rapidCooldown)
end
function Rapid:markAttack(now)
    if self.state=="Strike"and not self.sent then self.sent=true;self.attempts+=1;self.strikeUntil=math.min(self.deadline,now+math.max(self.config.rapidStrikeHold,self.config.aotrInputHold+self.config.aotrInputRegisterDelay+0.2))end
end
function Rapid:step(now,sample)
    local c=self.config
    local damaged=self.health and sample.health and sample.health<self.health
    if damaged then self.nextEntry=math.max(self.nextEntry,now+c.rapidDamagePause)end
    self.health=sample.health
    self.safeY=math.max(self.safeY or -math.huge,sample.safeY or sample.position.Y)
    if self.state=="Approach"or self.state=="Strike"then
        local reason
        if sample.grabbed then reason="Indicador de grab"
        elseif damaged then reason="Perda de vida"
        elseif not sample.healthRatio or sample.healthRatio<c.rapidMinimumHealth then reason="Vida insuficiente"
        elseif not sample.valid or sample.target~=self.target then reason="Alvo removido/alterado"
        elseif now>=self.deadline then reason="Tempo máximo de exposição"
        elseif self.state=="Strike"and now>=self.strikeUntil then reason="Janela de ataque encerrada"end
        if reason then self:abort(now,sample,reason)end
    end
    if self.state=="Retreat"then
        -- Never lower an escape destination when a nearby target moves or disappears.
        self.escape=Vector3.new(self.escape.X,math.max(self.escape.Y,self.safeY),self.escape.Z)
        if sample.position.Y>=self.escape.Y-c.rapidReadyTolerance then
            self.state="Cooldown";self.nextEntry=math.max(self.nextEntry,now+c.rapidCooldown);self.reason="Retirada concluída; aguardando intervalo"
        end
        return self.escape,false
    end
    if self.state=="Approach"then
        local destination=sample.targetPosition+Vector3.new(0,c.rapidHeight,0)
        if (sample.targetPosition-sample.position).Magnitude<=c.rapidStrikeDistance then
            self.state="Strike";self.strikeUntil=self.deadline;self.reason="Aguardando agendamento na nuca"
        end
        return destination,self.state=="Strike"and not self.sent
    end
    if self.state=="Strike"then return sample.targetPosition+Vector3.new(0,c.rapidHeight,0),not self.sent end
    local high=sample.highDestination
    if now>=self.nextEntry and sample.valid and not sample.pending and not sample.grabbed and not damaged
        and sample.healthRatio and sample.healthRatio>=c.rapidMinimumHealth and sample.canEnter
        and (high-sample.position).Magnitude<=c.rapidReadyTolerance then
        self.state="Approach";self.target=sample.target;self.sent=false;self.registeredThisPass=false;self.deadline=now+c.rapidMaxExposure
        self.reason="Aproximação com tempo limitado"
        return sample.targetPosition+Vector3.new(0,c.rapidHeight,0),false
    end
    self.reason=sample.grabbed and "Aguardando fim do grab"or (not sample.healthRatio and "Leitura de vida indisponível"
        or sample.healthRatio<c.rapidMinimumHealth and "Vida abaixo do mínimo; mantendo voo alto"or "Mantendo voo alto/intervalo")
    return high,false
end
return Rapid

end
factories["automation/Skills"] = function(require)
-- Uses keyboard slots only; no skill names, cooldowns or RemoteEvents are assumed.
local Skills={};Skills.__index=Skills
function Skills.new(config)
    return setmetatable({config=config,nextFarm=0,nextEscape=0,escapeAttempts=0,busy=false,epoch=0,status="Skills OFF"},Skills)
end
function Skills.plan(config,escape)
    local slots={}
    for slot=1,5 do if escape or config["skillSlot"..slot]then table.insert(slots,slot)end end
    return slots
end
function Skills:stop()
    self.epoch+=1;self.busy=false
    if self.release then pcall(self.release);self.release=nil end
    if self.thread then pcall(task.cancel,self.thread);self.thread=nil end
    self.status="Skills stopped"
end
function Skills:request(now,escape)
    local config=self.config
    if not(escape and config.grabUseAllSkills or not escape and config.autoSkills)then return false end
    if escape and self.busy and self.mode=="Farm"then self:stop()end
    if self.busy then return false end
    if escape then
        if now<self.nextEscape or self.escapeAttempts>=config.skillEscapeAttempts then return false end
    elseif now<self.nextFarm then return false end
    local slots=Skills.plan(config,escape)
    if #slots==0 then self.status="Nenhum slot selecionado";return false end
    local ok,input=pcall(function()
        if game:GetService("UserInputService"):GetFocusedTextBox()then return nil end
        return game:GetService("VirtualInputManager")
    end)
    if not ok or not input then
        self.status="Input indisponível ou campo de texto em foco"
        if escape then self.nextEscape=now+config.skillEscapeInterval else self.nextFarm=now+config.skillInterval end
        return false
    end
    if escape then self.nextEscape=now+config.skillEscapeInterval;self.escapeAttempts+=1 else self.nextFarm=now+config.skillInterval end
    self.mode=escape and "Grab"or "Farm";self.busy=true
    local epoch=self.epoch
    self.thread=task.defer(function()
        local success=pcall(function()
            local names={"One","Two","Three","Four","Five"}
            for index,slot in ipairs(slots)do
                if epoch~=self.epoch then return end
                if index>1 then task.wait(config.skillGap)end
                if epoch~=self.epoch then return end
                -- Do not type into chat if focus changes during the sequence.
                if game:GetService("UserInputService"):GetFocusedTextBox()then return end
                local key=Enum.KeyCode[names[slot]]
                self.release=function()input:SendKeyEvent(false,key,false,game)end
                input:SendKeyEvent(true,key,false,game)
                task.wait(config.skillHold)
                if self.release then self.release();self.release=nil end
            end
        end)
        if self.release then pcall(self.release);self.release=nil end
        if epoch==self.epoch then
            self.busy=false;self.thread=nil
            self.status=success and (self.mode..": teclas solicitadas; efeito não confirmado")or "Executor recusou entrada de skill"
        end
    end)
    return true
end
return Skills

end
factories["automation/Targeting"] = function(require)
local Targeting = {}
function Targeting.isPrimary(target,focus)
    if focus=="Nape"then return target.part=="Nape"end
    if focus=="Indicated"then return target.priority==0 end
    return true
end
function Targeting.select(targets, origin, mode, focus)
    local best, score
    for _, target in ipairs(targets) do
        if target.health > 0 and Targeting.isPrimary(target,focus)then
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
    aotrRetryMethod = "Auto", autoExecute = false,
    aotrCombatMode = "Source", aotrHitSpeedMin = 215, aotrHitSpeedMax = 230,
    aotrHitExtraMin = 10, aotrHitExtraMax = 100,
    aotrAltitudeP = 100, aotrAltitudeD = 20, aotrNoCollision = true,
    aotrAttackMethod = "InputRegister", aotrInputMethod = "Signal", aotrInputHold = 0.08,
    aotrInputRegisterDelay = 0.1,
    persistentFarm = false, farmActive = false, autoEscapeGrab = false,
    continuousM1 = false, m1Interval = 0.15,
    aotrFarLimbAttack = false, farLimbDistance = 40, farLimbInterval = 0.6, farLimbMaxPoints = 1,
    rapidApproach = false, rapidEntrySpeed = 220, rapidRetreatSpeed = 300,
    rapidHeight = 18, rapidStrikeDistance = 24, rapidMaxExposure = 0.9, rapidStrikeHold = 0.25,
    rapidCooldown = 8, rapidDamagePause = 5, rapidMinimumHealth = 0.85, rapidRetreatHeight = 100,
    rapidReadyTolerance = 8, rapidGain = 12,
    aotrAttackFromHeight = true,
    flightSafetyRevision = 1, aotrNapeApproach = false, aotrNapeHeight = 10, aotrNapeAttackDistance = 24,
    aotrFocusMode = "Nape", aotrAttackExtras = false,
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
    autoSkills = false, grabUseAllSkills = true,
    skillSlot1 = true, skillSlot2 = true, skillSlot3 = true, skillSlot4 = true, skillSlot5 = true,
    skillInterval = 8, skillGap = 0.2, skillHold = 0.08, skillEscapeInterval = 3, skillEscapeAttempts = 3,
    uiMode = "Auto", uiScale = 1, uiTheme = "Current",
    raidMode = false, raidHeight = 120, raidInterval = 1.5, raidTitans = 1, raidPoints = 1,
    lobbyAttackPath = "Esquerda", lobbyDefensePath = "Esquerda", lobbySupportPath = "Esquerda",
    aotrUniverseId = 4658598196,
}

end
factories["core/FlightSafety"] = function(require)
local Safety={}
function Safety.migrate(config,saved)
    if not saved or saved.flightSafetyRevision~=1 then
        config.aotrNapeApproach=false
        config.aotrHoverHeight=math.max(config.aotrHoverHeight,75)
    end
    config.flightSafetyRevision=1
    return config
end
return Safety

end
factories["core/InlineResume"] = function(require)
local Inline={}
function Inline.findQueue()
    if type(queue_on_teleport)=="function" then return queue_on_teleport,"queue_on_teleport" end
    if type(queueonteleport)=="function" then return queueonteleport,"queueonteleport" end
    for _, namespace in pairs({syn,fluxus,delta}) do
        if type(namespace)=="table" and type(namespace.queue_on_teleport)=="function" then return namespace.queue_on_teleport,"executor namespace" end
    end
end
function Inline.payload(runtime,bootstrap,json,origin,revision,cache)
    local loader
    if cache then loader="return assert(loadstring(readfile("..string.format("%q",cache)..")))()"
    else loader=string.format("local runtime=%q;local bootstrap=%q;return assert(loadstring(bootstrap))(runtime,bootstrap)",runtime,bootstrap) end
    return string.format([[local e=(getgenv and getgenv()) or _G
local seen=e.ProjectTitanResumeSeen or {};e.ProjectTitanResumeSeen=seen
local origin=%q;local revision=%d
if seen[origin] and seen[origin]>=revision then return end
seen[origin]=revision
e.MahmutAOTRResumeConfig=game:GetService("HttpService"):JSONDecode(%q)
%s
]],origin,revision,json,loader)
end
function Inline.attach(controller,runtime,bootstrap)
    local queue,name=Inline.findQueue()
    local adapter,config,log=controller.adapter,controller.config,controller.log
    local manager={revision=0,last=nil,origin=tostring(os.clock())..tostring({}),connection=nil}
    local cache
    if type(writefile)=="function" and type(readfile)=="function" then
        local file="ProjectTitan-autoload-v0.9.2.luau"
        local content=string.format("local runtime=%q;local bootstrap=%q;return assert(loadstring(bootstrap))(runtime,bootstrap)",runtime,bootstrap)
        local ok=pcall(function()writefile(file,content);assert(readfile(file)==content,"Cache verification failed")end)
        if ok then cache=file end
    end
    adapter.resumeManager=manager
    adapter.resumeStatus=queue and ("Inline ready: "..name) or "Queue capability unavailable"
    function manager:arm()
        if not config.autoExecute then adapter.resumeStatus="Autoload OFF";return false end
        if not queue then adapter.resumeStatus="Queue capability unavailable";return false end
        local json=game:GetService("HttpService"):JSONEncode(config)
        if json==self.last then return true end
        local revision=self.revision+1
        local payload=Inline.payload(runtime,bootstrap,json,self.origin,revision,cache)
        local ok,err=pcall(queue,payload)
        if ok then self.revision=revision;self.last=json;adapter.resumeStatus=(cache and "Cache queued #"or "Inline queued #")..revision
        else adapter.resumeStatus="Inline queue failed";log:write("error","autoload",err) end
        return ok
    end
    function manager:Disconnect()
        if self.connection then self.connection:Disconnect();self.connection=nil end
        if adapter.resumeManager==self then adapter.resumeManager=nil end
    end
    manager.connection=game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
        if state==Enum.TeleportState.Started or state==Enum.TeleportState.InProgress then manager:arm() end
    end)
    if config.farmActive then manager:arm() end
    return manager
end
return Inline

end
factories["core/LobbyDiagnostic"] = function(require)
local Diagnostic={}
local function context(node,root)
    local segments={};local visible=true;local own=false;local cursor=node;local count=0
    while cursor and cursor~=root and count<100 do
        table.insert(segments,1,cursor.Name)
        if cursor.Name=="ProjectTitanHub"then own=true end
        if cursor:IsA("GuiObject")and cursor.Visible==false then visible=false end
        if cursor:IsA("ScreenGui")and cursor.Enabled==false then visible=false end
        cursor=cursor.Parent;count+=1
    end
    return table.concat(segments,"/"),visible,own
end
function Diagnostic.scan(playerGui,section,full)
    assert(playerGui,"PlayerGui indisponível; aguarde o carregamento do jogo")
    local groupLimit=full and 20000 or 600
    local totalLimit=full and 20000 or 1200
    local groups={{},{},{},{}};local inspected=0;local errors=0;local omitted=0
    for _,node in ipairs(playerGui:GetDescendants())do
        local ok=pcall(function()
            if not(node:IsA("GuiButton")or node:IsA("TextLabel")or node:IsA("TextBox")or(node:IsA("Frame")and node.Active))then return end
            local path,visible,own=context(node,playerGui)
            if own then return end
            if section and section~="Todos"then
                local wanted="Interface/"..section.."/"
                local currencies="Interface/Topbar/Main/Currencies/"
                if string.sub(path,1,#wanted)~=wanted and string.sub(path,1,#currencies)~=currencies then return end
            end
            inspected+=1
            local text=""
            if node:IsA("TextLabel")or node:IsA("TextButton")then text=node.Text end
            local kind=node:IsA("GuiButton")and "button"or "context"
            local group=(visible and 0 or 2)+(kind=="button"and 1 or 2)
            if #groups[group]>=groupLimit then omitted+=1;return end
            table.insert(groups[group],{path=path,parent=node.Parent and node.Parent.Name or "",class=node.ClassName,
                kind=kind,text=string.sub(text or "",1,300),visible=visible,active=node.Active==true})
        end)
        if not ok then errors+=1 end
    end
    local rows={};for _,group in ipairs(groups)do
        table.sort(group,function(a,b)return a.path<b.path end)
        for _,row in ipairs(group)do if #rows<totalLimit then table.insert(rows,row)else omitted+=1 end end
    end
    return rows,{inspected=inspected,errors=errors,omitted=omitted}
end
function Diagnostic.mainButtons(playerGui)
    local rows,stats=Diagnostic.scan(playerGui,"Todos",true)
    local buttons={}
    for _,row in ipairs(rows)do
        if row.kind=="button"and row.visible then
            local parent=string.match(row.path,"^(.*)/[^/]+$")or ""
            local captions={}
            if row.text~=""then table.insert(captions,row.text)end
            for _,other in ipairs(rows)do
                if other.visible and other.kind=="context"and other.text~=""then
                    local otherParent=string.match(other.path,"^(.*)/[^/]+$")or ""
                    if otherParent==parent or string.sub(other.path,1,#row.path+1)==row.path.."/"then
                        if #captions<4 then table.insert(captions,other.text)end
                    end
                end
            end
            local copy=table.clone(row);copy.text=table.concat(captions," | ")
            copy.rank=string.find(copy.path,"Interface/Equipment/",1,true)and 1
                or string.find(copy.path,"Interface/Inventory/",1,true)and 1
                or string.find(copy.path,"Interface/Market/",1,true)and 1
                or string.find(copy.path,"Interface/Topbar/",1,true)and 3 or 2
            table.insert(buttons,copy)
        end
    end
    table.sort(buttons,function(a,b)if a.rank~=b.rank then return a.rank<b.rank end;return a.path<b.path end)
    local total=#buttons
    while #buttons>60 do table.remove(buttons)end
    return buttons,{inspected=stats.inspected,errors=stats.errors,omitted=stats.omitted+total-#buttons,visibleButtons=total}
end
function Diagnostic.saveAll(playerGui,entries)
    local rows,stats=Diagnostic.scan(playerGui,"Todos",true)
    local report={version="0.9.2",elements=rows,stats=stats,hubLogs=entries or {}}
    local json=game:GetService("HttpService"):JSONEncode(report)
    local text=Diagnostic.format(rows,stats)
    local names={"ProjectTitan-log-completo.json","ProjectTitan-log-completo.txt"}
    assert(type(writefile)=="function","Executor sem writefile. Use o resumo dos botões ou Copiar partes.")
    local jsonOK=pcall(writefile,names[1],json)
    local textOK=pcall(writefile,names[2],text)
    local saved={};if jsonOK then table.insert(saved,names[1])end;if textOK then table.insert(saved,names[2])end
    assert(#saved>0,"Não foi possível gravar os arquivos; verifique a permissão de arquivos do executor")
    return table.concat(saved," e "),#rows,stats.omitted
end
function Diagnostic.format(rows,stats)
    local lines={string.format("%d elementos | %d erros | %d omitidos",#rows,stats.errors,stats.omitted)}
    for _,row in ipairs(rows)do
        table.insert(lines,(row.visible and "[visível] "or "[oculto] ")..row.class.." "..row.path.."\n"..row.text)
    end
    return table.concat(lines,"\n\n")
end
function Diagnostic.pages(rows,stats,section)
    local http=game:GetService("HttpService")
    local groups={};local batch={}
    local function encode(elements)return http:JSONEncode({version="0.9.2",section=section,stats=stats,elements=elements})end
    for _,row in ipairs(rows)do
        table.insert(batch,row)
        if #encode(batch)>6500 and #batch>1 then
            table.remove(batch);table.insert(groups,batch);batch={row}
        end
    end
    if #batch>0 or #groups==0 then table.insert(groups,batch)end
    local pages={}
    for index,elements in ipairs(groups)do
        table.insert(pages,http:JSONEncode({version="0.9.2",section=section,part=index,total=#groups,stats=stats,elements=elements}))
    end
    return pages
end
function Diagnostic.export(content)
    if type(writefile)~="function"then return false,"Sem writefile; use Copiar resultado ou o texto abaixo"end
    local ok=pcall(writefile,"ProjectTitan-lobby-diagnostic.json",content)
    return ok,ok and "Arquivo salvo: ProjectTitan-lobby-diagnostic.json"or "Falha ao salvar; o resultado continua disponível no painel"
end
return Diagnostic

end
factories["core/LobbyNavigation"] = function(require)
-- Explicit navigation only; paths observed in the user's Equipment capture.
local Navigation={}
Navigation.paths={
    Equipment="Interface/Topbar/Main/Categories/Equipment/Interact",
    Upgrades="Interface/Equipment/Categories/Upgrades/Main/Interact",
    Skills="Interface/Equipment/Categories/Skill_Tree/Main/Interact",
    Perks="Interface/Equipment/Categories/Perks/Main/Interact",
    Prestige="Interface/Equipment/Categories/Prestige/Main/Interact",
}
Navigation.attributes={"ODM_Damage","ODM_Speed","ODM_Gas","Blade_Durability","ODM_Range","ODM_Control","ODM_Crit_Chance","ODM_Crit_Damage"}
function Navigation.activate(gui,path,input)
    local allowed=false
    for _,value in pairs(Navigation.paths)do if value==path then allowed=true end end
    for _,name in ipairs(Navigation.attributes)do if path=="Interface/Equipment/Stats/Blades/"..name.."/Inner/Interact"then allowed=true end end
    assert(allowed,"Ação fora da lista de navegação confirmada")
    local node=gui
    for segment in string.gmatch(path,"[^/]+")do node=node and node:FindFirstChild(segment)end
    assert(node and node:IsA("GuiButton"),"Controle de navegação não encontrado")
    assert(node.Active,"Controle desativado")
    local parent=node
    while parent and parent~=gui do
        assert(not(parent:IsA("GuiObject")and not parent.Visible),"Abra primeiro o menu que contém esse controle")
        assert(not(parent:IsA("ScreenGui")and not parent.Enabled),"Interface desativada")
        parent=parent.Parent
    end
    assert(type(firesignal)=="function"and type(getconnections)=="function","Executor sem suporte a callbacks da interface")
    local function connected(event)
        for _,connection in ipairs(getconnections(event))do if connection.Enabled~=false then return true end end
        return false
    end
    if connected(node.MouseButton1Click)then firesignal(node.MouseButton1Click)
    elseif typeof(input)=="InputObject"and connected(node.Activated)then firesignal(node.Activated,input,1)
    else error("Nenhum callback de navegação compatível; abra manualmente")end
    return "Navegação solicitada; confira a tela do jogo"
end
return Navigation

end
factories["core/LobbyState"] = function(require)
local State={}
local function resolve(root,path)
    for segment in string.gmatch(path,"[^/]+")do root=root and root:FindFirstChild(segment)end
    return root
end
local function text(root,path)
    local node=resolve(root,path)
    return node and (node:IsA("TextLabel")or node:IsA("TextButton"))and node.Text or "Indisponível"
end
local function available(root,path)
    local node=resolve(root,path)
    if not node or not node:IsA("GuiButton")then return "Não encontrado"end
    local active=node.Active;local cursor=node
    while cursor and cursor~=root do
        if cursor:IsA("GuiObject")and not cursor.Visible then return "Oculto; aguardando requisitos/menu"end
        if cursor:IsA("ScreenGui")and not cursor.Enabled then return "Interface desativada"end
        cursor=cursor.Parent
    end
    return active and "Visível; confirmação da ação ainda não integrada"or "Desativado"
end
function State.read(gui)
    assert(gui,"PlayerGui indisponível")
    local base="Interface/Equipment/Stat/"
    return "Atributo: "..text(gui,base.."Inner/Stat")
        .."\nAtual: "..text(gui,base.."Inner/Stat_Values/Current").." → "..text(gui,base.."Inner/Stat_Values/New")
        .."\nCusto/estado: "..text(gui,base.."Cost/Title")
        .."\nUpgrade: "..available(gui,base.."Upgrade")
        .."\nPrestígio: "..available(gui,"Interface/Equipment/Prestige/B_Prestige")
        .."\nOuro: "..text(gui,"Interface/Topbar/Main/Currencies/Gold/Amount")
        .." | Gemas: "..text(gui,"Interface/Topbar/Main/Currencies/Gems/Amount")
end
return State

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
local Safety=require("core/FlightSafety")
local Preferences = {}
local fileName = "ProjectTitan-settings-v0.7.1.json"
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
            if type(value) ~= "number" or (value >= 0 and value < math.huge and value == value) then config[name] = value end
        end
    end
    Safety.migrate(config,saved)
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
factories["core/Profiles"] = function(require)
local Safety=require("core/FlightSafety")
local Profiles={}
local file="ProjectTitan-presets.json"
local memory={}
local function read()
    if type(readfile)=="function" then
        local ok,data=pcall(function()local raw=readfile(file);assert(#raw<131072);return game:GetService("HttpService"):JSONDecode(raw)end)
        if ok and type(data)=="table"then memory=data end
    end
    return memory
end
function Profiles.names()
    local names={};for name in pairs(read())do table.insert(names,name)end;table.sort(names);return names
end
function Profiles.save(name,config)
    assert(type(name)=="string" and #name>0 and #name<=40,"Nome: 1 a 40 caracteres")
    local all=read();assert(all[name]or #Profiles.names()<20,"Limite: 20 predefinições")
    local copy=table.clone(config);copy.farmActive=false;copy.aotrActionsEnabled=false;copy.autoExecute=false
    all[name]=copy;memory=all
    if type(writefile)=="function"then writefile(file,game:GetService("HttpService"):JSONEncode(all));return "Salvo em arquivo"end
    return "Salvo apenas nesta sessão"
end
function Profiles.load(name,config)
    local saved=read()[name];assert(type(saved)=="table","Predefinição não encontrada")
    for key,old in pairs(config)do
        local value=saved[key]
        if typeof(value)==typeof(old) and (type(value)~="number"or(value==value and value>=0 and value<math.huge))then config[key]=value end
    end
    Safety.migrate(config,saved)
    config.farmActive=false;config.aotrActionsEnabled=false;config.autoExecute=false
end
function Profiles.delete(name)
    read()[name]=nil
    if type(writefile)=="function"then writefile(file,game:GetService("HttpService"):JSONEncode(memory))end
end
return Profiles

end
factories["core/Resume"] = function(require)
local Resume = {}
Resume.attachInline=require("core/InlineResume").attach
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
factories["core/Webhook"] = function(require)
local Webhook={}
Webhook.__index=Webhook
function Webhook.new()
    return setmetatable({url="",enabled=false,busy=false,nextAt=0,status="Desativado",closed=false},Webhook)
end
function Webhook:configure(url)
    assert(type(url)=="string" and #url<512 and url:match("^https://discord%.com/api/webhooks/%d+/[%w_%-]+$"),"URL Discord inválida")
    self.url=url;self.status="Configurado apenas nesta sessão"
end
function Webhook:send(event)
    if self.closed or not self.enabled or self.url=="" or self.busy or os.clock()<self.nextAt then return false end
    local send=request or http_request or (syn and syn.request)
    if type(send)~="function"then self.status="Executor sem request HTTP";return false end
    self.busy=true;self.nextAt=os.clock()+15
    local url=self.url
    task.spawn(function()
        local ok,response=pcall(send,{Url=url.."?wait=true",Method="POST",Headers={["Content-Type"]="application/json"},
            Body=game:GetService("HttpService"):JSONEncode({content="Project Titan: "..string.sub(event,1,200),allowed_mentions={parse={}}})})
        self.busy=false
        if self.closed then return end
        local code=ok and type(response)=="table"and tonumber(response.StatusCode)or 0
        if code and code>=200 and code<300 then self.status="Mensagem confirmada"
        elseif code==429 then
            local delay=60
            pcall(function()local body=game:GetService("HttpService"):JSONDecode(response.Body);delay=math.clamp(tonumber(body.retry_after)or 60,1,3600)end)
            self.nextAt=os.clock()+delay;self.status="Limite HTTP: aguarde; mensagem não repetida"
        else self.status="Falha HTTP "..tostring(code).."; mensagem não repetida"end
    end)
    return true
end
function Webhook:destroy()self.closed=true;self.enabled=false;self.url=""end
return Webhook

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
factories["ui/Dashboard"] = function(require)
local T=require("ui/Theme")
local Scope=require("core/Scope")
local Slider=require("ui/Slider")
local Preferences=require("core/Preferences")
local FarmModes=require("automation/FarmModes")
local Preset=require("automation/FarmPreset")
local Profiles=require("core/Profiles")
local LobbyNavigation=require("core/LobbyNavigation")
local LobbyState=require("core/LobbyState")
local LobbyDiagnostic=require("core/LobbyDiagnostic")
local Webhook=require("core/Webhook")
local Dashboard={}
function Dashboard.mount(engine,adapter,config,log,onDestroy)
    local scope=Scope.new()
    local webhook=Webhook.new();scope:add(function()webhook:destroy()end)
    T.apply(config.uiTheme)
    local capture=function(input)
        adapter.retryUI.lastInput=input;adapter.grabEscape.lastInput=input;adapter.inputAttack.lastInput=input
    end
    T.onInput=capture
    scope:add(function()if T.onInput==capture then T.onInput=nil end end)
    local gui=scope:add(T.make("ScreenGui",game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui"),
        {Name="ProjectTitanHub",ResetOnSpawn=false,DisplayOrder=1000}))
    local frame=T.make("Frame",gui,{Size=UDim2.fromOffset(700,620),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),BackgroundColor3=T.bg,BorderSizePixel=0})
    T.round(frame,18);T.stroke(frame)
    T.label(frame,"PROJECT TITAN",22,{Position=UDim2.fromOffset(22,12),Size=UDim2.new(1,-150,0,28),Font=Enum.Font.GothamBold})
    T.label(frame,"ADMIN HUB  /  0.9.2",12,{Position=UDim2.fromOffset(23,42),Size=UDim2.new(1,-150,0,18),TextColor3=T.muted})
    local function save()
        local ok,err=Preferences.save(config)
        if not ok then log:write("info","preferences",err) end
        if adapter.resumeManager then adapter.resumeManager:arm() end
    end
    local function stop()Preset.disable(config);engine:stop();save()end
    local restore=T.button(scope,gui,"PROJECT TITAN",function()end,42)
    restore.Size=UDim2.fromOffset(154,42);restore.Position=UDim2.fromOffset(12,12);restore.Visible=false;restore.TextColor3=T.accent
    local function minimize(value)frame.Visible=not value;restore.Visible=value end
    scope:add(restore.Activated:Connect(function()minimize(false)end))
    local mini=T.button(scope,frame,"−",function()minimize(true)end,34)
    mini.Size=UDim2.fromOffset(36,34);mini.Position=UDim2.new(1,-94,0,20)
    local close=T.button(scope,frame,"×",function()stop();onDestroy()end,34)
    close.Size=UDim2.fromOffset(36,34);close.Position=UDim2.new(1,-50,0,20);close.TextColor3=T.danger
    local scale=T.make("UIScale",frame,{Scale=1})
    local nav=T.make("ScrollingFrame",frame,{BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
    local pages,tabButtons={},{}
    local names={"Farm alto","Investida","Equipamento","Raid","Lobby","Configuração","Diagnóstico","Logs"}
    local selected="Farm alto"
    for _, name in ipairs(names)do
        local page=T.make("ScrollingFrame",frame,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
            ScrollBarImageColor3=T.border,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=name==selected})
        T.make("UIListLayout",page,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,10)})
        T.make("UIPadding",page,{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,14),PaddingLeft=UDim.new(0,2)})
        pages[name]=page
        tabButtons[name]=T.button(scope,nav,name,function()
            selected=name
            for key,p in pairs(pages)do p.Visible=key==name end
        end)
    end
    local function section(page,title,subtitle)
        T.label(page,title,19,{Size=UDim2.new(1,-8,0,30),Font=Enum.Font.GothamBold})
        if subtitle then T.label(page,subtitle,13,{Size=UDim2.new(1,-8,0,42),TextColor3=T.muted})end
    end
    local function change(callback)
        local running=engine.running;engine:stop();callback();save();if running then engine:start()end
    end
    local disposed=false
    local refreshParameters={}
    local function textInput(page,title,initial,callback)
        T.label(page,title,14)
        local box=T.make("TextBox",page,{Text=initial or "",PlaceholderText=title,ClearTextOnFocus=false,
            TextSize=14,TextColor3=T.text,BackgroundColor3=T.card,Size=UDim2.new(1,-8,0,40)})
        T.round(box,9)
        scope:add(box.FocusLost:Connect(function()if callback then callback(box.Text,box)end end))
        return box
    end
    local function parameter(page,key,title,description,minimum,maximum,unit,step)
        local card=T.make("Frame",page,{Name="Setting_"..key,BackgroundColor3=T.card,BorderSizePixel=0,Size=UDim2.new(1,-8,0,106)})
        T.round(card,12);T.stroke(card)
        T.label(card,title,15,{Position=UDim2.fromOffset(14,10),Size=UDim2.new(1,-150,0,24),Font=Enum.Font.GothamMedium})
        local value=T.label(card,"",16,{Position=UDim2.new(1,-130,0,10),Size=UDim2.fromOffset(112,24),TextXAlignment=Enum.TextXAlignment.Right,TextColor3=T.accent})
        T.label(card,description,12,{Position=UDim2.fromOffset(14,34),Size=UDim2.new(1,-125,0,24),TextColor3=T.muted})
        local refreshBar
        local exact=T.make("TextBox",card,{Text=tostring(config[key]),PlaceholderText="Valor exato",ClearTextOnFocus=false,
            TextColor3=T.text,BackgroundColor3=T.bg,TextSize=12,Size=UDim2.fromOffset(86,24),Position=UDim2.new(1,-104,0,36)})
        T.round(exact,5)
        scope:add(exact.FocusLost:Connect(function()
            local number=tonumber((exact.Text:gsub(",",".")))
            if number and number==number and number>=minimum and number<=maximum then
                if not step then number=math.floor(number+0.5)end
                change(function()config[key]=number end);if refreshBar then refreshBar()end
                value.Text=tostring(number).." "..unit
            else exact.Text=tostring(config[key]);log:write("info","parameter","Valor fora do intervalo: "..title)end
        end))
        local wasRunning=false
        local bar,renderBar=Slider.mount(scope,card,config,key,minimum,maximum,function(number)
            local formatted=step and step<1 and string.format("%.2f",number)or tostring(number)
            value.Text=formatted..(unit~="" and " "..unit or "")
        end,function()wasRunning=engine.running;engine:stop()end,function()
            if not disposed then save();if wasRunning then engine:start()end end;wasRunning=false
        end,step)
        refreshBar=renderBar
        table.insert(refreshParameters,function()renderBar();exact.Text=tostring(config[key]);value.Text=tostring(config[key]).." "..unit end)
        bar.Position=UDim2.fromOffset(4,62);bar.Size=UDim2.new(1,-8,0,38)
    end
    local farm=pages["Farm alto"]
    local rapidPage=pages.Investida
    section(farm,"Auto Farm alto","Ativar este modo interrompe a Investida. As configurações compartilhadas de combate também ficam nesta aba.")
    local blockingReason=T.label(farm,"",13,{Size=UDim2.new(1,-8,0,84),TextColor3=T.danger})
    local master=T.button(scope,farm,"ATIVAR FARM ALTO",function()
        if config.farmActive and not config.rapidApproach then stop()else FarmModes.start(engine,config,false);save()end
    end,52)
    master.TextColor3=T.accent
    local emergency=T.button(scope,farm,"PARAR TUDO",stop,42);emergency.TextColor3=T.danger
    parameter(farm,"aotrMaxTitans","Titãs por rodada","Quantidade máxima de titãs próximos",1,6,"titãs")
    parameter(farm,"aotrMaxLimbs","Pontos por titã","Inclui a nuca; extras só com Atacar pontos extras ON",1,6,"pontos")
    parameter(farm,"aotrHoverHeight","Altura de voo","Distância vertical acima das nucas",10,400,"studs")
    parameter(farm,"moveSpeed","Velocidade de voo","Velocidade máxima de deslocamento",10,600,"studs/s")
    parameter(farm,"aotrAuraRadius","Raio de ataque","Distância máxima das tentativas de acerto",20,800,"studs")
    parameter(farm,"attackCooldown","Intervalo dos ataques","Tempo entre as rodadas de ataque",0.05,10,"s",0.05)
    parameter(farm,"aotrBatchHitInterval","Intervalo entre pontos","Espera entre registros; o servidor também impõe limites",0.01,2,"s",0.01)
    parameter(farm,"aotrInputRegisterDelay","Espera após M1","Tempo entre ativar M1 e registrar os acertos",0,1,"s",0.01)
    parameter(farm,"aotrInputHold","Duração do M1","Tempo de pressão do controle de ataque",0.01,1,"s",0.01)
    parameter(farm,"aotrNapeHeight","Altura de aproximação","Inativa com Atacar do alto ON; altura normal fica preservada",2,60,"studs")
    parameter(farm,"aotrNapeAttackDistance","Distância para liberar ataque","Limite próximo só na aproximação; voo alto usa Raio de ataque",4,100,"studs")
    local rapidMaster=T.button(scope,rapidPage,"ATIVAR INVESTIDA",function()
        if config.farmActive and config.rapidApproach then stop()else FarmModes.start(engine,config,true);save()end
    end,52)
    rapidMaster.TextColor3=T.accent
    T.button(scope,rapidPage,"PARAR INVESTIDA",function()if config.rapidApproach then stop()end end)
    local rapidStatus=T.label(rapidPage,"",13,{Size=UDim2.new(1,-8,0,100),TextColor3=T.muted})
    section(rapidPage,"Aproximação rápida","Ativar interrompe o Farm alto e desliga Raid. Uma tentativa na nuca por passagem; retirada prioritária. M1 contínuo é opcional e pausa na retirada/grab.")
    parameter(rapidPage,"rapidEntrySpeed","Velocidade de entrada","Velocidade máxima da passagem curta",50,500,"studs/s")
    parameter(rapidPage,"rapidRetreatSpeed","Velocidade de retirada","Subida vertical antes de voltar a perseguir",100,600,"studs/s")
    parameter(rapidPage,"rapidHeight","Altura da passagem","Acima da nuca, apenas durante a entrada",8,60,"studs")
    parameter(rapidPage,"rapidStrikeDistance","Distância para a tentativa","Precisa superar a altura da passagem",10,100,"studs")
    parameter(rapidPage,"rapidMaxExposure","Tempo máximo de exposição","Inclui a descida; ao expirar, sobe sem insistir",0.3,3,"s",0.1)
    parameter(rapidPage,"rapidStrikeHold","Janela curta de ataque","Começa ao agendar; respeita o pipeline M1 e o limite de exposição",0.1,1.5,"s",0.05)
    parameter(rapidPage,"rapidCooldown","Intervalo entre passagens","Contado após completar a subida; valores baixos aumentam a exposição",0.1,60,"s",0.1)
    parameter(rapidPage,"rapidDamagePause","Pausa após dano","Independente do intervalo entre investidas",0.1,30,"s",0.1)
    parameter(rapidPage,"rapidMinimumHealth","Vida mínima para entrar","0,85 = 85%; qualquer perda de vida dispara retirada",0.5,1,"fração",0.05)
    parameter(rapidPage,"rapidRetreatHeight","Altura de retorno","Usa o maior valor entre este e a altura normal",75,400,"studs")
    parameter(rapidPage,"rapidReadyTolerance","Tolerância no ponto alto","Só inicia perto da posição de preparação",2,20,"studs")
    parameter(rapidPage,"rapidGain","Resposta da aproximação","Ganho de correção de posição com limite de velocidade",2,30,"x")
    parameter(farm,"skillInterval","Intervalo das skills","Espera mínima entre sequências no farm",1,120,"s",0.5)
    parameter(farm,"skillGap","Espera entre skills","Intervalo adicional entre teclas 1 a 5",0.05,3,"s",0.05)
    parameter(farm,"skillEscapeInterval","Grab: intervalo das skills","Tenta todas as cinco, independentemente dos slots do farm",1,30,"s",0.5)
    parameter(farm,"skillEscapeAttempts","Grab: tentativas de skills","Máximo de sequências por indicação contínua de grab",1,6,"vezes")
    section(farm,"Funções automáticas","Padrão: nuca, sem extras. Indicated segue o ponto indicado do chefe; Nearest permite seguir membros. Nuca fora do alcance não é substituída por um membro.")
    local toggles={}
    for _, item in ipairs({{"aotrAttackFromHeight","Atacar do alto (mantém altura de voo)"},{"aotrNapeApproach","Aproximação baixa: só com Atacar do alto OFF"},{"autoSkills","Usar skills no Auto Farm"},{"grabUseAllSkills","Grab: tentar todas as skills 1–5"},
        {"skillSlot1","Farm: skill 1"},{"skillSlot2","Farm: skill 2"},{"skillSlot3","Farm: skill 3"},{"skillSlot4","Farm: skill 4"},{"skillSlot5","Farm: skill 5"},
        {"autoAttack","Ataque automático"},{"autoRefill","Reabastecer no ponto"},{"autoRetry","Reiniciar missão"},
        {"autoEscapeGrab","Escapar de grab"},{"aotrAttackExtras","Atacar pontos extras (opcional)"},{"aotrAuraEnabled","Múltiplos alvos"},{"autoExecute","Retomar após teleporte"}})do
        local key,title=item[1],item[2]
        table.insert(toggles,{key=key,title=title,node=T.button(scope,farm,title,function()change(function()config[key]=not config[key]end)end)})
    end
    for _,page in ipairs({farm,rapidPage})do
        section(page,"Ataques durante o voo","M1 contínuo não significa dano garantido. Membros distantes são opcionais e não são usados durante a entrada/retirada da Investida.")
        for _,item in ipairs({{"continuousM1","M1 contínuo (pausa na retirada/grab)"},{"aotrFarLimbAttack","Atacar membros quando longe da nuca"}})do
            local key,title=item[1],item[2]
            table.insert(toggles,{key=key,title=title,node=T.button(scope,page,title,function()change(function()config[key]=not config[key]end)end)})
        end
        parameter(page,"m1Interval","Intervalo do M1 contínuo","Configuração compartilhada entre os dois modos",0.05,3,"s",0.05)
        parameter(page,"farLimbDistance","Distância mínima para membros","Só usa membros se a nuca desse titã estiver além desta distância",10,400,"studs")
        parameter(page,"farLimbInterval","Intervalo dos membros distantes","Ainda limitado pelo tempo da chamada do jogo",0.05,5,"s",0.05)
        parameter(page,"farLimbMaxPoints","Membros distantes por titã","Limite separado; respeita também os limites Raid",1,4,"pontos")
    end
    local modes={{key="aotrFocusMode",title="Foco: Nape=nuca / Indicated=marcador / Nearest=próximo",values={"Nape","Indicated","Nearest"}},
        {key="aotrRetryMethod",title="Método do Retry",values={"Auto","Signal","Navigation","Click"}},
        {key="aotrAttackMethod",title="Método de ataque",values={"InputRegister","Input","Remote"}}}
    for _, item in ipairs(modes)do
        local node=T.button(scope,farm,item.title,function()
            change(function()
                local index=table.find(item.values,config[item.key])or 1
                config[item.key]=item.values[index%#item.values+1]
            end)
        end)
        item.node=node
    end
    local raid=pages.Raid
    section(raid,"Modo Raid","ALERTA: alterar altura, alcance e cadência pode ser perigoso. Este modo não prevê ataques nem garante esquiva ou dano aceito pelo servidor.")
    local raidButton=T.button(scope,raid,"",function(button)
        change(function()config.raidMode=not config.raidMode;if config.raidMode then config.rapidApproach=false end end)
        button.Text="Modo Raid: "..(config.raidMode and "ON"or "OFF")
    end)
    raidButton.Text="Modo Raid: "..(config.raidMode and "ON"or "OFF")
    parameter(raid,"raidHeight","Altura mínima Raid","Usa a maior altura entre esta e a configuração normal",20,400,"studs")
    parameter(raid,"raidInterval","Intervalo mínimo Raid","Limita a frequência de rodadas, sem alterar dano real",0.1,15,"s",0.1)
    parameter(raid,"raidTitans","Limite de titãs Raid","Limite adicional por rodada",1,6,"titãs")
    parameter(raid,"raidPoints","Limite de pontos Raid","Limite adicional por titã",1,6,"pontos")
    local settings=pages["Configuração"]
    section(settings,"Aparência e predefinições","Predefinições carregam com automações paradas. Use Auto Farm para iniciar.")
    local function cycle(page,key,title,values)
        local button=T.button(scope,page,title..": "..config[key],function(button)
            local index=table.find(values,config[key])or 1;config[key]=values[index%#values+1]
            button.Text=title..": "..config[key];if key=="uiTheme"then T.apply(config.uiTheme)end;save()
        end)
        return button
    end
    cycle(settings,"uiMode","Modo",{"Auto","Mobile","PC"})
    cycle(settings,"uiTheme","Tema",{"Current","Dark","Light"})
    parameter(settings,"uiScale","Escala da interface","Mobile reduz a janela; escala ajusta o tamanho dos controles",0.55,1.5,"x",0.05)
    local presetName=textInput(settings,"Nome da predefinição","Principal")
    local presetStatus=T.label(settings,"",13,{Size=UDim2.new(1,-8,0,60)})
    local function profileAction(action)
        local ok,result=pcall(action);presetStatus.Text=ok and (tostring(result or "Concluído").."\n"..table.concat(Profiles.names(),", "))or tostring(result)
    end
    T.button(scope,settings,"SALVAR PREDEFINIÇÃO",function()profileAction(function()return Profiles.save(presetName.Text,config)end)end)
    T.button(scope,settings,"CARREGAR PREDEFINIÇÃO",function()
        profileAction(function()stop();Profiles.load(presetName.Text,config);for _,refresh in ipairs(refreshParameters)do refresh()end;T.apply(config.uiTheme);save();return "Carregada; automações paradas."end)
    end)
    T.button(scope,settings,"EXCLUIR PREDEFINIÇÃO",function()profileAction(function()Profiles.delete(presetName.Text)end)end)
    presetStatus.Text=table.concat(Profiles.names(),", ")
    section(settings,"Webhook Discord","Opcional: envia somente eventos genéricos, sem nome, inventário ou logs. URL fica nesta sessão e não entra nas predefinições.")
    textInput(settings,"Cole a URL do seu webhook","",function(text,box)
        local ok=pcall(function()webhook:configure(text)end)
        box.Text=ok and "URL configurada (oculta)"or "URL inválida"
    end)
    local webhookStatus=T.label(settings,"Desativado",13)
    T.button(scope,settings,"ATIVAR / DESATIVAR WEBHOOK",function(button)
        webhook.enabled=not webhook.enabled;button.Text=webhook.enabled and "WEBHOOK ON"or "WEBHOOK OFF"
    end)
    T.button(scope,settings,"ENVIAR TESTE",function()webhook:send("Teste solicitado pelo usuário")end)
    local previousMission,previousError=nil,nil
    local lobby=pages.Lobby
    section(lobby,"Integrações do lobby","Diagnóstico automático sem gastar recursos. Upgrade, prestígio, compras e exclusão aguardam controles, custos e confirmação verificáveis.")
    cycle(lobby,"lobbyAttackPath","Ataque (meio)",{"Esquerda","Direita"})
    cycle(lobby,"lobbyDefensePath","Defesa (direita)",{"Esquerda","Direita"})
    cycle(lobby,"lobbySupportPath","Suporte (esquerda)",{"Esquerda","Direita"})
    T.label(lobby,"Os caminhos são preferências; a compra de nós ainda não está integrada.",13,{Size=UDim2.new(1,-8,0,60)})
    local lobbyContent=""
    local lobbySection="Equipment"
    local lobbyPages={};local lobbyPage=1;local copyLobby
    local sections={"Equipment","Inventory","Market","Todos"}
    T.button(scope,lobby,"MENU DO DIAGNÓSTICO: Equipment",function(button)
        local index=table.find(sections,lobbySection)or 1;lobbySection=sections[index%#sections+1]
        button.Text="MENU DO DIAGNÓSTICO: "..lobbySection
    end)
    local lobbyStatus=T.label(lobby,"Abra o menu desejado. O diagnóstico inclui controles ocultos, ícones e textos próximos.",13,{Size=UDim2.new(1,-8,0,100)})
    local lobbyResults
    local function navigate(path)
        local ok,result=pcall(function()
            return LobbyNavigation.activate(game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui"),path,adapter.inputAttack.lastInput)
        end)
        lobbyStatus.Text=tostring(result)
        if not ok then log:write("info","lobby-navigation",result)end
    end
    T.button(scope,lobby,"ABRIR EQUIPAMENTO",function()navigate(LobbyNavigation.paths.Equipment)end)
    local category="Upgrades"
    T.button(scope,lobby,"CATEGORIA: Upgrades",function(button)
        local categories={"Upgrades","Skills","Perks","Prestige"}
        category=categories[(table.find(categories,category)or 1)%#categories+1];button.Text="CATEGORIA: "..category
    end)
    T.button(scope,lobby,"ABRIR CATEGORIA SELECIONADA",function()navigate(LobbyNavigation.paths[category])end)
    local attribute=1
    T.button(scope,lobby,"ATRIBUTO: ODM_Damage",function(button)
        attribute=attribute%#LobbyNavigation.attributes+1;button.Text="ATRIBUTO: "..LobbyNavigation.attributes[attribute]
    end)
    T.button(scope,lobby,"SELECIONAR ATRIBUTO NAS MELHORIAS",function()
        navigate("Interface/Equipment/Stats/Blades/"..LobbyNavigation.attributes[attribute].."/Inner/Interact")
    end)
    T.button(scope,lobby,"MOSTRAR BOTÕES PRINCIPAIS DA TELA ATUAL",function()
        local ok,result=pcall(function()
            local gui=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local rows,stats=LobbyDiagnostic.mainButtons(gui)
            lobbyResults.Text=LobbyDiagnostic.format(rows,stats)
            local content=game:GetService("HttpService"):JSONEncode({version="0.9.2",section="Tela atual",elements=rows,stats=stats})
            lobbyContent=content;lobbyPages=LobbyDiagnostic.pages(rows,stats,"Tela atual");lobbyPage=1
            copyLobby.Text="COPIAR PARTE 1 / "..#lobbyPages
            return tostring(stats.visibleButtons).." botões visíveis; resumo de até 60 abaixo. Isso não executa cliques."
        end)
        lobbyStatus.Text=tostring(result)
        if not ok then log:write("error","lobby-buttons",result)end
    end,62)
    T.button(scope,lobby,"SALVAR LOG COMPLETO EM ARQUIVO",function()
        local ok,result=pcall(function()
            local files,count,omitted=LobbyDiagnostic.saveAll(game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui"),log:snapshot())
            return tostring(count).." elementos; "..omitted.." omitidos. Salvo: "..files..". Procure na pasta workspace/arquivos do executor e envie o JSON aqui."
        end)
        lobbyStatus.Text=tostring(result)
        if not ok then log:write("error","lobby-export",result)end
    end,62)
    T.button(scope,lobby,"LER ATRIBUTO, SALDOS E REQUISITOS",function()
        local ok,result=pcall(function()return LobbyState.read(game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui"))end)
        lobbyResults.Text=tostring(result)
        lobbyStatus.Text=ok and "Leitura dos caminhos confirmados; nenhuma ação de gasto executada"or tostring(result)
    end,62)
    T.button(scope,lobby,"IDENTIFICAR INTERFACE DO LOBBY",function()
        local ok,result=pcall(function()
            local rows,stats=LobbyDiagnostic.scan(game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui"),lobbySection)
            local report=LobbyDiagnostic.format(rows,stats)
            lobbyResults.Text=report
            local encoded,content=pcall(function()return game:GetService("HttpService"):JSONEncode({version="0.9.2",elements=rows,stats=stats})end)
            lobbyContent=encoded and content or report
            lobbyPages=LobbyDiagnostic.pages(rows,stats,lobbySection);lobbyPage=1
            copyLobby.Text="COPIAR PARTE 1 / "..tostring(#lobbyPages)
            local _,message=LobbyDiagnostic.export(lobbyContent)
            return tostring(#rows).." elementos encontrados. "..message..". Role para ver o resultado abaixo. Nenhum clique executado."
        end)
        lobbyStatus.Text=tostring(result);if not ok then log:write("error","lobby-diagnostic",result)end
    end,64)
    copyLobby=T.button(scope,lobby,"COPIAR PARTE DO DIAGNÓSTICO",function(button)
        if lobbyContent==""then lobbyStatus.Text="Execute Identificar primeiro";return end
        if type(setclipboard)~="function"then lobbyStatus.Text="Sem clipboard; o resultado está no painel";return end
        local current=lobbyPage
        local ok=pcall(setclipboard,lobbyPages[current]or lobbyContent)
        if ok then
            lobbyStatus.Text="Parte "..current.." / "..#lobbyPages.." copiada. Cole no chat antes de copiar a próxima."
            lobbyPage=current%math.max(1,#lobbyPages)+1
            button.Text="COPIAR PARTE "..lobbyPage.." / "..#lobbyPages
        else lobbyStatus.Text="Falha ao copiar; consulte o resultado abaixo"end
    end)
    T.button(scope,lobby,"IMPRIMIR RESULTADO NO F9",function()
        if lobbyContent==""then lobbyStatus.Text="Execute Identificar primeiro";return end
        for start=1,#lobbyContent,1800 do print("[Project Titan lobby] "..string.sub(lobbyContent,start,start+1799))end
    end)
    lobbyResults=T.make("TextBox",lobby,{Text="Resultado aparecerá aqui",ClearTextOnFocus=false,MultiLine=true,TextEditable=false,
        TextWrapped=true,TextSize=12,Font=Enum.Font.Code,TextColor3=T.text,BackgroundColor3=T.card,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
        Size=UDim2.new(1,-8,0,100),AutomaticSize=Enum.AutomaticSize.Y})
    local equip=pages.Equipamento
    section(equip,"Equipamento","A reposição é confirmada pelas leituras do HUD; não pelo retorno de uma chamada.")
    local equipmentText=T.label(equip,"Aguardando leituras",14,{Size=UDim2.new(1,-8,0,144),TextColor3=T.muted,TextYAlignment=Enum.TextYAlignment.Top})
    local function selector(key,title)
        local index=0
        local node=T.button(scope,equip,title,function(button)
            local candidates=adapter:gasCandidates()
            if #candidates==0 then button.Text=title.." • nenhum indicador numérico";return end
            index=index%(#candidates+1)+1
            local choice=candidates[index];config[key]=choice and choice.path or ""
            button.Text=title.."\n"..(choice and (choice.path.." = "..choice.text)or "Não configurado");save()
        end,66)
        if config[key]~="" then node.Text=title.."\n"..config[key]end
    end
    selector("aotrBladeHudPath","Indicador de durabilidade")
    selector("aotrGasHudPath","Indicador de gás")
    T.button(scope,equip,"IR AO REABASTECIMENTO",function()adapter.equipment.manual=true end,48)
    section(pages["Diagnóstico"],"Estado das integrações")
    local dependencies=T.label(pages["Diagnóstico"],"Use Verificar dependências",13,{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.Code})
    T.button(scope,pages["Diagnóstico"],"VERIFICAR DEPENDÊNCIAS",function()
        local ok,result=pcall(function()return adapter:diagnose()end);dependencies.Text=tostring(result)
        if not ok then log:write("error","diagnostics",result)end
    end)
    local metrics=T.label(pages["Diagnóstico"],"",13,{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,Font=Enum.Font.Code})
    section(pages.Logs,"Registro da sessão")
    T.button(scope,pages.Logs,"ENVIAR REGISTROS AO F9",function()for _, row in ipairs(log:snapshot())do print("[Project Titan]",row.time,row.event,row.detail)end end)
    local logs=T.label(pages.Logs,"Sem registros",13,{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,Font=Enum.Font.Code})
    local footer=T.make("Frame",frame,{BackgroundColor3=T.card,BorderSizePixel=0,Position=UDim2.new(0,12,1,-48),Size=UDim2.new(1,-24,0,36)})
    T.round(footer,9)
    local status=T.label(footer,"PARADO",13,{Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-126,1,0)})
    local stopFooter=T.button(scope,footer,"PARAR",stop,28)
    stopFooter.Size=UDim2.fromOffset(86,28);stopFooter.Position=UDim2.new(1,-94,0,4);stopFooter.TextColor3=T.danger
    local function resize()
        local camera=workspace.CurrentCamera;if not camera then return end
        local viewport=camera.ViewportSize
        local mobile=config.uiMode=="Mobile"or(config.uiMode=="Auto"and game:GetService("UserInputService").TouchEnabled)
        local requested=math.clamp(config.uiScale,0.55,1.5)
        local width=mobile and 490 or 720;local height=mobile and 450 or 650
        local fit=math.min(requested,(viewport.X-24)/width,(viewport.Y-28)/height)
        scale.Scale=math.max(0.1,fit)
        frame.Size=UDim2.fromOffset(width,height)
        local wide=true
        nav.Position=UDim2.fromOffset(12,78);nav.Size=wide and UDim2.new(0,148,1,-138)or UDim2.new(1,-24,0,42)
        for i,name in ipairs(names)do
            local tab=tabButtons[name]
            tab.Position=wide and UDim2.fromOffset(0,(i-1)*52)or UDim2.new((i-1)/4,0,0,0)
            tab.Size=wide and UDim2.new(1,0,0,44)or UDim2.new(0.25,-4,1,0);tab.TextSize=wide and 16 or 13
            tab.TextColor3=name==selected and T.accent or T.muted
            local page=pages[name]
            page.Position=UDim2.fromOffset(wide and 176 or 12,wide and 78 or 132)
            page.Size=UDim2.new(1,-(wide and 188 or 24),1,-(wide and 138 or 192))
        end
    end
    local elapsed=0
    scope:add(game:GetService("RunService").Heartbeat:Connect(function(dt)
        elapsed+=dt;if elapsed<0.4 then return end;elapsed=0;resize()
        webhookStatus.Text=webhook.status
        if webhook.enabled then
            local ok,mission=pcall(function()return adapter:mission()end)
            if ok then
                if mission~=previousMission and (mission=="Complete"or mission=="Failed")then webhook:send("Missão: "..mission)end
                previousMission=mission
            end
            local snapshot=log:snapshot();local last=snapshot[#snapshot]
            if last and last.level=="error"and tostring(last.time)..last.event~=previousError then
                previousError=tostring(last.time)..last.event;webhook:send("Erro de automação registrado; consulte o painel")
            end
        end
        blockingReason.Text=engine.lastDependency and ("Aguardando: "..tostring(engine.lastDependency))or ""
        master.Text=config.farmActive and not config.rapidApproach and "FARM ALTO ON  •  DESLIGAR"or "ATIVAR FARM ALTO"
        rapidMaster.Text=config.farmActive and config.rapidApproach and "INVESTIDA ON  •  DESLIGAR"or "ATIVAR INVESTIDA"
        rapidStatus.Text=adapter.rapid.state.." / "..adapter.rapid.reason.."\nAgendados: "..adapter.rapid.attempts.." | Registros retornados: "..adapter.rapid.registrations.." | Cancelados sem retorno: "..adapter.rapid.canceled.."\n"..(engine.lastDependency or "")
        status.Text=(config.farmActive and "ATIVO  /  "or "PRÉVIA  /  ")..engine.state
        status.TextColor3=config.farmActive and T.accent or T.muted
        for _,item in ipairs(toggles)do local key=item.key;item.node.Text=item.title.."   "..(config[key]and "● ON"or "○ OFF");item.node.TextColor3=config[key]and T.accent or T.muted end
        for _, item in ipairs(modes)do item.node.Text=item.title.."  /  "..config[item.key]end
        local sample=adapter:readEquipment()
        equipmentText.Text="Reservas: "..tostring(sample.sets).." / "..tostring(sample.maxSets)
            .."\nDurabilidade: "..(sample.durability and string.format("%.0f%%",sample.durability*100)or "desconhecida")
            .."\nGás: "..(sample.gas and string.format("%.0f%%",sample.gas*100)or "desconhecido")
            .."\nEstado: "..adapter.equipment.status
        local parts={};for key,value in pairs(adapter:metrics())do table.insert(parts,key.." = "..tostring(value))end;table.sort(parts);metrics.Text=table.concat(parts,"\n")
        local rows=log:snapshot();local lines={}
        for i=math.max(1,#rows-24),#rows do table.insert(lines,string.format("%.1f  %s\n%s",rows[i].time,rows[i].event,rows[i].detail))end
        logs.Text=table.concat(lines,"\n\n")
    end))
    resize();scope:add(function()disposed=true end)
    return scope
end
return Dashboard

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
    if not button or not button:IsA("GuiObject") or button.AbsoluteSize.X <= 0 or button.AbsoluteSize.Y <= 0 then return false end
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
    local button, title,root = self:locate()
    if method=="Signal" then
        if not self:visible(root or button) then return "RetryWaitingUI",false end
        if not button or not button:IsA("GuiButton") or type(firesignal)~="function" or type(getconnections)~="function" then return "RetrySignalUnavailable",false end
        local function connected(event)
            local ok,rows=pcall(getconnections,event)
            return ok and #rows>0
        end
        if connected(button.MouseButton1Click) then firesignal(button.MouseButton1Click);return "RetryHandlerSent",true end
        if connected(button.MouseButton1Down) then
            local center=button.AbsolutePosition+button.AbsoluteSize/2
            self.release=function()firesignal(button.MouseButton1Up,center.X,center.Y)end
            local ok,err=pcall(function()firesignal(button.MouseButton1Down,center.X,center.Y);task.wait(self.config.aotrRetryHold or 0.25)end)
            self:cancel();if not ok then error(err) end
            return "RetryHandlerSent",true
        end
        if self.lastInput and connected(button.Activated) then
            firesignal(button.Activated,self.lastInput,0);return "RetryActivatedSent",true
        end
        return "RetrySignalUnavailable",false
    end
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
    local scroll=parent
    while scroll and not scroll:IsA("ScrollingFrame")do scroll=scroll.Parent end
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
        if scroll and scroll.Parent then scroll.ScrollingEnabled=scrolling end
        ended(cancelled)
    end
    scope:add(surface.InputBegan:Connect(function(input)
        if pointer then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        pointer = input; mouse = input.UserInputType == Enum.UserInputType.MouseButton1
        if scroll then scrolling=scroll.ScrollingEnabled;scroll.ScrollingEnabled=false end
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
    return surface,render
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
factories["ui/Theme"] = function(require)
local Theme={}
Theme.bg=Color3.fromRGB(12,17,23)
Theme.card=Color3.fromRGB(22,29,37)
Theme.border=Color3.fromRGB(43,55,67)
Theme.text=Color3.fromRGB(232,238,242)
Theme.muted=Color3.fromRGB(145,160,173)
Theme.accent=Color3.fromRGB(93,210,165)
Theme.danger=Color3.fromRGB(222,96,108)
local bindings=setmetatable({},{__mode="k"})
local palettes={
    Current={bg={12,17,23},card={22,29,37},border={43,55,67},text={232,238,242},muted={145,160,173},accent={93,210,165},danger={222,96,108}},
    Dark={bg={5,6,9},card={13,15,21},border={35,37,48},text={240,240,245},muted={160,162,175},accent={125,185,255},danger={255,115,130}},
    Light={bg={235,239,245},card={251,252,255},border={185,195,210},text={24,32,46},muted={75,90,110},accent={0,110,85},danger={175,35,55}},
}
function Theme.apply(name)
    local palette=palettes[name]or palettes.Current
    for key,rgb in pairs(palette)do Theme[key]=Color3.fromRGB(table.unpack(rgb))end
    for node,props in pairs(bindings)do
        for property,key in pairs(props)do pcall(function()node[property]=Theme[key]end)end
    end
end
local order=setmetatable({},{__mode="k"})
function Theme.make(class,parent,properties)
    local node=Instance.new(class)
    local props={}
    for key,value in pairs(properties or {}) do
        node[key]=value
        for _,semantic in ipairs({"bg","card","border","text","muted","accent","danger"})do
            if value==Theme[semantic]then props[key]=semantic;break end
        end
    end
    bindings[node]=props
    if parent then
        if node:IsA("GuiObject")then order[parent]=(order[parent]or 0)+1;node.LayoutOrder=order[parent]end
        node.Parent=parent
    end
    return node
end
function Theme.round(node,radius)
    Theme.make("UICorner",node,{CornerRadius=UDim.new(0,radius or 12)})
end
function Theme.stroke(node,color)
    Theme.make("UIStroke",node,{Color=color or Theme.border,Thickness=1,Transparency=0.15})
end
function Theme.label(parent,text,size,props)
    local data={Text=text,TextSize=size or 16,Font=Enum.Font.Gotham,TextColor3=Theme.text,
        BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Size=UDim2.new(1,0,0,28)}
    for key,value in pairs(props or {}) do data[key]=value end
    return Theme.make("TextLabel",parent,data)
end
function Theme.button(scope,parent,text,callback,height)
    local node=Theme.make("TextButton",parent,{Text=text,TextSize=16,Font=Enum.Font.GothamMedium,
        TextColor3=Theme.text,BackgroundColor3=Theme.card,AutoButtonColor=true,TextWrapped=true,
        BorderSizePixel=0,Size=UDim2.new(1,-8,0,height or 44)})
    Theme.round(node,10);Theme.stroke(node)
    scope:add(node.Activated:Connect(function(input)
        if Theme.onInput and typeof(input)=="InputObject" then Theme.onInput(input)end
        callback(node,input)
    end))
    return node
end
return Theme

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
return import("Main")
]========]
local bootstrap=[========[
local runtime,bootstrap=...
local Main=assert(loadstring(runtime))()
local environment = (getgenv and getgenv()) or _G
local ready=false
for _ = 1, 240 do
    local player = game:GetService("Players").LocalPlayer
    if game:IsLoaded() and player and player:FindFirstChildOfClass("PlayerGui") then ready=true;break end
    task.wait(0.5)
end
assert(ready,"Project Titan: PlayerGui did not become ready within 120 seconds")
local previous = environment.MahmutAOTRController
if type(previous) == "table" and type(previous.destroy) == "function" then pcall(function() previous:destroy() end) end
local defaults = { mode="AOTR" }
-- Main supplies all other defaults; only explicit launch overrides are persisted here.
local defaultModule=Main.defaultConfig
if defaultModule then defaults=defaultModule end
local initial = table.clone(defaults)
for key, value in pairs({
    mode = "AOTR", aotrActionsEnabled = false, autoAttack = true,
    autoReload = false, autoRetry = true, moveSpeed = 150, autoExecute = true,
    attackRange = 175, attackCooldown = 0.6, maxFailures = 3, tick = 0.1,
    aotrHoverHeight = 75, aotrAscentSpeed = 150,
    aotrAuraEnabled = true, aotrAuraRadius = 175, aotrSteeringGain = 1,
    aotrCombatMode = "Source", aotrAttackMethod = "InputRegister", aotrInputMethod = "Signal",
    aotrRetryMethod = "Auto",
}) do initial[key] = value end
if type(environment.MahmutAOTRResumeConfig) == "table" then
    for key, value in pairs(environment.MahmutAOTRResumeConfig) do
        if initial[key] ~= nil and typeof(initial[key]) == typeof(value) then initial[key] = value end
    end
    environment.MahmutAOTRResumeConfig = nil
end
local config = Main.Preferences.load(initial)
local controller = Main.start({ config = config })
environment.MahmutAOTRController = controller
controller.resumeConnection = Main.Resume.attachInline(controller,runtime,bootstrap)
print("[Project Titan] v0.9.2: retry recovery, nested grab detection, inline teleport bootstrap.")
return controller
]========]
return assert(loadstring(bootstrap))(runtime,bootstrap)
