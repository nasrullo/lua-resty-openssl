local ffi = require "ffi"
local asn1_macro = require("resty.openssl.include.asn1")
local C = ffi.C
local ffi_str = ffi.string
local floor = math.floor
local tonumber = tonumber
local past = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }

-- https://github.com/wahern/luaossl/blob/master/src/openssl.c
local function isleap(year)
  return (year % 4) == 0 and ((year % 100) > 0 or (year % 400) == 0)
end

local function yday(year, mon, mday)
  local d = past[mon] + mday - 1
  if mon > 2 and isleap(year) then
    d = d + 1
  end
  return d
end

local function leaps(year)
  return floor(year / 400) + floor(year / 4) - floor(year / 100)
end

local function new_asn1_string(s, tip)
    if type(tip) ~= 'number' or tip < 0 or tip > 30 then
        return nil, "invalid asn string type. It must be a number between 0 and 30"
    end
    local asn_str = ffi.C.ASN1_STRING_type_new(tip)
    ffi.gc(asn_str, ffi.C.ASN1_STRING_free)
    ffi.C.ASN1_STRING_set(asn_str, s, #s)
    return asn_str
end

local function asn1_to_unix(asn1)
  local s = asn1_macro.ASN1_STRING_get0_data(asn1)
  s = ffi_str(s)
  -- V_ASN1_UTCTIME           190303223958Z
  -- V_ASN1_GENERALIZEDTIME 21190822162753Z
  local yyoffset = 2
  local year
  -- # define V_ASN1_GENERALIZEDTIME          24
  if C.ASN1_STRING_type(asn1) == 24 then
    yyoffset = 4
    year = tonumber(s:sub(1, yyoffset))
  else
    year = tonumber(s:sub(1, yyoffset))
    year = year + (year < 50 and 2000 or 1900)
  end
  local month = tonumber(s:sub(yyoffset+1, yyoffset+2))
  if month > 12 or month < 1 then
    return nil, "asn1.asn1_to_unix: bad format " .. s
  end
  local day = tonumber(s:sub(yyoffset+3, yyoffset+4))
  if day > 31 or day < 1 then
    return nil, "asn1.asn1_to_unix: bad format " .. s
  end
  local hour = tonumber(s:sub(yyoffset+5, yyoffset+6))
  if hour > 23 or hour < 0 then
    return nil, "asn1.asn1_to_unix: bad format " .. s
  end
  local minute = tonumber(s:sub(yyoffset+7, yyoffset+8))
  if minute > 59 or hour < 0 then
    return nil, "asn1.asn1_to_unix: bad format " .. s
  end
  local second = tonumber(s:sub(yyoffset+9, yyoffset+10))
  if second > 59 or second < 0 then
    return nil, "asn1.asn1_to_unix: bad format " .. s
  end

  local tm
  tm = (year - 1970) * 365
  tm = tm + leaps(year - 1) - leaps(1969)
  tm = (tm + yday(year, month, day)) * 24
  tm = (tm + hour) * 60
  tm = (tm + minute) * 60
  tm = tm + second

  -- offset?
  local sign = s:sub(yyoffset+11, yyoffset+11)
  if sign == "+" or sign == "-" then
    local sgn = sign == "+" and 1 or -1
    local hh = tonumber(s:sub(yyoffset+12, yyoffset+13) or 'no')
    local mm = tonumber(s:sub(yyoffset+14, yyoffset+15) or 'no')
    if not hh or not mm then
      return nil, "asn1.asn1_to_unix: bad format " .. s
    end
    tm = tm + sgn * (hh * 3600 + mm * 60)
  end

  return tm
end

return {
  asn1_to_unix = asn1_to_unix,
  new_asn1_octet_string = new_asn1_octet_string,
}
