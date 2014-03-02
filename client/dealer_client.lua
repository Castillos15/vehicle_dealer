class "Dealer"

function Dealer:__init ( )
	self.locations = { }
	self.missions = { }
	self.panel = { }
	self.hitLocation = false
	self.inMission = false
	self.hitMission = false
	self.sx, self.sy = Game:GetSetting ( 30 ), Game:GetSetting ( 31 )

	self.panel.window = GUI:Window ( "Vehicle Dealer", Vector2 ( 0.0, 0.0 ), Vector2 ( 0.35, 0.62 ) )
	self.panel.window:SetVisible ( false )
	GUI:Center ( self.panel.window )
	self.panel.list = GUI:SortedList ( Vector2 ( 0.0, 0.0 ), Vector2 ( 0.34, 0.35 ), self.panel.window, { { name = "Name" }, { name = "Reward" } } )
	self.panel.list:Subscribe ( "RowSelected", self, self.displayData )
	self.panel.data = GUI:Label ( "Name: N/A\n\nReward: N/A\n\nTime: N/A\n\nVehicle: N/A\n\nDistance: N/A\n", Vector2 ( 0.0, 0.36 ), Vector2 ( 0.34, 0.15 ), self.panel.window )
	GUI:Label ( "______________________________________________________________________________________________", Vector2 ( 0.0, 0.51 ), Vector2 ( 0.35, 0.03 ), self.panel.window )
	self.panel.take = GUI:Button ( "Take mission", Vector2 ( 0.12, 0.54 ), Vector2 ( 0.1, 0.03 ), self.panel.window )
	self.panel.take:Subscribe ( "Press", self, self.takeMission )

	Network:Send ( "vehicleDealer.requestData" )
	Network:Subscribe ( "vehicleDealer.returnData", self, self.loadData )

	Events:Subscribe ( "KeyUp", self, self.onKeyPress )
	Events:Subscribe ( "LocalPlayerInput", self, self.disableControls )
end

function Dealer:loadData ( data )
	self.locations = data.locations
	self.missions = data.missions
	for index, mission in ipairs ( self.missions ) do
		local item = self.panel.list:AddItem ( tostring ( mission.name ) )
		item:SetCellText ( 1, "$".. convertNumber ( mission.reward ) )
		item:SetDataNumber ( "id", index )
	end

	Events:Subscribe ( "Render", self, self.render )
end

function Dealer:render ( )
	if ( Game:GetState ( ) ~= GUIState.Game ) then
		return
	end

	if ( LocalPlayer:GetWorld ( ) ~= DefaultWorld ) then
		return
	end

	if ( type ( self.inMission ) == "table" ) then
		local timeLeft = math.floor ( self.inMission.time - self.missionTimer:GetSeconds ( ) )
		if ( timeLeft > 0 ) then
			local text = "Time left: ".. tostring ( timeLeft )
			Render:FillArea ( Vector2 ( ( 5 / 1366 ) * self.sx, ( 220 / 768 ) * self.sy ), Vector2 ( ( 200 / 1366 ) * self.sx, ( 55 / 768 ) * self.sy ), Color ( 0, 0, 0, 150 ) )
			Render:DrawText ( Vector2 ( ( ( 100 - ( Render:GetTextWidth ( text ) / 2 ) ) / 1366 ) * self.sx, ( 240 / 768 ) * self.sy ), text, Color ( 255, 255, 255 ) )
			local distance = self.inMission.position:Distance2D ( LocalPlayer:GetPosition ( ) )
			if ( distance <= 22 ) then
				self:drawTextMarker ( "Delivery Point", self.inMission.position, distance, 0, 150, 0 )
			end
			if ( distance <= 4 ) then
				if LocalPlayer:InVehicle ( ) then
					Network:Send ( "vehicleDealer.reachDestination", self.inMission )
					self.inMission = nil
					self.missionTimer = nil
				end
			else
				local alpha = ( 255 * math.abs ( Client:GetElapsedSeconds ( ) % 1.5 - .75 ) / .75 )
				local size = Vector2 ( 10, 10 )
				Render:FillArea ( Render:WorldToMinimap ( self.inMission.position ) - size / 2, size, Color ( 0, 200, 0, alpha ) )
			end
		else
			Network:Send ( "vehicleDealer.missionFailed" )
			self.inMission = nil
			self.missionTimer = nil
		end
	end

	for index, loc in ipairs ( self.locations ) do
		local dist = loc.position:Distance2D ( LocalPlayer:GetPosition ( ) )
		if ( dist <= 20 ) then
			self:drawTextMarker ( "Vehicle Dealer", loc.position, dist, 255, 150, 0 )
		elseif ( dist >= 20 and dist < 100 ) then
			local size = Vector2 ( 10, 10 )
			Render:FillArea ( Render:WorldToMinimap ( loc.position ) - size / 2, size, Color ( 255, 150, 0 ) )
		end
		if ( dist <= 4 ) then
			if ( not LocalPlayer:InVehicle ( ) ) then
				if ( self.hitLocation ~= index ) then
					self.hitLocation = index
				end
				Render:FillArea ( Vector2 ( ( 5 / 1366 ) * self.sx, ( 220 / 768 ) * self.sy ), Vector2 ( ( 200 / 1366 ) * self.sx, ( 55 / 768 ) * self.sy ), Color ( 0, 0, 0, 150 ) )
				Render:DrawText ( Vector2 ( ( 27 / 1366 ) * self.sx, ( 240 / 768 ) * self.sy ), "Press 'H' to show GUI", Color ( 255, 255, 255 ) )
			end
		else
			self.hitLocation = nil
		end
	end
end

function Dealer:drawTextMarker ( text, pos, dist, r, g, b )
	local angle = Angle ( Camera:GetAngle ( ).yaw, 0, math.pi ) * Angle ( math.pi, 0, 0 )
	local position = ( pos + Vector3 ( 0, 2, 0 ) )
	local text_size = Render:GetTextSize ( text, TextSize.VeryLarge )
	local t = Transform3 ( )
	t:Translate ( position )
	t:Scale ( 0.01 )
	t:Rotate ( angle )
	t:Translate ( -Vector3 ( text_size.x, text_size.y, 0 ) / 2 )
	Render:SetTransform ( t )
	Render:DrawText ( Vector3 ( 0, 0, 0 ), text, Color ( 255, 255, 255, 255 ), TextSize.VeryLarge )

	Render:ResetTransform ( )
	local alpha = ( 255 * math.abs ( Client:GetElapsedSeconds ( ) % 1.5 - .75 ) / .75 )
	Render:FillTriangle ( pos, pos + ( Vector3 ( -1, 2, 0 ) * ( dist / 25 ) ), pos + ( Vector3 ( 1, 2, 0 ) * ( dist / 25 ) ), Color ( r, g, b, alpha ) )
	Render:FillTriangle ( pos, pos + ( Vector3 ( 0, 2, -1 ) * ( dist / 25 ) ), pos + ( Vector3 ( 0, 2, 1 ) * ( dist / 25 ) ), Color ( r, g, b, alpha ) )
end

function Dealer:disableControls ( )
	if ( self.panel.window:GetVisible ( ) and Game:GetState ( ) == GUIState.Game ) then
		return false
	end
end

function Dealer:onKeyPress ( args )
	if ( args.key == string.byte ( "H" ) ) then
		if ( self.hitLocation ) then
			if LocalPlayer:InVehicle ( ) then
				Chat:Print ( "Vehicle dealer: Exit your vehicle!", Color ( 255, 0, 0 ) )
			else
				self.panel.window:SetVisible ( true )
				Mouse:SetVisible ( true )
			end
		end
	end
end

function Dealer:displayData ( )
	local row = self.panel.list:GetSelectedRow ( )
	if ( row ) then
		local id = row:GetDataNumber ( "id" )
		local data = self.missions [ id ]
		if ( data ) then
			local distance = math.floor ( data.position:Distance2D ( LocalPlayer:GetPosition ( ) ) )
			self.panel.data:SetText ( "Name: ".. tostring ( data.name ) .."\n\nReward: $".. convertNumber ( data.reward ) .."\n\nTime: ".. tostring ( data.time ) .." seconds\n\nVehicle: ".. tostring ( Vehicle.GetNameByModelId ( data.vehicle ) ) .."\n\nDistance: ".. tostring ( distance ) .." meters" )
		end
	end
end

function Dealer:takeMission ( )
	local row = self.panel.list:GetSelectedRow ( )
	if ( row ) then
		local id = row:GetDataNumber ( "id" )
		local data = self.missions [ id ]
		if ( data ) then
			if ( type ( self.inMission ) == "table" ) then
				Chat:Print ( "Vehicle dealer: You already have a mission, finish it!", Color ( 255, 0, 0 ) )
			else
				local location = self.locations [ self.hitLocation ]
				if ( type ( location ) == "table" ) then
					self.inMission = data
					self.missionTimer = Timer ( )
					self.panel.window:SetVisible ( false )
					Mouse:SetVisible ( false )
					Network:Send ( "vehicleDealer.giveVehicle", { location = location, mission = data } )
				end
			end
		end
	end
end

Events:Subscribe ( "ModuleLoad",
	function ( )
		dealer = Dealer ( )

		Events:Fire ( "HelpAddItem",
			{
				name = "Vehicle Dealer",
				text = [[
					Vehicle Dealer by Castillo

					This script consists of delivering vehicles in a determinated amount of time.
					Once you choose a mission, it'll create a minimap green flashing rectangle
					to which you must drive the vehicle, if you arrive the destination with
					the vehicle you was given for the mission, you'll be given a money reward.

					Mission points will display in your minimap as a orange rectangles,
					if you are close to them, head there and press 'H' to show the missions list.
				]]
			}
		)
	end
)

Events:Subscribe ( "ModuleUnload",
	function ( )
		Events:Fire ( "HelpRemoveItem",
			{
				name = "Vehicle Dealer"
			}
		)
	end
)