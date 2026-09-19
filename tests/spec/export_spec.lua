local H = require("tests.helpers")

describe("Export", function()
  local CMM
  before_each(function()
    CMM = H.Boot()
    H.wow.player.equipped = { [1] = 30100, [11] = 30201, [12] = 30202, [16] = 30401 }
    CMM.Player.Refresh()
  end)

  it("base64 round-trips arbitrary strings", function()
    local B = CMM.Compat
    for _, s in ipairs({ "", "a", "ab", "abc", "abcd", "v1;WARRIOR;62", "\0\1\255" }) do
      assert.equals(s, B.Base64Decode(B.Base64Encode(s)))
    end
    assert.equals("aGVsbG8=", B.Base64Encode("hello"))
    assert.is_nil(B.Base64Decode("!!!!"))
  end)

  it("encodes class, level, spec, equipment and weights", function()
    local raw = CMM.Export.Raw(CMM.Player.Get(), { STR = 1, STA = 0.45, CRIT = 14 })
    assert.matches("^v1;WARRIOR;62;ARMS;", raw)
    assert.matches("HEAD=30100", raw)
    assert.matches("FINGER=30201/30202", raw)
    assert.matches("MAINHAND=30401", raw)
    assert.matches("CHEST=0", raw)
    assert.matches("CRIT:14,STA:0.45,STR:1$", raw)
  end)

  it("round-trips through the base64 string", function()
    local str = CMM.Export.String(CMM.Player.Get(), { STR = 1, STA = 0.45, HIT = 12.5 })
    assert.is_true(#str > 20)
    assert.is_nil(str:find("[^%w%+/=]"))
    local t = CMM.Export.Parse(str)
    assert.equals("WARRIOR", t.class)
    assert.equals(62, t.level)
    assert.equals("ARMS", t.spec)
    assert.equals(30100, t.equipped.HEAD)
    assert.same({ 30201, 30202 }, t.equipped.FINGER)
    assert.is_nil(t.equipped.CHEST)
    assert.same({ 30401 }, { t.equipped.MAINHAND })
    assert.is_nil(t.equipped.TRINKET[1])
    assert.is_near(12.5, t.weights.HIT, 1e-9)
    assert.equals(1, t.weights.STR)
  end)

  it("rejects bad input", function()
    assert.is_nil(CMM.Export.Parse(nil))
    assert.is_nil(CMM.Export.Parse("###"))
    assert.is_nil(CMM.Export.Parse(CMM.Compat.Base64Encode("v9;x;y;z;a;b")))
  end)
end)
