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

--[[
  Maps out which cameras have the same focus point maps as others.
  NikonDuplicates["d7100"] = "d7200" means that the D7100 has the same mapping
  as the D7200, and the D7200 text file will be used. 
--]]
NikonDuplicates = {}

NikonDuplicates["nikon d7100"] = "nikon d7200"


NikonDuplicates["nikon d800e"] = "nikon d800"
NikonDuplicates["nikon d810"] = "nikon d800"

NikonDuplicates["nikon d5300"] = "nikon d5500"
NikonDuplicates["nikon d5200"] = "nikon d5500"