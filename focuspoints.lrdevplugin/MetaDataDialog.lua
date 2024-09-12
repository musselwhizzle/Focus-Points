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
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

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

    bool_to_number={ [true]=1, [false]=0 }

    -- Split column1/column2 strings into arrays of tags/values to ease filtering
    tagLabels = {};
    for match in (column1..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(tagLabels, match);
    end

    tagValues = {};
    for match in (column2..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(tagValues, match);
    end

    numTags = 0
    for _ in pairs(tagLabels) do numTags = numTags + 1 end

    -- Define the various dialog UI elements
    local tagFilterLabel = viewFactory:static_text {
      title = "Show only tags containing:",
      alignment = 'right',
    }

  	local tagFilterEntry = viewFactory:edit_field {
  		immediate = true,
  	 	value = LrView.bind( 'tagFilter' ),
      fill_horizonal = 1,
      -- for proper window dimensions on MAC and WIN need to set different properties
      width_in_chars  = column1Length * bool_to_number[MAC_ENV == true],
      width_in_digits = column1Length * bool_to_number[WIN_ENV == true],
      immediate = true,
    }

    local tagFilter = viewFactory:column {
      tagFilterLabel, tagFilterEntry,
      margin_left = 5,
    }

  	-- This function will be called upon user input / whenever "tagFilter" is changed.
  	local function filterMetadata()

  	  local delimiter = "\r"
  	  local filteredLabels = ''
  	  local filteredValues = ''
  	  local pattern = string.upper(properties.tagFilter)

	    -- Check each individual tag label if it contains tagFilter string
	    -- if so, keep them along with the respective values
      for i=1, numTags do
        if string.find(string.upper(tagLabels[i]), pattern) then
          filteredLabels = filteredLabels .. tagLabels[i] .. delimiter
          filteredValues = filteredValues .. tagValues[i] .. delimiter
        end
      end

      -- Update view with the filtered entries
      properties.column1 = filteredLabels
      properties.column2 = filteredValues
    end

  	-- Add observer for tagFilter
	  properties:addObserver( "tagFilter", filterMetadata )

    local myText = viewFactory:static_text {
      title = LrView.bind "column1",
      selectable = false,
      -- for proper window dimensions on MAC and WIN need to set different properties
      width_in_chars  = column1Length * bool_to_number[MAC_ENV == true],
      width_in_digits = column1Length * bool_to_number[WIN_ENV == true],
      height_in_lines = numLines * bool_to_number[MAC_ENV == true] + 1 * bool_to_number[WIN_ENV == true],  -- numLines for MAC, 1 for WIN
    }

    local myText2 = viewFactory:static_text {
      title = LrView.bind "column2",
      selectable = false,
      -- for proper window dimensions on MAC and WIN need to set different properties
      width_in_chars  = column2Length * bool_to_number[MAC_ENV == true],
      width_in_digits = column2Length * bool_to_number[WIN_ENV == true],
      height_in_lines = numLines * bool_to_number[MAC_ENV == true] + 1 * bool_to_number[WIN_ENV == true],  -- numLines for MAC, 1 for WIN
    }

    local row = viewFactory:row {
      myText, myText2,
      margin_left = 5,
    }

    local scrollView = viewFactory:scrolled_view {
      row,
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
    properties.column1 = column1
    properties.column2 = column2

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
