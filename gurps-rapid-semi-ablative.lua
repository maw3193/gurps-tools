#!/usr/bin/lua

-- parse attack roll, given in the form of a damage roll (to parse), a number of hits, and the DR.

local damage_roll
local hits = 1
local dr = 0

local damage_types = {
    "burn",
    "cor",
    "cr",
    "cut",
    "fat",
    "imp",
    "pi-",
    "pi",
    "pi+",
    "pi++",
}

function get_damage_type(roll)
    for _,t in ipairs(damage_types) do
        if roll:find(t) then
            return t
        end
    end
end

function parse_damage_roll(roll)
    local dice = tonumber(roll:match("^(%d+)d"))
    local mult = tonumber(roll:match("^%d+dx(%d+)")) or 1
    local divisor = tonumber(roll:match("%((%d+)%)")) or 1
    local type = get_damage_type(roll)
    if dice  and type then
        return {average=dice*3.5*mult, dice=dice, mult=mult, divisor=divisor, type=type}
    else
        print("Failed to parse damage roll '"..roll.."'")
        os.exit(1)
    end
end

function parse_dr(spec)
    -- DR specification is comma-separated
    local resistances = {}
    for s in spec:gmatch("[^,]+") do
        local total = tonumber(s:match("^(%d+)"))
        local hardened = tonumber(s:match("^%d+H(%d)")) or 0
        local ablativeness = nil
        if s:match("SA$") then
            ablativeness = "semi"
        elseif s:match("A$") then
            ablativeness = "ablative"
        else
            ablativeness = "no"
        end
        if not total and not ablativeness then
            print ("Failed to parse DR fragment '"..s.."' in spec '"..spec.."'")
            os.exit(1)
        end
        table.insert(resistances, {current=total, total=total, hardened=hardened, ablativeness=ablativeness})
    end
    return resistances
end

local divisor_levels = {
    1,
    2,
    3,
    5,
    10,
    100,
    "inf"
}

function find_in_table(t, val)
    local i
    for i,v in ipairs(t) do
        if v == val then
            return i
        end
    end
end

function apply_hardening_to_divisor(divisor, hardening)
    local divisor_pos = find_in_table(divisor_levels, divisor)
    if not divisor_pos then
        print("divisor '"..divisor.."' not found in divisor levels")
        os.exit(1)
    end
    local new_pos = divisor_pos - hardening
    if new_pos <= 0 then new_pos = 1 end
    return divisor_levels[new_pos]
end

function calculate_penetrating_damage(roll, hits, dr)
    local penetrating_damage = 0
    local i
    for i=1,hits do
        local remaining_damage = roll.average
        for _,layer in ipairs(dr) do
            local div = apply_hardening_to_divisor(roll.divisor,
                                                   layer.hardened)
            local damage_loss = layer.current / div
            if layer.ablativeness == "ablative" then
                layer.current = layer.current - remaining_damage
            elseif roll.type == "cor" then
                layer.current = layer.current - remaining_damage / 5
            elseif layer.ablativeness == "semi" then
                layer.current = layer.current - remaining_damage / 10
            end
            if layer.current < 0 then layer.current = 0 end
            remaining_damage = remaining_damage - damage_loss
            if remaining_damage <= 0 then
                remaining_damage = 0
                break
            end
        end
        penetrating_damage = penetrating_damage + remaining_damage
    end
    return penetrating_damage
end

for i,v in ipairs(arg) do
    if v:find("--roll=") then
        local _,pos = v:find("--roll=")
        damage_roll = v:sub(pos + 1)
    elseif v:find("--hits=") then
        local _,pos = v:find("--hits=")
        hits = v:sub(pos + 1)
    elseif v:find("--DR=") then
        local _,pos = v:find("--DR=")
        dr = v:sub(pos + 1)
    else
        print("Unparsed arg '"..v.."'")
    end
end

if damage_roll then

    local damage = calculate_penetrating_damage(parse_damage_roll(damage_roll),
                                                hits, parse_dr(dr))
    print(damage)
else
    print([[
No defined damage!
Define a damage roll with "--roll=$ROLL",
where $ROLL is in the format $DICEdx$MULT $TYPE ... ($DIVISOR),
e.g. 6dx20 burn ex (2)

You will also want to define a number of hits with "--hits=$HITS"
and the structure of their DR with a comma-separated list of the format
"--DR=$TOTAL1[H$HARDENED1][A|SA][,...]", e.g.
1000SA,200
]])
end
