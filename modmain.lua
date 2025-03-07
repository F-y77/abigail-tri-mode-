GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k)end})

local enable_night_check = GetModConfigData("enable_night_check")

-- 暗影强化状态的管理
local SHADOW_BUFF_DURATION = 8
local MAX_SHADOW_BUFF_DURATION = 160
local SHADOW_BUFF_COOLDOWN = 10 -- 添加10秒冷却时间
local shadow_buff_timer = 0
local shadow_buff_cooldown_timer = 0 -- 冷却计时器
local is_shadow_buffed = false

-- 暗影形态状态管理
local is_shadow_form = false

-- 更新暗影形态属性的函数
local function UpdateShadowFormStats(ghost)
    if not ghost or not ghost.components.locomotor or not ghost.components.combat then
        return
    end

    -- 重置所有修改器
    ghost.components.locomotor:RemoveExternalSpeedMultiplier("shadow_form")
    ghost.components.combat.externaldamagemultipliers:RemoveModifier("shadow_form")

    -- 如果不是暗影形态，直接返回
    if not is_shadow_form then return end

    -- 根据时间设置不同的属性
    if TheWorld.state.isnight or TheWorld.state.isdusk then
        -- 夜晚和黄昏时速度和攻击翻倍
        ghost.components.locomotor:SetExternalSpeedMultiplier("shadow_form", 2)
        ghost.components.combat.externaldamagemultipliers:SetModifier("shadow_form", 2)
    elseif TheWorld.state.isnoon then
        -- 中午时速度和攻击减半
        ghost.components.locomotor:SetExternalSpeedMultiplier("shadow_form", 0.5)
        ghost.components.combat.externaldamagemultipliers:SetModifier("shadow_form", 0.5)
    else
        -- 其他时间保持正常
        ghost.components.locomotor:SetExternalSpeedMultiplier("shadow_form", 1)
        ghost.components.combat.externaldamagemultipliers:SetModifier("shadow_form", 1)
    end
end

-- 共用的切换形态函数
local function ToggleAbigailForm(doer)
    if not TheWorld.ismastersim then return false end
    
    local ghostlybond = doer.components.ghostlybond
    
    if ghostlybond == nil or ghostlybond.ghost == nil or not ghostlybond.summoned then
        return false, "NOGHOST"
    elseif enable_night_check == "yes" and not TheWorld.state.isnight then
        return false, "NOTNIGHT"
    end

    local ghost = ghostlybond.ghost
    -- 检查当前形态并切换到下一个形态
    if not ghost:HasTag("gestalt") and not ghost:HasTag("shadow_gestalt") then
        -- 从普通形态切换到月亮形态
        ghost:ChangeToGestalt(true)
        ghost:RemoveTag("shadow_gestalt")
        is_shadow_form = false
        return true, "MOON"
    elseif ghost:HasTag("gestalt") and not ghost:HasTag("shadow_gestalt") then
        -- 从月亮形态切换到暗影形态
        ghost:ChangeToGestalt(true)
        ghost:AddTag("shadow_gestalt")
        is_shadow_form = true
        if ghost.AnimState then
            ghost.AnimState:SetMultColour(0.5, 0.5, 0.5, 1)
        end
        UpdateShadowFormStats(ghost)
        return true, "SHADOW"
    else
        -- 从暗影形态切换回普通形态
        ghost:ChangeToGestalt(false)
        ghost:RemoveTag("shadow_gestalt")
        is_shadow_form = false
        if ghost.AnimState then
            ghost.AnimState:SetMultColour(1, 1, 1, 1)
        end
        UpdateShadowFormStats(ghost)
        return true, "NORMAL"
    end
end

-- 暗影强化形态切换函数
local function ToggleShadowBuff(doer)
    if not TheWorld.ismastersim then return false end
    
    local ghostlybond = doer.components.ghostlybond
    
    if ghostlybond == nil or ghostlybond.ghost == nil or not ghostlybond.summoned then
        return false, "NOGHOST"
    end

    -- 检查技能是否在冷却中
    if shadow_buff_cooldown_timer > 0 then
        return false, "COOLDOWN"
    end

    local ghost = ghostlybond.ghost
    
    -- 如果已经在强化状态，则取消强化
    if is_shadow_buffed then
        is_shadow_buffed = false
        shadow_buff_timer = 0
        if ghost.components.combat then
            ghost.components.combat.externaldamagemultipliers:RemoveModifier("shadow_buff")
            ghost.components.combat.externaldamagetakenmultipliers:RemoveModifier("shadow_buff")
        end
        if ghost.AnimState then
            ghost.AnimState:SetMultColour(1, 1, 1, 1)
        end
        return true, "BUFF_OFF"
    else
        -- 激活强化状态
        is_shadow_buffed = true
        shadow_buff_timer = SHADOW_BUFF_DURATION
        if ghost.components.combat then
            ghost.components.combat.externaldamagemultipliers:SetModifier("shadow_buff", 45)
            ghost.components.combat.externaldamagetakenmultipliers:SetModifier("shadow_buff", 25)
        end
        if ghost.AnimState then
            ghost.AnimState:SetMultColour(0.3, 0, 0.3, 1) -- 紫色调
        end
        -- 开始冷却计时
        shadow_buff_cooldown_timer = SHADOW_BUFF_COOLDOWN
        return true, "BUFF_ON"
    end
end

-- 添加时间变化监听
AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then return end
    
    -- 监听时间变化
    inst:WatchWorldState("isnight", function()
        if GLOBAL.ThePlayer and GLOBAL.ThePlayer.components.ghostlybond then
            local ghost = GLOBAL.ThePlayer.components.ghostlybond.ghost
            if ghost then
                UpdateShadowFormStats(ghost)
            end
        end
    end)
    
    inst:WatchWorldState("isdusk", function()
        if GLOBAL.ThePlayer and GLOBAL.ThePlayer.components.ghostlybond then
            local ghost = GLOBAL.ThePlayer.components.ghostlybond.ghost
            if ghost then
                UpdateShadowFormStats(ghost)
            end
        end
    end)
    
    inst:WatchWorldState("isnoon", function()
        if GLOBAL.ThePlayer and GLOBAL.ThePlayer.components.ghostlybond then
            local ghost = GLOBAL.ThePlayer.components.ghostlybond.ghost
            if ghost then
                UpdateShadowFormStats(ghost)
            end
        end
    end)
    
    inst:DoPeriodicTask(1, function()
        -- 更新强化状态计时器
        if is_shadow_buffed and shadow_buff_timer > 0 then
            shadow_buff_timer = shadow_buff_timer - 1
            if shadow_buff_timer <= 0 then
                -- 强化时间结束，重置状态
                local player = GLOBAL.ThePlayer
                if player then
                    ToggleShadowBuff(player)
                    player.components.talker:Say("暗影强化已结束")
                end
            end
        end
        
        -- 更新冷却时间计时器
        if shadow_buff_cooldown_timer > 0 then
            shadow_buff_cooldown_timer = shadow_buff_cooldown_timer - 1
        end
    end)
end)

-- 添加击杀事件监听
AddPrefabPostInit("wendy", function(inst)
    if not TheWorld.ismastersim then return end
    
    local old_OnKill = inst.components.combat.onkilledother
    inst.components.combat.onkilledother = function(doer, victim)
        if old_OnKill then
            old_OnKill(doer, victim)
        end
        
        if is_shadow_buffed then
            -- 延长强化时间
            shadow_buff_timer = math.min(shadow_buff_timer + SHADOW_BUFF_DURATION, MAX_SHADOW_BUFF_DURATION)
            doer.components.talker:Say("暗影强化延长了！剩余" .. shadow_buff_timer .. "秒")
        end
    end
end)

-- 月晷的修改
AddPrefabPostInit("moondial", function(inst)
    if not TheWorld.ismastersim then return end
    
    if inst.components.ghostgestalter then
        inst.components.ghostgestalter.domutatefn = function(inst, doer)
            local success, form = ToggleAbigailForm(doer)
            return success
        end
    end
end)

-- 添加按键监听
GLOBAL.TheInput:AddKeyHandler(
    function(key, down)
        if down then
            if key == GLOBAL.KEY_O then
                if GLOBAL.ThePlayer ~= nil then
                    local success, result = ToggleAbigailForm(GLOBAL.ThePlayer)
                    if not success then
                        if result == "NOGHOST" then
                            GLOBAL.ThePlayer.components.talker:Say("我需要先召唤阿比盖尔")
                        elseif result == "NOTNIGHT" then
                            GLOBAL.ThePlayer.components.talker:Say("只能在夜晚切换形态")
                        end
                    else
                        -- 显示切换后的形态提示
                        if result == "MOON" then
                            GLOBAL.ThePlayer.components.talker:Say("阿比盖尔切换为月亮形态")
                        elseif result == "SHADOW" then
                            local timeStr = ""
                            if TheWorld.state.isnight or TheWorld.state.isdusk then
                                timeStr = "，当前为夜晚/黄昏时间，速度和攻击翻倍"
                            elseif TheWorld.state.isnoon then
                                timeStr = "，当前为正午时间，速度和攻击减半"
                            end
                            GLOBAL.ThePlayer.components.talker:Say("阿比盖尔切换为暗影形态" .. timeStr)
                        else
                            GLOBAL.ThePlayer.components.talker:Say("阿比盖尔恢复普通形态")
                        end
                    end
                end
            elseif key == GLOBAL.KEY_L then
                if GLOBAL.ThePlayer ~= nil then
                    local success, result = ToggleShadowBuff(GLOBAL.ThePlayer)
                    if not success then
                        if result == "NOGHOST" then
                            GLOBAL.ThePlayer.components.talker:Say("我需要先召唤阿比盖尔")
                        elseif result == "COOLDOWN" then
                            GLOBAL.ThePlayer.components.talker:Say("暗影强化还在冷却中，剩余" .. shadow_buff_cooldown_timer .. "秒")
                        end
                    else
                        if result == "BUFF_ON" then
                            GLOBAL.ThePlayer.components.talker:Say("阿比盖尔获得暗影强化！持续" .. SHADOW_BUFF_DURATION .. "秒")
                        else
                            GLOBAL.ThePlayer.components.talker:Say("阿比盖尔的暗影强化已解除")
                        end
                    end
                end
            end
        end
    end
)