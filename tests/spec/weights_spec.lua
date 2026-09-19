local H = require("tests.helpers")

-- Load the whole addon when the other modules are present; otherwise (this spec only needs
-- Init + Weights + Specials) load just those three files with the same (ADDON, ns) convention.
local function loadAddon()
  local ok, ns = pcall(H.LoadAddon)
  if ok then return ns end
  H.wow.Reset()
  ns = {}
  for _, f in ipairs({ "Init.lua", "Weights.lua", "Specials.lua" }) do
    assert(loadfile("CasualMinMaxer/" .. f))(H.ADDON, ns)
  end
  return ns
end

-- Allowed weight keys: docs/ARCHITECTURE.md §2 plus the extra weight-only keys.
local STAT_KEYS = {
  "STR", "AGI", "STA", "INT", "SPI", "ARMOR", "AP", "RAP", "FAP", "SP",
  "SPFIRE", "SPFROST", "SPSHADOW", "SPNATURE", "SPARCANE", "SPHOLY", "HEAL", "MP5", "HP5", "BLOCKV", "ARP",
  "HIT", "SPHIT", "CRIT", "SPCRIT", "HASTE", "SPHASTE", "EXP", "DEF", "DODGE", "PARRY", "BLOCK", "RES",
  "DPS", "SPEED", "RDPS",
}
local EXTRA = { "SPEEDPREF", "DPS_OH", "SPEEDPREF_OH", "RDPS" }

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local ROLES = { melee = true, tank = true, caster = true, healer = true, ranged = true }

describe("Weights", function()
  local CMM, W, allowed

  setup(function()
    CMM = loadAddon()
    W = CMM.Weights
    allowed = {}
    local keys = (CMM.Constants and CMM.Constants.STAT_KEYS) or STAT_KEYS
    for _, k in ipairs(keys) do allowed[k] = true end
    for _, k in ipairs(EXTRA) do allowed[k] = true end
  end)

  it("defines all 9 classes and 27 specs", function()
    local nClasses, nSpecs = 0, 0
    for _, class in ipairs(CLASSES) do
      assert.is_table(W.DEFAULTS[class], class)
      nClasses = nClasses + 1
      for _ in pairs(W.DEFAULTS[class]) do nSpecs = nSpecs + 1 end
      assert.equals(3, #W.Specs(class), class .. " should have 3 specs")
    end
    assert.equals(9, nClasses)
    assert.equals(27, nSpecs)
  end)

  it("gives every spec a name, role, tabIndex and 5 non-empty phases with allowed keys", function()
    for _, class in ipairs(CLASSES) do
      local tabs = {}
      for key, spec in pairs(W.DEFAULTS[class]) do
        local label = class .. "." .. key
        assert.is_string(spec.name, label)
        assert.is_true(ROLES[spec.role] == true, label .. " role " .. tostring(spec.role))
        assert.is_number(spec.tabIndex, label)
        assert.is_nil(tabs[spec.tabIndex], label .. " duplicate tabIndex")
        tabs[spec.tabIndex] = true
        assert.equals(5, #spec.phases, label .. " phases")
        for i = 1, 5 do
          local n = 0
          for k, v in pairs(spec.phases[i]) do
            assert.is_true(allowed[k] == true, label .. " phase " .. i .. " unknown key " .. tostring(k))
            assert.is_number(v, label .. " " .. k)
            n = n + 1
          end
          assert.is_true(n > 0, label .. " phase " .. i .. " empty")
        end
      end
      assert.is_true(tabs[1] and tabs[2] and tabs[3], class .. " tab indexes 1..3")
    end
  end)

  it("anchors each spec's main stat at 1.0 (tanks: stamina up to 1.2) in every phase", function()
    for _, class in ipairs(CLASSES) do
      for key, spec in pairs(W.DEFAULTS[class]) do
        for i = 1, 5 do
          local anchored = false
          for _, v in pairs(spec.phases[i]) do
            if v >= 1 and v <= 1.2 then anchored = true end
          end
          assert.is_true(anchored, class .. "." .. key .. " phase " .. i .. " has no 1.0 anchor")
        end
      end
    end
  end)

  it("orders Specs by talent tab", function()
    local specs = W.Specs("WARRIOR")
    assert.equals("ARMS", specs[1].key)
    assert.equals("FURY", specs[2].key)
    assert.equals("PROTECTION", specs[3].key)
  end)

  it("maps levels to phases", function()
    assert.equals(1, W.PhaseIndex(1))
    assert.equals(1, W.PhaseIndex(19))
    assert.equals(2, W.PhaseIndex(20))
    assert.equals(3, W.PhaseIndex(57))
    assert.equals(4, W.PhaseIndex(58))
    assert.equals(5, W.PhaseIndex(70))
  end)

  it("blends weights across a phase boundary", function()
    local w55 = W.Get("WARRIOR", "ARMS", 54)
    local w57 = W.Get("WARRIOR", "ARMS", 57)
    local w58 = W.Get("WARRIOR", "ARMS", 58)
    assert.are_not.equal(w55.CRIT, w57.CRIT)
    assert.are_not.equal(w57.CRIT, w58.CRIT)
    assert.is_true(w57.CRIT > w55.CRIT and w57.CRIT < w58.CRIT)
    -- EXP only exists from phase 4: level 57 already gets 75 % of it
    assert.is_nil(w55.EXP)
    assert.is_true(w57.EXP > 0 and w57.EXP < w58.EXP)
    assert.same(W.DEFAULTS.WARRIOR.ARMS.phases[5], W.Get("WARRIOR", "ARMS", 70))
  end)

  it("returns an empty table for unknown specs", function()
    assert.same({}, W.Get("WARRIOR", "NOPE", 70))
    assert.same({}, W.Get("NOPE", "ARMS", 70))
  end)

  it("has a default gem for every role and color at level 30 and 70", function()
    for _, class in ipairs(CLASSES) do
      for key, spec in pairs(W.DEFAULTS[class]) do
        for _, level in ipairs({ 30, 70 }) do
          for _, color in ipairs({ "R", "Y", "B" }) do
            local gem = W.DefaultGem(class, key, level, color)
            assert.is_table(gem)
            local n = 0
            for k, v in pairs(gem) do
              assert.is_true(allowed[k] == true, spec.role .. " gem key " .. k)
              assert.is_number(v)
              n = n + 1
            end
            assert.is_true(n > 0, class .. "." .. key .. " " .. level .. " " .. color)
          end
          assert.same({}, W.DefaultGem(class, key, level, "M"))
        end
      end
    end
    -- rare gems at 70 are bigger than uncommon ones
    assert.is_true(W.DefaultGem("WARRIOR", "ARMS", 70, "R").STR > W.DefaultGem("WARRIOR", "ARMS", 69, "R").STR)
  end)

  it("returns socket bonus tables with allowed keys or nil", function()
    local n = 0
    for id, bonus in pairs(W.SOCKET_BONUS) do
      assert.is_number(id)
      assert.is_table(bonus)
      for k, v in pairs(bonus) do
        assert.is_true(allowed[k] == true, "socket bonus " .. id .. " key " .. k)
        assert.is_number(v)
      end
      assert.same(bonus, W.SocketBonus(id))
      n = n + 1
    end
    assert.is_true(n >= 30)
    assert.is_nil(W.SocketBonus(0))
    assert.is_nil(W.SocketBonus(999999))
  end)
end)
