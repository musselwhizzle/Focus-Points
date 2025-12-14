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

local LrSystemInfo      = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs         = import 'LrDialogs'
local LrView            = import 'LrView'
local LrBinding         = import 'LrBinding'

MetadataDialog = {}

function MetadataDialog.showDialog(photo, column1, column2, column1Length, column2Length, numLines)

  local result

  LrFunctionContext.callWithContext("showDialog", function(context)

    local f = LrView.osFactory()
    local properties = LrBinding.makePropertyTable( context ) -- make a table
    local delimiter = "\r"  -- carriage return; used to separate individual entries in column1 and column2 strings

    local appWidth, appHeight = LrSystemInfo.appWindowSize()
    local contentWidth  = appWidth  * .4
    local contentHeight = appHeight * .7

    if WIN_ENV then
      local scalingLevel = FocusPointPrefs.getDisplayScaleFactor()
      contentWidth  = contentWidth  * scalingLevel
      contentHeight = contentHeight * scalingLevel
    end

    local bool_to_number={ [true]=1, [false]=0 }

    -- Split column1/column2 strings into arrays of tags/values to ease filtering
    local tagLabels = {};
    for match in (column1..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(tagLabels, match);
    end

    local tagValues = {};
    for match in (column2..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(tagValues, match);
    end

    local numTags = 0
    for _ in pairs(tagLabels) do numTags = numTags + 1 end

    -- Define the various dialog UI elements

    local tagFilterLabel = f:static_text {
      title = "Show tags containing:",
      alignment = 'right',
    }

  	local tagFilterEntry = f:edit_field {
  		immediate = true,
  	 	value = LrView.bind( 'tagFilter' ),
      fill_horizonal = 1,
      -- for proper window dimensions on MAC and WIN need to set different properties
      width_in_chars  = column1Length * bool_to_number[MAC_ENV == true],
      width_in_digits = column1Length * bool_to_number[WIN_ENV == true],
    }

  	-- This function will be called upon user input / whenever "tagFilter" is changed.
  	local function tagFilterEntryField()

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
	  properties:addObserver( "tagFilter", tagFilterEntryField)


    local valueFilterLabel = f:static_text {
      title = "Show values containing:",
      alignment = 'right',
    }

  	local valueFilterEntry = f:edit_field {
  		immediate = true,
  	 	value = LrView.bind( 'valueFilter' ),
      fill_horizonal = 1,
      -- for proper window dimensions on MAC and WIN need to set different properties
      width_in_chars  = column1Length * bool_to_number[MAC_ENV == true],
      width_in_digits = column1Length * bool_to_number[WIN_ENV == true],
    }

  	-- This function will be called upon user input / whenever "valueFilter" is changed.
  	local function valueFilterEntryField()

  	  local delimiter = "\r"
  	  local filteredLabels = ''
  	  local filteredValues = ''
  	  local pattern = string.upper(properties.valueFilter)

	    -- Check each individual tag label if it contains valueFilter string
	    -- if so, keep them along with the respective values
      for i=1, numTags do
        if string.find(string.upper(tagValues[i]), pattern) then
          filteredLabels = filteredLabels .. tagLabels[i] .. delimiter
          filteredValues = filteredValues .. tagValues[i] .. delimiter
        end
      end

      -- Update view with the filtered entries
      properties.column1 = filteredLabels
      properties.column2 = filteredValues
    end

  	-- Add observer for valueFilter
	  properties:addObserver( "valueFilter", valueFilterEntryField)

    local filterHint = f:static_text {
        title = "Hint: use ^ $ . * + for pattern matching",
        alignment = "right"
    }

    local filters = f:row{
      f:column {
        tagFilterLabel, tagFilterEntry,
        margin_left = 0,
      },
      f:column {
        valueFilterLabel, valueFilterEntry,
        margin_left = 0,
      },
      f:spacer{fill_horizontal = 1},
      f:column {
        f:static_text { title = "" },
        filterHint
      }
    }

    local myText = f:static_text {
      title = LrView.bind "column1",
      selectable = false,
      -- for proper window dimensions on MAC and WIN need to set different properties
      width_in_chars  = column1Length * bool_to_number[MAC_ENV == true],
      width_in_digits = column1Length * bool_to_number[WIN_ENV == true],
      height_in_lines = numLines * bool_to_number[MAC_ENV == true] + 1 * bool_to_number[WIN_ENV == true],  -- #181: numLines for MAC, 1 for WIN
    }

    local myText2 = f:static_text {
      title = LrView.bind "column2",
      selectable = false,
      -- for proper window dimensions on MAC and WIN need to set different properties
      width_in_chars  = column2Length * bool_to_number[MAC_ENV == true],
      width_in_digits = column2Length * bool_to_number[WIN_ENV == true],
      height_in_lines = numLines * bool_to_number[MAC_ENV == true] + 1 * bool_to_number[WIN_ENV == true],  -- #181: numLines for MAC, 1 for WIN
    }

    local row = f:row {
      myText, myText2,
      margin_left = 5,
    }

    local scrollView = f:scrolled_view {
      row,
      width  = contentWidth,
      height = contentHeight,
    }

    local contents = f:column {
      spacing = f:label_spacing(),
      bind_to_object = properties, -- default bound table is the one we made
      filters,
      scrollView
    }

    -- Initialize text for the two columns
    properties.column1 = column1
    properties.column2 = column2

    result = LrDialogs.presentModalDialog {
      title = "Metadata for " .. photo:getRawMetadata("path"),
      resizable = false,  -- resizable dialog makes no sense if scrolled view doesn't resize as well
      cancelVerb = "< exclude >",
      actionVerb = "OK",
      otherVerb = "Open as text",
      contents = contents
    }

  end)

  return result

end


return MetadataDialog
