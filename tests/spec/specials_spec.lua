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

local STAT_KEYS = {
  "STR", "AGI", "STA", "INT", "SPI", "ARMOR", "AP", "RAP", "FAP", "SP",
  "SPFIRE", "SPFROST", "SPSHADOW", "SPNATURE", "SPARCANE", "SPHOLY", "HEAL", "MP5", "HP5", "BLOCKV", "ARP",
  "HIT", "SPHIT", "CRIT", "SPCRIT", "HASTE", "SPHASTE", "EXP", "DEF", "DODGE", "PARRY", "BLOCK", "RES",
  "DPS", "SPEED", "RDPS",
}

local SQLITE = "pipeline/work/tbcdb.sqlite"
local SQLITE_PARENT = os.getenv("HOME") .. "/repo/casual-minmaxer/pipeline/work/tbcdb.sqlite"

local function fileExists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

describe("Specials", function()
  local CMM, S, allowed

  setup(function()
    CMM = loadAddon()
    S = CMM.Specials
    allowed = {}
    for _, k in ipairs((CMM.Constants and CMM.Constants.STAT_KEYS) or STAT_KEYS) do allowed[k] = true end
  end)

  it("has numeric item ids and allowed stat keys", function()
    local n = 0
    for id, stats in pairs(S.TABLE) do
      assert.is_number(id)
      assert.is_true(id == math.floor(id) and id > 0, "bad id " .. tostring(id))
      assert.is_table(stats)
      for k, v in pairs(stats) do
        assert.is_true(allowed[k] == true, "special " .. id .. " unknown key " .. tostring(k))
        assert.is_number(v, "special " .. id .. " " .. k)
        assert.is_true(v >= 0, "special " .. id .. " negative " .. k)
      end
      n = n + 1
    end
    assert.is_true(n >= 100, "expected at least 100 specials, got " .. n)
  end)

  it("Get returns the table or nil", function()
    assert.same({ AP = 70 }, S.Get(28041)) -- Bladefist's Breadth
    assert.is_nil(S.Get(1))
  end)

  it("matches pipeline/overrides/specials.json", function()
    local f = assert(io.open("pipeline/overrides/specials.json", "r"))
    local json = f:read("*a")
    f:close()
    local n = 0
    for id, body in json:gmatch('"(%d+)":%s*{([^}]*)}') do
      id = tonumber(id)
      assert.is_table(S.TABLE[id], "json id " .. id .. " missing in Specials.lua")
      for k, v in body:gmatch('"(%w+)":%s*([%d%.]+)') do
        assert.equals(S.TABLE[id][k], tonumber(v), "json mismatch for " .. id .. " " .. k)
      end
      n = n + 1
    end
    local m = 0
    for _ in pairs(S.TABLE) do m = m + 1 end
    assert.equals(m, n)
  end)

  it("every id exists in the item database (integration)", function()
    local db = fileExists(SQLITE) and SQLITE or (fileExists(SQLITE_PARENT) and SQLITE_PARENT or nil)
    if not db then
      pending("tbcdb.sqlite snapshot not available")
      return
    end
    local ids = {}
    for id in pairs(S.TABLE) do ids[#ids + 1] = id end
    table.sort(ids)
    local sql = string.format(
      "with ids(id) as (select value from json_each('[%s]')) select id from ids "
        .. "where id not in (select entry from item_template where InventoryType>0)",
      table.concat(ids, ","))
    local p = assert(io.popen(string.format("sqlite3 %q %q", db, sql)))
    local missing = p:read("*a")
    p:close()
    assert.equals("", missing, "specials missing from item_template: " .. missing)
  end)
end)
