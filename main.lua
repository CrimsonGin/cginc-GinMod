log.info("Loading ".._ENV["!guid"]..".") --logging our mod being loaded.
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto(true) --what the mod knows to use.

local PATH = _ENV["!plugins_mod_folder_path"]--This variable is just the path where our mod is
local SOUND_PATH = path.combine(PATH, "Sounds/")--Where our sounds our if we have them.
local GIN = "Gin"--the Namespace

local initialise = function()--We need this to make sure the game loads before our mod does.

--#region Assets
    --helper function for getting sprite paths concisely, just saves having to write long lines like:
    --Resources.sprite_load(Namespace,"Animation",path.combine(SPRITE_PATH,"Animation.png"),Frames,X,Y)
    --Its usage is load_sprite("Animation","Animation.png",Frames,X,Y)
    local load_sprite = function (id, filename, frames, orig_x, orig_y, speed, left, top, right, bottom)
        local sprite_path = path.combine(PATH, "Sprites",  filename)
        return Resources.sprite_load(GIN, id, sprite_path, frames, orig_x, orig_y, speed, left, top, right, bottom)
    end
    --#region Sprites
        --#region Non-skill sprites
            local non_Skill_Sprites =
            {
                idle = load_sprite("gin_idle", "ginIdle.png", 5, 18,  22),
                walk = load_sprite("gin_run", "ginRun.png", 8, 15, 19),
                walkBack = load_sprite("gin_walkBack", "ginWalkBack.png", 8, 15, 19),
                jump = load_sprite("gin_jump", "ginJump.png", 1, 48, 69),
                jump_peak = load_sprite("gin_jump_peak", "ginPeak.png", 1, 48, 69),
                fall = load_sprite("gin_fall", "ginFall.png", 1, 48, 69),
                climb = load_sprite("gin_climb", "ginClimb.png", 3, 48, 55),
                death = load_sprite("gin_death", "ginDeath.png", 19, 48, 69),
                decoy = load_sprite("gin_decoy", "decoy.png", 0, 48, 69),
            }
        --#endregion
        --#region Skill Sprites
            local spr_slap = load_sprite("gin_atk1", "ginAtk1.png", 4, 48, 69)
            local spr_throw = load_sprite("gin_atk2", "ginThrowDirt.png", 6, 48, 69)
            local spr_panic = load_sprite("gin_panic", "ginPanic.png", 16, 15, 19)
            local spr_cry = load_sprite("ginCry", "ginCry.png", 17, 48, 69)

            --extra
            local spr_dirt = load_sprite("gin_dirt", "dirt.png", 3, 6, 6, 0.25, 2, 2, 9, 9)
            local spr_dirtCloned = load_sprite("gin_dirt_cloned", "dirtCloned.png", 4, 6, 6, 0.25, 2, 2, 9, 9)
        --#endregion
        --#region Icons, portraits, etc
            local spr_skills = load_sprite("gin_skills", "ginSkills.png", 5, 0, 0) 
            local spr_portrait = load_sprite("gin_portrait", "ginPortrait.png", 3)
            local spr_portrait_small = load_sprite("gin_portrait_small", "ginPortraitSmall.png") 
            local spr_loadout = load_sprite("gin_loadout", "ginLoadout.png", 30, 28, 0) 
        --#endregion
    --#endregion
    --#region Sounds
        local wet_slap = Resources.sfx_load(GIN, "ginWetSlap", path.combine(SOUND_PATH, "wetSlap.ogg"))
        local gin_panic = Resources.sfx_load(GIN, "ginPanic", path.combine(SOUND_PATH, "panic.ogg"))
        local gin_cry = Resources.sfx_load(GIN, "ginCry", path.combine(SOUND_PATH, "no-no-no-no.ogg"))
    --#endregion
--#endregion

--#region Survivor setup
    local gin = Survivor.new(GIN, "Gin")


    gin:onInit(function(actor) --This stuff is for walking backwards!!!
        local walk_half = Array.new()
        local idle_half = Array.new()
        local jump_half = Array.new()
        local jump_peak_half = Array.new()
        local fall_half = Array.new()
        idle_half:push(non_Skill_Sprites.idle, non_Skill_Sprites.idle, 0)
        walk_half:push(non_Skill_Sprites.walk, non_Skill_Sprites.walkBack, 0, non_Skill_Sprites.walkBack)
        jump_half:push(non_Skill_Sprites.jump, non_Skill_Sprites.jump, 0)
        jump_peak_half:push(non_Skill_Sprites.jump_peak, non_Skill_Sprites.jump_peak, 0)
        fall_half:push(non_Skill_Sprites.fall, non_Skill_Sprites.fall, 0)
        actor.sprite_walk_half = walk_half
        actor.sprite_idle_half = idle_half
        actor.sprite_jump_half = jump_half
        actor.sprite_jump_peak_half = jump_peak_half
        actor.sprite_fall_half = fall_half
        actor:survivor_util_init_half_sprites()
    end)

    gin:set_primary_color(Color.from_rgb(90, 80, 165)) --This is used for a variety of things in game
    gin.sprite_loadout = spr_loadout
    gin.sprite_portrait = spr_portrait
    gin.sprite_portrait_small = spr_portrait_small
    gin.sprite_title = non_Skill_Sprites.walk
    gin.sprite_idle = non_Skill_Sprites.idle
    gin.sprite_credits = spr_cry
    gin:set_animations(non_Skill_Sprites)
    gin:set_cape_offset(5, -2, 0, 2)
    gin:set_stats_base({
        maxhp = 3,
        damage = 14,
        regen = 0.01,
    })
    gin:set_stats_level({
        maxhp = 3,
        damage = 1.7,
        regen = 0.002,
        armor = 4,
    })

    --#region Dirt for secondary skill.
        -- dirt objects
        local obj_dirt = Object.new(GIN, "gin_Dirt")
        obj_dirt.obj_sprite = spr_dirt
        obj_dirt.obj_depth = 1
        local obj_dirt_cloned = Object.new(GIN, "gin_Dirt_Cloned")
        obj_dirt_cloned.obj_sprite = spr_dirtCloned
        obj_dirt_cloned.obj_depth = 1
        function dirtStep(inst)
            local data = inst:get_data()
            inst.x = inst.x + data.hspeed
            inst.y = inst.y + data.vspeed
            -- Hit the first enemy actor that's been collided with
            local actor_collisions, _ = inst:get_collisions(gm.constants.pActorCollisionBase)
            for _, actor in ipairs(actor_collisions) do
                if data.parent:attack_collision_canhit(actor) then
                    -- Deal damage
                    local dmg = data.damage_coeff 

                    for i=1, data.clone_multiplier do -- Multiple hits per clone, boosting damage and rerolling procs
                        data.parent:fire_direct(actor, dmg, data.angle, inst.x, inst.y, gm.constants.sEfSlash)
                    end
                    -- Destroy the dirt
                    inst:destroy()
                    return
                end
            end
            -- Hitting terrain destroys the dirt
            if inst:is_colliding(gm.constants.pSolidBulletCollision) then
                inst:destroy()
                return
            end
            -- Check we're within stage bounds
            local stage_width = GM._mod_room_get_current_width()
            local stage_height = GM._mod_room_get_current_height()
            if inst.x < -16 or inst.x > stage_width + 16
            or inst.y < -16 or inst.y > stage_height + 16
            then 
                inst:destroy()
                return
            end
        end

        obj_dirt:onStep(dirtStep)
        obj_dirt_cloned:onStep(dirtStep)
    --#endregion

--#endregion

--#region Initial skill setup (icons and stats)
    --#region Skill variables
        local skill_wetSlap = gin:get_primary(1)
        local skill_throwDirt = gin:get_secondary(1)
        local skill_panic = gin:get_utility(1)
        local skill_cry = gin:get_special(1)
    --#endregion
    --#region Skill Animations
        skill_wetSlap:set_skill_animation(spr_slap)
        skill_throwDirt:set_skill_animation(spr_throw)
        skill_panic:set_skill_animation(spr_panic)
        skill_cry:set_skill_animation(spr_cry)
    --#endregion
    --#region Skill States
        local state_wetSlap = State.new(GIN, skill_wetSlap.identifier)
        local state_throwDirt = State.new(GIN, skill_throwDirt.identifier)
        local state_panic = State.new(GIN, skill_panic.identifier)
        local state_cry = State.new(GIN, skill_cry.identifier)
    --#endregion
    --#region Skill Icons
        skill_wetSlap:set_skill_icon(spr_skills, 0)
        skill_throwDirt:set_skill_icon(spr_skills, 1)
        skill_panic:set_skill_icon(spr_skills, 2)
        skill_cry:set_skill_icon(spr_skills, 3)
    --#endregion
    --#region Skill damage and cooldown
        skill_wetSlap:set_skill_properties(.15, 0)
        skill_throwDirt:set_skill_properties(.3, 2*60)
        skill_panic:set_skill_properties(0, 4*60)
        skill_cry:set_skill_properties(0, 13*60)
    --#endregion
    skill_panic.override_strafe_direction = true--This will default to mouseaim until a direction is held.
    skill_panic.ignore_aim_direction = true--This will default to mouseaim until a direction is held.
--#endregion

--#region Skill functions
    --#region Primary skill (1st skill)
            skill_wetSlap:onActivate(function(actor)
                GM.actor_set_state(actor, state_wetSlap)
            end)
            state_wetSlap:onEnter(function(actor, data)
                actor.image_index = 0
                data.fired = 0
                data.current_hit = 0
            end)
            state_wetSlap:onStep(function(actor, data)
                actor:skill_util_fix_hspeed()--fix X speed when state is switchex
                actor:actor_animation_set(actor:actor_get_skill_animation(skill_wetSlap), 0.45)--Change animation to skill 1
                if data.fired == 0 and actor.image_index >= 2.0 then--if we already fired + frame number >= 2, fire once
                    local damage = actor:skill_get_damage(skill_wetSlap)--Get the damage coeff from the skill
                    if actor:is_authority() then--if local player
                        if not actor:skill_util_update_heaven_cracker(actor, damage) then--IF not firing heaven cracker
                            local buff_shadow_clone = Buff.find("ror", "shadowClone")--Get the shattered mirror buff
                            for i=0, GM.get_buff_stack(actor, buff_shadow_clone) do--Attack for each clone(shattered mirror)
                                local attack = actor:fire_explosion(actor.x,actor.y,140,60,damage,gm.constants.sNone,gm.constants.sSparks7,true)
                                attack.climb = i * 8
                            end
                        end
                    end
                    actor:sound_play(wet_slap, 1, 0.9 + math.random() * 0.9)--Play a sound (sound_id,volume,pitch)
                    data.fired = 1--Tell that we fired
                end
                actor:skill_util_exit_state_on_anim_end()--Auto exit the state after anim
            end)
    --#endregion
    --#region Secondary skill (2nd skill)
        skill_throwDirt:onActivate(function(actor)
            GM.actor_set_state(actor, state_throwDirt)
        end)
        state_throwDirt:onEnter(function(actor, data)
            actor.image_index = 0
            data.fired = 0
            data.current_hit = 0
        end)
        state_throwDirt:onStep(function(actor, data)
            actor:skill_util_fix_hspeed()
            actor:actor_animation_set(actor:actor_get_skill_animation(skill_throwDirt), 0.25)
            if data.fired == 0 and actor.image_index >= 2 then
                local dmg = actor:skill_get_damage(skill_throwDirt)
                local dirt_speed = 10
                local buff_shadow_clone = Buff.find("ror", "shadowClone")
                local clone_stacks = actor:buff_stack_count(buff_shadow_clone)
                local angle = actor:skill_util_facing_direction()
                local direction = GM.sin(GM.degtorad(angle)) 
                local spawn_x = actor.x + direction * 10
                local spawn_y = actor.y - 3
                -- Make the spread nice for multiple dirt
                local spread_per_dirt = 10
                local spread = 5 * spread_per_dirt
                angle = angle - spread / 2
                -- Spawn dirt with a different sprite if we have clone stacks
                local dirt_obj = obj_dirt
                if clone_stacks > 0 then
                    dirt_obj = obj_dirt_cloned
                end
                -- The loop that actually spawns the dirt
                local dirtCount = 5
                if actor.level >= 2 then
                    dirtCount = dirtCount + actor.level
                    dmg = dmg + actor.level*(math.random()*.1)
                    dirtCount = GM.clamp(dirtCount,0,80)
                end
                for i=0, dirtCount do
                    local dirt_inst = dirt_obj:create(spawn_x, spawn_y)
                    local dirt_data = dirt_inst:get_data()
                    dirt_data.parent = actor
                    dirt_data.vspeed = dirt_speed * GM.sin(GM.degtorad(angle))
                    dirt_data.hspeed = dirt_speed * GM.cos(GM.degtorad(angle))
                    dirt_data.damage_coeff = dmg
                    dirt_data.clone_multiplier = clone_stacks + 1
                    dirt_data.angle = angle
                    angle = angle + spread_per_dirt + math.random() * 0.2
                end
                actor:sound_play(gm.constants.wHuntressShoot1, 1, 0.8 + math.random() * 0.2)
                data.fired = 1
            end

            actor:skill_util_exit_state_on_anim_end()
        end)
    --#endregion
    --#region Utility skill (3rd skill)
        skill_panic:onActivate(function(actor)
            GM.actor_set_state(actor, state_panic)
        end)
        state_panic:onEnter(function(actor, data)
            actor.image_index = 0
            data.fired = 0
            data.current_hit = 0
        end)
        state_panic:onStep(function(actor)
            actor:actor_animation_set(actor:actor_get_skill_animation(skill_panic), 0.45)
            actor.image_speed = 0.25
            actor.pHspeed = actor.pHmax * 2.2 * actor.image_xscale
            actor:set_immune(8)
            if actor.image_index == 2 then
                actor:sound_play(gin_panic, 2.5, 1)--Play a sound (sound_id,volume,pitch)
            end
            actor:skill_util_exit_state_on_anim_end()
        end)
    --#endregion
    --#region Special skill (4th skill)
        skill_cry:onActivate(function(actor)
            GM.actor_set_state(actor, state_cry)
        end)
        state_cry:onEnter(function(actor, data)
            actor.image_index = 0
            data.fired = 0
        end)
        state_cry:onStep(function(actor, data)
            actor:skill_util_fix_hspeed()
            actor:actor_animation_set(actor:actor_get_skill_animation(skill_cry), 0.25)
            if data.fired == 0 and actor.image_index >= 3 then
                data.fired = 1
                --#region math for collision rect
                    local left, right = actor.x - 100, actor.x + 100
                    local bias = 72 --how bigg
                    left = math.min(left, left - bias)
                    right = math.max(right, right + bias)
                --#endregion
                actor:sound_play(gin_cry, 1, 0.8 + math.random() * 0.2)
                local fear = Buff.find("ror", "fear")
                local victims = List.new()
                actor:collision_rectangle_list(left,actor.y - 88,right,actor.y + 88,gm.constants.pActor,false,true,victims,false)
                local scepter = Item.find("ror", "ancientScepter")
                local has_scepter = (actor:item_stack_count(scepter) > 0)
                if has_scepter then
                    for _, victim in ipairs(victims) do
                        if victim.team ~= actor.team then
                            victim:buff_apply(fear, 16 * 60)
                        end
                    end
                    victims:destroy()
                else
                    for _, victim in ipairs(victims) do
                        if victim.team ~= actor.team then
                            victim:buff_apply(fear, 8 * 60)
                        end
                    end
                    victims:destroy()
                end
            end
            actor:skill_util_exit_state_on_anim_end()
        end)
    --#endregion
--#endregion

end
Initialize(initialise)