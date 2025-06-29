

--[[
	Plugin

	Object to lua, convert
	
	Developer : makerscript

	also thank https://create.roblox.com/store/asset/1894828823/Object-To-Lua-Serializer
--]]

local toolbar = plugin:CreateToolbar("Exporter")
local button = toolbar:CreateButton("Export as Code", "Export selected objects as Lua code", "")

local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")

local PropertyToString
local CONCAT = table.concat
local FLOOR = math.floor
local types = {}

local objectNameMap = {}

local function GCD(a, b)
	while (b > 0) do
		local _b = b
		b = a % b
		a = _b
	end
	return a
end

local function ColorValue(c)
	c = FLOOR(c * 255)
	if (c == 0) then return "0" elseif (c == 255) then return "1" end
	local gcd = GCD(c, 255)
	return (c / gcd .. "/" .. (255 / gcd))
end

local function IsDescendant(descendant, ancestor)
	while descendant do
		if descendant == ancestor then return true end
		descendant = descendant.Parent
	end
	return false
end

types.Axes = function(value)
	local args = {}
	for _, prop in ipairs({"X", "Y", "Z"}) do
		if value[prop] then table.insert(args, "Enum.Axis." .. prop) end
	end
	return "Axes.new(" .. table.concat(args, ",") .. ")"
end

types.BrickColor = function(value)
	return ("BrickColor.new(%q)"):format(value.Name)
end

types.CFrame = function(value)
	return "CFrame.new(" .. CONCAT({value:components()}, ",") .. ")"
end

types.Color3 = function(value)
	return "Color3.new(" .. value.R .. "," .. value.G .. "," .. value.B .. ")"
end

types.ColorSequence = function(value)
	local keypointsStr = {}
	for _, keypoint in pairs(value.Keypoints) do
		keypointsStr[#keypointsStr + 1] = PropertyToString("ColorSequenceKeypoint", keypoint)
	end
	return "ColorSequence.new({" .. CONCAT(keypointsStr, ",") .. "})"
end

types.ColorSequenceKeypoint = function(value)
	return "ColorSequenceKeypoint.new(" .. value.Time .. "," .. PropertyToString("Color3", value.Value) .. ")"
end

types.NumberRange = function(value)
	return value.Min == value.Max and
		("NumberRange.new(%s)"):format(value.Min) or
		("NumberRange.new(%s,%s)"):format(value.Min, value.Max)
end

types.NumberSequence = function(value)
	local keypointsStr = {}
	for _, keypoint in pairs(value.Keypoints) do
		keypointsStr[#keypointsStr + 1] = PropertyToString("NumberSequenceKeypoint", keypoint)
	end
	return "NumberSequence.new({" .. CONCAT(keypointsStr, ",") .. "})"
end

types.NumberSequenceKeypoint = function(value)
	return ("NumberSequenceKeypoint.new(%s,%s,%s)"):format(value.Time, value.Value, value.Envelope)
end

types.TweenInfo = function(value)
	return ("TweenInfo.new(%s, Enum.EasingStyle.%s, Enum.EasingDirection.%s, %s, %s, %s)"):format(
		value.Time, value.EasingStyle.Name, value.EasingDirection.Name,
		value.RepeatCount, tostring(value.Reverses), value.DelayTime
	)
end

types.Rect = function(value)
	return ("Rect.new(%s, %s, %s, %s)"):format(value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
end

types.EmissionDirection = function(value)
	return ("Enum.NormalId.%s"):format(value.Name)
end

types.TextureMode = function(value)
	return ("Enum.TextureMode.%s"):format(value.Name)
end

types.BeamRenderMode = function(value)
	return ("Enum.BeamRenderMode.%s"):format(value.Name)
end

types.UDim = function(value)
	return ("UDim.new(%s, %s)"):format(value.Scale, value.Offset)
end

types.UDim2 = function(value)
	return ("UDim2.new(%s, %s, %s, %s)"):format(
		value.X.Scale, value.X.Offset,
		value.Y.Scale, value.Y.Offset
	)
end

types.Vector2 = function(value)
	return ("Vector2.new(%s,%s)"):format(value.X, value.Y)
end

types.Vector3 = function(value)
	return ("Vector3.new(%s,%s,%s)"):format(value.X, value.Y, value.Z)
end

types.string = function(value)
	return ("%q"):format(value)
end

types.number = function(value)
	if value == math.huge then
		return "math.huge"
	elseif value == -math.huge then
		return "-math.huge"
	else
		return tostring(value)
	end
end

types.Content = types.string
types.CoordinateFrame = types.CFrame

local enumsByName = {}
for _, enum in pairs(Enum:GetEnums()) do
	enumsByName[tostring(enum)] = enum
end

PropertyToString = function(name, value)
	local serializeFunc = types[name]
	if serializeFunc then
		return serializeFunc(value)
	elseif enumsByName[name] then
		return "Enum." .. name .. "." .. value.Name
	elseif typeof(value) == "Instance" then
		local ref = objectNameMap[value]
		return ref or "nil --[[untracked instance]]"
	else
		return tostring(value)
	end
end

local PropertiesToCheck = table.pack(
	"Name", "Archivable", "Locked", "Transparency", "Anchored", "CanCollide", "Size", "CFrame",
	"Position", "Color", "Material", "Shape", "BrickColor", "Velocity", "Orientation", "Rotation",
	"Reflectance", "CastShadow", "Elasticity", "Friction", "RootPriority", "ActuatorType",
	"AngularResponsiveness", "Attachment0", "Attachment1", "Enabled", "InclinationAngle",
	"LimitsEnabled", "LowerLimit", "MotorMaxAcceleration", "MotorMaxTorque", "Restitution",
	"RigidityEnabled", "RotationAxis", "ServoMaxTorque", "Size", "TargetAngle", "UpperLimit",
	-- ParticleEmitter / Beam:
	"Acceleration", "Brightness", "Color", "Drag", "EmissionDirection", "EmissionSphereRadius",
	"Lifetime", "LightEmission", "LightInfluence", "Rate", "Rotation", "RotSpeed", "Speed",
	"SpreadAngle", "Texture", "TextureLength", "TimeScale", "VelocityInheritance", "ZOffset",
	"SecondaryColor", "Squash", "SquashFactor", "Heat", "UseHeat", "LockedToPart",
	"CurveSize0", "CurveSize1", "FaceCamera", "LocalTransparencyModifier", "Segments",
	"TextureMode", "TextureSpeed", "Transparency", "Width0", "Width1", "FlipbookLayout",
	"FlipbookMode", "FlipbookFramerate"
)

local uniqueProps = {}
local filteredProps = {}
for _, p in ipairs(PropertiesToCheck) do
	if not uniqueProps[p] then
		uniqueProps[p] = true
		table.insert(filteredProps, p)
	end
end
PropertiesToCheck = filteredProps

local function GetDefaultValue(instance, property)
	local success, defaultValue = pcall(function()
		local temp = Instance.new(instance.ClassName)
		local value = temp[property]
		temp:Destroy()
		return value
	end)
	return success and defaultValue or nil
end

local function SerializeInstance(instance, indent)
	indent = indent or ""
	local className = instance.ClassName
	local lines = {}

	local safeName = instance.Name:gsub("%W", "")
	if safeName == "" then safeName = "Obj" end

	local uniqueName = safeName
	local counter = 1
	while objectNameMap[instance] == nil and objectNameMap[uniqueName] do
		counter += 1
		uniqueName = safeName .. counter
	end

	objectNameMap[instance] = uniqueName
	local parentRef = instance.Parent and objectNameMap[instance.Parent]
	local instanceLine = "local " .. uniqueName .. " = Instance.new(\"" .. className .. "\"" ..
		(parentRef and (", " .. parentRef) or "") .. ")"
	table.insert(lines, indent .. instanceLine)

	for _, prop in ipairs(PropertiesToCheck) do
		local success, value = pcall(function() return instance[prop] end)
		if success and value ~= nil then
			local defaultValue = GetDefaultValue(instance, prop)
			if defaultValue == nil or not rawequal(value, defaultValue) then
				local typeName = typeof(value)
				local serialized = PropertyToString(typeName, value)
				if serialized then
					table.insert(lines, indent .. uniqueName .. "." .. prop .. " = " .. serialized)
				end
			end
		end
	end

	local childLines = {}
	for _, child in ipairs(instance:GetChildren()) do
		local childCode = SerializeInstance(child, indent .. "    ")
		for _, line in ipairs(childCode) do
			table.insert(childLines, line)
		end
	end

	for _, line in ipairs(childLines) do
		table.insert(lines, line)
	end

	return lines
end

button.Click:Connect(function()
	local selected = Selection:Get()
	if #selected == 0 then
		warn("Nothing selected")
		return
	end

	objectNameMap = {}

	local allLines = {}

	for _, obj in ipairs(selected) do
		local lines = SerializeInstance(obj)
		for _, line in ipairs(lines) do
			table.insert(allLines, line)
		end
		local varName = objectNameMap[obj]
		if not obj.Parent or obj.Parent == workspace then
			table.insert(allLines, varName .. ".Parent = workspace")
		end
	end

	local source = table.concat(allLines, "\n")

	local outputScript = Instance.new("Script")
	outputScript.Name = "ExportedCode"
	outputScript.Source = source
	outputScript.Parent = game:GetService("ServerScriptService")

	print("Exported to ServerScriptService as 'ExportedCode'")
end)
