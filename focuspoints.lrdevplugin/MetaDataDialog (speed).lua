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

local LrSystemInfo = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrLogger = import 'LrLogger'

local logger = LrLogger( 'FocusPoint' )
logger:enable( 'logfile' )

--[[
-- BEGIN MOD.156 - Add Metadata filter
-- showMetadataDialog largely rewritten to add entry field w/ observer and "Open as text" button
--]]


local LrBinding = import 'LrBinding'

require "Utils"


function showMetadataDialog(column1, column2, column1Length, column2Length, numLines)

  LrFunctionContext.callWithContext("showMetaDataDialog", function(context)

    local appWidth, appHeight = LrSystemInfo.appWindowSize()
    local viewFactory = LrView.osFactory()
    local properties = LrBinding.makePropertyTable( context ) -- make a table
    local delimiter = "\r"  -- carriage return; used to separate individual entries in column1 and column2 strings

    -- Split column1/column2 strings into arrays of tags/values to ease filtering
	logger:debug( 'index tag names' )
    tagLabels = {};
    searchLabels = {};
    for match in (column1..delimiter):gmatch("(.-)"..delimiter) do
      tagLabels[#tagLabels+1] = match
      searchLabels[#searchLabels+1] = string.upper(match)
    end

	logger:debug( 'index tag values' )
    tagValues = {};
    for match in (column2..delimiter):gmatch("(.-)"..delimiter) do
      tagValues[#tagValues+1] = match
    end

    local metadata = { }
    numTags = #tagLabels
    for i = 1, numTags - 1  do
      metadata[#metadata+1] = { title = tagLabels[i] .. string.rep(' ', column1Length - #tagLabels[i]) .. " : " .. tagValues[i], value = tagLabels[i] }
    end

	logger:debug( 'indexed ' .. numTags .. ' tags' )

    -- these props are needed on windows. on mac, they make the columns a bit larger than needed
    if (MAC_ENV) then
      column1Length = nil
      column2Length = nil
    end

    -- Define the various dialog UI elements
    local tagFilterLabel = viewFactory:static_text {
      title = "Show only tags containing:",
      alignment = 'right',
    }

    local tagFilterEntry = viewFactory:edit_field {
      immediate = true,
      value = LrView.bind( 'tagFilter' ),
      fill_horizonal = 1,
      width_in_chars = column1Length,
      immediate = true,
    }

    local tagFilter = viewFactory:column {
      tagFilterLabel, tagFilterEntry,
      margin_left = 5,
    }

    -- This function will be called upon user input / whenever "tagFilter" is changed.
    local function filterMetadata()

      logger:debug( 'filter metadata' )
      local pattern = string.upper(properties.tagFilter)
      -- Check each individual tag label if it contains tagFilter string
      -- if so, keep them along with the respective values
      local metadata = { }
      logger:debug( 'search for tag ' .. pattern )
      for i, tagLabel in ipairs(searchLabels) do
        if string.find(tagLabel, pattern) then
          metadata[#metadata+1] = { title = tagLabels[i] .. " : " .. tagValues[i], value = tagLabels[i] }
        end
      end
      logger:debug( 'update property columns' )
      -- Update view with the filtered entries
      properties.column1 = metadata
      logger:debug( 'update property columns finished' )
    end

    -- Add observer for tagFilter
    properties:addObserver( "tagFilter", filterMetadata )

    local scrollView = viewFactory:simple_list {
      items = LrView.bind "column1",
      width = appWidth * .4,  -- don't need such wide display, it's scrollable anyway
      height = appHeight *.7,
    }

    local contents = viewFactory:column {
      spacing = viewFactory:label_spacing(),
      bind_to_object = properties, -- default bound table is the one we made
      tagFilter,
      scrollView
    }

    -- Initialize text for the two columns
    properties.column1 = metadata

    result = LrDialogs.presentModalDialog {
      title = "Metadata display",
      resizable = false,  -- resizable dialog makes no sense if scrolled view doesn't resize as well
      cancelVerb = "< exclude >",
      actionVerb = "OK",
      otherVerb = "Open as text",
      contents = contents
    }

  end)

  return result

end

--[[
-- END MOD - Add Metadata filter
--]]
