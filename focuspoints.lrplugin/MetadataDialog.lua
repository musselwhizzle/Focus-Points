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

--[[----------------------------------------------------------------------------
  MetadataDialog.lua

  Purpose of this module:
  Build the view hierarchy of containers and controls and displays the dialog.
------------------------------------------------------------------------------]]
local MetadataDialog = {}

-- Imported LR namespaces
local LrFunctionContext = import  'LrFunctionContext'
local LrDialogs         = import  'LrDialogs'
local LrView            = import  'LrView'
local LrBinding         = import  'LrBinding'

-- Required Lua definitions
local FocusPointPrefs   = require 'FocusPointPrefs'
local GlobalDefs        = require 'GlobalDefs'
local _strict           = require 'strict'
local Log               = require 'Log'

--[[----------------------------------------------------------------------------
  public string result
  showDialog(table photo, table column1, table column2, int column1Width, int column2Width, int numOfLines

  Invoked when 'Focus Point Viewer -> Show Focus Points' is selected.
  Reads the metadata from the selected photo's image file, processes autofocus
  information, and displays a dialog to:
  - visualize focus points
  - display relevant image/shooting/focus information
  - tag (flag, rate or color) the current image
  Returns the value of the button used to dismiss the dialog.
------------------------------------------------------------------------------]]
function MetadataDialog.showDialog(photo, column1, column2, column1Length, column2Length, numLines)

  local result

  LrFunctionContext.callWithContext("showMetadataDialog", showErrors( function(context)

    local bool_to_number={ [true]=1, [false]=0 }

    local f = LrView.osFactory()
    local properties = LrBinding.makePropertyTable( context )
    local delimiter = "\r"  -- carriage return; used to separate individual entries in column1 and column2 strings

    local windowSize    = FocusPointPrefs.getPluginWindowSize()  -- sizing factor for S..XXL
    local contentHeight = GlobalDefs.appHeight * windowSize
    local contentWidth  = contentHeight * 0.7                    -- minimum width of dialog window

    -- Consider user-defined display scaling value on Windows
    local scalingLevel
    if WIN_ENV then
      scalingLevel = FocusPointPrefs.getDisplayScaleFactor()
      contentHeight = contentHeight * scalingLevel
      contentWidth  = contentWidth  * scalingLevel
    end

    local filters, metadataView
    local hintText = "Hint: use ^ $ . * + for pattern matching"

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

    ----------------------------------------------------------------------------
    -- Definition of header line with filters
    ----------------------------------------------------------------------------
    do
      local tagFilterLabel = f:static_text {
        title = "Show tags containing:",
        alignment = 'right',
      }

      local tagFilterEntry = f:edit_field {
        immediate = true,
        value = LrView.bind( 'tagFilter' ),
        -- for proper window dimensions on MAC and WIN need to set different properties
        width_in_chars  = column1Length * bool_to_number[MAC_ENV == true],
        width_in_digits = column1Length * bool_to_number[WIN_ENV == true],
      }

      local function tagFilterEntryField()
      -- This function will be called upon user input / whenever "tagFilter" is changed.
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

      -- Wire observer
      properties:addObserver( "tagFilter", tagFilterEntryField)


      local valueFilterLabel = f:static_text {
        title = "Show values containing:",
        alignment = 'right',
      }

      local valueFilterEntry = f:edit_field {
        immediate = true,
        value = LrView.bind( 'valueFilter' ),
        -- for proper window dimensions on MAC and WIN need to set different properties
        width_in_chars  = column1Length * bool_to_number[MAC_ENV == true],
        width_in_digits = column1Length * bool_to_number[WIN_ENV == true],
      }

      local function valueFilterEntryField()
      -- This function will be called upon user input / whenever "valueFilter" is changed.
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

      -- Wire observer
      properties:addObserver( "valueFilter", valueFilterEntryField)

      local filterHint = f:static_text {
        title = hintText,
        alignment = "right",
      }

      filters = f:row{
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
          filterHint,
        },
      }
    end

    ----------------------------------------------------------------------------
    -- Definition of the two columns with labels and values
    ----------------------------------------------------------------------------
    do
      local myText1 = f:static_text {
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
        myText1, myText2,
        margin_left = 5,
      }

      local function pixelWidth(columnLength)
        local PX_PER_CHAR_MAC  = 7.0  -- @TODO is this correct on MAC ??
        local PX_PER_DIGIT_WIN = 7.0
        local pxWidth
        if MAC_ENV then
          pxWidth = columnLength * PX_PER_CHAR_MAC
        else
          pxWidth = columnLength * PX_PER_DIGIT_WIN
        end
        Log.logDebug("ShowMetadata",
          string.format("ScrolledView: contentWidth=%s px, column1Length(c1)=%s, hintLength(h)=%s, pixelWidth((2xc1+h)x7)=%s px",
            math.floor(contentWidth), column1Length, string.len(hintText), math.floor(pxWidth)))
        if pxWidth < contentWidth  then pxWidth = contentWidth end
        return pxWidth
      end

      metadataView = f:scrolled_view {
        row,
        width  = pixelWidth(column1Length*2 + string.len("Hint: use ^ $ . * + for pattern matching")),
        height = contentHeight,
      }
    end

    -- Dialog definition
    local contents = f:column {
      bind_to_object = properties,
      height = contentHeight,
      fill_horizontal = 1,
      filters,
      metadataView,
      spacing = f:label_spacing(),
    }

    -- Initialize text for the two columns
    properties.column1 = column1
    properties.column2 = column2

    -- Open the dialog window
    result = LrDialogs.presentModalDialog {
      title = "Metadata for " .. photo:getRawMetadata("path"),
      resizable = false,  -- resizable dialog makes no sense if scrolled view doesn't resize as well
      cancelVerb = "< exclude >",
      actionVerb = "OK",
      otherVerb = "Open as text",
      contents = contents,
    }

  end))

  return result
end

return MetadataDialog -- ok
