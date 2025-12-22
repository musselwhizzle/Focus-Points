--[[
  Copyright Karsten Gieselmann (capricorn8)

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
--]]

-- This module
local Utf8 = {}

-----------------------------------------------------------------------
-- Fast lookup for UTF-8 leading byte → sequence length
-----------------------------------------------------------------------
local LEN = {
    -- ASCII
    [0]=1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    -- 0x20..0x7F → still 1 byte
}
-- fill 0x20..0x7F with 1
for i=0x20,0x7F do LEN[i]=1 end
-- Two byte: 110xxxxx
for i=0xC0,0xDF do LEN[i]=2 end
-- Three byte: 1110xxxx
for i=0xE0,0xEF do LEN[i]=3 end
-- Four byte: 11110xxx
for i=0xF0,0xF7 do LEN[i]=4 end

local function char_len(b)
    -- default to 1 if invalid
    return LEN[b] or 1
end

-----------------------------------------------------------------------
-- Fast character length
-----------------------------------------------------------------------
function Utf8.len(s)
    local i, n = 1, 0
    local bytes = #s
    while i <= bytes do
        local b = s:byte(i)
        i = i + (LEN[b] or 1)
        n = n + 1
    end
    return n
end

-----------------------------------------------------------------------
-- char index → byte index (fast)
-----------------------------------------------------------------------
function Utf8.char_to_byte(s, ci)
    if ci < 1 then return nil end

    local i, c = 1, 1
    local bytes = #s

    if ci == 1 then return 1 end

    while i <= bytes do
        if c == ci then return i end
        local b = s:byte(i)
        i = i + (LEN[b] or 1)
        c = c + 1
    end

    if ci == c then return bytes+1 end
    return nil
end

-----------------------------------------------------------------------
-- byte index → character index (fast)
-----------------------------------------------------------------------
function Utf8.byte_to_char(s, bi)
    if bi < 1 then return nil end

    local i, c = 1, 1
    local bytes = #s

    if bi == 1 then return 1 end

    while i < bi and i <= bytes do
        local b = s:byte(i)
        i = i + (LEN[b] or 1)
        c = c + 1
    end
    return c
end

-----------------------------------------------------------------------
-- UTF-8 safe substring by character indices
-- DOES NOT ACCEPT NEGATIVE INDICES (by design)
-----------------------------------------------------------------------
function Utf8.sub(s, cs, ce)
    ce = ce or cs

    local bs = Utf8.char_to_byte(s, cs)
    if not bs then return "" end

    local be_byte = Utf8.char_to_byte(s, ce + 1)
    local be = be_byte and (be_byte - 1) or -1

    return string.sub(s, bs, be)
end

-----------------------------------------------------------------------
-- Find (plain search), returning character indexes
-----------------------------------------------------------------------
function Utf8.find(s, sub)
    local bs, be = string.find(s, sub, 1, true)
    if not bs then return nil end

    local cs = Utf8.byte_to_char(s, bs)
    local ce = Utf8.byte_to_char(s, be + 1)
    if ce then ce = ce - 1 else ce = Utf8.len(s) end

    return cs, ce, bs, be
end

-----------------------------------------------------------------------
-- Last UTF-8 character (optimized)
-----------------------------------------------------------------------
function Utf8.last_char(s)
    local i = #s
    if i == 0 then return "" end

    -- skip continuation bytes (10xxxxxx)
    while i > 1 do
        local b = s:byte(i)
        if b >= 0x80 and b < 0xC0 then
            i = i - 1
        else
            break
        end
    end

    return string.sub(s, i)
end

-----------------------------------------------------------------------
-- Get next UTF-8 character
-----------------------------------------------------------------------
function Utf8.next_char(s, i)
  local c = string.byte(s, i)
  if not c then return nil end

  -- Determine UTF-8 sequence length
  local len
  if c     < 0x80 then len = 1
  elseif c < 0xE0 then len = 2
  elseif c < 0xF0 then len = 3
  else                 len = 4
  end

  return s:sub(i, i + len - 1), i + len
end


return Utf8
