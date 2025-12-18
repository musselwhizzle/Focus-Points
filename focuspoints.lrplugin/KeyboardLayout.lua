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

--[[-----------------------------------------------------------------------------------------------
  Definition of supported keyboard layouts:
  The plugin needs to know which characters are produced when pressing a shifted/unshifted digit key.
  This is required to parse and execute the keyboard shortcuts for rating (0-5) and color (6-9).
---------------------------------------------------------------------------------------------------]]

-- Required Lua definitions
require 'Utf8.lua'

-- This module
KeyboardLayout = {}

--[[-----------------------------------------------------------------------------------------------
  !! Further layouts can be added to this table without the need to modify the code
     for the new layout to be recognized and handled !!
---------------------------------------------------------------------------------------------------]]

local KeyboardLayouts = {
  -- US English
  {
    id = "US",
    label = "US English",
    locales = { "en-US" },
    unshifted = "1234567890",
    shifted   = "!@#$%^&*()",
  },

  -- UK English
  {
    id = "UK",
    label = "UK English",
    locales = { "en-GB", "en-IE" },
    unshifted = "1234567890",
    shifted   = "!\"£$%^&*()",
  },

  -- German
  {
    id = "DE",
    label = "German",
    locales = { "de-DE", "de-AT" },
    unshifted = "1234567890",
    shifted   = "!\"§$%&/()=",
  },

  -- Swiss German
  {
    id = "CH-DE",
    label = "Swiss German",
    locales = { "de-CH" },
    unshifted = "1234567890",
    shifted   = "+\"*ç%&/()=",
  },

  -- French (AZERTY)
  {
    id = "FR",
    label = "French",
    locales = { "fr-FR" },
    unshifted = "&é\"'(-è_çà",
    shifted   = "1234567890",
  },

  -- Belgian French
  {
    id = "BE-FR",
    label = "Belgian French",
    locales = { "fr-BE" },
    unshifted = "&é\"'(-è_ç=",
    shifted   = "1234567890",
  },

  -- Italian
  {
    id = "IT",
    label = "Italian",
    locales = { "it-IT" },
    unshifted = "1234567890",
    shifted   = "!\"£$%&/()=",
  },

  -- Spanish
  {
    id = "ES",
    label = "Spanish",
    locales = { "es-ES" },
    unshifted = "1234567890",
    shifted   = "!\"·$%&/()=",
  },

    -- Czech
  {
    id = "CZ",
    label = "Czech",
    locales = { "cs-CZ" },
    unshifted = "1234567890",
    shifted   = "!\"#$%&/()=",
  },

  -- Slovak
  {
    id = "SK",
    label = "Slovak",
    locales = { "sk-SK" },
    unshifted = "1234567890",
    shifted   = "!\"#$%&/()=",
  },

  -- Nordic (Swedish, Danish, Norwegian, Finnish)
  {
    id = "Nordic",
    label = "Nordic",
    locales = { "sv-SE", "no-NO", "da-DK", "fi-FI" },
    unshifted = "1234567890",
    shifted   = "!\"#¤%&/()=",
  },

  -- Latin American Spanish
  {
    id = "ES-LA",
    label = "Latin American Spanish",
    locales = { "es-MX", "es-AR", "es-CO", "es-CL" },
    unshifted = "1234567890",
    shifted   = "!\"·$%&/()=",
  },

  -- Brazilian Portuguese
  {
    id = "BR-PT",
    label = "Brazilian Portuguese",
    locales = { "pt-BR" },
    unshifted = "1234567890",
    shifted   = "!\"$%¨&*()=",
  },

  -- Japanese JIS
  {
    id = "JP-JIS",
    label = "Japanese (JIS)",
    locales = { "ja-JP" },
    unshifted = "1234567890",
    shifted   = "!\"#$%&'()=",
  },

  -- Korean
  {
    id = "KR",
    label = "Korean",
    locales = { "ko-KR" },
    unshifted = "1234567890",
    shifted   = "!@#$%^&*()",
  },

  -- Chinese (US QWERTY)
  {
    id = "CN",
    label = "Chinese (US QWERTY)",
    locales = { "zh-CN", "zh-TW", "zh-HK" },
    unshifted = "1234567890",
    shifted   = "!@#$%^&*()",
  },

  -- Australia / New Zealand
  {
    id = "AU",
    label = "Australia / NZ",
    locales = { "en-AU", "en-NZ" },
    unshifted = "1234567890",
    shifted   = "!@#$%^&*()",
  },

}

--[[-----------------------------------------------------------------------------------------------
  Functions to access the relevant keyboard layout data
---------------------------------------------------------------------------------------------------]]


-- Build dictionary: layoutId → layoutEntry
KeyboardLayout.layoutById = {}
for _, t in ipairs(KeyboardLayouts) do
  KeyboardLayout.layoutById[t.id] = t
end

-----------------------------------------------------------------------
-- Produce dropdown items dynamically
-----------------------------------------------------------------------
function KeyboardLayout.buildDropdownItems()
    local items = {}
    for _, entry in ipairs(KeyboardLayouts) do
      table.insert(items, {
        title = entry.label,
        value = entry.id
      })
    end
    return items
end

-----------------------------------------------------------------------
-- Return:
--   digit   : 0..9 (number)
--   shifted : true/false
-- If not matched -> returns nil, nil
-----------------------------------------------------------------------

function KeyboardLayout.mapTypedCharToDigit(char, layoutId)

  if not layoutId then
    LrDialogs.message(
      "Keyboard layout not specified",
      "This is required for proper handling of shifted '0'-'9' keystrokes.\n\n" ..
      "Go to Plug-in Manager > Plugin Settings > User Interface to set your keyboard layout!")
    return nil, nil
  end

  local layout = KeyboardLayout.layoutById[layoutId]
  if not layout then
    return nil, nil
  end

  local unshifted = layout.unshifted
  local shifted   = layout.shifted

  -- 1) Unshifted scan
  do
    local pos = 1
    local digit = 1

    while true do
      local c, nextPos = Utf8.next_char(unshifted, pos)
      if not c then break end     -- end of string

      if c == char then
        return digit % 10, false     -- matched unshifted digit, map 10 (for '0') to 0
      end

      digit = digit + 1
      pos = nextPos
    end
  end

  -- 2) Shifted scan
  do
    local pos = 1
    local digit = 1

    while true do
      local c, nextPos = Utf8.next_char(shifted, pos)
      if not c then break end

      if c == char then
        return digit % 10, true      -- matched shifted digit, , map 10 (for '0') to 0
      end

      digit = digit + 1
      pos = nextPos
    end
  end

  -- no match
  return nil, nil
end


-- return KeyboardLayout
