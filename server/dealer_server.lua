class "Dealer"

function Dealer:__init ( )
	self.locations = { }
	self.missions = { }
	self.vehicles = { }

	local file = io.open ( "data.txt" )
	if ( file ) then
		for line in file:lines ( ) do
			if ( line:sub ( 1, 1 ) == "L" ) then
				line = line:gsub ( "Location%(", ""  )
				line = line:gsub ( "%)", "" )
				line = line:gsub ( " ", "" )

				local tokens = line:split ( "," )
				table.insert (
					self.locations,
					{
						position = Vector3 ( tonumber ( tokens [ 1 ] ), tonumber ( tokens [ 2 ] ), tonumber ( tokens [ 3 ] ) ),
						vehPosition = Vector3 ( tonumber ( tokens [ 4 ] ), tonumber ( tokens [ 5 ] ), tonumber ( tokens [ 6 ] ) ),
						vehAngle = Angle ( tonumber ( tokens [ 7 ] ) or 0, tonumber ( tokens [ 8 ] ) or 0, tonumber ( tokens [ 9 ] ) or 0 )
					}
				)
			elseif ( line:sub ( 1, 1 ) == "M" ) then
				line = line:gsub ( "Mission%(", ""  )
				line = line:gsub ( "%)", "" )
				--line = line:gsub ( " ", " " )

				local tokens = line:split ( "," )
				table.insert (
					self.missions,
					{
						name = ( tokens [ 1 ] or "Unknown" ),
						reward = ( tonumber ( tokens [ 2 ] ) or 0 ),
						time = ( tonumber ( tokens [ 3 ] ) or 60 ),
						vehicle = tonumber ( tokens [ 4 ] ),
						position = Vector3 ( tonumber ( tokens [ 5 ] ), tonumber ( tokens [ 6 ] ), tonumber ( tokens [ 7 ] ) )
					}
				)
			end
		end
	end

	Network:Subscribe ( "vehicleDealer.requestData", self, self.requestData )
	Network:Subscribe ( "vehicleDealer.reachDestination", self, self.giveReward )
	Network:Subscribe ( "vehicleDealer.giveVehicle", self, self.giveVehicle )
	Network:Subscribe ( "vehicleDealer.missionFailed", self, self.missionFailed )
	Events:Subscribe ( "ModuleUnload", self, self.onModuleUnload )
end

function Dealer:requestData ( _, player )
	if IsValid ( player ) then
		Network:Send ( player, "vehicleDealer.returnData", { locations = self.locations, missions = self.missions } )
	end
end

function Dealer:giveReward ( data, player )
	if IsValid ( player ) then
		local steamID = tostring ( player:GetSteamId ( ) )
		local vehicle = player:GetVehicle ( )
		if ( self.vehicles [ steamID ] == vehicle ) then
			if ( type ( data ) == "table" ) then
				player:SendChatMessage ( "Vehicle dealer: Good job. Here's your reward $".. convertNumber ( data.reward ) .."!", Color ( 0, 255, 0 ) )
				player:SetMoney ( player:GetMoney ( ) + data.reward )
			end
			if ( self.vehicles [ steamID ] ) then
				if IsValid ( self.vehicles [ steamID ] ) then
					self.vehicles [ steamID ]:Remove ( )
				end
				self.vehicles [ steamID ] = nil
			end
		else
			player:SendChatMessage ( "Vehicle dealer: This vehicle is not the one requested!", Color ( 255, 0, 0 ) )
		end
	end
end

function Dealer:giveVehicle ( args, player )
	if ( type ( args ) == "table" ) then
		local steamID = tostring ( player:GetSteamId ( ) )
		local vehicle = Vehicle.Create ( args.mission.vehicle, args.location.vehPosition, args.location.vehAngle )
		vehicle:SetUnoccupiedRespawnTime ( nil )
		vehicle:SetDeathRemove ( true )
		vehicle:SetUnoccupiedRemove ( false )
		if IsValid ( vehicle ) then
			player:EnterVehicle ( vehicle, VehicleSeat.Driver )
			self.vehicles [ steamID ] = vehicle
			player:SendChatMessage ( "Vehicle dealer: Go to the flashing GREEN rectangle in your map.", Color ( 0, 255, 0 ) )
		end
	end
end

function Dealer:missionFailed ( _, player )
	local steamID = tostring ( player:GetSteamId ( ) )
	if ( self.vehicles [ steamID ] ) then
		if IsValid ( self.vehicles [ steamID ] ) then
			self.vehicles [ steamID ]:Remove ( )
		end
		self.vehicles [ steamID ] = nil
	end
	player:SendChatMessage ( "Vehicle dealer: You ran out of time, mission failed!", Color ( 255, 0, 0 ) )
end

function Dealer:onModuleUnload ( )
	for _, vehicle in pairs ( self.vehicles ) do
		if IsValid ( vehicle ) then
			vehicle:Remove ( )
		end
	end
end

dealer = Dealer ( )