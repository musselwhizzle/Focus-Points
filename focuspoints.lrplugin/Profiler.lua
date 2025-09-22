-- to enable use of debugging toolkit
local Debug    = require "Debug".init ()
--[[
  Copyright 2016 Whizzbang Inc

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


Profiler = {}

Profiler.ProfilerActive = false

--[[
  @@public table Profiler.init()
  ----
  Wrap the functions relevant for a runtime analysis with simple profiling
--]]
function Profiler.init()

    Profiler.ProfilerActive = true

    PointsRendererFactory.createRenderer  = Debug.profileFunc (PointsRendererFactory.createRenderer,  "1.  CreateRenderer")
    ExifUtils.readMetaDataAsTable         = Debug.profileFunc (ExifUtils.readMetaDataAsTable,         "1.1 readMetaDataAsTable")
    AppleDelegates.getAfPoints            = Debug.profileFunc (AppleDelegates.getAfPoints,            "2   AppleGetAfPoints")
    CanonDelegates.getAfPoints            = Debug.profileFunc (CanonDelegates.getAfPoints,            "2   Canon.GetAfPoints")
    FujifilmDelegates.getAfPoints         = Debug.profileFunc (FujifilmDelegates.getAfPoints,         "2   Fuji.GetAfPoints")
    NikonDelegates.getAfPoints            = Debug.profileFunc (NikonDelegates.getAfPoints,            "2   Nikon.GetAfPoints")
    OlympusDelegates.getAfPoints          = Debug.profileFunc (OlympusDelegates.getAfPoints,          "2   Olympus.GetAfPoints")
    PanasonicDelegates.getAfPoints        = Debug.profileFunc (PanasonicDelegates.getAfPoints,        "2   Panasonic.GetAfPoints")
    PentaxDelegates.getAfPoints           = Debug.profileFunc (PentaxDelegates.getAfPoints,           "2   Pentax.GetAfPoints")
    SonyDelegates.getAfPoints             = Debug.profileFunc (SonyDelegates.getAfPoints,             "2   Sony.GetAfPoints")
    DefaultPointRenderer.createPhotoView  = Debug.profileFunc (DefaultPointRenderer.createPhotoView,  "3.  CreatePhotoView")
    DefaultPointRenderer.prepareRendering = Debug.profileFunc (DefaultPointRenderer.prepareRendering, "3.1 PrepareRendering")
    MogrifyUtils.createDiskImage          = Debug.profileFunc (MogrifyUtils.createDiskImage,          "3.2 MogrifyCreateDiskImage")
    MogrifyUtils.drawFocusPoints          = Debug.profileFunc (MogrifyUtils.drawFocusPoints,          "3.3 MogrifyDrawFocusPoints")
--  ExifUtils.findValue                   = Debug.profileFunc (ExifUtils.findValue, "ExifFindValue")
end


function Profiler.sortResults(output)
    -- Split into lines
    local lines = {}
    for line in output:gmatch("([^\n]*)\n?") do
        if line ~= "" then
            table.insert(lines, line)
        end
    end

    if #lines <= 1 then
        return output -- nothing to sort
    end

    -- First line is the header
    local header = table.remove(lines, 1)

    -- Indentation to match the log format
    local indent = string.rep(" ", 49)

     -- Filter: keep only lines where the second column ("calls") is NOT "0"
    local filtered = {}
    for _, line in ipairs(lines) do
        local calls = string.sub(line, 32, 41):match("^%s*(.-)%s*$")
        if calls ~= "0" then
            table.insert(filtered, line)
        end
    end
    lines = filtered

    -- Get function name column width from header
    local firstSpace = header:find("%s")
    local colWidth = firstSpace and firstSpace - 1 or #header

    -- Sort lines by first column (trimmed)
    table.sort(lines, function(a, b)
        local fa = a:sub(1, colWidth):match("^%s*(.-)%s*$")
        local fb = b:sub(1, colWidth):match("^%s*(.-)%s*$")
        return fa:lower() < fb:lower()
    end)

    -- Recombine header + sorted lines
    return (table.concat({header, table.concat(lines, "\n")}, "\n")
      :gsub("\n", "\n" .. indent))
end
