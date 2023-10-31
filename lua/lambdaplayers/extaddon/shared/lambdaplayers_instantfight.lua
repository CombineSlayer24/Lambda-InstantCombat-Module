local Rand = math.Rand
local random = math.random
local ents_GetAll = ents.GetAll
local hook_Add = hook.Add
local HUD_PRINTTALK = HUD_PRINTTALK
local WorldSpaceCenter = WorldSpaceCenter
local RandomPairs = RandomPairs
local attackOthers      = 		CreateLambdaConvar( "lambdaplayers_combat_attackothers", 0, true, false, false, "If Lambda Players should immediately start attacking anything at their sight.", 0, 1, { name = "Attack On Sight", type = "Bool", category = "Combat" } )
local attackOnMove	    = 		CreateLambdaConvar( "lambdaplayers_combat_attackothersonmove", 0, true, false, false, "If Lambda Players should immediately start attacking anything when moving?", 0, 1, { name = "Attack Randomly When Moving", type = "Bool", category = "Combat" } )
local huntDown          = 		CreateLambdaConvar( "lambdaplayers_combat_huntdownothers", 0, true, false, false, "If Lambda Players should hunt down other Lambdas. 'Attack On Sight' option needs to be enabled for it to work.", 0, 1, { name = "Search For Prey", type = "Bool", category = "Combat" } )
local defendMyself      = 		CreateLambdaConvar( "lambdaplayers_combat_defendmyself", 0, true, false, false, "If the Lambda Player being attacked should go after the attacker.", 0, 1, { name = "Defend Against Attacker", type = "Bool", category = "Combat" } )
local defendChance      = 		CreateLambdaConvar( "lambdaplayers_combat_defendmyselfchance", 65, true, false, false, "Chance for Lambda Player to defend themselves.", 0, 100, { decimals = 0, name = "Defend Chance", type = "Slider", category = "Combat" } )

if ( SERVER ) then

	local CurTime = CurTime
	local min = math.min

	local function LambdaOnInitialize( self )
		self.l_NextEnemySearchT = CurTime() + Rand( 0.33, 1.0 )
	end

	-- Debug purposes
	local function getEntityName( ent )
		if ent.IsLambdaPlayer then
			return ent:GetLambdaName()
		elseif ent:IsPlayer() then
			return ent:GetName()
		elseif ent:IsNPC() then
			return ent:GetClass()
		else
			return "Unknown Entity"
		end
	end

	-- This is really confusing
	local function DefendMyself( self, ent )
		local selfName = getEntityName( self )
		local targetName = getEntityName( ent )

		if random( 100 ) <= defendChance:GetInt() and self.IsLambdaPlayer then
			self:AttackTarget( ent )
	
			if random( 100 ) <= self:GetVoiceChance() then self:PlaySoundFile( "panic" ) end
			--PrintMessage( HUD_PRINTTALK, targetName .. ": I'm defending myself against " .. selfName )
		end
	end

	-- sightline, if set to True, then we use
	-- CanSee() check if a target is visible.
	-- If False, then disregard the CanSee() check
	local function AttackVictim( self, sightline )
		local myPos = self:WorldSpaceCenter()
		local eneDist = ( self:InCombat() and myPos:DistToSqr( self:GetEnemy():WorldSpaceCenter() ) )
		local myForward = self:GetForward()
		local dotView = ( validEnemy and 0.33 or 0.5 )
	
		local surroundings = self:FindInSphere( nil, 2000, function( ent )
			if !LambdaIsValid( ent ) or self:IsPanicking() then return false end
			if !self:CanTarget( ent ) then return false end
			if ent.IsLambdaPlayer and state == "Tranquilized" then return false end
	
			local selfName = getEntityName( self )
			local targetName = getEntityName( ent )
	
			if sightline then
				local entPos = ent:WorldSpaceCenter()
				local los = ( entPos - myPos ); los.z = 0
				los:Normalize()
				if los:Dot( myForward ) < dotView or eneDist and myPos:DistToSqr( entPos ) >= eneDist or !self:CanTarget( ent ) or !self:CanSee( ent ) then return false end
			end

			--PrintMessage( HUD_PRINTTALK, selfName .. ": I'm attacking " .. targetName )
	
			if defendMyself:GetBool() then
				DefendMyself( ent, self )
			end
	
			return ( self:IsInRange( ent, 2000 ) )
		end)
	
		if #surroundings > 0 then
			self:AttackTarget( surroundings[ random( #surroundings ) ] )
			self:PlaySoundFile( "taunt" )
		end
	end

	local function LambdaOnThink( self, wepent, isdead )
		if isdead then return end

		if CurTime() > self.l_NextEnemySearchT then
			self.l_NextEnemySearchT = CurTime() + Rand( 0.33, 1.0 )

			if attackOthers:GetBool() and !self:InCombat() then
				AttackVictim( self, true )
			end
		end
	end

	local function LambdaOnBeginMove( self, pos, onNavmesh )
		local state = self:GetState()
		if state != "Idle" and state != "FindTarget" then return end

		local behavior = random( 1 , 6 )
		-- behavior 1 = Path to a nearby LambdaPlayer or a targetable NPC
		-- behavior 2 = Instantly target a Lambdaplayer or a NPC (NEEDS SOME WORK)
		if behavior == 1 then
			if random( 100 ) <= 25 then
				if huntDown:GetBool() and attackOthers:GetBool() then
					for _, ent in RandomPairs( ents_GetAll() ) do
						if ent != self and self:CanTarget( ent ) then -- Let's find someone

							local targetName = getEntityName( ent )

							local rndPos = ( self:GetRandomPosition( ent:GetPos(), random( 150, 350 ) ) )
							self:SetRun( random( 3 ) == 1 )
							self:RecomputePath( rndPos )

							--PrintMessage( HUD_PRINTTALK, self:GetLambdaName() .. ": I'm looking to hurt " .. targetName )

							self:PlaySoundFile( "witness" )
							return
						end
					end
				end
			end

		elseif behavior == 2 then
			if attackOthers:GetBool() and attackOnMove:GetBool() and !self:InCombat() then
				AttackVictim( self, false )
			end
		end
	end

	hook_Add( "LambdaOnInitialize", "LambdaOnInitialize", LambdaOnInitialize )
	hook_Add( "LambdaOnThink", "OnThink", LambdaOnThink )
	hook_Add( "LambdaOnBeginMove", "OnBeginMove", LambdaOnBeginMove )
end